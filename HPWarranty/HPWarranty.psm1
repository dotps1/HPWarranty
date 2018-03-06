#Load .NET Assemblies
$NetAssemblies = Get-Childitem -Path $PSScriptRoot\lib\*.dll -ErrorAction SilentlyContinue -Recurse
foreach ($NetAssembly in $NetAssemblies) {
	Add-Type -Path $NetAssembly.fullname -ErrorAction Stop
}

#Load Powershell Module submodules if present
<#
$SubModules = Get-Childitem -Path $PSScriptRoot\Submodules -ErrorAction SilentlyContinue
foreach ($SubModuleItem in $SubModules) {
	Import-Module $SubModuleItem.fullname -ErrorAction Stop
}
#>

#Get public and private function definition files.
$PublicFunctions  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$PrivateFunctions = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
Foreach($FunctionToImport in @($PublicFunctions + $PrivateFunctions))
{
    Try
    {
        . $FunctionToImport.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

#Export the public functions. This should also be done in the manifest
Export-ModuleMember -Function $PublicFunctions.Basename

# Initalizes an empty HashTable to hold registration values to be reused.
# After the DateTime is set, if its older then the current time minus the ThresholdInMinutes it will be rebuilt with next invocation.
$Script:HPEntRegistration = @{ 
    Gdid = $null
    Token = $null
    ThresholdInMinutes = 15
    DateTime = $null
}
