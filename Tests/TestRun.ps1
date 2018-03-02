import-module $home/documents/github/hpwarranty/HPWarranty -force -verbose
#Valid System
HPWarranty\Get-HPEntWarrantyEntitlement -SerialNumber MXQ50307CK -ProductNumber 779559-S01  -verbose -OutVariable serverwarranty -querymethod isee
#Out of Warranty
#Get-HPEntWarrantyEntitlement -SerialNumber 2M242600FQ -ProductNumber 686792-B21 -verbose -OutVariable serverwarranty -querymethod isee
#$m = get-module hpwarranty
#& $m {invoke-hpscwarrantyrequest use2225PLS}