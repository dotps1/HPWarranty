<#
.SYNOPSIS
    Creates a session with HP ISEE Web Services.
.DESCRIPTION
    Creates a session with HP ISEE Web Services and returns the a Gdid and Token, which are necessary for Warranty Lookups.
.INPUTS
    None.
.OUTPUTS
    System.Management.Automation.PSObject.
.PARAMETER ComputerName
    The remote Hewlett-Packard Computer to retrieve WMI Information from.
.PARAMETER SerialNumber
    The serial number of the Hewlett-Packard System.
.PARAMETER ProductModel
    The product Model of the Hewlett-Packard System.
.EXAMPLE
    PS C:\> Invoke-HPWarrantyRegistrationRequest

    Name                           Value
    ----                           -----
    Token                          N0b2GQkmyM3CN23haBM6KSrnJ/VILMpnwwEjPFiuc8yQwDqtkig6Y1Z3j5Xyou2V4PTF1CbmxIljlZPCUaYjN/B4zDz3y8PugT2...
    Gdid                           0b0de1fc-1abc-2def-3ghi-aa76cbbe8e8b
.EXAMPLE
    PS C:\> Invoke-HPWarrantyRegistrationRequest -SerialNumber ABCDE12345 -ProductModel "HP ProBook 645 G1"

    Name                           Value
    ----                           -----
    Token                          N0b2GQkmyM3CN23haBM6KSrnJ/VILMpnwwEjPFiuc8yQwDqtkig6Y1Z3j5Xyou2V4PTF1CbmxIljlZPCUaYjN/B4zDz3y8PugT2...
    Gdid                           0b0de1fc-1abc-2def-3ghi-aa76cbbe8e8b
.NOTES
    Requires PowerShell V4.0
    A valid serial number and computer model are required to establish the session.
    Only one Registration Session needs to be established, the Gdid and Token can be reused for the Invoke-HPWarrantyLookup Cmdlet.
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
Function Invoke-HPWarrantyRegistrationRequest
{
    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(ParameterSetName = 'Default')]
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
        $ProductModel
    )
    
    if ($PSCmdlet.ParameterSetName -eq '__AllParameterSets' -or $PSCmdlet.ParameterSetName -eq 'Default')
    {
        try
        {
            $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace 'root\CIMV2' -Property 'Manufacturer' -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
            if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP')
            {
                $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
                $ProductModel = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop).Model.Trim()
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

    [Xml]$registrationSOAPRequest = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\RegistrationSOAPRequest.xml") `
        -replace '<UniversialDateTime>',$([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString('yyyy\/MM\/dd hh:mm:ss \G\M\T')) `
        -replace '<SerialNumber>',$SerialNumber.Trim() `
        -replace '<ProductModel>',$ProductModel.Trim()

    $registrationAction = Invoke-SOAPRequest -SOAPRequest $registrationSOAPRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

    return [PSObject] @{
        'Gdid'  = $registrationAction.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
        'Token' = $registrationAction.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
    }
}