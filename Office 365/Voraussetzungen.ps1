Import-Module MSOnline

# Diesen Teil ermittelt ob der Anmeldedienst installiert ist
$keys = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
$items = $keys | Foreach-Object { Get-ItemProperty $_.PsPath } 
$MSKey = $items | where {$_.displayname -like 'Microsoft Online Services-Anmeldeassistent'}

if ($MSKey)
{

}
else {
Write-Warning 'Microsoft Online Services Sign-in Assistent ist nicht installiert. Bitte installieren Sie die nötigen Komponenten'
}