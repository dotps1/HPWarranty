﻿#region ExportedFunctions

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
        [ValidateScript({ if (Test-Connection -ComputerName $_ -Quiet -Count 2) { $true } })]
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
            $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace "root\CIMV2" -Property "Manufacturer" -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
            if ($manufacturer -eq "Hewlett-Packard" -or $manufacturer -eq "HP")
            {
                $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
                $ProductModel = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop).Model.Trim()
            }
            else
            {
                throw "Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems."
            }
        }
        catch [System.Exception]
        {
            throw $_
        }
    }

    [Xml]$registrationSOAPRequest = (Get-Content "$PSScriptRoot\RegistrationSOAPRequest.xml") `
        -replace '<UniversialDateTime>',$([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString("yyyy\/MM\/dd hh:mm:ss \G\M\T")) `
        -replace '<SerialNumber>',$SerialNumber.Trim() `
        -replace '<ProductModel>',$ProductModel.Trim()

    $registrationAction = Invoke-SOAPRequest -SOAPRequest $registrationSOAPRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

    return [PSObject] @{
        'Gdid'  = $registrationAction.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
        'Token' = $registrationAction.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
    }
}

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
                   ValueFromPipeLineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'Static',
                   ValueFromPipeLineByPropertyName = $true)]
        [String]
        $Gdid,

        [Parameter(ParameterSetName = 'Default',
                   ValueFromPipeLineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'Static',
                   ValueFromPipeLineByPropertyName = $true)]
        [String]
        $Token,

        [Parameter(ParameterSetName = 'Default')]
        [ValidateScript({ if (Test-Connection -ComputerName $_ -Quiet -Count 2) { $true } })]
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
        [ValidateScript({ if (Test-Path -Path $_) { $true } })]
        [String]
        $PathToExportFullXml
    )

    if ($PSCmdlet.ParameterSetName -eq '__AllParameterSets' -or $PSCmdlet.ParameterSetName -eq 'Default')
    {
        try
        {
            $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace "root\CIMV2" -Property "Manufacturer" -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
            if ($manufacturer -eq "Hewlett-Packard" -or $manufacturer -eq "HP")
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
                throw "Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems."
            }
        }
        catch [System.Exception]
        {
            throw $_
        }
    }

    [Xml]$entitlementSOAPRequest = (Get-Content "$PSScriptRoot\EntitlementSOAPRequest.xml") `
        -replace '<Gdid>',$Gdid `
        -replace '<Token>',$Token `
        -replace '<Serial>',$SerialNumber.Trim() `
        -replace '<SKU>',$ProductID.Trim()

    $entitlementAction = Invoke-SOAPRequest -SOAPRequest $entitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
    $entitlement = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response)
    
    if ($PSBoundParameters.ContainsKey('PathToExportFullXml'))
    {
        if (-not ($PSBoundParameters.PathToExportFullXml.ToString().EndsWith("\")))
        {
            $PathToExportFullXml += "\"
        }

        $entitlement.Save($PathToExportFullXml + $SerialNumber + "_WarrantyEntitlement.xml")
    }

    return [PSObject] @{
        'SerialNumber' = $SerialNumber
        'ProductID' = $ProductID
        'ActiveWarrantyEntitlement' = $entitlement.GetElementsByTagName("ActiveWarrantyEntitlement").InnerText
        'OverallWarrantyStartDate' = $entitlement.GetElementsByTagName("OverallWarrantyStartDate").InnerText
        'OverallWarrantyEndDate' = $entitlement.GetElementsByTagName("OverallWarrantyEndDate").InnerText
        'OverallContractEndDate' = $entitlement.GetElementsByTagName("OverallContractEndDate").InnerText
        'WarrantyDeterminationDescription' = $entitlement.GetElementsByTagName("WarrantyDeterminationDescription").InnerText
        'GracePeriod' = $entitlement.GetElementsByTagName("GracePeriod").InnerText
    }
}

<#
.SYNOPSIS
    Queries ConfigMgr Database for Information needed to query the Hewlett-Packard Servers for Warranty Information.
.DESCRIPTION
    Queries inventoried information from Microsoft System Center Configuration manager for data to allow for bulk Hewlett-Packard Warranty Lookups.
.INPUTS
    None.
.OUTPUTS
    System.Array.
.PARAMETER SqlServer
    The SQL Server containing the ConfigMgr database.
.PARAMETER ConnectionPort
    Port to connect to SQL server with, default value is 1433.
.PARAMETER Database
    The name of the ConfigMgr database.
.PARAMETER IntergratedSecurity
    Use the currently logged on users credentials.
.EXAMPLE
    PS C:\> Get-HPComputerInformationForWarrantyFromCMDB -Database CM_ABC -IntergratedSecurity

    ComputerName        : ComputerA
    Username            : UserA
    ADSiteName          : ADSiteA
    LastHardwareScan    : 1/1/2015 12:00:00 AM
    ProductManufacturer : Hewlett-Packard
    ProductID           : ABCDE123#ABA
    SerialNumber        : ABCDE12345
    ProductModel        : HP ProBook 1000 G1

    ComputerName        : ComputerB
    Username            : UserB
    ADSiteName          : ADSiteB
    LastHardwareScan    : 1/1/2014 12:00:00 AM
    ProductManufacturer : Hewlett-Packard
    ProductID           : 123ABCDE#BAB
    SerialNumber        : 12345ABCDE
    ProductModel        : HP EliteBook 5000
.EXAMPLE
    PS C:\> Get-HPComputerInformationForWarrantyFromCMDB -SqlServer localhost -Database ConfigMgr -IntergratedSecurity

    ComputerName        : ComputerA
    Username            : UserA
    ADSiteName          : ADSiteA
    LastHardwareScan    : 1/1/2015 12:00:00 AM
    ProductManufacturer : Hewlett-Packard
    ProductID           : ABCDE123#ABA
    SerialNumber        : ABCDE12345
    ProductModel        : HP ProBook 1000 G1

    ComputerName        : ComputerB
    Username            : UserB
    ADSiteName          : ADSiteB
    LastHardwareScan    : 1/1/2015 12:00:00 AM
    ProductManufacturer : Hewlett-Packard
    ProductID           : ABCDE123#ABA
    SerialNumber        : ABCDE12345
    ProductModel        : HP ProBook 1000 G1
.NOTES
    The root\WMI MS_SystemInformation needs to be inventoried into ConfigMgr so the Product ID/Number (SKU) can be retireved.
.LINK
    http://dotps1.github.io
#>
Function Get-HPComputerInformationForWarrantyFromCMDB
{
    [CmdletBinding()]
    [OutputType([Array])]
    Param
    (
        [Parameter()]
        [ValidateScript({ if (Test-Connection -ComputerName $_ -Quiet -Count 2) { $true } })]
        [String]
        $SqlServer = $env:COMPUTERNAME,

        [ValidateRange(1,50009)]
        [Alias("Port")]
        [Int] 
        $ConnectionPort = 1433,

        [Parameter(Mandatory = $true)]
        [Alias("CMDB")]
        [String]
        $Database,

        [Parameter()]
        [Switch]
        $IntergratedSecurity
    )

   $sqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection -Property @{ ConnectionString = "Server=$SqlServer,$ConnectionPort;Database=$Database;" }

    if ($IntergratedSecurity.IsPresent)
    {
        $sqlConnection.ConnectionString += "Integrated Security=true;"
    }
    else
    {
        $sqlCredentials = Get-Credential
        $sqlConnection.ConnectionString += "User ID=$($sqlCredentials.Username);Password=$($sqlCredentials.GetNetworkCredential().Password);"
    }
    
    try
    {
        $sqlConnection.Open()
    }
    catch [System.Exception]
    {
        throw $_
    }

    $sql = "SELECT Computer_System_DATA.Name00                    AS ComputerName,
                   Computer_System_Data.UserName00                AS Username,
	               PC_BIOS_DATA.SerialNumber00                    AS SerialNumber,
	               MS_SYSTEMINFORMATION_DATA.SystemSKU00          AS ProductID,
	               MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 AS ProductManufacturer,
	               MS_SYSTEMINFORMATION_DATA.SystemProductName00  AS ProductModel,
                   System_DISC.AD_Site_Name0                      AS ADSiteName,
                   WorkstationStatus_DATA.LastHWScan			  AS LastHardwareScan
              FROM MS_SYSTEMINFORMATION_DATA
	               JOIN Computer_System_Data   ON MS_SYSTEMINFORMATION_DATA.MachineID = Computer_System_DATA.MachineID
	               JOIN PC_BIOS_DATA           ON MS_SYSTEMINFORMATION_DATA.MachineID = PC_BIOS_DATA.MachineID
                   JOIN System_DISC            ON MS_SYSTEMINFORMATION_DATA.MachineID = System_DISC.ItemKey
                   JOIN WorkstationStatus_DATA ON MS_SYSTEMINFORMATION_DATA.MachineID = WorkstationStatus_DATA.MachineID
	          WHERE MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'HP' 
	             OR MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'Hewlett-Packard'
	            AND PC_BIOS_DATA.SerialNumber00 <> ' '
                AND MS_SYSTEMINFORMATION_DATA.SystemSKU00 <> ' ' 
	            AND MS_SYSTEMINFORMATION_DATA.SystemProductName00 <> ' '
              ORDER BY WorkstationStatus_DATA.LastHWScan"

    $results = (New-Object -TypeName System.Data.SqlClient.SqlCommand -Property @{ CommandText = $sql; Connection = $sqlConnection }).ExecuteReader()
    
    if ($results.HasRows)
    {
        While ($results.Read())
        {
            $results.GetEnumerator() | %{ New-Object -TypeName PSObject -Property @{ ComputerName = $_["ComputerName"]
                                                                                     Username = $_["Username"]
                                                                                     SerialNumber = $_["SerialNumber"]
                                                                                     ProductID = $_["ProductID"]
                                                                                     ProductManufacturer = $_["ProductManufacturer"]
                                                                                     ProductModel = $_["ProductModel"]
                                                                                     ADSiteName = $_["ADSiteName"]
                                                                                     LastHardwareScan = $_["LastHardwareScan"] } }
        }
	}
	
    $results.Close()
    $sqlConnection.Close()
}

#endregion ExportedFunctions

 #region HelperFunctions

<#
.SYNOPSIS
    Executes a SOAP Request.
.DESCRIPTION
    Sends a SOAP Request to Hewlett-Packard ISEE Servers to either create a Registration GDID and Token, or retrieve Warranty Info.
.INPUTS
    None.
.OUTPUTS
    System.Xml
.PARAMETER SOAPRequest
    The Xml Formatted request to be sent.
.PARAMETER Url
    The ISEE URL to send the SOAP request.
.PARAMETER Action
    The ISEE Action to be performed.
.EXAMPLE
    Invoke-SOAPRequest -SOAPRequest $registrationSOAPRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'
.EXAMPLE
    Invoke-SOAPRequest -SOAPRequest $entitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
.NOTES
    This module contains two XML douments used for the -SOAPRequest Parameter.
    RegistrationSOAPRequest.xml (See Invoke-HPWarrantyRegistrationRequest Cmdlet)
    EntitlementSOAPRequest.xml (See Invoke-HPWarrantyLookup Cmdlet).
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
Function Invoke-SOAPRequest 
{
    [CmdletBinding()]
    [OutputType([Xml])]
    Param 
    (
        [Parameter(Mandatory = $true)]
        [Xml]
        $SOAPRequest,

        [Parameter(Mandatory = $true)]
        [ValidateSet('https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx','https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx')]
        [String]
        $URL,

        [Parameter(Mandatory = $true)]
        [ValidateSet('http://www.hp.com/isee/webservices/RegisterClient2','http://www.hp.com/isee/webservices/GetOOSEntitlementList2')]
        [String]
        $Action
    )

    $soapWebRequest = [System.Net.WebRequest]::Create($URL) 
    $soapWebRequest.Headers.Add("SOAPAction",$Action)

    $soapWebRequest.ContentType = 'text/xml; charset=utf-8'
    $soapWebRequest.Accept = "text/xml" 
    $soapWebRequest.Method = "POST" 
    $soapWebRequest.UserAgent = 'RemoteSupport/A.05.05 - gSOAP/2.7'

    $soapWebRequest.Timeout = 30000
    $soapWebRequest.ServicePoint.Expect100Continue = $false
    $soapWebRequest.ServicePoint.MaxIdleTime = 2000
    $soapWebRequest.ProtocolVersion = [system.net.httpversion]::version10

    $requestStream = $soapWebRequest.GetRequestStream() 
    $SOAPRequest.Save($requestStream) 
    
    $requestStream.Close() 

    $responseStream = ($soapWebRequest.GetResponse()).GetResponseStream() 
    
    $soapReader = [System.IO.StreamReader]($responseStream) 
    $ReturnXml = [Xml]$soapReader.ReadToEnd() 
    
    $responseStream.Close() 

    return $ReturnXml 
}

#endregion HelperFunctions