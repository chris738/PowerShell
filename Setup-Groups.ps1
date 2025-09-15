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
    $ouPath = "OU=$dep,DC=eHH,DC=de"

    # Globale Gruppe (Mitarbeiter)
    $ggGroup = "GG_${dep}-MA"
    if (-not (Get-ADGroup -Filter {Name -eq $ggGroup} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $ggGroup -GroupScope Global -GroupCategory Security -Path $ouPath -Description "Globale Gruppe Mitarbeiter $dep"
        Write-Host "👥 Gruppe erstellt: $ggGroup in $dep"
    }

    # Domain Local Gruppe (FS-Rechte)
    $dlGroup = "DL_${dep}-FS_RW"
    if (-not (Get-ADGroup -Filter {Name -eq $dlGroup} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $dlGroup -GroupScope DomainLocal -GroupCategory Security -Path $ouPath -Description "Domain Local Gruppe FS RW $dep"
        Write-Host "👥 Gruppe erstellt: $dlGroup in $dep"
    }

    # Globale Gruppe Mitglied in Domain Local Gruppe
    try {
        Add-ADGroupMember -Identity $dlGroup -Members $ggGroup -ErrorAction Stop
        Write-Host "🔗 $ggGroup → $dlGroup"
    }
    catch {
        Write-Host "⚠️ $ggGroup konnte nicht in $dlGroup eingefügt werden ($_)" -ForegroundColor Yellow
    }
}
