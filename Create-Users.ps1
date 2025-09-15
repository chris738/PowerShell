# Create-Users.ps1
# Erstellt AD-Benutzer basierend auf CSV-Abteilungen mit Vorname.Nachname SAM Format
# Aufruf: .\Create-Users.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

Import-Module ActiveDirectory

# Lade gemeinsame Funktionen
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $scriptDir "Common-Functions.ps1")

# CSV-Datei bestimmen
if (-not $CsvFile) {
    $CsvFile = Get-DefaultCsvPath
}

# CSV validieren
if (-not (Test-CsvFile -CsvPath $CsvFile)) {
    exit 1
}

$users = Import-Csv -Path $CsvFile -Delimiter ";"

# Domain Info
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"

foreach ($user in $users) {
    $vorname   = ($user.Vorname -replace '\s+','').Trim()
    $nachname  = ($user.Nachname -replace '\s+','').Trim()
    $ou        = $user.Abteilung
    $email     = $user.'E-Mail'
    
    if (-not $vorname -or -not $nachname) {
        Write-Warning "Vorname oder Nachname fehlt für Benutzer: $($user.Vorname) $($user.Nachname)"
        continue
    }
    
    # Neues SAM Format: Vorname.Nachname
    $sam       = Get-SamAccountName -Vorname $vorname -Nachname $nachname
    $display   = "$($user.Vorname) $($user.Nachname)"

    # OU-Pfad basierend auf Domain
    $ouPath = "OU=$ou,$dcPath"

    # Passwort generieren (oder aus CSV erweitern)
    $pwd = ConvertTo-SecureString "Start123!" -AsPlainText -Force

    try {
        # Prüfen ob Benutzer bereits existiert
        $existingUser = Get-ADUser -Filter {SamAccountName -eq $sam} -ErrorAction SilentlyContinue
        if ($existingUser) {
            Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo $sam
            continue
        }

        New-ADUser `
            -Name $display `
            -GivenName $user.Vorname `
            -Surname $user.Nachname `
            -SamAccountName $sam `
            -UserPrincipalName "$sam@$($domain.DNSRoot)" `
            -EmailAddress $email `
            -Path $ouPath `
            -AccountPassword $pwd `
            -ChangePasswordAtLogon $true `
            -Enabled $true

        $cleanMessage = Remove-EmojiFromString -InputString "Benutzer $display erfolgreich angelegt: $sam in $ouPath"
        Write-Host $cleanMessage -ForegroundColor White
    }
    catch {
        if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*bereits vorhanden*") {
            Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo $sam
        } else {
            Write-ErrorMessage -Message "Fehler bei $display ($sam): $_" -Type "Error"
        }
    }
}
