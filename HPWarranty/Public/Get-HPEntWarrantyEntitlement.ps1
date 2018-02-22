Function Get-HPEntWarrantyEntitlement {
    
    [CmdletBinding(
        DefaultParameterSetName = '__AllParameterSets'
    )]
    [OutputType(
        [HashTable]
    )]
    
	Param (
        [Parameter(
            ParameterSetName = 'Computer',
            ValueFromPipeline = $true
        )]
        [ValidateScript({
            if ($_ -eq $env:COMPUTERNAME) { 
                $true 
            } else { 
                try { 
                    Test-Connection -ComputerName $_ -Count 1 -ErrorAction Stop
                    $true 
                } catch { 
                    throw "Unable to connect to $_." 
                }
            }
        })]
        [String[]]
        $ComputerName = $env:ComputerName,

        [Parameter(
            ParameterSetName = 'Computer'
        )]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = $null,

		[Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipeLineByPropertyName = $true
        )]
		[String]
        $ProductNumber,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipelineByPropertyName = $true
        )]
		[String]
        $SerialNumber,

		[Parameter()]
		[String]
        $CountryCode = 'US',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $XmlExportPath = $null
	)

    Begin {
        if ((Get-Date) -gt $Script:HPEntRegistration.TokenRenewDate ) {
            $registrationRequest = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPEntWarrantyRegistration.xml").Replace(
                '<[!--UniversialDateTime--!]>', $([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString('yyyy\/MM\/dd hh:mm:ss \G\M\T'))
            ).Replace(
                '<[!--SerialNumber--!]>', $SerialNumber
            )
            write-verbose "Connecting to HP Instant Support"
            [Xml]$registration = Invoke-HPEntSOAPRequest -SOAPRequest $registrationRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

            $Script:HPEntRegistration = @{
                Gdid = $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
                Token = $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
                TokenRenewDate = (Get-Date).addminutes($Script:HPEntRegistration.ThresholdInMinutes)
            }
        }

        
        $request = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPEntWarrantyEntitlement.xml").Replace(
            '<[!--Gdid--!]>', $Script:HPEntRegistration.Gdid
        ).Replace(
            '<[!--Token--!]>', $Script:HPEntRegistration.Token
        ).Replace(
            '<[!--CountryCode--!]>', $CountryCode
        )
    }

    Process {
        foreach ($ComputerNameItem in $ComputerName) {
            
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                $systemInformation = Get-HPProductNumberAndSerialNumber -ComputerName $ComputerNameItem -Credential $Credential
                if ($systemInformation) {
                    $ProductNumber = $systemInformation.ProductNumber
                    $SerialNumber = $systemInformation.SerialNumber
                } else {
                    write-error "Unable to retrieve product information from $ComputerName. Verify your credentials are correct and the device is reachable"
                    continue
                }            
            }

            write-verbose "Looking up device with Product ID $ProductNumber and Serial Number $SerialNumber"
            try {
                [Xml]$entitlement = (
                    Invoke-HPEntSOAPRequest -SOAPRequest $request.Replace(
                        '<[!--ProductNumber--!]>', $ProductNumber
                    ).Replace(
                        '<[!--SerialNumber--!]>', $SerialNumber
                    ) -Url 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
                ).Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response
            } catch {
                Write-Error -Message 'Failed to invoke SOAP request.'
                continue
            }

            if ($DebugPreference -eq 'Inquire') {
                Write-Debug -Message 'Returning raw xml.'
                return $entitlement
            }

			if ($entitlement) {
                if ($entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError) {
                    Write-Error -Message $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError.ErrorText
                }
                if ($PSBoundParameters.ContainsKey('XmlExportPath')) {
                    try {
                        $entitlement.Save("${XmlExportPath}\${SerialNumber}_entitlement.xml")
                    } catch {
                        Write-Error -Message 'Failed to save xml file.'
                    }
                }
                
                $output = [ordered]@{
                    'SerialNumber' = $SerialNumber
                    'ProductNumber' = $ProductNumber
                    'ActiveEntitlement' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.ActiveWarrantyEntitlement
                    'OverallEntitlementStartDate' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.OverallWarrantyStartDate
                    'OverallEntitlementEndDate' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.OverallWarrantyEndDate
                }

                if ($PSCmdlet.ParameterSetName -eq 'Computer') {
                    $output.computername = $ComputerName[$i]
                } else {
                    $output.computername = $null
                }

                [PSCustomObject]$output
            } else {
                Write-Error -Message 'No entitlement found.'
                continue
            }
        }
    }
}
