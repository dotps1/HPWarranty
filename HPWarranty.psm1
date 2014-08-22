function Invoke-SOAPRequest 
{
    [CmdletBinding()]
    [OutputType([Xml])]
    Param 
    (
        # SOAPRequest, Type Xml, The request to be sent.
        [Parameter(Mandatory = $true)]
        [Xml]
        $SOAPRequest,

        # URL, Type String, The URL to send the SOAP request.
        [Parameter(Mandatory = $true)]
        [ValidateSet('https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx','https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx')]
        [String]
        $URL,

        # Action, Type String, The Acction to be performed.
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
.EXAMPLE
    Invoke-HPWarrantyRegistrationRequest
.EXAMPLE
    Invoke-HPWarrantyRegistrationRequest -SerialNumber ABCDE12345 -ProductModel "HP ProBook 645 G1"
.NOTES
    Requires PowerShell V4.0
    A valid serial number and computer model are required to establish the session.
    Only one Registration Session needs to be established, the the Gdid and Token can be reused for the Excute-HPWarrantyLookup cmdlet.
    Credits to:
        StackOverFlow:OneLogicalMyth
        StackOverFlow:user3076063
        ocdnix HP ISEE PoC Dev
        Steve Schofield Microsoft MVP - IIS
.LINK
    http://stackoverflow.com/questions/19503442/hp-warranty-lookup-using-powershell-soap
    http://ocdnix.wordpress.com/2013/03/14/hp-server-warranty-via-the-isee-api/
    http://www.iislogs.com/steveschofield/execute-a-soap-request-from-powershell
    http://dotps1.github.io
    Twitter: @dotps1
#>
function Invoke-HPWarrantyRegistrationRequest
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSObject])]
    Param
    (
        # ComputerName, Type String, The remote Hewlett-Packard Computer.
        [Parameter(ParameterSetName = 'Default')]
        [ValidateScript({ if (-not(Test-Connection -ComputerName $_ -Quiet -Count 2)) { throw "Failed to connect to $_.  Please ensure the system is available." } else { $true } })]
        [String]
        $ComputerName = $env:COMPUTERNAME,

        # SerialNumber, Type String, The serial number of the Hewlett-Packard System.
        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [ValidateLength(10,10)]
        [Alias("SN")]
        [String]
        $SerialNumber,

        # ProductModel, Type String, The product Model of the Hewlett-Packard System.
        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [Alias("PN")]
        [String]
        $ProductModel
    )
    
    if (-not($PSBoundParameters.ContainsValue($SerialNumber) -and $PSBoundParameters.ContainsValue($ProductModel)))
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
        catch
        {
            throw "Unable to retrieve WMI Information from $ComputerName."
        }
    }

    $UTC = Get-Date ((Get-Date).ToUniversalTime()) -Format 'yyyy/MM/dd HH:mm:ss \G\M\T'
    [Xml]$registrationSOAPRequest = (Get-Content "$PSScriptRoot\RegistrationSOAPRequest.xml") -replace "<UniversialDateTime>","`"$($UTC)`"" `
        -replace '<SerialNumber>', "`"$($SerialNumber)`"" `
        -replace '<ProductModel>',"`"$($ProductModel)`""

    $registrationAction = Invoke-SOAPRequest -SOAPRequest $registrationSOAPRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

    [PSObject]$registration = @{
        'Gdid'  = $registrationAction.envelope.body.RegisterClient2Response.RegisterClient2Result.Gdid
        'Token' = $registrationAction.envelope.body.RegisterClient2Response.RegisterClient2Result.registrationtoken
    }

    return $registration
}

<#
.SYNOPSIS
    Uses the HP ISEE Web Services to retrive warranty information.
.DESCRIPTION
    Retrives the start date, standard end date and extened end date warranty information for an Hewlett-Packard system.
.EXAMPLE
    $registration = Invoke-HPWarrantyRegistrationRequest; Invoke-HPWarrantyLookup -Gdid $registration.Gdid -Token $registration.Token
.EXAMPLE
    $registration = Invoke-HPWarrantyRegistrationRequest; Invoke-HPWarrantyLookup -Gdid $registration.Gdid -Token $registration.Token -SerialNumber AABBCCD123 -ProductNumber F2R10UT#ABA
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
    http://ocdnix.wordpress.com/2013/03/14/hp-server-warranty-via-the-isee-api/
    http://www.iislogs.com/steveschofield/execute-a-soap-request-from-powershell
    http://dotps1.github.io
    Twitter: @dotps1
#>
function Invoke-HPWarrantyLookup
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSObject])]
    Param
    (
        # Gdid, Type String, The Gdid Identitfier of the session with the HP ISEE Service.
        [String]
        $Gdid,

        # Token, Type String, The Token of the session with the HP ISEE Service.
        [String]
        $Token,

        # ComputerName, Type String, The remote Hewlett-Packard Computer.
        [Parameter(ParameterSetName = 'Default')]
        [ValidateScript({ if (-not(Test-Connection -ComputerName $_ -Quiet -Count 2)) { throw "Failed to connect to $_.  Please ensure the system is available." } else { $true } })]
        [String]
        $ComputerName = $env:COMPUTERNAME,

        # SerialNumber, Type String, The serial number of the Hewlett-Packard System.
        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [ValidateLength(10,10)]
        [Alias("SN")]
        [String]
        $SerialNumber,

        # ProductNumber, Type String, The product number (SKU) of the Hewlett-Packard System.
        [Parameter(ParameterSetName = 'Static',
                   Mandatory = $true)]
        [Alias("PN")]
        [String]
        $ProductNumber
    )

    if (-not($PSBoundParameters.ContainsValue($SerialNumber) -and $PSBoundParameters.ContainsValue($ProductNumber)))
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
        catch
        {
            throw "Unable to retrieve WMI Information from $ComputerName."
        }
    }

    [Xml]$entitlementSOAPRequest = (Get-Content "$PSScriptRoot\EntitlementSOAPRequest.xml") -replace '<Gdid>',$Gdid `
        -replace '<Token>',$Token `
        -replace '<Serial>',$SerialNumber `
        -replace '<SKU>',$ProductNumber

    $global:var = $entitlementSOAPRequest

    $entitlementAction = Invoke-SOAPRequest -SOAPRequest $entitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'

    [PSObject]$warranty = @{
        'SerialNumber'            = $SerialNumber
        'WarrantyStartDate'       = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("WarrantyStartDate").InnerText
        'WarrantyStandardEndDate' = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("EndDate").InnerText[1]
        'WarrantyExtendedEndDate' = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("EndDate").InnerText[0]
    }
    
    if ($warranty -ne $null)
    {
        return $warranty
    }
}

<#
.SYNOPSIS
    Queries ConfigMgr Database for Information needed to query the Hewlett-Packard Servers for Warranty Information.
.DESCRIPTION

.EXAMPLE
    Get-ComputerInformationForHPWarrantyInformationFromCMDB -IntergratedSecurity
.EXAMPLE
    Get-ComputerInformationForHPWarrantyInformationFromCMDB -SqlServer localhost -Database ConfigMgr -IntergratedSecurity
.NOTES
    The root\WMI MS_SystemInformation needs to be inventoried into ConfigMgr so the Product Number (SKU) can be retireved.
.LINK
    http://dotps1.github.io
    Twitter: @dotps1
#>
function Get-HPComputerInformationForWarrantyRequestFromCMDB
{
    [CmdletBinding()]
    [OutputType([Array])]
    Param
    (
        # SqlServer, Type String, The SQL Server containing the ConfigMgr database.
        [Parameter(Mandatory = $true)]
        [ValidateScript({ if (-not(Test-Connection -ComputerName $_ -Quiet -Count 2)) { throw "Failed to connect to $_.  Please ensure the system is available." } else { $true } })]
        [String]
        $SqlServer = $env:COMPUTERNAME,

        # ConnectionPort, Type Int, Port to connect to SQL server with, defualt value is 1433.
        [ValidateRange(1,50009)]
        [Alias("Port")]
        [Int]
        $ConnectionPort = 1433,

        # Database, Type String, The name of the ConfigMgr database.
        [Parameter(Mandatory = $true)]
        [Alias("CMDB")]
        [String]
        $Database,

        # IntergratedSecurity, Type Switch, Use the currently logged on users credentials.
        [Switch]
        $IntergratedSecurity
    )

    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString="Server=$SqlServer,$ConnectionPort;Database=$Database;Integrated Security="
    if ($IntergratedSecurity)
    {
        $sqlConnection.ConnectionString +="true;"
    }
    else
    {
        $sqlCredentials = Get-Credential
        $sqlConnection.ConnectionString += "false;User ID=$($sqlCredentials.Username);Password=$($sqlCredentials.GetNetworkCredential().Password);"
    }
    
    try
    {
        $sqlConnection.Open()
    }
    catch
    {
        throw $Error[0].Exception.Message
    }

    $sqlCMD = New-Object System.Data.SqlClient.SqlCommand
    $sqlCMD.CommandText = "SELECT Computer_System_DATA.Name00                    AS ComputerName,
                                  Computer_System_Data.UserName00                AS Username,
	                              PC_BIOS_DATA.SerialNumber00                    AS SerialNumber,
	                              MS_SYSTEMINFORMATION_DATA.SystemSKU00          AS ProductNumber,
	                              MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 AS ProductManufacturer,
	                              MS_SYSTEMINFORMATION_DATA.SystemProductName00  AS ProductModel,
                                  System_DISC.AD_Site_Name0                      AS ADSiteName,
                                  WorkstationStatus_DATA.LastHWScan				 AS LastHardwareScan
                           FROM MS_SYSTEMINFORMATION_DATA
	                           JOIN Computer_System_Data   ON MS_SYSTEMINFORMATION_DATA.MachineID = Computer_System_DATA.MachineID
	                           JOIN PC_BIOS_DATA           ON MS_SYSTEMINFORMATION_DATA.MachineID = PC_BIOS_DATA.MachineID
                               JOIN System_DISC            ON MS_SYSTEMINFORMATION_DATA.MachineID = System_DISC.ItemKey
                               JOIN WorkstationStatus_DATA ON MS_SYSTEMINFORMATION_DATA.MachineID = WorkstationStatus_DATA.MachineID
	                       WHERE MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'HP' 
	                           OR  MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'Hewlett-Packard'
	                           AND MS_SYSTEMINFORMATION_DATA.SystemSKU00 <> ' ' 
	                           AND MS_SYSTEMINFORMATION_DATA.SystemProductName00 <> ' '
                           ORDER BY WorkstationStatus_DATA.LastHWScan"

    $sqlCMD.Connection = $sqlConnection
    $results = $sqlCMD.ExecuteReader()
    
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