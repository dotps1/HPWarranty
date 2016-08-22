Function  Get-HPSystemInformationFromCMDB {
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
        $IntegratedSecurity,

        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias(
            'Name'
        )]
        [String[]]
        $ComputerName = '%'
    )

   $sqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection -Property @{ 
        ConnectionString = "Server=$SqlServer,$ConnectionPort;Database=$Database;" 
    }

    if ($IntegratedSecurity.IsPresent) {
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

    $tableExists = (New-Object -TypeName System.Data.SqlClient.SqlCommand -Property @{
        Connection = $sqlConnection
        CommandText = "SELECT COUNT (*) FROM information_schema.tables WHERE table_name = 'MS_SYSTEMINFORMATION_DATA'"
    }).ExecuteScalar()
    
    if ($tableExists -eq 0) {
        Write-Error -Exception System.InvalidOperationException -Message 'The table MS_SYSTEMINFORMATION_DATA does not exist.' -Category InvalidOperation -RecommendedAction 'The MS_SYSTEMINFORMATION_DATA must be inventoried with the SCCM Client to use this cmdlet.'
        return
    }

    for ($i = 0; $i -lt $ComputerName.Length; $i++) {
        $results = (New-Object -TypeName System.Data.SqlClient.SqlCommand -Property @{ 
            Connection = $sqlConnection
            CommandText = `
                "SELECT Computer_System_DATA.Name00                    AS ComputerName,
                        Computer_System_Data.UserName00                AS Username,
	                    PC_BIOS_DATA.SerialNumber00                    AS SerialNumber,
	                    MS_SYSTEMINFORMATION_DATA.SystemSKU00          AS ProductNumber,
	                    MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 AS ProductManufacturer,
	                    MS_SYSTEMINFORMATION_DATA.SystemProductName00  AS ProductModel,
                        System_DISC.AD_Site_Name0                      AS ADSiteName,
                        WorkstationStatus_DATA.LastHWScan			   AS LastHardwareScan
                        FROM MS_SYSTEMINFORMATION_DATA
	                        JOIN Computer_System_Data   ON MS_SYSTEMINFORMATION_DATA.MachineID = Computer_System_DATA.MachineID
	                        JOIN PC_BIOS_DATA           ON MS_SYSTEMINFORMATION_DATA.MachineID = PC_BIOS_DATA.MachineID
                            JOIN System_DISC            ON MS_SYSTEMINFORMATION_DATA.MachineID = System_DISC.ItemKey
                            JOIN WorkstationStatus_DATA ON MS_SYSTEMINFORMATION_DATA.MachineID = WorkstationStatus_DATA.MachineID
	                    WHERE (MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'HP' 
	                           OR MS_SYSTEMINFORMATION_DATA.SystemManufacturer00 = 'Hewlett-Packard')
	                    AND PC_BIOS_DATA.SerialNumber00 <> ' '
                        AND MS_SYSTEMINFORMATION_DATA.SystemSKU00 <> ' ' 
                        AND Computer_System_DATA.Name00 LIKE '%$($ComputerName[$i])%'
                        ORDER BY WorkstationStatus_DATA.LastHWScan"
        }).ExecuteReader()
    
        if ($results.HasRows) {
            $results.GetEnumerator() | ForEach-Object { 
                New-Object -TypeName PSCustomObject -Property @{
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
	
        $results.Close()
    }

    $sqlConnection.Close()
}
