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

# Domain Info
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"

foreach ($dep in $departments) {
    $ouPath = "OU=$dep,$dcPath"

    # Globale Gruppe (Mitarbeiter)
    $ggGroup = "GG_${dep}-MA"
    if (-not (Get-ADGroup -Filter {Name -eq $ggGroup} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $ggGroup -GroupScope Global -GroupCategory Security -Path $ouPath -Description "Globale Gruppe Mitarbeiter $dep"
        Write-Host "Gruppe erstellt: $ggGroup in $dep"
    }

    # Domain Local Gruppen (FS-Rechte) - RW und R
    $dlGroupRW = "DL_${dep}-FS_RW"
    $dlGroupR  = "DL_${dep}-FS_R"
    
    foreach ($dlGroup in @($dlGroupRW, $dlGroupR)) {
        if (-not (Get-ADGroup -Filter {Name -eq $dlGroup} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
            $description = if ($dlGroup -like "*_RW") { "Domain Local Gruppe FS RW $dep" } else { "Domain Local Gruppe FS R $dep" }
            New-ADGroup -Name $dlGroup -GroupScope DomainLocal -GroupCategory Security -Path $ouPath -Description $description
            Write-Host "Gruppe erstellt: $dlGroup in $dep"
        }
    }

    # Globale Gruppe Mitglied in Domain Local Gruppen
    foreach ($dlGroup in @($dlGroupRW, $dlGroupR)) {
        try {
            Add-ADGroupMember -Identity $dlGroup -Members $ggGroup -ErrorAction Stop
            Write-Host "$ggGroup → $dlGroup"
        }
        catch {
            Write-Host "$ggGroup konnte nicht in $dlGroup eingefügt werden ($_)" -ForegroundColor Yellow
        }
    }
}
