## HPWarranty Cmdlets

* [Invoke-HPWarrantyRegistrationRequest](https://github.com/dotps1/HPWarranty/wiki/Invoke-HPWarrantyRegistrationRequest)
* [Invoke-HPWarrantyEntitlementList](https://github.com/dotps1/HPWarranty/wiki/Invoke-HPWarrantyEntitlementList)
* [Get-HPComputerInformationForWarrantyFromCMDB](https://github.com/dotps1/HPWarranty/wiki/Get-HPComputerInformationForWarrantyFromCMDB)

Basically, to use HPs ISEE to get warranty info, there are a few things that need to happen:

1.  A Session needs to be established with their Web Services, this is done by using the Invoke-HPWarrantyRegistrationRequest.  You need a valid SerialNumber and Product Model to do this.  If successful, it will return a Gdid and a Session Token, that then needs to be passed to the Invoke-HPWarrantyEntitlementList.
2.  Using the Gdid and the Token from step 1, and a valid SerialNumber and ProductNumber you can request the information for that device, returning the SerialNumber,ProductID,ActiveWarrantyEntitlement,OverallWarrantyStartDate,OverallWarrantyEndDate,WarrantyDeterminationDescription,GracePeriod (The return SOAP Envelop contains much more information, but that is was I parse and return).
3.  You can reuse the Gdid and Token from step one in a foreach loop to retrieve multiple warranty objects.  That is why I created the Get-HPComputerInformationForWarrantyRequestFromCMDB (only tested on SCCM 2012 SP1 DB).  If you configure your SCCM Client to inventory the MS_SystemInformation WMI Class (Found in the root namespace, not in CIMV2, root\MS_SystemInformation) you can then use this function to return form the CM_<SiteCode> database an array of objects containing the information needed to complete all actions.  SerialNumber,ProductModel,ProductID.


Example 1:
```PowerShell
# Execute from a local HP Workstation
Import-Module HPWarranty; Invoke-HPWarrantyEntitlementList
```

Example 2:
```PowerShell
# Create one session but look up multiple warranty's
Import-Module -Name HPWarranty

$HP1 = @{
	'SerialNumber' = 'A1B2C3D4E5'
	'ProductModel' = 'HP Laptop 100 G1'
	'ProductID' = '123ABC'
}

$HP2 = @{
	'SerialNumber' = '12345ABCDE'
	'ProductModel' = 'HP Desktop 1100 G1'
	'ProductID' = 'ABC123'
}

	
# Use either HP1 or HP2 properties to establish a session with the HP Web Services.
$reg = Invoke-HPWarrantyRegistrationRequest -SerialNumber $HP1.SerialNumber -ProductModel $HP1.ProductModel

Invoke-HPWarrantyEntitlementList -Gdid $reg.Gdid -Token $reg.Token -SerialNumber $HP1.SerialNumber -ProductID $HP1.ProductID
Invoke-HPWarrantyEntitlementList -Gdid $reg.Gdid -Token $reg.Token -SerialNumber $HP2.SerialNumber -ProductID $HP2.ProductID
```

Example 3:
```PowerShell
# Query a remote computer for information to create a session with the the HP Web Services.
# Remote WMI access is necessary to use this function remotely.
Import-Module -Name HPWarranty

$reg = Invoke-HPWarrantyRegistrationRequest -ComputerName HPComputer.mydomain.org

Invoke-HPWarrantyEntitlementList -Gdid $reg.Gdid -Token $reg.Token -ComputerName HPComputer.mydomain.org
```

Example 4:
```PowerShell
# Execute with information from ConfigMgr Database:
Import-Module -Name HPWarranty

$reg = Invoke-HPWarrantyRegistrationRequest -SerialNumber "ABCDE12345" -ProductModel "HP ProBook 645 G1"

$HPs = Get-HPComputerInformationForWarrantyFromCMDB -SqlServer MySccmDBServer -Database CM_MS1 -IntergratedSecurity
foreach ($HP in $HPs)
{
	 Invoke-HPWarrantyEntitlementList -Gdid $reg.Gdid -Token $reg.Token -SerialNumber $HP.SerialNumber -ProductID $HP.ProductID
}
```
	
Example 5:
```PowerShell
# Hashtables are a little tricky to export to CSV, so here is how I run my build date report:
Import-Module -Name HPWarranty
Import-Module -Name ActiveDirectory

$reg = Invoke-HPWarrantyRegistrationRequest

# This output is tailored to the request that was given to me, not all of these values maybe necessary to return.
Get-HPComputerInformationForWarrantyFromCMDB -SqlServer MyCMDB.mydomain.org -Database CM_MS1 -IntergratedSecurity |
Select-Object -Property @{ Name = 'ComputerName';     Expression = { $_.ComputerName } }, 
						@{ Name = 'SerialNumber';     Expression = { $_.SerialNumber } }, 
						@{ Name = 'ProductModel';     Expression = { $_.ProductModel } }, 
						@{ Name = 'BuildDate';        Expression = { (Invoke-HPWarrantyEntitlementList -Gdid $reg.Gdid -Token $reg.Token -SerialNumber $_.SerialNumber -ProductID $_.ProductID).OverallWarrantyStartDate } },
						@{ Name = 'LastHardwareScan'; Expression = { Get-Date (Get-Date $_.LastHardwareScan).ToShortDateString() -Format 'yyyy-MM-dd' } },
						@{ Name = 'LastLoggedOnUser'; Expression = { $_.Username } },
						@{ Name = 'CompanyName';      Expression = { if ($_.Username -ne $null){ (Get-ADUser -Identity $_.Username.ToString().Trim('MYDOMAIN\') -Properties Company).Company } } } |
Export-Csv -Path C:\HPBuildInfo.csv -NoTypeInformation -Append 
```