# BEFORE-AFTER-Comparison.md
# Vergleich: Vorher vs. Nachher

## VORHER (Probleme)

### Setup-Groups.ps1 - Alt
```powershell
Import-Module ActiveDirectory

# Abteilungen / OUs - HARDCODED!
$departments = @("IT","Events","Facility","Gast","Vorstand","Shop","Verwaltung")

foreach ($dep in $departments) {
    # ... Gruppen erstellen
}
```

**Probleme:**
Hardcoded Abteilungen  
Unterschiedliche Listen in verschiedenen Skripten  
Manuelle Anpassung für jedes Deployment nötig  
Inkonsistenz zwischen CSV und Skripten  
Fehleranfällig bei Änderungen  

## NACHHER (Lösung)

### Setup-Groups.ps1 - Neu
```powershell
# Setup-Groups.ps1
# Erstellt Gruppen basierend auf Abteilungen aus CSV-Datei
# Aufruf: .\Setup-Groups.ps1 [pfad-zur-csv-datei]

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

# CSV validieren und Abteilungen laden
if (-not (Test-CsvFile -CsvPath $CsvFile)) {
    exit 1
}

$departments = Get-DepartmentsFromCSV -CsvPath $CsvFile
if ($departments.Count -eq 0) {
    Write-Error "Keine Abteilungen in der CSV-Datei gefunden!"
    exit 1
}

foreach ($dep in $departments) {
    # ... Gruppen erstellen
}
```

**Verbesserungen:**
Automatisches Laden der Abteilungen aus CSV  
Parametrisiert - flexible CSV-Datei Auswahl  
Validierung der CSV-Datei  
Zentrale Funktionsbibliothek  
Fehlerbehandlung  
Konsistenz zwischen allen Skripten  

## Vergleich Abteilungen

| Quelle | Abteilungen |
|--------|-------------|
| **CSV-Datei (Ist)** | Geschäftsführung, Bar, Events, Shop, Verwaltung, EDV, Facility, Gast |
| **Alte Skripte (Hardcoded)** | IT, Events, Facility, Gast, Vorstand, Shop, Verwaltung |
| **Problem** | Inkonsistenz! "Geschäftsführung" ≠ "Vorstand", "EDV" ≠ "IT", "Bar" fehlt |

## Neue Funktionen

### Master-Skript
```powershell
# Führt alle Skripte koordiniert aus
.\Run-All-Scripts.ps1

# Mit benutzerdefinierter CSV
.\Run-All-Scripts.ps1 -CsvFile "andere-benutzer.csv"

# Selektive Ausführung
.\Run-All-Scripts.ps1 -SkipUsers -SkipHomeFolders
```

### Gemeinsame Funktionsbibliothek
- `Get-DepartmentsFromCSV()` - Liest Abteilungen aus CSV
- `Test-CsvFile()` - Validiert CSV-Format
- `Get-DefaultCsvPath()` - Standard CSV-Pfad

### Automatisierte Tests
```powershell
.\Test-Scripts.ps1  # Testet alle Skripte und CSV-Integration
```

## Endergebnis

**Problem gelöst!**
- Alle Skripte nutzen jetzt dieselbe CSV-Quelle
- Keine manuellen Anpassungen mehr nötig
- Abteilungen werden automatisch erkannt
- Master-Skript für koordinierte Ausführung
- Umfassende Dokumentation und Tests