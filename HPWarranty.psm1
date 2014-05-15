function Invoke-SOAPRequest 
{
    [CmdletBinding()]
    [OutputType([Xml])]
    Param 
    (
        # SOAPRequest, Type Xml, The request to be sent.
        [Parameter(Mandatory=$true,
                    Position=0)]
        [Xml]
        $SOAPRequest,

        # URL, Type String, The URL to send the SOAP request.
        [Parameter(Mandatory=$true,
                    Position=1)]
        [ValidateSet('https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx','https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx')]
        [String]
        $URL,

        # Action, Type String, The Acction to be performed.
        [Parameter(Mandatory=$true,
                    Position=2)]
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
    https://github.com/ocdnix/hpisee
    https://github.com/PowerShellSith
    Twitter: @PowerShellSith
#>
function Invoke-HPWarrantyRegistrationRequest
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # SerialNumber, Type String, The serial number of the Hewlett-Packard System.
        [Parameter(Position=0)]
        [ValidateLength(10,10)]
        [String]
        $SerialNumber=(Get-WmiObject -Class Win32_Bios).SerialNumber,

        # ProductModel, Type String, The product Model of the Hewlett-Packard System.
        [Parameter(Position=1)]
        [String]
        $ProductModel=(Get-WmiObject -Class Win32_ComputerSystem).Model,

        # ComputerName, Type String, The remote Hewlett-Packard Computer.
        [Parameter(ParameterSetName='RemoteComputer')]
        [String]
        $ComputerName
    )
    
    if ($ComputerName)
    {
        try
        {
            $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber
            $ProductModel = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop).Model
        }
        catch
        {
            throw "Unable to retrieve WMI Information from $ComputerName."
        }
    }

[Xml]$registrationSOAPRequest = @"
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:iseeReg="http://www.hp.com/isee/webservices/">
<SOAP-ENV:Body>
    <iseeReg:RegisterClient2>
    <iseeReg:request>&lt;isee:ISEE-Registration xmlns:isee="http://www.hp.com/schemas/isee/5.00/event" schemaVersion="5.00"&gt;
&lt;RegistrationSource&gt;
    &lt;HP_OOSIdentifiers&gt;
    &lt;OSID&gt;
        &lt;Section name="SYSTEM_IDENTIFIERS"&gt;
        &lt;Property name="TimestampGenerated" value="$(Get-Date ((Get-Date).ToUniversalTime()) -Format 'yyyy/MM/dd HH:mm:ss \G\M\T')"/&gt;
        &lt;/Section&gt;
    &lt;/OSID&gt;
    &lt;CSID&gt;
        &lt;Section name="SYSTEM_IDENTIFIERS"&gt;
        &lt;Property name="CollectorType" value="MC3"/&gt;
        &lt;Property name="CollectorVersion" value="T05.80.1 build 1"/&gt;
        &lt;Property name="AutoDetectedSystemSerialNumber" value="$SerialNumber"/&gt;
        &lt;Property name="SystemModel" value="$ProductModel"/&gt;
        &lt;Property name="TimestampGenerated" value="$(Get-Date ((Get-Date).ToUniversalTime()) -Format 'yyyy/MM/dd HH:mm:ss \G\M\T')"/&gt;
        &lt;/Section&gt;
    &lt;/CSID&gt;
    &lt;/HP_OOSIdentifiers&gt;
    &lt;PRS_Address&gt;
    &lt;AddressType&gt;0&lt;/AddressType&gt;
    &lt;Address1/&gt;
    &lt;Address2/&gt;
    &lt;Address3/&gt;
    &lt;Address4/&gt;
    &lt;City/&gt;
    &lt;Region/&gt;
    &lt;PostalCode/&gt;
    &lt;TimeZone/&gt;
    &lt;Country/&gt;
    &lt;/PRS_Address&gt;
&lt;/RegistrationSource&gt;
&lt;HP_ISEECustomer&gt;
    &lt;Business/&gt;
    &lt;Name/&gt;
&lt;/HP_ISEECustomer&gt;
&lt;HP_ISEEPerson&gt;
    &lt;CommunicationMode&gt;255&lt;/CommunicationMode&gt;
    &lt;ContactType/&gt;
    &lt;FirstName/&gt;
    &lt;LastName/&gt;
    &lt;Salutation/&gt;
    &lt;Title/&gt;
    &lt;EmailAddress/&gt;
    &lt;TelephoneNumber/&gt;
    &lt;PreferredLanguage/&gt;
    &lt;Availability/&gt;
&lt;/HP_ISEEPerson&gt;
&lt;/isee:ISEE-Registration&gt;</iseeReg:request>
    </iseeReg:RegisterClient2>
</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@

    $registrationAction = Invoke-SOAPRequest -SOAPRequest $registrationSOAPRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2'

    [PSObject]$registration = @{
                                    'Gdid' = $registrationAction.envelope.body.RegisterClient2Response.RegisterClient2Result.Gdid
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
    https://github.com/ocdnix/hpisee
    https://github.com/PowerShellSith
    Twitter: @PowerShellSith
#>
function Invoke-HPWarrantyLookup
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # Gdid, Type String, The Gdid Identitfier of the session with the HP ISEE Service.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [String]
        $Gdid,

        # Token, Type String, The Token of the session with the HP ISEE Service.
        [Parameter(Mandatory=$true,
                   Position=1)]
        [String]
        $Token,

        # SerialNumber, Type String, The serial number of the Hewlett-Packard System.
        [Parameter(Position=2)]
        [ValidateLength(10,10)]
        [String]
        $SerialNumber=(Get-WmiObject -Class Win32_Bios).SerialNumber,

        # ProductNumber, Type String, The product number (SKU) of the Hewlett-Packard System.
        [Parameter(Position=3)]
        [String]
        $ProductNumber=(Get-WmiObject -Namespace root\WMI MS_SystemInformation).SystemSKU,

        # ComputerName, Type String, The remote Hewlett-Packard Computer.
        [Parameter(ParameterSetName='RemoteComputer')]
        [String]
        $ComputerName
    )

    if ($ComputerName)
    {
        try
        {
            $SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber
            $ProductNumber = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU
        }
        catch
        {
            throw "Unable to retrieve WMI Information from $ComputerName."
        }
    }

    [Xml]$entitlementSOAPRequest = @"
<SOAP-ENV:Envelope
    xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:isee="http://www.hp.com/isee/webservices/">
  <SOAP-ENV:Header>
    <isee:IseeWebServicesHeader>
      <isee:GDID>$Gdid</isee:GDID>
      <isee:registrationToken>$Token</isee:registrationToken>
      <isee:OSID/>
      <isee:CSID/>
    </isee:IseeWebServicesHeader>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <isee:GetOOSEntitlementList2>
      <isee:request>
        &lt;isee:ISEE-GetOOSEntitlementInfoRequest
    xmlns:isee="http://www.hp.com/schemas/isee/5.00/entitlement"
    schemaVersion="5.00"&gt;
  &lt;HP_ISEEEntitlementParameters&gt;
    &lt;CountryCode&gt;ES&lt;/CountryCode&gt;
    &lt;SerialNumber&gt;$SerialNumber&lt;/SerialNumber&gt;
    &lt;ProductNumber&gt;$ProductNumber&lt;/ProductNumber&gt;
    &lt;EntitlementType&gt;&lt;/EntitlementType&gt;
    &lt;EntitlementId&gt;&lt;/EntitlementId&gt;
    &lt;ObligationId&gt;&lt;/ObligationId&gt;
  &lt;/HP_ISEEEntitlementParameters&gt;
&lt;/isee:ISEE-GetOOSEntitlementInfoRequest&gt;
      </isee:request>
    </isee:GetOOSEntitlementList2>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@

    $entitlementAction = Invoke-SOAPRequest -SOAPRequest $EntitlementSOAPRequest -URL 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'

    [PSObject]$warranty = @{
                                'SerialNumber' = $SerialNumber
                                'WarrantyStartDate' = ([Xml]$entitlementAction.Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response).GetElementsByTagName("WarrantyStartDate").InnerText
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
    Get-ComputerInformationForHPWarrantyInformation -IntergratedSecurity
.EXAMPLE
    Get-ComputerInformationForHPWarrantyInformation -SqlServer localhost -Database ConfigMgr -IntergratedSecurity
.NOTES
    The root\WMI MS_SystemInformation needs to be inventoried into ConfigMgr so the Product Number (SKU) can be retireved.
.LINK
    https://github.com/PowerShellSith
    Twitter: @PowerShellSith
#>
function Get-HPComputerInformationForWarrantyRequestFromCCMDB
{
    [CmdletBinding()]
    [OutputType([Array])]
    Param
    (
        # SqlServer, Type string, The SQL Server containing the ConfigMgr database.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]
        $SqlServer=$env:COMPUTERNAME,

        # ConnectionPort, Type int, Port to connect to SQL server with, defualt value is 1433.
        [parameter(Position=1)]
        [ValidateRange(1,50009)]
        [Alias("Port")]
        [int]
        $ConnectionPort=1433,

        # Database, Type string, The name of the ConfigMgr database.
        [Parameter(Mandatory=$true,
                   Position=2)]
        [string]
        $Database,

        # IntergratedSecurity, Type switch, Use the currently logged on users credentials.
        [switch]
        $IntergratedSecurity
    )

    $sqlConnection=New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString="Server=$SqlServer,$ConnectionPort;Database=$Database;Integrated Security="
    if ($IntergratedSecurity)
    {
        $sqlConnection.ConnectionString+="true;"
    }
    else
    {
        $sqlCredentials=Get-Credential
        $sqlConnection.ConnectionString+="false;User ID=$($sqlCredentials.Username);Password=$($sqlCredentials.GetNetworkCredential().Password);"
    }
    
    try
    {
        $sqlConnection.Open()
    }
    catch
    {
        throw $Error[0].Exception.Message
    }

    $sqlCMD=New-Object System.Data.SqlClient.SqlCommand
    $sqlCMD.CommandText= "SELECT Computer_System_DATA.Name00                     AS ComputerName,
	                             PC_BIOS_DATA.SerialNumber00                     AS SerialNumber,
	                             MS_SYSTEMINFORMATION_DATA.SystemSKU00           AS ProductNumber,
	                             MS_SYSTEMINFORMATION_DATA.SystemManufacturer00  AS ProductManufacturer,
	                             MS_SYSTEMINFORMATION_DATA.SystemProductName00   AS ProductModel,
	                             Computer_System_Data.TimeKey					 AS LastCommunicationTime
                         FROM MS_SYSTEMINFORMATION_DATA
	                         JOIN  Computer_System_Data ON MS_SYSTEMINFORMATION_DATA.MachineID = Computer_System_DATA.MachineID
	                         JOIN  PC_BIOS_DATA         ON MS_SYSTEMINFORMATION_DATA.MachineID = PC_BIOS_DATA.MachineID
	                         WHERE MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'HP' 
	                         OR    MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'Hewlett-Packard'
	                         AND   MS_SYSTEMINFORMATION_DATA.SystemSKU00 <> ' ' 
	                         AND   MS_SYSTEMINFORMATION_DATA.SystemProductName00 <> ' '
                         ORDER BY MS_SYSTEMINFORMATION_DATA.BaseBoardProduct00"

    $sqlCMD.Connection = $sqlConnection
    $results = $sqlCMD.ExecuteReader()
    
    if ($results.HasRows)
    {
        While ($results.Read())
        {
            $results.GetEnumerator() | %{ New-Object -TypeName PSObject -Property @{ComputerName = $_["ComputerName"]
                                                                                    SerialNumber = $_["SerialNumber"]
                                                                                    ProductNumber = $_["ProductNumber"]
                                                                                    ProductManufacturer = $_["ProductManufacturer"]
                                                                                    ProductModel = $_["ProductModel"]
                                                                                    LastCommunicationTime = $_["LastCommunicationTime"]
                                                                                    }}
        }
    }

    $results.Close()
    $sqlConnection.Close()
}