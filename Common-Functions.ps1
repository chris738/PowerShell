# Common-Functions.ps1
# Gemeinsame Funktionen für alle PowerShell-Skripte

function Get-DepartmentsFromCSV {
    <#
    .SYNOPSIS
    Liest eindeutige Abteilungen aus der CSV-Datei
    
    .PARAMETER CsvPath
    Pfad zur CSV-Datei mit Benutzerdaten
    
    .RETURNS
    Array mit eindeutigen Abteilungsnamen
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )
    
    if (-Not (Test-Path $CsvPath)) {
        Write-Error "CSV-Datei $CsvPath nicht gefunden!"
        return @()
    }
    
    try {
        $users = Import-Csv -Path $CsvPath -Delimiter ";"
        $departments = $users | Select-Object -ExpandProperty Abteilung -Unique | Where-Object { $_ -ne "" }
        Write-Host "Gefundene Abteilungen aus CSV: $($departments -join ', ')" -ForegroundColor Green
        return $departments
    }
    catch {
        Write-Error "Fehler beim Lesen der CSV-Datei: $_"
        return @()
    }
}

function Get-DefaultCsvPath {
    <#
    .SYNOPSIS
    Gibt den Standard-Pfad zur CSV-Datei zurück
    #>
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    return Join-Path $scriptDir "Userlist-EchtHamburg.csv"
}

function Test-CsvFile {
    <#
    .SYNOPSIS
    Überprüft, ob die CSV-Datei die erforderlichen Spalten enthält
    
    .PARAMETER CsvPath
    Pfad zur CSV-Datei
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )
    
    if (-Not (Test-Path $CsvPath)) {
        Write-Error "CSV-Datei $CsvPath nicht gefunden!"
        return $false
    }
    
    try {
        $sample = Import-Csv -Path $CsvPath -Delimiter ";" | Select-Object -First 1
        $requiredColumns = @('Vorname', 'Nachname', 'Abteilung', 'E-Mail')
        
        foreach ($col in $requiredColumns) {
            if (-not $sample.PSObject.Properties.Name.Contains($col)) {
                Write-Error "Erforderliche Spalte '$col' fehlt in der CSV-Datei!"
                return $false
            }
        }
        
        Write-Host "CSV-Datei Format ist korrekt" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Fehler beim Validieren der CSV-Datei: $_"
        return $false
    }
}