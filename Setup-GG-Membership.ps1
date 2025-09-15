# Setup-GG-Membership.ps1
# Fügt Benutzer in Gruppen basierend auf CSV-Abteilungen hinzu
# Aufruf: .\Setup-GG-Membership.ps1 [pfad-zur-csv-datei]

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

# Global-Gruppen definieren
$dlGlobalRW = "DL_Global-FS_RW"
$dlGlobalR  = "DL_Global-FS_R"

foreach ($dep in $departments) {
    $ouPath = "OU=$dep,$dcPath"

    # GG erstellen
    $ggName = "GG_${dep}-MA"
    if (-not (Get-ADGroup -Filter {Name -eq $ggName} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $ggName -GroupScope Global -GroupCategory Security -Path $ouPath -Description "Globale Mitarbeitergruppe $dep"
        Write-Host "👥 GG erstellt: $ggName"
    } else {
        Write-Host "ℹ️ GG existiert: $ggName"
    }

    # Benutzer der OU in GG schieben
    $users = Get-ADUser -SearchBase $ouPath -Filter * -ErrorAction SilentlyContinue
    foreach ($u in $users) {
        try {
            Add-ADGroupMember -Identity $ggName -Members $u.SamAccountName -ErrorAction Stop
            Write-Host "➕ User $($u.SamAccountName) → $ggName"
        }
        catch {
            Write-Host "⚠️ User $($u.SamAccountName) ist evtl. schon Mitglied in $ggName"
        }
    }

    # DLs definieren
    $dlRW = "DL_${dep}-FS_RW"
    $dlR  = "DL_${dep}-FS_R"

    # GG in DL_RW aufnehmen
    if (Get-ADGroup -Filter {Name -eq $dlRW} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlRW -Members $ggName -ErrorAction Stop
            Write-Host "🔗 $ggName → $dlRW"
        } catch { Write-Host "⚠️ $ggName evtl. schon in $dlRW" }
    }

    # GG in DL_R aufnehmen (optional: nur wenn nötig)
    if (Get-ADGroup -Filter {Name -eq $dlR} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlR -Members $ggName -ErrorAction Stop
            Write-Host "🔗 $ggName → $dlR"
        } catch { Write-Host "⚠️ $ggName evtl. schon in $dlR" }
    }

    # *** WICHTIG: Alle GG Gruppen zur Global-Gruppe hinzufügen ***
    # GG in Global RW aufnehmen (alle Benutzer haben Vollzugriff auf Global)
    if (Get-ADGroup -Filter {Name -eq $dlGlobalRW} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlGlobalRW -Members $ggName -ErrorAction Stop
            Write-Host "🌍 $ggName → $dlGlobalRW (Global Zugriff)"
        } catch { Write-Host "⚠️ $ggName evtl. schon in $dlGlobalRW" }
    } else {
        Write-Host "⚠️ Global-Gruppe $dlGlobalRW nicht gefunden!"
    }
}

Write-Host "✅ Setup abgeschlossen."
