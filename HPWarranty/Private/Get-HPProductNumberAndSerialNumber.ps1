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
        $Credential = $null
    )

    try {
        $cimSession = New-CimSession -ComputerName $ComputerName -Credential $Credential -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop
        $manufacturer = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP') {
            Write-OutPut -InputObject ([HashTable]@{
                SerialNumber = (Get-CimInstance -CimSession $cimSession -Class 'Win32_Bios' -ErrorAction Stop).SerialNumber.Trim()
                ProductNumber = (Get-CimInstance -CimSession $cimSession -Class 'MS_SystemInformation' -Namespace 'root\WMI' -ErrorAction Stop).SystemSKU.Trim()
            })
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
