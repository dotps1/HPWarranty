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
        if ($Script:HPEntRegistration.DateTime -lt (Get-Date).AddMinutes($Script:HPEntRegistration.ThresholdInMinutes)) {
		    $registrationRequest = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPEntWarrantyRegistration.xml").Replace(
                '<[!--UniversialDateTime--!]>', $([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString('yyyy\/MM\/dd hh:mm:ss \G\M\T'))
            ).Replace(
                '<[!--SerialNumber--!]>', $SerialNumber
            )

            [Xml]$registration = Invoke-HPEntSOAPRequest -SOAPRequest $registrationRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

            $Script:HPEntRegistration = @{
                Gdid = $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
                Token = $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
                DateTime = Get-Date
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
        for ($i = 0; $i -lt $ComputerName.Length; $i++) {
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                if ($null -ne ($systemInformation = Get-HPProductNumberAndSerialNumber -ComputerName $ComputerName[$i] -Credential $Credential)) {
                    $ProductNumber = $systemInformation.ProductNumber
                    $SerialNumber = $systemInformation.SerialNumber
                } else {
                    continue
                }
            } else {
                $ComputerName[$i] = $null
            }

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

			if ($null -ne $entitlement) {
                if ($null -ne $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError) {
                    Write-Error -Message $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError.ErrorText
                }
                if ($PSBoundParameters.ContainsKey('XmlExportPath')) {
                    try {
                        $entitlement.Save("${XmlExportPath}\${SerialNumber}_entitlement.xml")
                    } catch {
                        Write-Error -Message 'Failed to save xml file.'
                    }
                }
                
                [HashTable]$output = @{
                    'SerialNumber' = $SerialNumber
                    'ProductNumber' = $ProductNumber
                    'ActiveEntitlement' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.ActiveWarrantyEntitlement
                    'OverallEntitlementStartDate' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.OverallWarrantyStartDate
                    'OverallEntitlementEndDate' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.OverallWarrantyEndDate
                    'ActiveContractEntitlement' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.ActiveContractEntitlement
                    'OverallContractStartDate' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.OverallContractStartDate
                    'OverallContractEndDate' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.OverallContractEndDate
                    'SvcAgreementID' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.Contract.SvcAgreementID
                    'OfferDescription' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.Contract.Offer.OfferDescription
                    'ResponseTime' = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EsReply.CombinedUnitEntitlement.Contract.Offer.Modifier.ModDesc
		}

                if ($PSCmdlet.ParameterSetName -eq 'Computer') {
                    $output.Add('ComputerName', $ComputerName[$i])
                }

                Write-Output -InputObject $output
            } else {
                Write-Error -Message 'No entitlement found.'
                continue
            }
        }
    }
}
