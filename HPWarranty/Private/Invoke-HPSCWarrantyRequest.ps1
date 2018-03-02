function Invoke-HPSCWarrantyRequest {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory)][String]$SerialNumber,
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
            $requestBody = "rows%5B0%5D.item.serialNumber=$SerialNumberItem&rows%5B0%5D.item.countryCode=$CountryCode&submitButton=Submit"

            $requestParams = @{
                URI = ("https://" + $HPWCHostname + $HPWCPath)
                Body = $requestBody
                Method = "POST"
            }
            $response = invoke-webrequest @requestParams -verbose:$false

            if ($response) {
                $responseError = $response.ParsedHtml.IHTMLDocument3_getElementsByTagName("span") | where classname -match 'hpui-system-error-text' | select -first 1
                if ($responseError) {
                    write-error ("$SerialNumber`: Error occurred during HPSC query - " + $responseError.InnerText.trim())
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