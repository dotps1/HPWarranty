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