Function Invoke-HPIncSOAPRequest {

    [CmdletBinding()]
    [OutputType(
        [Xml]
    )]

	Param (
        [Parameter(
            Mandatory = $true
        )]
        [Xml]
        $SOAPRequest = "$PSScriptRoot\..\RequestTemplates\HPIncWarrantyEntitlement.xml",
        
        [Parameter()]
        [String]
        $URL = 'https://api-uns-sgw.external.hp.com/gw/hpit/egit/obligation.sa/1.1'
    )

    try {
	    $soapWebRequest = [System.Net.WebRequest]::Create($URL) 
	    $soapWebRequest.Headers.Add('X-HP-SBS-ApplicationId','hpi-obligation-hpsa')
	    $soapWebRequest.Headers.Add('X-HP-SBS-ApplicationKey','ft2VGa2hx9j$')
	    $soapWebRequest.ContentType = 'text/xml; charset=utf-8'
	    $soapWebRequest.Accept = 'text/xml'
	    $soapWebRequest.Method = 'POST'
	    $soapWebRequest.ProtocolVersion = [System.Net.HttpVersion]::Version11

	    $requestStream = $soapWebRequest.GetRequestStream() 
	    $SOAPRequest.Save($requestStream) 
	    $requestStream.Close() 

	    $response = $soapWebRequest.GetResponse() 
	    $responseStream = $response.GetResponseStream() 
	    $soapReader = [System.IO.StreamReader]($responseStream) 
	    $returnXml = [Xml]$soapReader.ReadToEnd() 
	    $responseStream.Close() 

	    return $returnXml
    } catch {
        throw $_
    }
}