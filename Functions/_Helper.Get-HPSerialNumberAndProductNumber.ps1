Function Get-HPSerialNumberAndProductNumber {
    
    [OutputType([PSObject])]

    Param (
        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipeLine = $true
        )]
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
        $ComputerName = $env:ComputerName
    )

    try {
        $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem -Namespace 'root\CIMV2' -Property 'Manufacturer' -ComputerName $ComputerName -ErrorAction Stop).Manufacturer
        if ($manufacturer -eq 'Hewlett-Packard' -or $manufacturer -eq 'HP') {
            $serialNumber = (Get-WmiObject -Class Win32_Bios -ComputerName $ComputerName -ErrorAction Stop).SerialNumber.Trim()
            $productNumber = (Get-WmiObject -Namespace root\WMI MS_SystemInformation -ComputerName $ComputerName -ErrorAction Stop).SystemSKU.Trim()
        } else {
            throw 'Computer Manufacturer is not of type Hewlett-Packard.  This cmdlet can only be used with values from Hewlett-Packard systems.'
        }
    } catch {
        throw "Failed to retrive SerailNumber and ProductNumber from $ComputerName."
    }

    return [PSObject]@{
        SerialNumber = $serialNumber
        ProductNumber = $productNumber
    }
}