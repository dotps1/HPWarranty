function ConvertFrom-HPSCWarrantyResponse {
    param(
        [Parameter(Mandatory = $true)]
        [HtmlAgilityPack.HtmlNode] $WebRequest,

        [Parameter()]
        [String] $SerialNumber,

        [Parameter()]
        [string] $TableClass = "hpui-standard-table"
    )

    #Extract the warranty details table
    $warrantyTable = $WebRequest.SelectSingleNode("//table[@class='$TableClass']")
    if (-not $warrantyTable) {write-error "Could not find table $tableClass. Maybe HPE changed the format?";continue}

    #Get the headers
    $titles = $warrantyTable.SelectNodes("//th") | foreach {
        Format-HtmlInnerText $PSItem
    }

    ## Go through all of the rows in the table. Some cells are sneaky and span multiple rows and need a sticky value.
    $entitlements = @()
    $rowSpans = [Ordered] @{}

    $rows = $warrantyTable.SelectNodes("//tbody/tr[@class='hpui-normal-row']")
    foreach($row in $rows)
    {
        ## Now go through the cells in the the row. For each, try to find the
        ## title that represents that column and create a hashtable mapping those
        ## titles to content

        $resultObject = [Ordered] @{}
        $cells = $row.childnodes | where name -match 'td'

        $cellIndex = 0
        foreach ($title in $titles) { 
            #If a title is found in the RowSpans cache, repeat that value first
            if ($rowSpans."$title") {
                $resultObject.$title = $rowSpans.$Title.Value
                $rowspans.$title.Remaining = $rowspans.$title.Remaining - 1
                if ($rowspans.$title.Remaining -le 0) {
                    $rowspans.Remove($title)
                }
                continue
            }
            
            $cellItem = $cells[$cellIndex]
            $resultValue = Format-HtmlInnerText $cellItem
            
            #If a cell spans multiple rows, we need to remember the value for X future runs
            $cellRowSpanValue = ($cellitem.Attributes | where name -eq 'rowspan').value
            if ($cellRowSpanValue -gt 1) {
                $rowSpans.$title = @{
                    Value=$resultValue
                    Remaining=($cellRowSpanValue - 1)
                }
            }

            $resultObject.$title = $resultValue
            $cellIndex++
        }


        ## And finally cast that hashtable to a PSCustomObject
        $entitlements += [PSCustomObject]$resultObject

    }

    #Build the response
    $ProductDescriptionAndSerialNumberRegEx = '^(.*?)\ *SN:\ *(\w+)$'

    #First try to get the exact table by serialNumber, then try a looser match if not found
    if ($serialNumber) {
        $ProductDescriptionRaw = $WebRequest.SelectSingleNode("//*[@id='product_description_$serialNumber']").innertext.trim()
        #Clean up the returned result by decoding HTML and removing extra spaces from the innertext extraction process
        $ProductDescriptionRaw = [System.Web.HTTPUtility]::HtmlDecode($ProductDescriptionRaw) -replace "\s+"," "
    }
    if (-not $ProductDescriptionRaw) {write-error "Unable to find a warranty table in the response. Maybe HPE changed the format and broke this query format?"; continue}
    
    $ProductDescription = $ProductDescriptionRaw -replace $ProductDescriptionAndSerialNumberRegEx,'$1'
    $returnedSerialNumber = $ProductDescriptionRaw -replace $ProductDescriptionAndSerialNumberRegEx,'$2'
    if ($serialNumber -and ($serialNumber -notmatch $returnedSerialNumber)) {
        write-error "Response output didn't match queried serial number, Maybe HPE changed the format?"
        continue
    } else {
        $serialNumber = $returnedSerialNumber
    }
    if ($serialNumber -notmatch $returnedSerialNumber) {}
    $SerialNumber = $ProductDescriptionRaw -replace $ProductDescriptionAndSerialNumberRegEx,'$2'

    #Convert the time strings to DateTime for use in datetime math
    foreach ($entitlementItem in $entitlements) {
        "Start Date","End Date" | foreach {
            if ($entitlementItem.$PSItem) {
                $entitlementItem.$PSItem = [DateTime]$entitlementItem.$PSItem
            }
        }
    }

    $warranties = $entitlements | where type -match 'Warranty'
    $contracts = $entitlements | where type -match 'Support agreement|Packaged Support'

    $returnObject = [ordered]@{
        'ComputerName' = $null
        'SerialNumber' = $SerialNumber
        'ProductNumber' = $null
        'ProductDescription' = $ProductDescription
        'IsUnderCoverage' = [Bool]($entitlements.status -match "Active")
        'OverallCoverageEndDate' = $entitlements."End Date" | where {$PSItem} | sort | select -last 1
        'OverallCoverageStartDate' = $entitlements."Start Date" | where {$PSItem} | sort | select -first 1
        'ActiveWarranty' = [Bool]($warranties.status -match "Active")
        'OverallWarrantyEndDate' = $warranties."End Date" | where {$PSItem} | sort | select -last 1
        'OverallWarrantyStartDate' = $warranties."Start Date" | where {$PSItem} | sort | select -first 1
        'ActiveContract' = [Bool]($contracts.status -match "Active")
        'OverallContractEndDate' = $contracts."End Date" | where {$PSItem} | sort | select -last 1
        'OverallContractStartDate' = $contracts."Start Date" | where {$PSItem} | sort | select -first 1
        'WarrantyDetail' = $warranties
        'ContractDetail' = $contracts
        'OriginalOrderDetail' = $null
    }

    #If the returned object at least has a serial number, return it, otherwise skip
    if ($returnObject.SerialNumber) {
        $returnObject
    }
}