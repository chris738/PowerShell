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
        try {
            New-ADGroup -Name $ggName -GroupScope Global -GroupCategory Security -Path $ouPath -Description "Globale Mitarbeitergruppe $dep"
            $cleanMessage = Remove-EmojiFromString -InputString "GG erstellt: $ggName"
            Write-Host $cleanMessage
        }
        catch {
            Write-ErrorMessage -Message "Fehler beim Erstellen der Gruppe $ggName : $_" -Type "Error"
        }
    } else {
        $cleanMessage = Remove-EmojiFromString -InputString "GG existiert: $ggName"
        Write-Host $cleanMessage
    }

    # Benutzer der OU in GG schieben
    $users = Get-ADUser -SearchBase $ouPath -Filter * -ErrorAction SilentlyContinue
    foreach ($u in $users) {
        try {
            Add-ADGroupMember -Identity $ggName -Members $u.SamAccountName -ErrorAction Stop
            $cleanMessage = Remove-EmojiFromString -InputString "User $($u.SamAccountName) → $ggName"
            Write-Host $cleanMessage
        }
        catch {
            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*bereits vorhanden*") {
                Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo "$($u.SamAccountName) in $ggName"
            } else {
                Write-ErrorMessage -Message "User $($u.SamAccountName) konnte nicht zu $ggName hinzugefügt werden: $_" -Type "Error"
            }
        }
    }

    # DLs definieren
    $dlRW = "DL_${dep}-FS_RW"
    $dlR  = "DL_${dep}-FS_R"

    # GG in DL_RW aufnehmen
    if (Get-ADGroup -Filter {Name -eq $dlRW} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlRW -Members $ggName -ErrorAction Stop
            $cleanMessage = Remove-EmojiFromString -InputString "$ggName → $dlRW"
            Write-Host $cleanMessage
        } 
        catch { 
            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*bereits vorhanden*") {
                Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo "$ggName in $dlRW"
            } else {
                Write-ErrorMessage -Message "$ggName konnte nicht zu $dlRW hinzugefügt werden: $_" -Type "Error"
            }
        }
    }

    # GG in DL_R aufnehmen (optional: nur wenn nötig)
    if (Get-ADGroup -Filter {Name -eq $dlR} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlR -Members $ggName -ErrorAction Stop
            $cleanMessage = Remove-EmojiFromString -InputString "$ggName → $dlR"
            Write-Host $cleanMessage
        } 
        catch { 
            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*bereits vorhanden*") {
                Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo "$ggName in $dlR"
            } else {
                Write-ErrorMessage -Message "$ggName konnte nicht zu $dlR hinzugefügt werden: $_" -Type "Error"
            }
        }
    }

    # *** WICHTIG: Alle GG Gruppen zur Global-Gruppe hinzufügen ***
    # GG in Global RW aufnehmen (alle Benutzer haben Vollzugriff auf Global)
    if (Get-ADGroup -Filter {Name -eq $dlGlobalRW} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlGlobalRW -Members $ggName -ErrorAction Stop
            $cleanMessage = Remove-EmojiFromString -InputString "$ggName → $dlGlobalRW (Global Zugriff)"
            Write-Host $cleanMessage
        } 
        catch { 
            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*bereits vorhanden*") {
                Write-ErrorMessage -Message "Fehler bei: Das angegebene Konto ist bereits vorhanden." -Type "AlreadyExists" -AdditionalInfo "$ggName in $dlGlobalRW"
            } else {
                Write-ErrorMessage -Message "$ggName konnte nicht zu $dlGlobalRW hinzugefügt werden: $_" -Type "Error"
            }
        }
    } else {
        Write-ErrorMessage -Message "Global-Gruppe $dlGlobalRW nicht gefunden!" -Type "NotFound"
    }
}

$cleanMessage = Remove-EmojiFromString -InputString "Setup abgeschlossen."
Write-Host $cleanMessage
