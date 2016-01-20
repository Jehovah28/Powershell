function New-Office365User {

[CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]

param (
    [parameter(Mandatory,
               HelpMessage='Bitte den vollständigen Pfad zu einer CSV-Datei angeben.',
               ValueFromPipeline)]
    [ValidateScript({
    if (-not (Test-path -Path $_))
        {throw "Die Datei $_ ist nicht vorhanden"}
    else 
        {$true}
    })]
    $CSVDatei,

    [parameter(Mandatory,HelpMessage='Bitte eine gültige Emailadresse eines Mitarbeites angeben!')]
    [ValidateScript({ 
    if (-not (get-aduser -Filter {Userprincipalname -eq $_}))
                      { throw 'Die Emailadresse ist keine gültige Emailadresse eines Mitarbeiters!'}
                      else {$true}
                    })]
    [string]$EMailadresse,

    [parameter(Mandatory,HelpMessage='Bitte einen Office 365 Account angeben der globaler Administrator ist.')]
    [String]$Office365Admin
)

Begin {
     if ($PSCmdlet.ShouldProcess($CSVDatei))
     {  
#region Logerstellung

        $ErrorActionPreference = 'Stop'
        # Formatierung für den Namen des Transcipts
        $date=Get-Date -Format g | foreach {$_ -replace ':','.'}
        $filename='NewOffice365User_' +($date.ToString()) + '.txt'
        
        # Speicherpfad für das Log
        $logpath="$env:HOMEPATH\Documents"
        Start-Transcript -IncludeInvocationHeader -Path "$logpath\$filename"
#endregion Logerstellung       

#region Arbeitsumgebung vorbereiten
        Write-Verbose -Message "Importiere die Datei $CSVDatei"
        $CSV=Import-Csv -LiteralPath $CSVDatei

        # Benutzername und Passwort für Office 365
        $UserCredential = Get-Credential -UserName $Office365Admin -Message "Bitte das Passwort für $($Office365Admin) eingeben"
        
        #Zu Exchange Online verbinden
        $Params = @{
                    ConfigurationName = 'Microsoft.Exchange'
                    ConnectionUri = 'https://outlook.office365.com/powershell-liveid/'
                    Credential = $UserCredential
                    Authentication = 'Basic'
                    AllowRedirection = $true
        }
        $Session = New-PSSession @Params
        
        # Session importieren
        Import-PSSession -Session $Session -AllowClobber
        
        Write-Verbose -Message 'Verbindung mit Azure herstellen'
        Connect-MsolService -Credential $UserCredential
#endregion Arbeitsumgebung vorbereiten

#region Helper-Function Set-OnlineUser
            # Helper Function
            # Fügt den erstellten Benutzer zur Verteilergruppe Outlook in Exchange Online hinzu, ändert die Adressbuchrichtline auf Outlook.Abp 
            # und der Standartwert für das öffentliche Ordnerpostfach wird auf Ordnerpostfach-o365 geändert
            function Set-OnlineUser {
               [CmdletBinding()]
               param ($OnlineUser) 

               Write-Verbose -Message "Benutzer $($user.UserPrincipalName) der Verteilergruppe Outlook hinzugefügt"
               Add-DistributionGroupMember -Identity 'Outlook' -Member $User.UserPrincipalName -ErrorAction SilentlyContinue 

               # Publicfolder und Adressbuchrichtline ändern
               # Werte für die Adressbuchrichtline und Publicfolder anpassen
               Write-Verbose -Message "Ändere die Adressbuchrichtline und den Standart Publich Folder für $($User.UserPrincipalName)"
               Get-Mailbox -Identity $User.UserPrincipalName | Set-Mailbox -AddressBookPolicy 'Outlook.Abp' -DefaultPublicFolderMailbox Ordnerpostfach-o365

               }
#endregion Helper-Function Set-OnlineUser

         }      
      }

Process {

        try {   
                if ($PSCmdlet.ShouldProcess($CSVDatei))
                {
                    
#region Create User in Azure AD
                 foreach ($User in $CSV)
                 {

                 # Hashtable mit einigen Standartwerten
                 $Params = @{
                            'UserPrincipalName' = $User.Userprincipalname
                            'DisplayName' = $User.Displayname
                            'Password' = $User.Password
                            'StrongPasswordRequired' = $false
                            'LicenseAssignment' = 'YOURCOMPANYNAME:YOURLICENCE'
                            'UsageLocation' = 'DE'
                            'ForceChangePassword' = $false
                            }
                    
                    # Erstellt den/die User in Office 365
                    Write-Verbose -Message "Erstelle den Benutzer $($User.UserPrincipalName)"
                    New-MsolUser @Params -ErrorAction Stop

                      }
                    
#endregion Create User in Azure AD

#region warte auf Fertigstellung der Email-Postfächer
                    Write-Host 'Warten auf Fertigstellung der E-Mail-Postfächer' -ForegroundColor Yellow
                    Write-Host 'Warte 120 Sekunden ...' -ForegroundColor Yellow
                    
                    # Auf den Abschluss der Erstellung der Postfächer warten
                    Start-Sleep -Seconds 120
    
#endregion warte auf Fertigstellung der Email-Postfächer

#region set user properties
                    foreach ($User in $CSV)
                    {
                        # Führe die Funktion aus wenn die Postfächer vorhanden sind, ansonsten warte weitere 60 Sekunden auf die Fertigstellung und führe dann die Funktion aus
                        if (Get-Mailbox $User.Userprincipalname)
                        {
                        # Führe die Funktion aus wenn die Postfächer nach 120 Sekunden vorhanden sind
                          Set-OnlineUser -Onlineuser $User -ErrorAction Stop
                        }
                   
                        else
                        { 
                        # Führe die Funktion aus nachdem weitere 120 Sekunden gewartet wurde
                        Write-Host "Postfach für den Benutzer $($User.UserPrincipalName) ist noch in Bearbeitung" -ForegroundColor Yellow
                        Write-Host 'Warte 120 Sekunden' -ForegroundColor Yellow
                        Start-Sleep -Seconds 120
                        Set-OnlineUser -Onlineuser $User -ErrorAction Stop
                        }
    
                    }
#endregion set user properties
                  }
            }
        catch
            {
            Write-Output $_.Exception.Message

            # Exchange-Sitzung löschen
            Remove-PSSession -Session $Session -Verbose -ErrorAction Stop
                
            # Module für Azure AD und ActiveDirectory aus der aktuellen Sitzung entfernen
            Remove-Module -Name 'MSOnline','ActiveDirectory' -ErrorAction Stop -Force
            
            Stop-Transcript

#region Mail für Fehler

# AD-User-Objekt des aktuell angemeldeten Benutzers
Write-Verbose -Message "AD-User-Objekt für $($env:Username) ermitteln"
$Signature = Get-ADUser -Identity $env:Username

# Here-String für den Body der zusendenen EMail. Inhalt kann bei Bedarf angepasst werden.
$body = @"
Hallo $($Signature.Givenname),

Bei der Erstellung der Benutzerkonten für Office 365 gab es Probleme.

Der Fehler lautet:
$($_.Exception.Message)

Bitte den Fehler beheben und die Funktion erneut ausführen.
"@

                # Eigenschaften für Send-MailMessage
                $params = @{to = $Signature.UserPrincipalName
                Subject = 'Office 365 Accounts'
                Body = $body
                UseSSL = $true
                Port = 587
                SmtpServer = 'smtp.office365.com'
                From = $Office365Admin
                Credential = $UserCredential
                Attachment = "$logpath\$filename"
                Encoding = 'UTF8'
                }
                
                Write-Verbose -Message "Sende Email an $($Signature)"
                
                # Email an gewünschten Empfänger senden
                Send-MailMessage @params
#endregion Mail für Fehler

                break
              } 

            }
        
    End {
            
#region cleanup
                # Exchange-Sitzung löschen
                Remove-PSSession -Session $Session -Verbose
                
                # Module für Azure AD und ActiveDirectory aus der aktuellen Sitzung entfernen
                Remove-Module -Name 'MSOnline','ActiveDirectory' -Force
                
                Write-Verbose -Message 'Alle Benutzer erfolgreich erstellt'

                # Aufzeichnung stoppen und auf Speicherung des Logs warten
                Stop-Transcript
                Start-Sleep -Seconds 5

#endregion cleanup

#region EMail

# AD-User-Objekt des Empfängers  
Write-Verbose -Message "AD-User-Objekt für $($EMailadresse) ermitteln"
$Empfaenger = get-aduser -filter {UserprincipalName -eq $EMailadresse}

# AD-User-Objekt des aktuell angemeldeten Benutzers
Write-Verbose -Message "AD-User-Objekt für $($env:Username) ermitteln"
$Signature = Get-ADUser -Identity $env:Username

# Ausgabe der Emailadressen für die Accounts in der Email vorbereiten
$UPN = foreach ($User in $CSV)
            {
            "$($user.UserPrincipalName)"
            }
$Ausgabe = $UPN | Format-List | Out-String 

# Here-String für den Body der zusendenen EMail. Inhalt kann bei Bedarf angepasst werden.
$body = @"
Hallo $($Empfaenger.Givenname),

die Accounts wurden erfolgreich angelegt.

Die Benutzernamen lauten:

$($Ausgabe)
Das Passwort für alle Benutzer ist $($csv[0].Password)

Mit freundlichen Grüßen

$($Signature.givenname) $($Signature.Surname)
"@

                # Eigenschaften für Send-MailMessage
                $params = @{to = $EMailadresse
                Subject = 'Office 365 Accounts'
                Body = $body
                UseSSL = $true
                Port = 587
                SmtpServer = 'smtp.office365.com'
                From = $Office365Admin
                Credential = $UserCredential
                Encoding = 'UTF8'
                }
                
                Write-Verbose -Message "Sende Email an $($EMailadresse)"
                
                # Email an gewünschten Empfänger senden
                Send-MailMessage @params

#endregion EMail 

    }

}