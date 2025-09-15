# AddUsers.ps1
# Aufruf: .\AddUsers.ps1 users.csv

param(
    [Parameter(Mandatory=$true)]
    [string]$csvFile
)

Import-Module ActiveDirectory

if (-Not (Test-Path $csvFile)) {
    Write-Host "CSV-Datei $csvFile nicht gefunden!" -ForegroundColor Red
    exit 1
}

$users = Import-Csv -Path $csvFile -Delimiter ";"

foreach ($user in $users) {
    $vorname   = $user.Vorname
    $nachname  = $user.Nachname
    $ou        = $user.Abteilung
    $email     = $user.'E-Mail'
    $sam       = ($vorname.Substring(0,1) + $nachname).ToLower()
    $display   = "$vorname $nachname"

    # OU-Pfad anpassen auf deine Domain
    $ouPath = "OU=$ou,DC=ehh,DC=de"

    # Passwort generieren (oder aus CSV erweitern)
    $pwd = ConvertTo-SecureString "Start123!" -AsPlainText -Force

    try {
        New-ADUser `
            -Name $display `
            -GivenName $vorname `
            -Surname $nachname `
            -SamAccountName $sam `
            -UserPrincipalName "$sam@ehh.de" `
            -EmailAddress $email `
            -Path $ouPath `
            -AccountPassword $pwd `
            -ChangePasswordAtLogon $true `
            -Enabled $true

        Write-Host "Benutzer $display erfolgreich angelegt in $ouPath"
    }
    catch {
        Write-Host "Fehler bei: $_"
    }
}
