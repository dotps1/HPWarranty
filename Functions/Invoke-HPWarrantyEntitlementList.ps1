<#
.SYNOPSIS
    Uses the HP ISEE Web Services to retrieve warranty information.
.DESCRIPTION
    Retrives the start date, standard end date and extened end date warranty information for an Hewlett-Packard system.
.INPUTS
    System.String.
.OUTPUTS
    System.Management.Automation.PSObject.
.PARAMETER Gdid
    The Gdid Identifier of the session with the HP ISEE Service.
.PARAMETER Token
    The Token of the session with the HP ISEE Service.
.PARAMETER ComputerName
    The remote Hewlett-Packard Computer to retrieve WMI Information from.
.PARAMETER SerialNumber
    The serial number of a Hewlett-Packard System.
.PARAMETER ProductID
    The product ID/number or (SKU) of a Hewlett-Packard System.
.PARAMETER PathToExportFullXml
    Specify a full path to export the entire entitlement response for the system.
.EXAMPLE
    PS C:\> Invoke-HPWarrantyEntitlementList -PathToExportFullXml "$env:USERPROFILE\Desktop\"

    Name                           Value
    ----                           -----
    GracePeriod                    30
    ProductID                      ABCD123#ABA
    WarrantyDeterminationDescri... Serial Number decode
    OverallWarrantyEndDate         2015-01-01
    OverallWarrantyStartDate       2011-01-01
    SerialNumber                   ABCDE12345
    OverallContractEndDate
    ActiveWarrantyEntitlement      false
.EXAMPLE
    PS C:\> $registration = Invoke-HPWarrantyRegistrationRequest; Invoke-HPWarrantyEntitlementList -Gdid $registration.Gdid -Token $registration.Token

    Name                           Value
    ----                           -----
    GracePeriod                    30
    ProductID                      ABCD123#ABA
    WarrantyDeterminationDescri... Serial Number decode
    OverallWarrantyEndDate         2015-01-01
    OverallWarrantyStartDate       2011-01-01
    SerialNumber                   ABCDE12345
    OverallContractEndDate
    ActiveWarrantyEntitlement      false
.EXAMPLE
    PS C:\> Invoke-HPWarrantyRegistrationRequest -SerialNumber abcde12345 -ProductModel "HP Laptop" | Invoke-HPWarrantyEntitlementList -Gdid $_.Gdid -Token $_.Token -SerialNumber abcde12345 -ProductID "ABCD123#ABA"

    Name                           Value
    ----                           -----
    GracePeriod                    30
    ProductID                      ABCD123#ABA
    WarrantyDeterminationDescri... Ship date
    OverallWarrantyEndDate         2016-01-01
    OverallWarrantyStartDate       2012-01-01
    SerialNumber                   ABCDE12345
    OverallContractEndDate
    ActiveWarrantyEntitlement      true
.NOTES
    Requires PowerShell V4.0
    A valid Gdid and Token are required to used this cmdlet.
    Credits to:
        StackOverFlow:OneLogicalMyth
        StackOverFlow:user3076063
        ocdnix HP ISEE PoC Dev
        Steve Schofield Microsoft MVP - IIS
.LINK
    http://stackoverflow.com/questions/19503442/hp-warranty-lookup-using-powershell-soap
.LINK
    http://ocdnix.wordpress.com/2013/03/14/hp-server-warranty-via-the-isee-api/
.LINK
    http://www.iislogs.com/steveschofield/execute-a-soap-request-from-powershell
.LINK
    http://dotps1.github.io
#>
Function Invoke-HPWarrantyEntitlementList
{
    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(ParameterSetName = 'Default',
                   ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'Static',
                   ValueFromPipelineByPropertyName = $true)]
        [String]
        $Gdid,

        [Parameter(ParameterSetName = 'Default',
                   ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'Static',
                   ValueFromPipelineByPropertyName = $true)]
        [String]
        $Token,

        [Parameter(ParameterSetName = 'Default',
                   ValueFromPipeline = $true)]
        [ValidateScript({ if ($_ -eq $env:COMPUTERNAME){ $true } else { try { Test-Connection -ComputerName $_ -Count 2 -ErrorAction Stop ; $true } catch { throw "Unable to connect to $_." } } })]
        [String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [String]
        $SerialNumber,

        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [String]
        $ProductID,
        
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Static')]
        [String]
        $PathToExportFullXml
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