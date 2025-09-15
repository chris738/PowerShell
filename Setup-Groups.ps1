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

# --- Globale Gruppen für Fileserver ---
# Diese Gruppen werden auf Domain-Ebene erstellt für bessere Zugänglichkeit aller OUs
$dlGlobalRW = "DL_Global-FS_RW"
$dlGlobalR  = "DL_Global-FS_R"

foreach ($grp in @($dlGlobalRW, $dlGlobalR)) {
    if (-not (Get-ADGroup -Filter {Name -eq $grp} -ErrorAction SilentlyContinue)) {
        try {
            New-ADGroup -Name $grp -GroupScope DomainLocal -GroupCategory Security -Path $dcPath -Description "DL Gruppe für Global Fileshare"
            $cleanMessage = Remove-EmojiFromString -InputString "Global-Gruppe erstellt: $grp auf Domain-Ebene"
            Write-Host $cleanMessage
        }
        catch {
            Write-ErrorMessage -Message "Fehler beim Erstellen der Global-Gruppe $grp : $_" -Type "Error"
        }
    }
}

foreach ($dep in $departments) {
    $ouPath = "OU=$dep,$dcPath"

    # Globale Gruppe (Mitarbeiter)
    $ggGroup = "GG_${dep}-MA"
    if (-not (Get-ADGroup -Filter {Name -eq $ggGroup} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        try {
            New-ADGroup -Name $ggGroup -GroupScope Global -GroupCategory Security -Path $ouPath -Description "Globale Gruppe Mitarbeiter $dep"
            $cleanMessage = Remove-EmojiFromString -InputString "Gruppe erstellt: $ggGroup in $dep"
            Write-Host $cleanMessage
        }
        catch {
            Write-ErrorMessage -Message "Fehler beim Erstellen der Gruppe $ggGroup : $_" -Type "Error"
        }
    }

    # Domain Local Gruppen (FS-Rechte) - RW und R
    $dlGroupRW = "DL_${dep}-FS_RW"
    $dlGroupR  = "DL_${dep}-FS_R"
    
    foreach ($dlGroup in @($dlGroupRW, $dlGroupR)) {
        if (-not (Get-ADGroup -Filter {Name -eq $dlGroup} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
            try {
                $description = if ($dlGroup -like "*_RW") { "Domain Local Gruppe FS RW $dep" } else { "Domain Local Gruppe FS R $dep" }
                New-ADGroup -Name $dlGroup -GroupScope DomainLocal -GroupCategory Security -Path $ouPath -Description $description
                $cleanMessage = Remove-EmojiFromString -InputString "Gruppe erstellt: $dlGroup in $dep"
                Write-Host $cleanMessage
            }
            catch {
                Write-ErrorMessage -Message "Fehler beim Erstellen der Gruppe $dlGroup : $_" -Type "Error"
            }
        }
    }

    # Globale Gruppe Mitglied in Domain Local Gruppen
    foreach ($dlGroup in @($dlGroupRW, $dlGroupR)) {
        try {
            Add-ADGroupMember -Identity $dlGroup -Members $ggGroup -ErrorAction Stop
            $cleanMessage = Remove-EmojiFromString -InputString "$ggGroup → $dlGroup"
            Write-Host $cleanMessage
        }
        catch {
            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*bereits vorhanden*") {
                Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo "$ggGroup in $dlGroup"
            } else {
                Write-ErrorMessage -Message "$ggGroup konnte nicht in $dlGroup eingefügt werden: $_" -Type "Error"
            }
        }
    }
}
