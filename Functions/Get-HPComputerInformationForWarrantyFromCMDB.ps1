Function Get-HPComputerInformationForWarrantyFromCMDB {
    
    [OutputType([Array])]
    
    Param (
        [Parameter()]
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
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateRange(
            1,50009
        )]
        [Int] 
        $ConnectionPort = 1433,

        [Parameter(
            Mandatory = $true
        )]
        [String]
        $Database,

        [Parameter()]
        [Switch]
        $IntergratedSecurity
    )

   $sqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection -Property @{ 
        ConnectionString = "Server=$SqlServer,$ConnectionPort;Database=$Database;" 
    }

    if ($IntergratedSecurity.IsPresent) {
        $sqlConnection.ConnectionString += "Integrated Security=true;"
    } else {
        $sqlCredentials = Get-Credential
        $sqlConnection.ConnectionString += "User ID=$($sqlCredentials.Username);Password=$($sqlCredentials.GetNetworkCredential().Password);"
    }
    
    try {
        $sqlConnection.Open()
    } catch {
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

    $results = (New-Object -TypeName System.Data.SqlClient.SqlCommand -Property @{
        CommandText = $sql 
        Connection = $sqlConnection 
    }).ExecuteReader()
    
    if ($results.HasRows) {
        while ($results.Read()) {
            $results.GetEnumerator() | ForEach-Object { 
                New-Object -TypeName PSObject -Property @{
                    ComputerName = $_["ComputerName"]
                    Username = $_["Username"]
                    SerialNumber = $_["SerialNumber"]
                    ProductNumber = $_["ProductNumber"]
                    ProductManufacturer = $_["ProductManufacturer"]
                    ProductModel = $_["ProductModel"]
                    ADSiteName = $_["ADSiteName"]
                    LastHardwareScan = $_["LastHardwareScan"] 
                } 
            }
        }
	}
	
    $results.Close()
    $sqlConnection.Close()
}