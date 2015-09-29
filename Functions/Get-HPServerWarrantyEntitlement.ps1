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
        $ProductNumber,

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

    if (-not $PSCmdlet.ParameterSetName -eq 'Static') {
        try {
            $reg = Invoke-HPWarrantyRegistrationRequest -ComputerName $ComputerName
            $gdid = $reg.Gdid
            $token = $reg.Token

            $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
            $ProductID = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU.Trim()
        } catch {
            throw $_
        }
    }

    [Xml]$entitlementSOAPRequest = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPServerWarrantyEntitlement.xml").Replace(
        '<[!--Gdid--!]>',$gdid
    ).Replace(
        '<[!--Token--!]>',$token
    ).Replace(
        '<[!--Serial--!]>',$SerialNumber
    ).Replace(
        '<[!--ProductID--!]>',$ProductNumber
    )

    $entitlementAction = Invoke-SOAPRequest -SOAPRequest $entitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
    $entitlement = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response)


    return [PSObject] @{
        'SerialNumber' = $SerialNumber
        'ProductNumber' = $ProductNumber
        'ActiveWarrantyEntitlement' = $entitlement.GetElementsByTagName('ActiveWarrantyEntitlement').InnerText
        'OverallWarrantyStartDate' = $entitlement.GetElementsByTagName('OverallWarrantyStartDate').InnerText
        'OverallWarrantyEndDate' = $entitlement.GetElementsByTagName('OverallWarrantyEndDate').InnerText
        'OverallContractEndDate' = $entitlement.GetElementsByTagName('OverallContractEndDate').InnerText
        'WarrantyDeterminationDescription' = $entitlement.GetElementsByTagName('WarrantyDeterminationDescription').InnerText
        'GracePeriod' = $entitlement.GetElementsByTagName('GracePeriod').InnerText
    }
}