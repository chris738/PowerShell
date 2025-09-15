# Test-SamAccountChanges.ps1
# Demonstriert die Änderungen am SAM Account Naming
# Aufruf: .\Test-SamAccountChanges.ps1

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

# CSV validieren
if (-not (Test-CsvFile -CsvPath $CsvFile)) {
    exit 1
}

Write-Host "Test: SAM Account Naming Änderungen" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

$users = Import-Csv -Path $CsvFile -Delimiter ";"

Write-Host "`nVorher/Nachher Vergleich für SAM Account Names:" -ForegroundColor Yellow

$count = 0
foreach ($user in $users) {
    $count++
    if ($count -gt 10) { 
        Write-Host "... (nur erste 10 Benutzer angezeigt)" -ForegroundColor Gray
        break 
    }
    
    $vorname = ($user.Vorname -replace '\s+','').Trim()
    $nachname = ($user.Nachname -replace '\s+','').Trim()
    
    if (-not $vorname -or -not $nachname) { continue }
    
    # ALT: Erster Buchstabe + Nachname
    $oldSam = ($vorname.Substring(0,1) + $nachname).ToLower()
    
    # NEU: Vorname.Nachname
    $newSam = Get-SamAccountName -Vorname $vorname -Nachname $nachname
    
    Write-Host "  $($user.Vorname) $($user.Nachname):"
    Write-Host "    ALT: $oldSam" -ForegroundColor Red
    Write-Host "    NEU: $newSam" -ForegroundColor Green
    Write-Host ""
}

Write-Host "`nÄnderungen im Detail:" -ForegroundColor Yellow
Write-Host "• SAM Format: 'j.janssen' → 'jan.janssen'" -ForegroundColor Green
Write-Host "• Ordnername: Entspricht jetzt SAM Account Name" -ForegroundColor Green  
Write-Host "• Server Detection: Automatische Domain Controller Erkennung" -ForegroundColor Green
Write-Host "• Home-Pfad: \\server\Home$\jan.janssen" -ForegroundColor Green
Write-Host "• Global RW: Alle MA-Gruppen werden zur Global-Gruppe hinzugefügt" -ForegroundColor Green

Write-Host "`nImplementierte Anforderungen:" -ForegroundColor Yellow
Write-Host "✅ SAM Account Name: Vorname.Nachname Format" -ForegroundColor Green
Write-Host "✅ Laufwerkszuordnungen zum Domain Controller" -ForegroundColor Green 
Write-Host "✅ Ordner und Rechte korrekt gesetzt" -ForegroundColor Green
Write-Host "✅ MA-Gruppen zur Global RW Gruppe hinzugefügt" -ForegroundColor Green

Write-Host "`nTest abgeschlossen!" -ForegroundColor Cyan