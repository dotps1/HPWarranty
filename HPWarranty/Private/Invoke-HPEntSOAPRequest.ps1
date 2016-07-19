<#
.SYNOPSIS
    Invokes a SOAP Request.
.DESCRIPTION
    Sends a SOAP Request to Hewlett-Packard ISEE Servers to either create a Registration GDID and Token, or retrieve Warranty Info.
.INPUTS
    None.
.OUTPUTS
    System.Xml
.PARAMETER SOAPRequest
    The Xml Formatted request to be sent.
.PARAMETER Url
    The ISEE URL to send the SOAP request.
.PARAMETER Action
    The ISEE Action to be performed.
.NOTES
    This module contains two XML douments used for the -SOAPRequest Parameter.
    RegistrationSOAPRequest.xml (See Invoke-HPWarrantyRegistrationRequest Cmdlet)
    EntitlementSOAPRequest.xml (See Invoke-HPWarrantyLookup Cmdlet).
    Credits to:
        StackOverFlow:OneLogicalMyth
        StackOverFlow:user3076063
        ocdnix HP ISEE PoC Dev
        Steve Schofield Microsoft MVP - IIS
.LINK
    http://stackoverflow.com/questions/19503442/hp-warranty-lookup-using-powershell-soap
.LINK
    http://ocdnix.wordpress.com/2013/03/14/hp-server-warranty-via-the-isee-api/
.LINK
    http://www.iislogs.com/steveschofield/execute-a-soap-request-from-powershell
.LINK
    http://dotps1.github.io/HPWarranty
#>
Function Invoke-HPEntSOAPRequest  {
    
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

        [Parameter(
            Mandatory = $true
        )]
        [ValidateSet(
            'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx',
            'https://services.isee.hp.com/EntitlementCheck/EntitlementCheckService.asmx'
        )]
        [String]
        $Url,

        [Parameter(
            Mandatory = $true
        )]
        [ValidateSet(
            'http://www.hp.com/isee/webservices/RegisterClient2',
            'http://www.hp.com/isee/webservices/GetOOSEntitlementList2'
        )]
        [String]
        $Action
    )

    $soapWebRequest = [System.Net.WebRequest]::Create($URL) 
    $soapWebRequest.Headers.Add('SOAPAction', $Action)
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
