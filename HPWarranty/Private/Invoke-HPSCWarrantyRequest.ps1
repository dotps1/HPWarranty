function Invoke-HPSCWarrantyRequest {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory)][String]$SerialNumber,
        [Parameter()][String]$ProductNumber,
        [Parameter()][String]$CountryCode = "US"
    )

    begin {
        if (-not $SCRIPT:InvokeHPSCWarrantyRequestWarnedOnce) {
            write-warning "The HPSC query method retrieves information from HP Service Center Warranty Request page by screenscraping the HTML response. It may break at any time at the whim of HPE if they make a significant change. DO NOT USE FOR PRODUCTION WORKLOADS!"
            $SCRIPT:InvokeHPSCWarrantyRequestWarnedOnce = $true
        }
        #Send the requests as TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $HPWCHostname = "support.hpe.com"
        $HPWCPath = "/hpsc/wc/public/find"
    }
    process {
        #TODO: Do bulk query, however trying to parse this is *super* annoying as HP doesn't make it separate tables on the output
        foreach ($SerialNumberItem in $SerialNumber) {
            $requestBody = "rows%5B0%5D.item.serialNumber=$SerialNumberItem&$(if ($ProductNumber) {"rows%5B0%5D.item.productNumber=$ProductNumber&"})rows%5B0%5D.item.countryCode=$CountryCode&submitButton=Submit"
            $requestParams = @{
                URI = ("https://" + $HPWCHostname + $HPWCPath)
                Body = $requestBody
                Method = "POST"
            }
            $response = invoke-webrequest -UseBasicParsing @requestParams -verbose:$false | ConvertFrom-HTML

            if ($response) {
                $responseError = $response.SelectSingleNode('//span[@class="hpui-system-error-text"]')
                if ($responseError) {
                    write-error ("$SerialNumber`: Error occurred during HPSC query - " + $responseError.InnerText.trim())
                    continue
                }
                
                #Handle the error if a product ID is required
                $productNumberNeededError = $response.SelectSingleNode('//div[@class="hpui-user-error-text"]')
                if ($productNumberNeededError) {
                    write-error "$SerialNumberItem`: $($productNumberNeededError.InnerText.trim())"
                    continue
                }

                ConvertFrom-HPSCWarrantyResponse $response -SerialNumber $SerialNumber
            } 
            else {
                write-error "Unable to retrieve warranty information for $SerialNumberItem via HPSC method"
                continue
            }
        }
    }
}