<#
    .SYNOPSIS
        Get the Product Number (SKU) and Serial Number from a system.
    .DESCRIPTION
        Query the local or remote system for its Product Number (SKU) and Serial Number, return that object in a HashTable.
    .INPUTS
        None.
    .OUTPUTS
        System.Collections.HashTable
    .PARAMETER ComputerName
        The system to query.
    .PARAMETER Credential
        PSCredential object to authenticate with.
    .LINK
        http://dotps1.github.io/HPWarranty
#>

Function Get-HPProductNumberAndSerialNumber {
    
    [CmdletBinding()]
    [OutputType(
        [HashTable]
    )]

    Param (
        [Parameter()]
        [String]
        $ComputerName = $env:ComputerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = $null,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $ESXCredential = $null
    )
    write-verbose "$Computername`: Attempting to retrieve Product Number and Serial Number automatically. Beginning Discovery..."

    #Detect if it is a Windows Server by checking for MSRPC port
    if ((test-port $ComputerName -port 135 -tcptimeout 2000 -verbose:$false).open) {
        write-verbose "Windows Server Detected! Retrieving Product and Serial Number"
        try {
            $cimSession = New-CimSession -ComputerName $ComputerName -Credential $Credential -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop
            $manufacturer = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem -ErrorAction Stop | 
                Select-Object -ExpandProperty Manufacturer

            if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP') {
                return @{
                    SerialNumber = (Get-CimInstance -CimSession $cimSession -Class 'Win32_Bios' -ErrorAction Stop).SerialNumber.Trim()
                    ProductNumber = (Get-CimInstance -CimSession $cimSession -Class 'MS_SystemInformation' -Namespace 'root\WMI' -ErrorAction Stop).SystemSKU.Trim()
                }
            } else {
                Write-Error -Message 'Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems.'
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
            Credential = {if ($ESXCredential) {$ESXcredential} else {$Credential}}
            SessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding utf8 -UseSsl
        }
        try {
            $CIMSession = New-CimSession @CimSessionParams
            $ServerInfo = Get-CimInstance -verbose:$false -cimsession $session -classname CIM_PhysicalPackage | 
                where elementname -match 'Chassis' | 
                select -first 1 manufacturer,
                    model,
                    serialnumber,
                    @{N="productnumber";E={($PSItem.oemspecificstrings -match '^Product ID:') -replace '^Product ID: (\w{6}-\w{3})$','$1'}}

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
            Write-Error -Message "Failed to retrive SerialNumber and ProductNumber from $ComputerName."
            return $null
        }
    } else {
        write-error "Could not connect to the target device. Verify if it is a Windows server that port 135 is accessible and if it is a VMware server that ports 902 and 443 are accessible"
    }
}