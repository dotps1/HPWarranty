Describe "HPWarranty API Operational Tests" {
    Context "Serial Number Query Test" {
        import-module .\HPWarranty -force
        $SNs = @()
        $SNs += [PSCustomObject]@{SerialNumber="MXQ84504T0";ProductNumber="459497-B21"}
        $SNs += [PSCustomObject]@{SerialNumber="MX263000LM";ProductNumber="840668-001"}
        $SNs += [PSCustomObject]@{SerialNumber="2M223101UX";ProductNumber="686784-001"}
        $SNs += [PSCustomObject]@{SerialNumber="GB8949B8PM";ProductNumber="498357-B21"}
        $SNs += [PSCustomObject]@{SerialNumber="2S6206B304";ProductNumber="AP846A"}
        $SNs += [PSCustomObject]@{SerialNumber="USE62317RY";ProductNumber="403321-B21"}

        #These serial numbers were found on public google image searches
        It "Serial Number MXQ84504T0 is not covered" {
            ($SNs[0] | Get-HPEntWarrantyEntitlement -warningaction silentlycontinue).Covered | Should -Be $false
        }
        It "Serial Number MX263000LM is covered" {
            ($SNs[1] | Get-HPEntWarrantyEntitlement -warningaction silentlycontinue).Covered | Should -Be $true
        }
    }
}