Function Get-HPWarrantyEntitlement {
    
    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([PSCustomObject])]
    
	Param (
        [Parameter(
            ParameterSetName = 'Default',
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

        [Parameter(
            ParameterSetName = '__AllParameterSets'
        )]
		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
		[String]
        $CountryCode = 'US',

        [Parameter(
            ParameterSetName = '__AllParameterSets'
        )]
		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
        [String]
        [ValidateNotNullOrEmpty()]
        $XmlExportPath = $null
	)

    Begin {
        [Xml]$registration = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPWarrantyRegistration.xml").Replace(
            '<[!--UniversialDateTime--!]>',$([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString('yyyy\/MM\/dd hh:mm:ss \G\M\T'))
        )

        $registration = Invoke-SOAPRequest -SOAPRequest $registration -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'
        
        $request = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPWarrantyEntitlement.xml").Replace(
            '<[!--Gdid--!]>', $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
        ).Replace(
            '<[!--Token--!]>', $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
        ).Replace(
            '<[!--CountryCode--!]>', $CountryCode
        )
    }

    Process {
        foreach ($c in $ComputerName) {
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                if (($systemInformation = Get-HPProductNumberAndSerialNumber -ComputerName $c) -ne $null) {
                    $ProductNumber = $systemInformation.ProductNumber
                    $SerialNumber = $systemInformation.SerialNumber
                } else {
                    continue
                }
            }

            try {
                $entitlementAction = Invoke-SOAPRequest -SOAPRequest $request.Replace(
                    '<[!--ProductNumber--!]>', $ProductNumber
                ).Replace(
                    '<[!--SerialNumber--!]>', $SerialNumber
                ) -Url 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
                $entitlement = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response) 
            } catch {
                Write-Error -Message 'Failed to invoke SOAP request.'
                continue
            }

            if ($entitlement -ne $null) {
                if ($entitlement.GetElementsByTagName('ErrorID').InnerText -ne $null) {
                    Write-Error -Message $($entitlement.GetElementsByTagName('DataPayLoad').InnerText) -ErrorId $($entitlement.GetElementsByTagName('ErrorID').InnerText)
                    continue
                } else {
                    if ($PSBoundParameters.ContainsKey('XmlExportPath')) {
                        try {
                            $entitlement.Save("$XmlExportPath\${SerialNumber}_entitlement.xml")
                        } catch {
                            Write-Error -Message 'Failed to save xml file.'
                        }
                    }

                    [PSCustomObject]@{
                        'SerialNumber' = $SerialNumber
                        'ProductNumber' = $ProductNumber
                        'ProductLineDescription' = $entitlement.GetElementsByTagName('ProductLineDescription').InnerText
                        'ProductLineCode' = $entitlement.GetElementsByTagName('ProductLineCode').InnerText
                        'ActiveWarrantyEntitlement' = $entitlement.GetElementsByTagName('ActiveWarrantyEntitlement').InnerText
                        'OverallWarrantyStartDate' = $entitlement.GetElementsByTagName('OverallWarrantyStartDate').InnerText
                        'OverallWarrantyEndDate' = $entitlement.GetElementsByTagName('OverallWarrantyEndDate').InnerText
                        'OverallContractEndDate' = $entitlement.GetElementsByTagName('OverallContractEndDate').InnerText
                        'WarrantyDeterminationDescription' = $entitlement.GetElementsByTagName('WarrantyDeterminationDescription').InnerText
                        'WarrantyDeterminationCode' = $entitlement.GetElementsByTagName('WarrantyDeterminationCode').InnerText
                        'WarrantyExtension' = $entitlement.GetElementsByTagName('WarrantyExtension').InnerText
                        'GracePeriod' = $entitlement.GetElementsByTagName('WarrantyExtension').InnerText
                    }
                }
            } else {
                Write-Error -Message 'No entitlement found.'
                continue
            }
        }
    }
}