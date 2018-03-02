function Register-HPEntISEEService {
    param (
        [String]$SerialNumber
    )
    if ((Get-Date) -gt $Script:HPEntRegistration.TokenRenewDate ) {
        $registrationRequest = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPEntWarrantyRegistration.xml").Replace(
            '<[!--UniversialDateTime--!]>', $([DateTime]::SpecifyKind($(Get-Date), [DateTimeKind]::Local).ToUniversalTime().ToString('yyyy\/MM\/dd hh:mm:ss \G\M\T'))
        ).Replace(
            '<[!--SerialNumber--!]>', $SerialNumber
        )
        write-verbose "Registering Connection Session with HP Instant Support. This can take up to 90 seconds for some reason lately..."
        try {
            [Xml]$registration = Invoke-HPEntSOAPRequest -SOAPRequest $registrationRequest -URL 'https://services.isee.hp.com/ClientRegistration/ClientRegistrationService.asmx' -Action 'http://www.hp.com/isee/webservices/RegisterClient2' -erroraction stop
        } catch {
            write-error $PSItem
        }
        
        if ($registration) {
            $Script:HPEntRegistration = @{
                Gdid = $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.Gdid
                Token = $registration.Envelope.Body.RegisterClient2Response.RegisterClient2Result.RegistrationToken
                TokenRenewDate = (Get-Date).addminutes($Script:HPEntRegistration.ThresholdInMinutes)
            }

            $Script:HPEntRequestTemplate = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPEntWarrantyEntitlement.xml").Replace(
                '<[!--Gdid--!]>', $Script:HPEntRegistration.Gdid
            ).Replace(
                '<[!--Token--!]>', $Script:HPEntRegistration.Token
            ).Replace(
                '<[!--CountryCode--!]>', $CountryCode
            )
        }
        
    }
    #Return a copy of the template so it doesn't get directly modified
    if ($Script:HPEntRequestTemplate) {
        $Script:HPEntRequestTemplate.PSObject.Copy()
    }   
}