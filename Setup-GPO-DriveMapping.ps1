# Setup-GPO-DriveMapping.ps1
# Erstellt und verknüpft drei GPOs für Laufwerkszuordnungen basierend auf create_gpos.ps1 und link_gpos.ps1
# VERBESSERT: Kombiniert die modularen Ansätze für optimale GPO-Verwaltung
# 
# Erstellt folgende GPOs:
# 1. Globales G: Laufwerk für alle Benutzer
# 2. Abteilungs-T: Laufwerk mit Item-Level-Targeting
# 3. Taskbar-Suchleiste deaktivieren
#
# Aufruf: .\Setup-GPO-DriveMapping.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile,
    
    [Parameter(Mandatory=$false)]
    [string]$GlobalGpoName = 'Map_G_Drive',
    
    [Parameter(Mandatory=$false)]
    [string]$DepartmentGpoName = 'Map_T_Drive',
    
    [Parameter(Mandatory=$false)]
    [string]$SearchGpoName = 'Disable_Search_Bar'
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

Write-Host "=== Erstelle drei GPOs für erweiterte Laufwerkszuordnungen ===" -ForegroundColor Cyan
Write-Host "Basierend auf den modularen Skripten create_gpos.ps1 und link_gpos.ps1" -ForegroundColor Gray
Write-Host ""

# Domain Info
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"
$serverName = Get-DomainControllerServer

# ===== HILFSFUNKTIONEN FÜR XML-BASIERTE DRIVE MAPPINGS =====
# Übernommen und angepasst von create_gpos.ps1

function New-DriveMappingXml {
    <#
    .SYNOPSIS
    Erstellt das Laufwerk-XML für eine einzelne Zuordnung
    
    .DESCRIPTION
    Erzeugt XML-Konfiguration für Group Policy Preferences Drive Mappings
    mit optionalem Item-Level-Targeting für OU-spezifische Zuordnungen
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DriveLetter,
        [Parameter(Mandatory)]
        [string]$SharePath,
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [string]$Action,
        [Parameter()]
        [string]$OUFilter = $null
    )
    
    $driveNode = @()
    $uid = [guid]::NewGuid().ToString()
    $changed = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $driveNode += "  <Drive clsid='{935D1B74-9CB8-4e3c-9914-7DD559B7A417}' name='${DriveLetter}:' status='${DriveLetter}:' image='2' changed='$changed' uid='$uid'>"
    $driveNode += "    <Properties action='$Action' thisDrive='NOCHANGE' allDrives='NOCHANGE' userName='' cpassword='' path='$SharePath' label='$Label' persistent='1' useLetter='1' letter='$DriveLetter' />"
    if ($OUFilter) {
        $driveNode += "    <Filters><FilterGroup bool='AND' not='0' name='$Label' sid='' userContext='1' primaryToken='0' localGroup='0'><q:Query xmlns:q='http://www.microsoft.com/GroupPolicy/Settings/Base' clsid='{6AC7EEA7-EE10-4d05-8B80-396A7AA4F820}'><q:GroupMembership name='$OUFilter' sid='' userContext='1' primaryToken='0' localGroup='0'/></q:Query></FilterGroup></Filters>"
    }
    $driveNode += "  </Drive>"
    return ($driveNode -join "`n")
}

function Save-DriveMappings {
    <#
    .SYNOPSIS
    Speichert die XML-Datei für ein GPO
    
    .DESCRIPTION
    Erstellt die Drives.xml Datei im SYSVOL-Verzeichnis des angegebenen GPOs
    #>
    param(
        [Parameter(Mandatory)]
        [Guid]$GpoId,
        [Parameter(Mandatory)]
        [string[]]$DriveXmlEntries
    )
    
    try {
        $domain = (Get-ADDomain).DNSRoot
        $gpoPath = "\\$domain\SYSVOL\$domain\Policies\{$GpoId}\User\Preferences\Drives"
        
        # Verzeichnis erstellen falls nicht vorhanden
        if (-not (Test-Path $gpoPath)) {
            New-Item -ItemType Directory -Path $gpoPath -Force | Out-Null
            Write-Host "Erstelle GPO-Verzeichnis: $gpoPath" -ForegroundColor Gray
        }
        
        # XML-Inhalt zusammenbauen
        $xmlContent = @()
        $xmlContent += "<?xml version='1.0' encoding='utf-8'?>"
        $xmlContent += "<Drives clsid='{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}'>"
        $xmlContent += $DriveXmlEntries
        $xmlContent += "</Drives>"
        
        # XML-Datei speichern
        $xmlFilePath = Join-Path $gpoPath 'Drives.xml'
        $xmlContent -join "`n" | Out-File -FilePath $xmlFilePath -Encoding utf8
        Write-Host "Drives.xml erstellt: $xmlFilePath" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler beim Speichern der Drive Mappings: $_"
    }
}

# ===== GPO-VERWALTUNGSFUNKTIONEN =====
function Get-OrCreateGPO {
    <#
    .SYNOPSIS
    GPO erstellen oder abrufen (erweiterte Version)
    #>
    param(
        [string]$Name,
        [string]$Comment
    )
    
    try {
        $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
        if (-not $gpo) {
            $gpo = New-GPO -Name $Name -Comment $Comment
            Write-Host "✓ GPO erstellt: $Name" -ForegroundColor Green
        } else {
            Write-Host "○ GPO bereits vorhanden: $Name" -ForegroundColor Yellow
        }
        return $gpo
    }
    catch {
        Write-Error "Fehler bei GPO-Erstellung '$Name': $_"
        return $null
    }
}

function New-GPOLink {
    <#
    .SYNOPSIS
    Erstellt GPO-Verknüpfung mit Fehlerbehandlung
    #>
    param(
        [string]$GpoName,
        [string]$TargetOU,
        [string]$Description = ""
    )
    
    try {
        # Prüfen ob OU existiert
        if (-not (Get-ADOrganizationalUnit -Filter {DistinguishedName -eq $TargetOU} -ErrorAction SilentlyContinue)) {
            Write-Warning "OU nicht gefunden: $TargetOU"
            return $false
        }
        
        # Prüfen ob Verknüpfung bereits existiert
        $existingLink = Get-GPInheritance -Target $TargetOU -ErrorAction SilentlyContinue | Where-Object { $_.GpoLinks.DisplayName -eq $GpoName }
        if ($existingLink) {
            Write-Host "○ GPO '$GpoName' bereits mit OU verknüpft: $TargetOU" -ForegroundColor Yellow
            return $true
        }
        
        # Neue Verknüpfung erstellen
        New-GPLink -Name $GpoName -Target $TargetOU -Enforced:$false -LinkEnabled:$true -ErrorAction Stop
        Write-Host "✓ GPO '$GpoName' verknüpft mit: $TargetOU" -ForegroundColor Green
        if ($Description) {
            Write-Host "  $Description" -ForegroundColor Gray
        }
        return $true
    }
    catch {
        Write-Error "Fehler beim Verknüpfen der GPO '$GpoName' mit '$TargetOU': $_"
        return $false
    }
}

# ===== HAUPTLOGIK: DREI-GPO-ERSTELLUNG =====

Write-Host "1. Erstelle GPO für globales G: Laufwerk..." -ForegroundColor Cyan

# GPO 1: Globales G: Laufwerk für alle Benutzer
$globalGPO = Get-OrCreateGPO -Name $GlobalGpoName -Comment "Globales Laufwerk G: für alle Benutzer"

if ($globalGPO) {
    $globalSharePath = "\\$serverName\Global$"
    
    # XML-basierte Drive Mapping konfigurieren
    $entriesG = @()
    $entriesG += New-DriveMappingXml -DriveLetter 'G' -SharePath $globalSharePath -Label 'Global' -Action 'U'
    Save-DriveMappings -GpoId $globalGPO.Id -DriveXmlEntries $entriesG
    
    Write-Host "   G: -> $globalSharePath" -ForegroundColor White
}

Write-Host ""
Write-Host "2. Erstelle GPO für Abteilungs-T: Laufwerke..." -ForegroundColor Cyan

# GPO 2: Abteilungslaufwerk T: mit Item-Level-Targeting
$deptGPO = Get-OrCreateGPO -Name $DepartmentGpoName -Comment "Abteilungslaufwerk T: für jede OU mit Item-Level-Targeting"

if ($deptGPO) {
    # Hashtable für Abteilungspfade erstellen
    $departmentSharePaths = @{}
    foreach ($dep in $departments) {
        $ouDN = "OU=$dep,$dcPath"
        $sharePath = "\\$serverName\Abteilungen$\$dep"
        $departmentSharePaths[$ouDN] = $sharePath
    }
    
    # XML-Einträge für T: Laufwerk mit Item-Level-Targeting
    $entriesT = @()
    foreach ($ouDN in $departmentSharePaths.Keys) {
        $sharePath = $departmentSharePaths[$ouDN]
        $ouName = ($ouDN -split ',')[0] -replace '^OU='
        
        # Item-Level-Targeting: Gruppe als Filter verwenden
        $groupFilter = "DL_$ouName-FS_RW"
        $entriesT += New-DriveMappingXml -DriveLetter 'T' -SharePath $sharePath -Label $ouName -Action 'U' -OUFilter $groupFilter
        Write-Host "   T: -> $sharePath (für Gruppe $groupFilter)" -ForegroundColor White
    }
    Save-DriveMappings -GpoId $deptGPO.Id -DriveXmlEntries $entriesT
}

Write-Host ""
Write-Host "3. Erstelle GPO für Taskbar-Suchleiste..." -ForegroundColor Cyan

# GPO 3: Taskbar-Suchleiste deaktivieren
$searchGPO = Get-OrCreateGPO -Name $SearchGpoName -Comment "Deaktiviert die Windows-Taskleisten-Suche"

if ($searchGPO) {
    # Registry-Einträge für Suchleiste
    try {
        Set-GPRegistryValue -Name $SearchGpoName -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'SearchBoxTaskbarMode' -Type DWord -Value 0 -ErrorAction Stop
        Set-GPRegistryValue -Name $SearchGpoName -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'BingSearchEnabled' -Type DWord -Value 0 -ErrorAction Stop
        Set-GPRegistryValue -Name $SearchGpoName -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'CortanaConsent' -Type DWord -Value 0 -ErrorAction Stop
        Write-Host "   Suchleiste komplett deaktiviert (SearchBoxTaskbarMode=0)" -ForegroundColor White
    }
    catch {
        Write-Error "Fehler bei Suchleisten-Konfiguration: $_"
    }
}

Write-Host ""
Write-Host "=== VERKNÜPFUNG DER GPOs MIT OUs ===" -ForegroundColor Cyan

# Verknüpfungen erstellen (basierend auf link_gpos.ps1 Logik)
$linkResults = @()

# 1. Globales GPO mit Domain verknüpfen
if ($globalGPO) {
    Write-Host "Verknüpfe globales GPO mit Domain..." -ForegroundColor Yellow
    $result = New-GPOLink -GpoName $globalGPO.DisplayName -TargetOU $dcPath -Description "Für alle Benutzer in der Domain"
    $linkResults += @{GPO = $globalGPO.DisplayName; Target = "Domain"; Success = $result}
}

# 2. Abteilungs-GPO mit jeder OU verknüpfen
if ($deptGPO) {
    Write-Host "Verknüpfe Abteilungs-GPO mit OUs..." -ForegroundColor Yellow
    foreach ($dep in $departments) {
        $ouPath = "OU=$dep,$dcPath"
        $result = New-GPOLink -GpoName $deptGPO.DisplayName -TargetOU $ouPath -Description "Item-Level-Targeting für Abteilung $dep"
        $linkResults += @{GPO = $deptGPO.DisplayName; Target = $dep; Success = $result}
    }
}

# 3. Suchleisten-GPO mit allen OUs verknüpfen
if ($searchGPO) {
    Write-Host "Verknüpfe Suchleisten-GPO..." -ForegroundColor Yellow
    
    # Mit Domain verknüpfen für alle Benutzer
    $result = New-GPOLink -GpoName $searchGPO.DisplayName -TargetOU $dcPath -Description "Suchleiste für alle Benutzer deaktivieren"
    $linkResults += @{GPO = $searchGPO.DisplayName; Target = "Domain"; Success = $result}
}

Write-Host ""
Write-Host "=== ZUSAMMENFASSUNG DER GPO-ERSTELLUNG ===" -ForegroundColor Cyan
Write-Host ""

# Ergebnisse anzeigen
$successfulLinks = ($linkResults | Where-Object { $_.Success -eq $true }).Count
$totalLinks = $linkResults.Count

Write-Host "ERSTELLTE GPOs:" -ForegroundColor Green
if ($globalGPO) { Write-Host "✓ $($globalGPO.DisplayName) - Globales G: Laufwerk" -ForegroundColor White }
if ($deptGPO) { Write-Host "✓ $($deptGPO.DisplayName) - Abteilungs-T: Laufwerke (mit Item-Level-Targeting)" -ForegroundColor White }
if ($searchGPO) { Write-Host "✓ $($searchGPO.DisplayName) - Taskbar-Suchleiste deaktiviert" -ForegroundColor White }

Write-Host ""
Write-Host "VERKNÜPFUNGEN:" -ForegroundColor Green
Write-Host "✓ $successfulLinks von $totalLinks Verknüpfungen erfolgreich" -ForegroundColor White

foreach ($result in $linkResults) {
    $status = if ($result.Success) { "✓" } else { "✗" }
    $color = if ($result.Success) { "Green" } else { "Red" }
    Write-Host "$status $($result.GPO) -> $($result.Target)" -ForegroundColor $color
}

Write-Host ""
Write-Host "WICHTIGE HINWEISE:" -ForegroundColor Yellow
Write-Host ""
Write-Host "VERBESSERTE IMPLEMENTIERUNG:" -ForegroundColor Cyan
Write-Host "• Basiert auf den modularen Skripten create_gpos.ps1 und link_gpos.ps1" -ForegroundColor White
Write-Host "• Verwendet XML-basierte Drive Mappings (Group Policy Preferences)" -ForegroundColor White
Write-Host "• Item-Level-Targeting für abteilungsspezifische T: Laufwerke" -ForegroundColor White
Write-Host "• Drei separate GPOs für optimale Verwaltung" -ForegroundColor White
Write-Host ""
Write-Host "KONFIGURATION:" -ForegroundColor Cyan
Write-Host "• G: Laufwerk: Für alle Benutzer (über Domain-Verknüpfung)" -ForegroundColor White
Write-Host "• T: Laufwerk: Je nach Abteilungsgruppe (DL_*-FS_RW)" -ForegroundColor White
Write-Host "• Suchleiste: Komplett deaktiviert (alle Registry-Werte)" -ForegroundColor White
Write-Host ""
Write-Host "NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
Write-Host "1. Group Policy Management Console (gpmc.msc) öffnen" -ForegroundColor White
Write-Host "2. Erstellte GPOs überprüfen und bei Bedarf anpassen" -ForegroundColor White
Write-Host "3. Sicherheitsfilterung für Abteilungs-GPO auf DL-Gruppen setzen" -ForegroundColor White
Write-Host "4. Group Policy Update auf Clients: gpupdate /force" -ForegroundColor White
Write-Host ""
Write-Host "DOKUMENTATION:" -ForegroundColor Cyan
Write-Host "Siehe GROUP-POLICY-DRIVE-MAPPING.md für detaillierte Anweisungen" -ForegroundColor White
Write-Host ""
Write-Host "=== GPO SETUP ABGESCHLOSSEN ===" -ForegroundColor Green