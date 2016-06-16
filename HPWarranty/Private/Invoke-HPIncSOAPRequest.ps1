<#
    .SYNOPSIS
        Invokes a SOAP Request.
    .DESCRIPTION
        Sends a SOAP Request to Hewlett-Packard and returns Entitlement data for non Enterprise systems.
    .INPUTS
        None.
    .OUTPUTS
        System.Xml
    .PARAMETER SOAPRequest
        The Xml formated request to send
    .PARAMETER Url
        The URL to send the SOAP request.
    .LINK
        http://dotps1.github.io/HPWarranty
#>
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
        $SOAPRequest,
        
        [Parameter()]
        [String]
        $Url = 'https://api-uns-sgw.external.hp.com/gw/hpit/egit/obligation.sa/1.1'
    )

    $soapWebRequest = [System.Net.WebRequest]::Create($URL) 
    $soapWebRequest.Headers.Add('X-HP-SBS-ApplicationId','hpi-obligation-hpsa')
    $soapWebRequest.Headers.Add('X-HP-SBS-ApplicationKey','ft2VGa2hx9j$')
    $soapWebRequest.ContentType = 'text/xml; charset=utf-8'
    $soapWebRequest.Accept = 'text/xml'
    $soapWebRequest.Method = 'POST'

    try {
	    $SOAPRequest.Save(
            ($requestStream = $soapWebRequest.GetRequestStream())
        )

	    $requestStream.Close() 

	    $responseStream = ($soapWebRequest.GetResponse()).GetResponseStream()
        
        [Xml]([System.IO.StreamReader]($responseStream)).ReadToEnd()

	    $responseStream.Close() 
    } catch {
        throw $_
    }
}
