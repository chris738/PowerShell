# Test-Scripts.ps1
# Testet alle Skripte auf korrektes Laden der CSV-Daten

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir "Common-Functions.ps1")

Write-Host "Teste CSV-Integration aller Skripte..." -ForegroundColor Cyan

# CSV-Pfad
$csvFile = Join-Path $scriptDir "Userlist-EchtHamburg.csv"

# Test CSV-Validierung
Write-Host "1. Teste CSV-Validierung..."
if (Test-CsvFile -CsvPath $csvFile) {
    Write-Host "   CSV-Datei ist gültig"
} else {
    Write-Host "   CSV-Datei ist ungültig"
    exit 1
}

# Test Abteilungen-Loading
Write-Host "2. Teste Abteilungen-Loading..."
$departments = Get-DepartmentsFromCSV -CsvPath $csvFile
if ($departments.Count -gt 0) {
    Write-Host "   $($departments.Count) Abteilungen gefunden: $($departments -join ', ')"
} else {
    Write-Host "   Keine Abteilungen gefunden"
    exit 1
}

# Test Skript-Syntax
$scripts = @("Setup-Groups.ps1", "Setup-GG-Membership.ps1", "Create-HomeFolders.ps1", 
            "Setup-Fileserver.ps1", "Setup-Fileserver-Rights.ps1", "Run-All-Scripts.ps1")

Write-Host "3. Teste Skript-Syntax..."
foreach ($script in $scripts) {
    $scriptPath = Join-Path $scriptDir $script
    if (Test-Path $scriptPath) {
        try {
            Get-Command $scriptPath | Out-Null
            Write-Host "   $script - Syntax OK"
        }
        catch {
            Write-Host "   $script - Syntax-Fehler: $_"
        }
    } else {
        Write-Host "   $script - Datei nicht gefunden"
    }
}

Write-Host "Tests abgeschlossen!" -ForegroundColor Green