Function Get-HPServerWarrantyEntitlement {
    
    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([PSCustomObject])]
    
	Param (
        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipeLine = $true
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
        [String]
        $ComputerName = $env:ComputerName,

		[Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipelineByPropertyName = $true
        )]
		[String]
        $SerialNumber,

		[Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipeLineByPropertyName = $true
        )]
		[String]
        $ProductNumber,

		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
        [String]
        [ValidateNotNullOrEmpty()]
        $XmlExportPath
	)

    Begin {
        [Xml]$registration = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPServerWarrantyRegistration.xml").Replace(
            '<[!--UniversialDateTime--!]>',$([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString('yyyy\/MM\/dd hh:mm:ss \G\M\T'))
        )

        $registration = Invoke-SOAPRequest -SOAPRequest $registration -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'
        
        $request = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPServerWarrantyEntitlement.xml").Replace(
            '<[!--Gdid--!]>', $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
        ).Replace(
            '<[!--Token--!]>', $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
        )
    }

    Process {
        if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
            try {
                $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace 'root\CIMV2' -Property 'Manufacturer' -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
                if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP') {
                    $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
                    $ProductNumber = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU.Trim()
                } else {
                    throw 'Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems.'
                }
            } catch {
                throw "Failed to retrive SerailNumber and ProductID from $ComputerName."
            }
        }

        $request = $request.Replace(
            '<[!--SerialNumber--!]>', $SerialNumber
        ).Replace(
            '<[!--ProductNumber--!]>', $ProductNumber
        )

        try {
            $entitlementAction = Invoke-SOAPRequest -SOAPRequest $request -Url 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2' 
            $entitlement = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response) 
        } catch {
            throw 'Failed to invoke SOAP request.'
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