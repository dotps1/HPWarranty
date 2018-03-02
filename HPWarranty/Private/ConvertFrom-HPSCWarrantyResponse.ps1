
function ConvertFrom-HPSCWarrantyResponse {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.HtmlWebResponseObject] $WebRequest,

        [Parameter()]
        [String] $SerialNumber,        

        [Parameter()]
        [int] $TableNumber,

        [Parameter()]
        [string] $TableClass = "hpui-standard-table"
    )

    #TODO: Refactor this to use HTML Agility Pack rather than IE DOM to make it Powershell Core Compatible

    ## Extract the tables out of the web request
    $tables = @($WebRequest.ParsedHtml.IHTMLDocument3_getElementsByTagName("TABLE"))
    if ($TableNumber) {
        $table = $tables[$TableNumber]
    } else {
        $table = $tables | where className -eq $tableClass
    }

    ## Go through all of the rows in the table. Some cells are sneaky and span multiple rows and need a sticky value.
    $entitlements = @()
    $titles = @()
    $rows = @($table.Rows)
    $rowSpans = [Ordered] @{}
    foreach($row in $rows)
    {
        $cells = @($row.Cells)

        ## If we've found a table header, remember its titles

        if($cells[0].tagName -eq "TH")
        {
            $emptyTitleCount = 1
            $titles = @(
                $cells | foreach { 
                    $title = ("" + $_.InnerText).Trim()
                    if (-not $title) {$title = "P$emptyTitleCount";$emptyTitleCount++}
                    $title
                }
            )
            continue
        }

        ## If we haven't found any table headers, make up names "P1", "P2", etc.
        if(-not $titles)
        {
            $titles = @(1..($cells.Count + 2) | % { "P$_" })
        }


        ## Now go through the cells in the the row. For each, try to find the
        ## title that represents that column and create a hashtable mapping those
        ## titles to content

        $resultObject = [Ordered] @{}
        
        $cellIndex = 0
        foreach ($title in $titles) { 
            #If a title is found in the RowSpans cache, repeat that value first
            if ($rowSpans."$title") {
                $resultObject.$title = $rowSpans.$Title.Value
                $rowspans.$title.Remaining = $rowspans.$title.Remaining - 1
                if ($rowspans.$title.Remaining -eq 0) {
                    $rowspans.Remove($title)
                }
                continue
            }
            
            $cellItem = $cells[$cellIndex]
            $resultValue = ("" + $cellItem.InnerText).Trim()
            
            #If a cell spans multiple rows, we need to remember the value for X future runs
            if ($cellItem.rowspan -gt 1) {
                $rowSpans.$title = @{
                    Value=$resultValue
                    Remaining=($cellItem.rowspan - 1)
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
        $ProductDescriptionRaw = ($WebRequest.ParsedHtml.IHTMLDocument3_getElementByID("product_description_$serialNumber") | select -first 1).innertext.trim()
    }
    if (-not $ProductDescriptionRaw) {
        $ProductDescriptionRaw = ($WebRequest.ParsedHtml.IHTMLDocument3_getElementsByTagName("td") | where id -match '^product_description_' | select -first 1).innertext.trim()
    }
    if (-not $ProductDescriptionRaw) {write-error "Unable to find a warranty table in the response. Maybe HPE changed the format and broke this query format?"}
    
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
    $returnObject
}