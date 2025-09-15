# Setup-NetworkShares.ps1
# Erstellt Netzwerkfreigaben für Home, Global und Abteilungen in PowerShell
# Aufruf: .\Setup-NetworkShares.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

# Module importieren (nur auf Windows Server verfügbar)
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module SmbShare -ErrorAction Stop
}
catch {
    Write-Warning "Erforderliche Module (ActiveDirectory, SmbShare) nicht verfügbar."
    Write-Host "Dieses Skript funktioniert nur auf Windows Servern mit Active Directory und SMB-Features." -ForegroundColor Yellow
    Write-Host "Auf Linux/macOS Testumgebungen wird das Skript übersprungen." -ForegroundColor Yellow
    exit 0
}

# Lade gemeinsame Funktionen
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $scriptDir "Common-Functions.ps1")

# CSV-Datei bestimmen
if (-not $CsvFile) {
    $CsvFile = Get-DefaultCsvPath
}

# CSV validieren und Abteilungen laden
if (-not (Test-CsvFile -CsvPath $CsvFile)) {
    exit 1
}

$departments = Get-DepartmentsFromCSV -CsvPath $CsvFile
if ($departments.Count -eq 0) {
    Write-Error "Keine Abteilungen in der CSV-Datei gefunden!"
    exit 1
}

# Basis-Pfad für Shares
$basePath = "F:\Shares"

# Admin-Gruppe mit sicherer Identitätserkennung
try {
    $adminIdentity = Get-SafeDomainAdminsIdentity
    Write-Host "Domain Admins Identität erfolgreich aufgelöst"
}
catch {
    Write-ErrorMessage -Message "Kritischer Fehler: Konnte Domain Admins Identität nicht auflösen" -Type "Error"
    exit 1
}

# Funktion: Netzwerkfreigabe erstellen oder aktualisieren
function Setup-NetworkShare {
    param(
        [string]$ShareName,
        [string]$SharePath,
        [string]$Description,
        [string[]]$FullAccessUsers = @(),
        [string[]]$ChangeAccessUsers = @(),
        [string[]]$ReadAccessUsers = @()
    )

    try {
        # Prüfen ob Share bereits existiert
        $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
        
        if ($existingShare) {
            Write-Host "Share '$ShareName' existiert bereits, überspringe Erstellung"
            return
        }

        # Verzeichnis sicherstellen
        if (-not (Test-Path $SharePath)) {
            Write-Warning "Verzeichnis $SharePath existiert nicht - wird übersprungen"
            return
        }

        # Share erstellen
        New-SmbShare -Name $ShareName -Path $SharePath -Description $Description -FullAccess "Everyone" | Out-Null
        Write-Host "Netzwerkfreigabe erstellt: $ShareName -> $SharePath"

        # Erweiterte Berechtigungen setzen falls angegeben
        if ($FullAccessUsers.Count -gt 0 -or $ChangeAccessUsers.Count -gt 0 -or $ReadAccessUsers.Count -gt 0) {
            # Erst Everyone entfernen
            Revoke-SmbShareAccess -Name $ShareName -AccountName "Everyone" -Force -ErrorAction SilentlyContinue

            # Domain Admins immer Vollzugriff
            Grant-SmbShareAccess -Name $ShareName -AccountName "Domänen-Admins" -AccessRight Full -Force -ErrorAction SilentlyContinue
            Grant-SmbShareAccess -Name $ShareName -AccountName "Domain Admins" -AccessRight Full -Force -ErrorAction SilentlyContinue

            # Spezifische Berechtigungen
            foreach ($user in $FullAccessUsers) {
                Grant-SmbShareAccess -Name $ShareName -AccountName $user -AccessRight Full -Force -ErrorAction SilentlyContinue
            }
            foreach ($user in $ChangeAccessUsers) {
                Grant-SmbShareAccess -Name $ShareName -AccountName $user -AccessRight Change -Force -ErrorAction SilentlyContinue
            }
            foreach ($user in $ReadAccessUsers) {
                Grant-SmbShareAccess -Name $ShareName -AccountName $user -AccessRight Read -Force -ErrorAction SilentlyContinue
            }
        }

        $cleanMessage = Remove-EmojiFromString -InputString "Share-Berechtigungen gesetzt für: $ShareName"
        Write-Host $cleanMessage

    }
    catch {
        Write-ErrorMessage -Message "Fehler beim Erstellen der Freigabe $ShareName : $_" -Type "Error"
    }
}

Write-Host "Starte Erstellung der Netzwerkfreigaben..." -ForegroundColor Cyan

# 1. Home-Share (Home$)
$homeSharePath = Join-Path $basePath "Home"
Setup-NetworkShare -ShareName "Home$" -SharePath $homeSharePath -Description "Home-Verzeichnisse der Benutzer" -ChangeAccessUsers @("Authenticated Users")

# 2. Global-Share (Global$) 
$globalSharePath = Join-Path $basePath "Global"
$globalGroup = "DL_Global-FS_RW"
Setup-NetworkShare -ShareName "Global$" -SharePath $globalSharePath -Description "Globales Verzeichnis für alle Benutzer" -ChangeAccessUsers @($globalGroup)

# 3. Abteilungen-Share (Abteilungen$)
$departmentsSharePath = Join-Path $basePath "Abteilungen"
$departmentGroups = @()
foreach ($dep in $departments) {
    $departmentGroups += "DL_${dep}-FS_RW"
}
Setup-NetworkShare -ShareName "Abteilungen$" -SharePath $departmentsSharePath -Description "Abteilungsverzeichnisse" -ChangeAccessUsers $departmentGroups

# 4. Scripts-Share (Scripts$) - für Logon-Scripts
$scriptsSharePath = Join-Path $basePath "Scripts"
Setup-NetworkShare -ShareName "Scripts$" -SharePath $scriptsSharePath -Description "Benutzer Logon-Scripts" -ReadAccessUsers @("Authenticated Users")

Write-Host "Alle Netzwerkfreigaben wurden erfolgreich erstellt!" -ForegroundColor Green

# Freigaben anzeigen
Write-Host "`nErstelle Freigaben:" -ForegroundColor Yellow
Get-SmbShare | Where-Object { $_.Name -in @("Home$", "Global$", "Abteilungen$", "Scripts$") } | Format-Table Name, Path, Description -AutoSize