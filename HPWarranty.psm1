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

<#
.SYNOPSIS
    Creates a session with HP ISEE Web Servies.
.DESCRIPTION
    Creates a session with HP ISEE Web Servies and returns the necassary information send Requests.
.INPUTS
    None.
.OUTPUTS
    System.Management.Automation.PSObject.
.PARAMETER ComputerName
    The remote Hewlett-Packard Computer to retrive WMI Information from.
.PARAMETER SerialNumber
    The serial number of the Hewlett-Packard System.
.PARAMETER ProductModel
    The product Model of the Hewlett-Packard System.
.EXAMPLE
    Invoke-HPWarrantyRegistrationRequest
.EXAMPLE
    Invoke-HPWarrantyRegistrationRequest -SerialNumber ABCDE12345 -ProductModel "HP ProBook 645 G1"
.NOTES
    Requires PowerShell V4.0
    A valid serial number and computer model are required to establish the session.
    Only one Registration Session needs to be established, the the Gdid and Token can be reused for the Invoke-HPWarrantyLookup Cmdlet.
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
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(ParameterSetName = 'Default')]
        [ValidateScript({ if (Test-Connection -ComputerName $_ -Quiet -Count 2) { $true } })]
        [String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [ValidateLength(10,10)]
        [Alias("SN")]
        [String]
        $SerialNumber,

        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [Alias("PN")]
        [String]
        $ProductModel
    )
    
    if (-not ($PSBoundParameters.ContainsKey('SerialNumber') -and $PSBoundParameters.ContainsKey('ProductModel')))
    {
        try
        {
            if ((Get-WmiObject -Class Win32_ComputerSystem -Namespace "root\CIMV2" -Property "Manufacturer" -ComputerName $ComputerName -ErrorAction Stop).Manufacturer -eq "Hewlett-Packard" -or (Get-WmiObject -Class Win32_ComputerSystem -Namespace "root\CIMV2" -Property "Manufacturer" -ComputerName $ComputerName -ErrorAction Stop).Manufacturer -eq "HP")
            {
                $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber
                $ProductModel = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop).Model
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

    [Xml]$registrationSOAPRequest = (Get-Content "$PSScriptRoot\RegistrationSOAPRequest.xml") -replace "<UniversialDateTime>",$([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString("yyyy/MM/dd hh:mm:ss \G\M\T")) `
        -replace '<SerialNumber>',$SerialNumber.Trim() `
        -replace '<ProductModel>',$ProductModel.Trim()

    $registrationAction = Invoke-SOAPRequest -SOAPRequest $registrationSOAPRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

    return [PSObject] @{
        'Gdid'  = $registrationAction.envelope.body.RegisterClient2Response.RegisterClient2Result.Gdid
        'Token' = $registrationAction.envelope.body.RegisterClient2Response.RegisterClient2Result.registrationtoken
    }
}

<#
.SYNOPSIS
    Uses the HP ISEE Web Services to retrive warranty information.
.DESCRIPTION
    Retrives the start date, standard end date and extened end date warranty information for an Hewlett-Packard system.
.INPUTS
    None.
.OUTPUTS
    System.Management.Automation.PSObject.
.PARAMETER Gdid
    The Gdid Identitfier of the session with the HP ISEE Service.
.PARAMETER Token
    The Token of the session with the HP ISEE Service.
.PARAMETER ComputerName
    The remote Hewlett-Packard Computer to retrive WMI Information from.
.PARAMETER SerialNumber
    The serial number of a Hewlett-Packard System.
.PARAMETER ProductNumber
    The product number or (SKU) of a Hewlett-Packard System.
.EXAMPLE
    Invoke-HPWarrantyEntitlementList
.EXAMPLE
    $registration = Invoke-HPWarrantyRegistrationRequest; Invoke-HPWarrantyEntitlementList -Gdid $registration.Gdid -Token $registration.Token
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
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSObject])]
    Param
    (
        [Parameter()]
        [String]
        $Gdid,

        [Parameter()]
        [String]
        $Token,

        [Parameter(ParameterSetName = 'Default')]
        [ValidateScript({ if (Test-Connection -ComputerName $_ -Quiet -Count 2) { $true } })]
        [String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [ValidateLength(10,10)]
        [Alias("SN")]
        [String]
        $SerialNumber,

        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [Alias("PN")]
        [String]
        $ProductNumber
    )

    if (-not ($PSBoundParameters.ContainsKey('SerialNumber') -and $PSBoundParameters.ContainsKey('ProductNumber')))
    {
        try
        {
            if((Get-WmiObject -Class Win32_ComputerSystem -Namespace "root\CIMV2" -Property "Manufacturer" -ComputerName $ComputerName -ErrorAction Stop).Manufacturer -eq "Hewlett-Packard" -or (Get-WmiObject -Class Win32_ComputerSystem -Namespace "root\CIMV2" -Property "Manufacturer" -ComputerName $ComputerName -ErrorAction Stop).Manufacturer -eq "HP")
            {
                $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber
                $ProductNumber = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU

                if (-not($PSBoundParameters.ContainsValue($Gdid)) -or -not($PSBoundParameters.ContainsValue($Token)))
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

    [Xml]$entitlementSOAPRequest = (Get-Content "$PSScriptRoot\EntitlementSOAPRequest.xml")`
        -replace '<Gdid>',$Gdid `
        -replace '<Token>',$Token `
        -replace '<Serial>',$SerialNumber.Trim() `
        -replace '<SKU>',$ProductNumber.Trim()

    $entitlementAction = Invoke-SOAPRequest -SOAPRequest $entitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'

    return [PSObject] @{
        'SerialNumber'            = $SerialNumber
        'ProductNumber'           = $ProductNumber
        'WarrantyStartDate'       = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("WarrantyStartDate").InnerText
        'WarrantyStandardEndDate' = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("EndDate").InnerText[1]
        'WarrantyExtendedEndDate' = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("EndDate").InnerText[0]
        'WarrantyCarePackEndDate' = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("EndDate").InnerText[2]
    }
}

<#
.SYNOPSIS
    Queries ConfigMgr Database for Information needed to query the Hewlett-Packard Servers for Warranty Information.
.DESCRIPTION
    Queries inventored information from Microsoft System Center Configuration manager for data to allow for bulk Hewlett-Packard Warranty Lookups.
.INPUTS
    None.
.OUTPUTS
    System.Array.
.PARAMETER SqlServer
    The SQL Server containing the ConfigMgr database.
.PARAMETER ConnectionPort
    Port to connect to SQL server with, defualt value is 1433.
.PARAMETER Database
    The name of the ConfigMgr database.
.PARAMETER IntergratedSecurity
    Use the currently logged on users credentials.
.EXAMPLE
    Get-HPComputerInformationForWarrantyFromCMDB -Database CM_ABC -IntergratedSecurity
.EXAMPLE
    Get-HPComputerInformationForWarrantyFromCMDB -SqlServer localhost -Database ConfigMgr -IntergratedSecurity
.NOTES
    The root\WMI MS_SystemInformation needs to be inventoried into ConfigMgr so the Product Number (SKU) can be retireved.
.LINK
    http://dotps1.github.io
#>
Function Get-HPComputerInformationForWarrantyFromCMDB
{
    [CmdletBinding()]
    [OutputType([Array])]
    Param
    (
        [Parameter(Mandatory = $true)]
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
	               MS_SYSTEMINFORMATION_DATA.SystemSKU00          AS ProductNumber,
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
            $results.GetEnumerator() | %{ New-Object -TypeName PSObject -Property @{ ComputerName        = $_["ComputerName"]
                                                                                     Username            = $_["Username"]
                                                                                     SerialNumber        = $_["SerialNumber"]
                                                                                     ProductNumber       = $_["ProductNumber"]
                                                                                     ProductManufacturer = $_["ProductManufacturer"]
                                                                                     ProductModel        = $_["ProductModel"]
                                                                                     ADSiteName          = $_["ADSiteName"]
                                                                                     LastHardwareScan    = $_["LastHardwareScan"] } }
        }
	}
	
    $results.Close()
    $sqlConnection.Close()
}