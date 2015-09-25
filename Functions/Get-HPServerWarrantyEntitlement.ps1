Function Get-HPServerWarrantyEntitlement {
    
    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([PSObject])]
    
    Param (
        [Parameter(
            ParameterSetName = 'Remote',
            ValueFromPipeline = $true
        )]
        [String]
        $ComputerName = $env:COMPUTERNAME,

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
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $ProductID,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipeLineByPropertyName = $true
        )]
        [String]
        $ProductModel,
        
		[Parameter(
            ParameterSetName = 'Remote'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
        [String]
        [ValidateNotNullOrEmpty()]
        $XmlExportPath
    )

    if ($PSCmdlet.ParameterSetName -eq '__AllParameterSets' -or $PSCmdlet.ParameterSetName -eq 'Default')
    {
        try
        {
            $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace 'root\CIMV2' -Property 'Manufacturer' -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
            if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP')
            {
                $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
                $ProductID = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU.Trim()

                if (-not ($PSBoundParameters.ContainsKey('Gdid')) -or -not ($PSBoundParameters.ContainsKey('Token')))
                {
                    $reg = Invoke-HPWarrantyRegistrationRequest -ComputerName $ComputerName
                    $Gdid = $reg.Gdid
                    $Token = $reg.Token
                }
            }
            else
            {
                throw 'Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems.'
            }
        }
        catch
        {
            throw $_
        }
    }

    [Xml]$entitlementSOAPRequest = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\EntitlementSOAPRequest.xml") `
        -replace '<Gdid>',$Gdid `
        -replace '<Token>',$Token `
        -replace '<Serial>',$SerialNumber.Trim() `
        -replace '<SKU>',$ProductID.Trim()

    $entitlementAction = Invoke-SOAPRequest -SOAPRequest $entitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
    $entitlement = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response)

    if ($PSBoundParameters.ContainsKey('PathToExportFullXml'))
    {
        if (-not ($PathToExportFullXml.EndsWith('.xml')))
        {
            $PathToExportFullXml += '.xml'
        }

        try
        {
            $entitlement.Save($PathToExportFullXml)
        }
        catch
        {
            Write-Error -Message $_.ToString()
        }
    }

    return [PSObject] @{
        'SerialNumber' = $SerialNumber
        'ProductID' = $ProductID
        'ActiveWarrantyEntitlement' = $entitlement.GetElementsByTagName('ActiveWarrantyEntitlement').InnerText
        'OverallWarrantyStartDate' = $entitlement.GetElementsByTagName('OverallWarrantyStartDate').InnerText
        'OverallWarrantyEndDate' = $entitlement.GetElementsByTagName('OverallWarrantyEndDate').InnerText
        'OverallContractEndDate' = $entitlement.GetElementsByTagName('OverallContractEndDate').InnerText
        'WarrantyDeterminationDescription' = $entitlement.GetElementsByTagName('WarrantyDeterminationDescription').InnerText
        'GracePeriod' = $entitlement.GetElementsByTagName('GracePeriod').InnerText
    }
}