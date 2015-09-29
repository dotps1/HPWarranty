# HPWarranty PowerShell Module
## As HP has recently split into two different companies, this is a complete rewrite, and is still beta.

This module can be installed from the [PowerShellGallery](https://www.powershellgallery.com/packages/HPWarranty/).  You need [WMF 5](https://www.microsoft.com/en-us/download/details.aspx?id=44987) to use this feature.
```PowerShell
Install-Module -Name HPWarranty
```

HP has recently split into two divisions, and this a first attempt to support both HP server and workstation warranty via PowerShell.
I currently have no way to check if a machine is a 'Server' or a 'Workstaion', so that falls on you, for now.
This is still very beta, so please report any issues.  Thanks.

## HPWarranty Cmdlets

* [Get-HPServerWarrantyEntitlement]()
* [Get-HPWorkstationWarrantyEntitlement]()


Example 1:
```PowerShell
# Execute from local HP workstation.
Get-HPWorkstationWarrantyEntitlement
```

Example 2:
```PowerShell
# Execute against remote HP workstation (must be on).
Get-HPWorkstationWarrantyEntitlement -ComputerName 'MyFriendsHP.ourdomain.org'
```

Example 3:
```PowerShell
# Execute against multipule HP workstations
@('HP1', 'HP2') | Get-HPWorkstationWarrantyEntitlement
```