Function Get-HPWorkstationWarrantyEntitlement {
    
    [OutputType([PSCustomObject])]
    
	Param (
		[Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
		[String]
        $SerialNumber,

		[Parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true
        )]
		[String]
        $ProductNumber,

		[Parameter()]
		[String]
        $CountryCode = 'US',

		[Parameter()]
        [String]
        [ValidateNotNullOrEmpty()]
        $XmlExportPath = $null
	)

    Begin {
        $request = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPWorkstaionWarrantyEntitlement.xml").Replace(
            '<[!--EntitlementCheckDate--!]>', (Get-Date -Format 'yyyy-MM-dd')
        ).Replace(
            '<[!--CountryCode--!]>', $CountryCode
        )
    }

    Process {
        try {
            [xml]$entitlement = Invoke-RestMethod -Body $request.Replace(
                '<[!--SerialNumber--!]>', $SerialNumber
            ).Replace(
                '<[!--ProductNumber--!]>', $ProductNumber
            ) -Uri 'https://entitlement-ext.corp.hp.com/es/ES10_1/ESListener'  -ContentType 'text/html' -Method Post -ErrorAction Stop
        } catch {
            throw 'Failed to invoke rest method.'
        }

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
}