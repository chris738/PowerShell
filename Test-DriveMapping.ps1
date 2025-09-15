# Test-DriveMapping.ps1
# Testet die Laufwerkszuordnungs-Funktionalität ohne AD-Änderungen
# Aufruf: .\Test-DriveMapping.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

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

Write-Host "Teste Laufwerkszuordnungs-Funktionalität..." -ForegroundColor Cyan

$users = Import-Csv -Path $CsvFile -Delimiter ";"
$server = Get-DomainControllerServer

Write-Host "Verwende Server: $server" -ForegroundColor Green
Write-Host "`nGeplante Laufwerkszuordnungen:" -ForegroundColor Yellow

foreach ($user in $users) {
    $vorname = ($user.Vorname -replace '\s+','').Trim()
    $nachname = ($user.Nachname -replace '\s+','').Trim()
    $abteilung = $user.Abteilung
    
    if (-not $vorname -or -not $nachname) { continue }
    
    # Neues SAM Format: Vorname.Nachname  
    $sam = Get-SamAccountName -Vorname $vorname -Nachname $nachname
    $folderName = $sam  # Ordnername entspricht SAM
    
    # Pfade definieren
    $homePath = "\\$server\Home$\$folderName"
    $globalPath = "\\$server\Global$"
    $departmentPath = "\\$server\Abteilungen$\$abteilung"
    
    Write-Host "`nBenutzer: $sam ($($user.Vorname) $($user.Nachname))" -ForegroundColor White
    Write-Host "  H: → $homePath" -ForegroundColor Green
    Write-Host "  G: → $globalPath" -ForegroundColor Green  
    Write-Host "  S: → $departmentPath" -ForegroundColor Green
    
    # Zeige Logon-Script Inhalt
    $scriptContent = @"
@echo off
net use G: "$globalPath" /persistent:yes >nul 2>&1
net use S: "$departmentPath" /persistent:yes >nul 2>&1
"@
    
    Write-Host "  Logon-Script: ${sam}_logon.bat" -ForegroundColor Cyan
}

Write-Host "`nZusammenfassung:" -ForegroundColor Yellow
$departments = $users | Select-Object -ExpandProperty Abteilung -Unique
Write-Host "Abteilungen: $($departments -join ', ')" -ForegroundColor White
Write-Host "Benutzer gesamt: $($users.Count)" -ForegroundColor White
Write-Host "Scripts-Verzeichnis: \\$server\Scripts$" -ForegroundColor White

Write-Host "`nTest abgeschlossen! Die Laufwerkszuordnungen würden wie oben gezeigt konfiguriert." -ForegroundColor Green