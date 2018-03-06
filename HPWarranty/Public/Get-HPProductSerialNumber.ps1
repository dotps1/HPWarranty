<#
    .SYNOPSIS
        Get the Product Number (SKU) and Serial Number from a system.
    .DESCRIPTION
        Query the local or remote system for its Product Number (SKU) and Serial Number.
        This function will first identify based on open ports whether this is a Windows or VMware system
        And then query using the appropriate management interface
    .EXAMPLE
        Get-HPProductAndSerialNumber
    
    .EXAMPLE
        Get-HPProductAndSerialNumber MyVMWareHost -esxcredential (Get-Credential)
        Retrieves the specified information from a VMware host, prompting for root credentials
#>

Function Get-HPProductSerialNumber {
    
    [CmdletBinding()]
    [OutputType(
        [HashTable]
    )]

    Param (
        #The hostname or IP address you wish to query. Defaults to the local computer
        [Parameter(Position=1,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [String]
        $ComputerName = $env:ComputerName,

        #The credentials you wish to use when connecting. Defaults to your logged in Windows Account if on a windows system.
        [Parameter()]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = $null,

        #The credentials to use on ESX servers. Specify this if they are different than the default credentials you specify.
        [Parameter()]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $ESXCredential
    )
    write-verbose "$Computername`: Attempting to retrieve Product Number and Serial Number automatically. Beginning Discovery..."

    #Detect if it is a Windows Server by checking for MSRPC port
    if ((test-port $ComputerName -port 135 -tcptimeout 2000 -verbose:$false).open) {
        write-verbose "Windows Server Detected! Retrieving Product and Serial Number via WMI CIM"
        try {
            $cimSession = New-CimSession -ComputerName $ComputerName -Credential $Credential -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop -verbose:$false
            $manufacturer = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem -verbose:$false -ErrorAction Stop | 
                Select-Object -ExpandProperty Manufacturer

            if ($manufacturer -match 'Hewlett-Packard|HP') {
                return @{
                    SerialNumber = (Get-CimInstance -CimSession $cimSession -Class 'Win32_Bios' -verbose:$false -ErrorAction Stop).SerialNumber.Trim()
                    ProductNumber = (Get-CimInstance -CimSession $cimSession -Class 'MS_SystemInformation' -verbose:$false -Namespace 'root\WMI' -ErrorAction Stop).SystemSKU.Trim()
                }
            } else {
                Write-Error -Message 'Computer Manufacturer is not of type Hewlett-Packard, HP, or HPE.  This cmdlet can only be used with HP systems.'
                return $null
            }
        } catch {
            $_
            Write-Error -Message "Failed to retrive SerialNumber and ProductNumber from $ComputerName."
            return $null
        }
    }
    elseif ((test-port $ComputerName -port 902 -tcptimeout 2000 -verbose:$false).open) {
        write-verbose "VMware ESXi Server Detected!"

        $CIMSessionParams = @{
            Port = '443'
            Authentication = 'Basic'
            Verbose = $false
            ComputerName = $ComputerName
            Credential = if ($ESXCredential) {$ESXcredential} elseif ($null -eq $Credential) {$ESXCredential = Get-Credential -Username "root" -Message "Please specify ESXi root credentials for $ComputerName";$ESXCredential} else {$Credential}
            SessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding utf8 -UseSsl
        }
        try {
            $CIMSession = New-CimSession @CimSessionParams -erroraction stop
            $ServerInfo = Get-CimInstance -cimsession $CIMSession -classname CIM_PhysicalPackage -erroraction stop -verbose:$false | 
                where elementname -match 'Chassis' | 
                select -first 1 manufacturer,
                    model,
                    serialnumber,
                    @{N="productnumber";E={($PSItem.oemspecificstrings -match '^Product ID:') -replace '^Product ID: *([^ ]+) *$','$1'}}

            if ($ServerInfo.manufacturer -notmatch 'HP|Hewlett-Packard') {
                Write-Error -Message "$ComputerName`: Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems."
                return $null
            } 
            return @{
                SerialNumber = $ServerInfo.SerialNumber
                ProductNumber = $ServerInfo.ProductNumber
            }
        }
        catch {
            Write-Error -Message "Failed to retrieve SerialNumber and ProductNumber from $ComputerName."
            return $null
        }
    } else {
        write-error "Could not connect to the target device. Verify if it is a Windows server that port 135 is accessible and if it is a VMware server that ports 902 and 443 are accessible"
    }
}