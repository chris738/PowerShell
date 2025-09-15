# Run-All-Scripts.ps1
# Führt alle Skripte mit derselben CSV-Datei aus
# Aufruf: .\Run-All-Scripts.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipUsers,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGroups,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipFileserver,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipHomeFolders
)

# Lade gemeinsame Funktionen
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $scriptDir "Common-Functions.ps1")

# CSV-Datei bestimmen
if (-not $CsvFile) {
    $CsvFile = Get-DefaultCsvPath
}

Write-Host "🚀 Starte Ausführung aller Skripte mit CSV: $CsvFile" -ForegroundColor Cyan

# CSV validieren
if (-not (Test-CsvFile -CsvPath $CsvFile)) {
    exit 1
}

$departments = Get-DepartmentsFromCSV -CsvPath $CsvFile
Write-Host "📋 Verarbeite Abteilungen: $($departments -join ', ')" -ForegroundColor Yellow

# Skripte in der richtigen Reihenfolge ausführen
$scripts = @(
    @{Name="Setup-Groups.ps1"; Skip=$SkipGroups; Description="Erstelle Gruppen"},
    @{Name="Create-Users.ps1"; Skip=$SkipUsers; Description="Erstelle Benutzer"},
    @{Name="Setup-GG-Membership.ps1"; Skip=$SkipGroups; Description="Gruppenmitgliedschaften"},
    @{Name="Setup-Fileserver.ps1"; Skip=$SkipFileserver; Description="Fileserver-Struktur"},
    @{Name="Setup-Fileserver-Rights.ps1"; Skip=$SkipFileserver; Description="Fileserver-Rechte"},
    @{Name="Create-HomeFolders.ps1"; Skip=$SkipHomeFolders; Description="Home-Ordner"}
)

foreach ($script in $scripts) {
    if ($script.Skip) {
        Write-Host "⏭️ Überspringe: $($script.Description)" -ForegroundColor Gray
        continue
    }
    
    $scriptPath = Join-Path $scriptDir $script.Name
    if (Test-Path $scriptPath) {
        Write-Host "▶️ Führe aus: $($script.Description) ($($script.Name))" -ForegroundColor Green
        try {
            & $scriptPath -CsvFile $CsvFile
            Write-Host "✅ Abgeschlossen: $($script.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Fehler in $($script.Name): $_" -ForegroundColor Red
        }
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    }
    else {
        Write-Host "⚠️ Skript nicht gefunden: $scriptPath" -ForegroundColor Yellow
    }
}

Write-Host "🎉 Alle Skripte abgeschlossen!" -ForegroundColor Cyan