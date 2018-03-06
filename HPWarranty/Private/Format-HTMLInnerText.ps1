function Format-HTMLInnerText {
    param ($InputObject)
    #Extract the text
    $result = $inputobject.innertext
    #Convert it fron HTML
    $result = [System.Web.HTTPUtility]::HtmlDecode($result)
    #Remove extra whitespaces
    $result = $result -replace "\s+"," "
 
    #Trim any remaining whitespace
    return $result.trim()
}