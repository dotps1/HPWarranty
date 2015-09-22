<#
.SYNOPSIS
    Sends entitlement requeset to HP Inc(PCs) and returns entitlements XML
.DESCRIPTION
    Retrives warranty information for HP Inc. PCs
.OUTPUTS
    XML
.PARAMETER RequestTemplate
    Path to the XML template that will be used for the request.
.PARAMETER Serial
    The serial number of the PC
.PARAMETER ProductNo
    The product number of the PC
.PARAMETER CountryCode
    OPTIONAL: Defaults to "US".
.PARAMETER PathToExportFullXml
    Specify a full path to export the entire entitlement response for the system.
.EXAMPLE
    PS C:\> Invoke-HpIncRequest -RequestTemplate ".\ReqTemp.xml" -Serial "ABCDEF123" -ProductNo "123453#ABC"
.EXAMPLE
    PS C:\> Invoke-HpIncRequest -RequestTemplate ".\ReqTemp.xml" -Serial "ABCDEF123" -ProductNo "123453#ABC" -CountryCode "US"
#>
Function Invoke-HpIncRequest {
	param(
		[Parameter(Mandatory = $true)]
		[string]$RequestTemplate,
		[Parameter(Mandatory = $true)]
		[string]$Serial,
		[Parameter(Mandatory = $true)]
		[string]$ProductNo,
		[Parameter(Mandatory = $false)]
		[string]$CountryCode = "US"
	)

	$chkDate = Get-Date -Format "yyyy-MM-dd"

	$request = (get-content $RequestTemplate) #| Foreach-Object {$_ -replace "\xEF\xBB\xBF", ""}
	$request = $request -replace('<COUNTRYCODE>', $CountryCode) -replace('<CHECKDATE>', $chkDate) -replace('<SERIAL>', $Serial) -replace('<PRODUCT>', $ProductNo)
	[xml]$reply = Invoke-RestMethod -Body $request -Uri "https://entitlement-ext.corp.hp.com/es/ES10_1/ESListener"  -ContentType 'text/html' -Method Post
	
	return $reply
}



