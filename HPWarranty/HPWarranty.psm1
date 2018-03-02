$paths = @(
    'Private',
    'Public'
)

foreach ($path in $paths) {
    "$(Split-Path -Path $MyInvocation.MyCommand.Path)\$path\*.ps1" | Resolve-Path | ForEach-Object { 
	    . $_.ProviderPath 
    }
}

Update-FormatData "$(Split-Path -Path $MyInvocation.MyCommand.Path)\Types\*.ps1xml"

# Initalizes an empty HashTable to hold registration values to be reused.
# After the DateTime is set, if its older then the current time minus the ThresholdInMinutes it will be rebuilt with next invocation.
$Script:HPEntRegistration = @{ 
    Gdid = $null
    Token = $null
    ThresholdInMinutes = 15
    DateTime = $null
}
