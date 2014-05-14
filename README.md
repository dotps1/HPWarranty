HPWarranty
==========

PowerShell module to help retrieve Hewlett-Packard Warranty Information

Use this module to get the Hewlett-Packard Warranty Information from their ISEE Web Services.  There is a function included to retrieve the necessary information from a ConfigMgr DB.  However, you need to inventory the root\MS_SystemInformation Namespace, which is not done by default

	$Registration = Execute-HPWarrantyRegistrationRequest
	
	$HPComputers = Get-HPComputerInformationForWarrantyRequestFromCCMDB -SqlServer MY_CCM_DB_Server -ConnectionPort 1433 -Database CM_ABC -IntergratedSecurity
	
	foreach ($Computer in $HPComputers)
	{
		Execute-HPWarrantyLookup -Gdid $Registration.Gdid -Token $Registration.Token -SerialNumber $Computer.SerialNumber -ProductNumber $Computer.ProductNumber
	}
	
Or

	# Retrieve Warranty Information for LocalHPHost
	$Registration = Execute-HPWarrantyRegistrationRequest; Execute-HPWarrantyLookup -Gdid $Registration.Gdid -Token $Registration.Token
	
After HP re factored their Web Fronted Services you could no longer use HTTP Scraping and pass a serial number to the URL.  This is work around to that.  Enjoy!