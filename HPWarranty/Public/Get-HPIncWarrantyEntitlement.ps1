Function Get-HPIncWarrantyEntitlement {
    
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
            ValueFromPipelineByPropertyName = $true
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
        [ValidateNotNullOrEmpty()]
        [String]
        $XmlExportPath = $null
	)

    Begin {
        $request = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPIncWarrantyEntitlement.xml").Replace(
            '<[!--CountryCode--!]>', $CountryCode
        )
    }

    Process {
        for ($i = 0; $i -lt $ComputerName.Length; $i++) {
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                if (($systemInformation = Get-HPProductNumberAndSerialNumber -ComputerName $ComputerName[$i]) -ne $null) {
                    $SerialNumber = $systemInformation.SerialNumber
                    $ProductNumber = $systemInformation.ProductNumber
                } else {
                    continue
                }
            } else {
                $ComputerName[$i] = $null
            }

            try {
                [Xml]$entitlement = Invoke-HPIncSoapRequest -SOAPRequest $request.Replace(
                    '<[!--SerialNumber--!]>', $SerialNumber
                ).Replace(
                    '<[!--ProductNumber--!]>', $ProductNumber
                ) -ErrorAction Stop
            } catch {
                Write-Error -Message 'Failed to invoke rest method.'
                continue
            }

            if ($entitlement -ne $null) {
                if ($entitlement.GetElementsByTagName('ErrorID').InnerText -ne $null) {
                    Write-Error -Message $($entitlement.GetElementsByTagName('DataPayLoad').InnerText) -ErrorId $($entitlement.GetElementsByTagName('ErrorID').InnerText)
                    continue
                } else {
                    if ($PSBoundParameters.ContainsKey('XmlExportPath')) {
                        try {
                            $entitlement.Save("${XmlExportPath}\${SerialNumber}_entitlement.xml")
                        } catch {
                            Write-Error -Message 'Failed to save xml file.'
                        }
                    }

                    [PSCustomObject]@{
                        'ComputerName' = $ComputerName[$i]
                        'SerialNumber' = $SerialNumber
                        'ProductNumber' = $ProductNumber
                        'ProductLineDescription' = $entitlement.GetElementsByTagName('productLineDescription').InnerText
                        'ProductLineCode' = $entitlement.GetElementsByTagName('productLineCode').InnerText
                        'ServiceObligationHardwareActiveIndicator' = $entitlement.GetElementsByTagName('serviceObligationHardwareActiveIndicator').InnerText
                        'ServiceObligationStartDate' = $entitlement.GetElementsByTagName('serviceObligationStartDate').InnerText
                        'ServiceObligationEndDate' = $entitlement.GetElementsByTagName('serviceObligationEndDate').InnerText
                        'DateSourceCode' = $entitlement.GetElementsByTagName('dateSourceCode').InnerText
                        'DateSourceDescription' = $entitlement.GetElementsByTagName('dateSourceDescription').InnerText
                        'WarrantyIdentifierCode' = $entitlement.GetElementsByTagName('warrantyIdentifierCode').InnerText
                    }
                }
            } else {
                Write-Error -Message 'No entitlement found.'
                continue
            }
        }
    }
}