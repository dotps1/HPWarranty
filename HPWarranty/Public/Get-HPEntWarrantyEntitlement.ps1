Function Get-HPEntWarrantyEntitlement {
    
    [CmdletBinding(
        DefaultParameterSetName = 'Computer'
    )]
    [OutputType(
        [PSCustomObject]
    )]
    
	Param (
        [Parameter(
            ParameterSetName = 'Computer',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position=1
        )]
        [String[]]
        $ComputerName = $env:ComputerName,

        [Parameter(
            ParameterSetName = 'Computer'
        )]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = $null,

        [Parameter(
            ParameterSetName = 'Computer'
        )]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        [System.Management.Automation.Credential()]
        $ESXCredential = $null,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            Position=1,
            ValueFromPipelineByPropertyName = $true
        )]
		[String[]]
        $SerialNumber = "GetHPEntWarrantyEntitlement",

		[Parameter(
            ParameterSetName = 'Static',
            Position=2,
            ValueFromPipeLineByPropertyName = $true
        )]
		[String]
        $ProductNumber,

		[Parameter()]
		[String]
        $CountryCode = 'US',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $XmlExportPath = $null,
        
        #Specify which query method to use. Valid values are "HPSC" and "ISEE". 
        #HPSC - HP Service Center Warranty Check HTML Screenscrape
        #ISEE - HP Instant Support Enterprise Edition XML Web Service
        #If you specify both e.g. "HPSC","ISEE" then this cmdlet will attempt the first one specified and try the second if it fails. Default is "HPSC"
        [Parameter()]
        [ValidateSet("HPSC","ISEE")]
        [String[]]
        $QueryMethod = ("HPSC"),

        #Returns the data in the legacy hashtable format rather than the new object format
        [Switch]$AsHashTable
	)

    Begin {
        #Store creds for PN/SN discovery
        $GetHPProductSerialNumberParams = @{
            Credential = $Credential
            ESXCredential = $ESXCredential
        }

        if (($QueryMethod -contains "ISEE") -and ($PSCmdlet.ParameterSetName -match 'Static') -and (-not $ProductNumber)) {
            throw "ISEE query method specified but -ProductNumber not specified. You must specify a product number for this query method. If you don't know your product number, try the '-QueryMethod HPSC' parameter"
        }
    }

    Process {
        foreach ($ComputerNameItem in $ComputerName) {
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                $systemInformation = Get-HPProductSerialNumber -ComputerName $ComputerNameItem @GetHPProductSerialNumberParams
                if ($systemInformation) {
                    $ProductNumber = $systemInformation.ProductNumber
                    $SerialNumber = $systemInformation.SerialNumber
                } else {
                    write-error "Unable to retrieve product information from $ComputerName. Verify your credentials are correct and the device is reachable"
                    continue
                }
            }

            foreach ($SerialNumberItem in $SerialNumber) {

                foreach ($QueryMethodItem in $QueryMethod) {
                    switch ($QueryMethodItem) {
                        "HPSC" {
                            write-verbose "Looking up device with Serial Number $SerialNumberItem$(if ($ProductNumber) {`" and Product ID $ProductNumber`"}) via HPSC method"
                            $output = Invoke-HPSCWarrantyRequest -SerialNumber $SerialNumberItem -CountryCode $CountryCode
                        }
                        "ISEE" {
                            #Prep the ISEE Request
                            $request = Register-HPEntISEEService $SerialNumberItem
                            if (-not $request) {
                                write-error "Unable to register with HP Instant Support at this time. Disabling ISEE discovery method for this run."
                                $QueryMethod = $QueryMethod | where {$PSItem -ne "ISEE"}
                                continue
                            }

                            write-verbose "Looking up device with Serial Number $SerialNumberItem$(if ($ProductNumber) {`" and Product ID $ProductNumber`"}) via ISEE method"
                            try {
                                [Xml]$entitlement = (
                                    Invoke-HPEntSOAPRequest -SOAPRequest $request.Replace(
                                        '<[!--ProductNumber--!]>', $ProductNumber
                                    ).Replace(
                                        '<[!--SerialNumber--!]>', $SerialNumberItem
                                    ) -Url 'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx' -Action 'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
                                ).Envelope.Body.GetOOSEntitlementList2Response.GetOOSEntitlementList2Result.Response
                            } catch {
                                Write-Error -Message 'Failed to invoke SOAP request.'
                                continue
                            }
                            if ($DebugPreference -eq 'Inquire') {
                                Write-Debug -Message 'Returning raw xml.'
                                return $entitlement
                            }
                            if ($XmlExportPath) {
                                try {
                                    $entitlement.Save("${XmlExportPath}\${SerialNumber}_entitlement.xml")
                                } catch {
                                    Write-Error -Message 'Failed to save xml file.'
                                }
                            }

                            #Error Handling
                            if ($entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError) {
                                switch ($entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError.ErrorID) {
                                    214 {
                                        write-warning "This system was not found in the HPE ISEE database but may be covered in the HPSC or HP Consumer warranty databases" 
                                        if ($QueryMethod -contains "HPSC") {
                                            write-warning "Re-Attempting using HPSC method..."
                                            $output = Invoke-HPSCWarrantyRequest -SerialNumber $SerialNumberItem -CountryCode $CountryCode
                                        } else {
                                            continue
                                        }
                                    }
                                    default {
                                        Write-Error -Message $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.EIAError.ErrorText
                                        continue
                                    }
            
                                }
                            }
                            
                            $entitlementInfo = $entitlement.'ISEE-GetOOSEntitlementInfoResponse'.Data.esreply.CombinedUnitEntitlement
                            if ($entitlementInfo) {
                                $output = [ordered]@{
                                    'ComputerName' = $null
                                    'SerialNumber' = $SerialNumberItem
                                    'ProductNumber' = $ProductNumber
                                    #Remove some unnecessary spaces and newlines from the product description
                                    'ProductDescription' = $entitlementInfo.oos.product.productdescription.replace("`n","") -replace " {2,}"
                                    'IsUnderCoverage' = if ($activeWarranty -or $activeContract) {$true} else {$false}
                                    'OverallCoverageEndDate' = $null #TODO Add coverage end date
                                    'OverallCoverageStartDate' = $null #TODO Add coverage start date
                                    'ActiveWarranty' = if ($activeWarranty) {$true} else {$false}
                                    'OverallWarrantyEndDate' = [DateTime]$entitlementInfo.OverallWarrantyEndDate
                                    'OverallWarrantyStartDate' = [DateTime]$entitlementInfo.OverallWarrantyStartDate
                                    'ActiveContract' = if ($activeContract) {$true} else {$false}
                                    'OverallContractEndDate' = [DateTime]$entitlementInfo.OverallContractEndDate
                                    'OverallContractStartDate' = [DateTime]$entitlementInfo.OverallContractStartDate
                                    'WarrantyDetail' = $entitlementInfo.warranty
                                    'ContractDetail' = $entitlementInfo.contract
                                    'OriginalOrderDetail' = $entitlementInfo.oos
                                }
                            }
                        }
                    }

                    #If the query method succeded, don't try the next method and move on
                    if ($output) {break}
                }

                if ($output) {
                    #Add back attributes which may not have been applied
                    if ($PSCmdlet.ParameterSetName -eq 'Computer') {
                        $output.computername = $ComputerNameItem
                    }
                    $output.ProductNumber = $ProductNumber

                    #Calculate the overall start and end dates if they haven't been calculated yet
                    if (-not $output.OverallCoverageStartDate) {
                        $output.OverallCoverageStartDate = $output.OverallWarrantyStartDate,$output.OverallContractStartDate | where {$PSItem -ne $null} | sort | select -first 1
                    }
                    if (-not $output.OverallCoverageEndDate) {
                        $output.OverallCoverageEndDate = $output.OverallWarrantyEndDate,$output.OverallEndDate | where {$PSItem -ne $null} | sort | select -last 1
                    }

                    #Alias some property names to match the custom type definition

                    #Deliver the warranty report
                    if ($AsHashTable) {
                        #Legacy compatability format
                        [ordered]@{
                            SerialNumber = $output.SerialNumber
                            ProductNumber = $output.ProductNumber
                            OverallEntitlementStartDate = $OverallCoverageStartDate
                            OverallEntitlementEndDate = $OverallCoverageEndDate
                            ActiveEntitlement = $output.IsUnderCoverage
                        }
                    } else {
                        #Return the warranty information with a custom type for easy viewing/formatting and some aliases to match the custom formatting
                        $returnObject = [PSCustomObject]$output
                        [PSCustomObject]$returnObject.PSObject.TypeNames.Insert(0,"HPWarranty.HPWarrantyInfo")
                        $returnObject | Add-Member -MemberType AliasProperty -Name Covered -Value IsUnderCoverage
                        $returnObject | Add-Member -MemberType AliasProperty -Name Start -Value OverallCoverageStartDate
                        $returnObject | Add-Member -MemberType AliasProperty -Name End -Value OverallCoverageEndDate
                        $returnObject
                    }
                    
                } else {
                    write-error "No Entitlement was obtained using specified methods. Check that your network is operational and the APIs aren't under maintenance"
                    continue
                }

            }
        }
    }
}
