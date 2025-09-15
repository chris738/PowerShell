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

function Get-DomainControllerServer {
    <#
    .SYNOPSIS
    Ermittelt den Domain Controller Server für Laufwerkszuordnungen
    
    .DESCRIPTION
    Versucht zuerst den aktuellen Server zu verwenden (wo das Script läuft),
    dann den Domain Controller, und falls nötig eine IP-Adresse
    
    .RETURNS
    Servername oder IP-Adresse für UNC-Pfade
    #>
    try {
        # Zuerst: Aktueller Server (wo Script läuft)
        $currentServer = $env:COMPUTERNAME
        if ($currentServer) {
            Write-Host "Verwende aktuellen Server: $currentServer" -ForegroundColor Green
            return $currentServer
        }
        
        # Fallback: Domain Controller ermitteln
        $domain = Get-ADDomain -ErrorAction SilentlyContinue
        if ($domain -and $domain.PDCEmulator) {
            $dcServer = $domain.PDCEmulator.Split('.')[0]  # Nur Hostname ohne Domain
            Write-Host "Domain Controller ermittelt: $dcServer" -ForegroundColor Green
            return $dcServer
        }
        
        # Letzter Fallback: localhost
        Write-Warning "Konnte keinen Server ermitteln, verwende localhost"
        return "localhost"
    }
    catch {
        Write-Warning "Fehler bei Server-Ermittlung: $_"
        # Notfall-Fallback: localhost
        return "localhost"
    }
}

function Get-SamAccountName {
    <#
    .SYNOPSIS
    Erstellt SAM Account Name im Format Vorname.Nachname
    
    .PARAMETER Vorname
    Vorname des Benutzers
    
    .PARAMETER Nachname  
    Nachname des Benutzers
    
    .RETURNS
    SAM Account Name im Format "vorname.nachname" (lowercase)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Vorname,
        
        [Parameter(Mandatory=$true)]
        [string]$Nachname
    )
    
    $cleanVorname = ($Vorname -replace '\s+','').Trim()
    $cleanNachname = ($Nachname -replace '\s+','').Trim()
    
    if (-not $cleanVorname -or -not $cleanNachname) {
        throw "Vorname und Nachname dürfen nicht leer sein"
    }
    
    return "$cleanVorname.$cleanNachname".ToLower()
}