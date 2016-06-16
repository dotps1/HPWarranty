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
        $Credential = $null
    )

    try {
        $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace 'root\CIMV2' -Property 'Manufacturer' -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop).Manufacturer
        if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP') {
            return [HashTable] @{
                SerialNumber = (Get-WmiObject -Namespace 'root\cimV2' -Class 'Win32_Bios' -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop).SerialNumber.Trim()
                ProductNumber = (Get-WmiObject -Namespace 'root\WMI' -Class 'MS_SystemInformation' -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop).SystemSKU.Trim()
            }
        } else {
            Write-Error -Message 'Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems.'
            return $null
        }
    } catch {
        Write-Error -Message "Failed to retrive SerailNumber and ProductNumber from $ComputerName."
        return $null
    }
}
