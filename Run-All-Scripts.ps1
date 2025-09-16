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
    [switch]$SkipHomeFolders,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipNetworkShares,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipXMLGPO,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSharePermissions
)

# Lade gemeinsame Funktionen
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $scriptDir "Common-Functions.ps1")

# CSV-Datei bestimmen
if (-not $CsvFile) {
    $CsvFile = Get-DefaultCsvPath
}

Write-Host "Starte Ausführung aller Skripte mit CSV: $CsvFile" -ForegroundColor Cyan

# CSV validieren
if (-not (Test-CsvFile -CsvPath $CsvFile)) {
    exit 1
}

$departments = Get-DepartmentsFromCSV -CsvPath $CsvFile
Write-Host "Verarbeite Abteilungen: $($departments -join ', ')" -ForegroundColor Yellow

# Global Share Path für XML-GPO Scripts bestimmen
$globalSharePath = $null
try {
    $serverName = Get-DomainControllerServer
    $globalSharePath = "\\$serverName\Global$"
    Write-Host "Global Share Path: $globalSharePath" -ForegroundColor Cyan
}
catch {
    Write-Warning "Konnte Global Share Path nicht bestimmen. XML-GPO Scripts werden übersprungen."
}

# Skripte in der richtigen Reihenfolge ausführen
$scripts = @(
    @{Name="Setup-Groups.ps1"; Skip=$SkipGroups; Description="Erstelle Gruppen"},
    @{Name="Create-Users.ps1"; Skip=$SkipUsers; Description="Erstelle Benutzer"},
    @{Name="Setup-GG-Membership.ps1"; Skip=$SkipGroups; Description="Gruppenmitgliedschaften"},
    @{Name="Setup-Fileserver.ps1"; Skip=$SkipFileserver; Description="Fileserver-Struktur"},
    @{Name="Setup-NetworkShares.ps1"; Skip=$SkipNetworkShares; Description="Netzwerkfreigaben"},
    @{Name="Setup-Fileserver-Rights.ps1"; Skip=$SkipFileserver; Description="Fileserver-Rechte"},
    @{Name="Create-HomeFolders.ps1"; Skip=$SkipHomeFolders; Description="Home-Ordner"},
    @{Name="Create-ThreeGPOs-XML.ps1"; Skip=$SkipXMLGPO; Description="XML-basierte GPO Erstellung"; RequiresGlobalShare=$true},
    @{Name="Link-ThreeGPOs-XML.ps1"; Skip=$SkipXMLGPO; Description="XML-basierte GPO Verknüpfung"; RequiresGlobalShare=$false},
    @{Name="Setup-SharePermissions.ps1"; Skip=$SkipSharePermissions; Description="Share-Berechtigungen"}
)

foreach ($script in $scripts) {
    if ($script.Skip) {
        Write-Host "Überspringe: $($script.Description)" -ForegroundColor Gray
        continue
    }
    
    $scriptPath = Join-Path $scriptDir $script.Name
    if (Test-Path $scriptPath) {
        Write-Host "Führe aus: $($script.Description) ($($script.Name))" -ForegroundColor Green
        try {
            # Prüfe ob Script GlobalSharePath benötigt
            if ($script.RequiresGlobalShare -and $globalSharePath) {
                & $scriptPath -CsvFile $CsvFile -GlobalSharePath $globalSharePath
            }
            elseif ($script.RequiresGlobalShare -and -not $globalSharePath) {
                Write-Host "Überspringe $($script.Name): GlobalSharePath nicht verfügbar" -ForegroundColor Yellow
                continue
            }
            else {
                & $scriptPath -CsvFile $CsvFile
            }
            Write-Host "Abgeschlossen: $($script.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "Fehler in $($script.Name): $_" -ForegroundColor Red
        }
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    }
    else {
        Write-Host "Skript nicht gefunden: $scriptPath" -ForegroundColor Yellow
    }
}

Write-Host "Alle Skripte abgeschlossen!" -ForegroundColor Cyan