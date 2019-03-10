# HPWarranty PowerShell Module

## **Finally getting this working a bit again, refractor in progress.**

This module can be installed from the [PowerShellGallery](https://www.powershellgallery.com/packages/HPWarranty/).  You need [WMF 5](https://www.microsoft.com/en-us/download/details.aspx?id=44987) to use this feature.
```PowerShell
Install-Module -Name HPWarranty
```

HP has recently split into two divisions, and this a first attempt to support both HP server and workstation warranty via PowerShell.
I currently have no way to check if a machine is a 'Server' or a 'Workstation', so that falls on you, for now.  I have added the error returned from HP to the errorstream, so you should be able to tell what the issue is more easily.
This is still very beta, so please report any issues.  Thanks.

## HPWarranty Cmdlets

* Get-HPIncWarrantyEntitlement
* Get-HPEntWarrantyEntitlement
* Get-HPSystemInformationFromCMDB

Example 1:
```PowerShell
# Execute from local HP workstation.
Get-HPIncWarrantyEntitlement
```

Example 2:
```PowerShell
# Execute against remote HP workstation (must be on).
Get-HPIncWarrantyEntitlement -ComputerName 'MyFriendsHP.ourdomain.org' -Credential (Get-Credential)
```

Example 3:
```PowerShell
# Execute for local HPE Server
Get-HPEntWarrantyEntitlement
```