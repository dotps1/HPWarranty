#requires -Module Pester, PSScriptAnalyzer

#Move out of tests to the subdirectory of the modulepwd
if ((get-item .).Name -match 'Tests') {Set-Location $PSScriptRoot\..}

$ModuleName = 'HPWarranty'
$ModuleManifestPath = Get-ChildItem "$ModuleName.psd1" -recurse
Describe 'Module Integrity' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
        $? | Should Be $true
    }
    It 'Can Be Imported as a module' {
        (Import-Module -Force -Name $ModuleManifestPath -PassThru).Name | Should Be $ModuleName
    }
}
Describe "PSScriptAnalyzer" {
    $results = Invoke-ScriptAnalyzer -Path .\HPWarranty -Recurse -Exclude "PSAvoidUsingCmdletAliases"

    It 'PSScriptAnalyzer returns zero errors for all files in the repository' {
        $results.Count | Should Be 0
    }
}
