# Demo-CSV-Integration.ps1
# Demonstriert die automatische CSV-Integration

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir "Common-Functions.ps1")

Write-Host "🎬 Demo: Automatische CSV-gesteuerte Skripte" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

# CSV-Datei laden
$csvFile = Join-Path $scriptDir "Userlist-EchtHamburg.csv"
Write-Host "📄 CSV-Datei: $csvFile" -ForegroundColor Yellow

# Zeige CSV-Inhalt (erste 5 Zeilen)
Write-Host "`n📋 CSV-Inhalt (Beispiel):" -ForegroundColor Yellow
$csvContent = Get-Content $csvFile -TotalCount 6
foreach ($line in $csvContent) {
    Write-Host "   $line" -ForegroundColor Gray
}

# Lade Abteilungen automatisch
Write-Host "`n🔍 Automatische Abteilungserkennung:" -ForegroundColor Yellow
$departments = Get-DepartmentsFromCSV -CsvPath $csvFile

Write-Host "`n📊 Statistiken:" -ForegroundColor Yellow
$users = Import-Csv -Path $csvFile -Delimiter ";"
$stats = $users | Group-Object Abteilung | Sort-Object Count -Descending

foreach ($stat in $stats) {
    Write-Host "   $($stat.Name): $($stat.Count) Benutzer" -ForegroundColor White
}

Write-Host "`n✨ Vorteile der neuen CSV-Integration:" -ForegroundColor Green
Write-Host "   ✅ Keine manuellen Anpassungen der Skripte mehr nötig"
Write-Host "   ✅ Abteilungen werden automatisch aus CSV erkannt"
Write-Host "   ✅ Alle Skripte verwenden dieselbe Datenquelle"
Write-Host "   ✅ Zentrale Konfiguration über CSV-Datei"
Write-Host "   ✅ Master-Skript führt alle Skripte koordiniert aus"

Write-Host "`n🚀 Nächste Schritte:" -ForegroundColor Cyan
Write-Host "   1. .\Run-All-Scripts.ps1              # Alle Skripte ausführen"
Write-Host "   2. .\Run-All-Scripts.ps1 -SkipUsers   # Ohne Benutzer-Erstellung"
Write-Host "   3. .\Setup-Groups.ps1                 # Nur Gruppen erstellen"
Write-Host "   4. .\Test-Scripts.ps1                 # Integration testen"

Write-Host "`n🎉 Setup abgeschlossen! Alle Skripte sind jetzt CSV-gesteuert." -ForegroundColor Green