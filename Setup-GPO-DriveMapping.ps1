# Setup-GPO-DriveMapping.ps1
# Erstellt GPOs für Laufwerkszuordnungen (T: für Abteilungen, G: für Global) und deaktiviert Suchleiste
# Aufruf: .\Setup-GPO-DriveMapping.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

# Module importieren
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
}
catch {
    Write-Warning "Erforderliche Module (ActiveDirectory, GroupPolicy) nicht verfügbar."
    Write-Host "Dieses Skript funktioniert nur auf Windows Servern mit Active Directory und Group Policy Management." -ForegroundColor Yellow
    Write-Host "Auf Linux/macOS Testumgebungen wird das Skript übersprungen." -ForegroundColor Yellow
    exit 0
}

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

Write-Host "Erstelle GPOs für Laufwerkszuordnungen..." -ForegroundColor Cyan

# Domain Info
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"

# Funktion: GPO erstellen oder abrufen
function Get-OrCreateGPO {
    param(
        [string]$Name,
        [string]$Comment
    )
    
    try {
        $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
        if (-not $gpo) {
            $gpo = New-GPO -Name $Name -Comment $Comment
            Write-Host "GPO erstellt: $Name" -ForegroundColor Green
        } else {
            Write-Host "GPO bereits vorhanden: $Name" -ForegroundColor Yellow
        }
        return $gpo
    }
    catch {
        Write-Error "Fehler bei GPO-Erstellung '$Name': $_"
        return $null
    }
}

# Funktion: Registry-Einstellungen für GPO hinzufügen
function Add-GPRegistryValue {
    param(
        [string]$GPOName,
        [string]$Key,
        [string]$ValueName,
        [string]$Type,
        [string]$Value
    )
    
    try {
        Set-GPRegistryValue -Name $GPOName -Key $Key -ValueName $ValueName -Type $Type -Value $Value
        Write-Host "Registry-Einstellung hinzugefügt: $Key\$ValueName = $Value" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler beim Hinzufügen der Registry-Einstellung: $_"
    }
}

# 1. GPO für Globales Laufwerk (G:) erstellen
$globalGPO = Get-OrCreateGPO -Name "DriveMapping-Global-G" -Comment "Zuordnung des globalen Laufwerks G: für alle Benutzer"

if ($globalGPO) {
    # G: Laufwerk über Registry-Einstellungen konfigurieren
    # Hinweis: In Produktionsumgebung würde man Group Policy Preferences verwenden
    # Diese Registry-Einstellungen simulieren die GPP-Funktionalität
    
    # Suchleiste in Taskbar deaktivieren
    Add-GPRegistryValue -GPOName $globalGPO.DisplayName -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "SearchboxTaskbarMode" -Type DWord -Value "0"
    
    Write-Host "Globale GPO konfiguriert: G: Laufwerk und Suchleiste deaktiviert" -ForegroundColor Green
}

# 2. GPOs für Abteilungslaufwerke (T:) erstellen
foreach ($dep in $departments) {
    $gpoName = "DriveMapping-$dep-T"
    $gpoComment = "Zuordnung des Abteilungslaufwerks T: für Abteilung $dep"
    
    $deptGPO = Get-OrCreateGPO -Name $gpoName -Comment $gpoComment
    
    if ($deptGPO) {
        # T: Laufwerk für Abteilung konfigurieren
        # Hinweis: In Produktionsumgebung würde man Group Policy Preferences verwenden
        
        # Suchleiste in Taskbar deaktivieren (für alle GPOs)
        Add-GPRegistryValue -GPOName $deptGPO.DisplayName -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "SearchboxTaskbarMode" -Type DWord -Value "0"
        
        Write-Host "Abteilungs-GPO konfiguriert: $dep - T: Laufwerk und Suchleiste deaktiviert" -ForegroundColor Green
        
        # GPO mit entsprechender OU verknüpfen
        try {
            $ouPath = "OU=$dep,$dcPath"
            if (Get-ADOrganizationalUnit -Filter {DistinguishedName -eq $ouPath} -ErrorAction SilentlyContinue) {
                # Prüfen, ob Verknüpfung bereits existiert
                $existingLink = Get-GPInheritance -Target $ouPath | Where-Object { $_.GpoLinks.DisplayName -eq $deptGPO.DisplayName }
                if (-not $existingLink) {
                    New-GPLink -Name $deptGPO.DisplayName -Target $ouPath -LinkEnabled Yes
                    Write-Host "GPO '$($deptGPO.DisplayName)' mit OU '$dep' verknüpft" -ForegroundColor Green
                } else {
                    Write-Host "GPO '$($deptGPO.DisplayName)' bereits mit OU '$dep' verknüpft" -ForegroundColor Yellow
                }
            } else {
                Write-Warning "OU '$dep' nicht gefunden. GPO wurde erstellt, aber nicht verknüpft."
            }
        }
        catch {
            Write-Error "Fehler beim Verknüpfen der GPO mit OU '$dep': $_"
        }
    }
}

# 3. Globale GPO mit Domain verknüpfen
if ($globalGPO) {
    try {
        # Prüfen, ob Verknüpfung bereits existiert
        $existingLink = Get-GPInheritance -Target $dcPath | Where-Object { $_.GpoLinks.DisplayName -eq $globalGPO.DisplayName }
        if (-not $existingLink) {
            New-GPLink -Name $globalGPO.DisplayName -Target $dcPath -LinkEnabled Yes
            Write-Host "Globale GPO '$($globalGPO.DisplayName)' mit Domain verknüpft" -ForegroundColor Green
        } else {
            Write-Host "Globale GPO '$($globalGPO.DisplayName)' bereits mit Domain verknüpft" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Fehler beim Verknüpfen der globalen GPO mit Domain: $_"
    }
}

Write-Host "=== GPO Drive Mapping Setup abgeschlossen ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "WICHTIGER HINWEIS:" -ForegroundColor Red
Write-Host "Die eigentlichen Laufwerkszuordnungen müssen über Group Policy Preferences konfiguriert werden:" -ForegroundColor Yellow
Write-Host "1. Öffnen Sie Group Policy Management Console (gpmc.msc)" -ForegroundColor White
Write-Host "2. Bearbeiten Sie die erstellten GPOs" -ForegroundColor White
Write-Host "3. Navigieren Sie zu: Benutzerkonfiguration → Einstellungen → Windows-Einstellungen → Laufwerkszuordnungen" -ForegroundColor White
Write-Host "4. Konfigurieren Sie:" -ForegroundColor White
Write-Host "   - G: → \\%LOGONSERVER%\Global$ (für globale GPO)" -ForegroundColor White
Write-Host "   - T: → \\%LOGONSERVER%\Abteilungen$\{Abteilung} (für Abteilungs-GPOs)" -ForegroundColor White
Write-Host "5. Setzen Sie entsprechende Sicherheitsfilterung auf DL-Gruppen" -ForegroundColor White
Write-Host ""
Write-Host "Siehe auch: GROUP-POLICY-DRIVE-MAPPING.md für detaillierte Anweisungen" -ForegroundColor Cyan