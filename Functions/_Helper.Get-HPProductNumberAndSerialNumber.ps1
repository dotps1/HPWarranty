Function Get-HPProductNumberAndSerialNumber {
    
    [OutputType([PSObject])]

    Param (
        [Parameter()]
        [String]
        $ComputerName = $env:ComputerName
    )

    try {
        $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace 'root\CIMV2' -Property 'Manufacturer' -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
        if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP') {
            return [PSObject] @{
                SerialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
                ProductNumber = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU.Trim()
            }
        } else {
            throw 'Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems.'
        }
    } catch {
        throw "Failed to retrive SerailNumber and ProductNumber from $ComputerName."
    }
}