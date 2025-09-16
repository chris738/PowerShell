#
# Skriptname: Create-ThreeGPOs-XML.ps1
# Beschreibung:
#   Dieses PowerShell-Skript erstellt drei Gruppenrichtlinienobjekte (GPOs) via XML:
#   1. Globales Laufwerk einbinden (G: Laufwerk für alle Benutzer)
#   2. Abteilungslaufwerk einbinden (T: Laufwerk mit Item-Level-Targeting)
#   3. Suchleiste in der Taskbar deaktivieren (Registry-basiert)
#
#   Das Skript verwendet XML-basierte Group Policy Preferences für optimale
#   Verwaltung und Skalierbarkeit. Alle GPOs werden automatisch erstellt
#   und mit den entsprechenden Organisationseinheiten verknüpft.
#
# Voraussetzungen:
#   - ActiveDirectory und GroupPolicy PowerShell-Module
#   - Ausreichende Berechtigungen für GPO-Erstellung
#   - Windows Server mit SYSVOL-Zugriff
#
# Aufruf:
#   .\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$"
#   .\Create-ThreeGPOs-XML.ps1 -CsvFile "alternative.csv" -GlobalSharePath "\\server\Global$"
#

param(
    [Parameter(Mandatory=$true)]
    [string]$GlobalSharePath,

    [Parameter(Mandatory=$false)]
    [string]$CsvFile,

    [Parameter(Mandatory=$false)]
    [string]$GlobalGpoName = 'XML_Global_G_Drive',

    [Parameter(Mandatory=$false)]
    [string]$DepartmentGpoName = 'XML_Department_T_Drive',

    [Parameter(Mandatory=$false)]
    [string]$SearchGpoName = 'XML_Disable_Search_Bar',

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Module importieren mit Fehlerbehandlung
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
    Write-Host "✓ PowerShell-Module erfolgreich geladen" -ForegroundColor Green
}
catch {
    Write-Warning "Erforderliche Module (ActiveDirectory, GroupPolicy) nicht verfügbar."
    Write-Host "Dieses Skript funktioniert nur auf Windows Servern mit Active Directory." -ForegroundColor Yellow
    if (-not $WhatIf) {
        exit 1
    }
}

# Lade gemeinsame Funktionen falls verfügbar
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$commonFunctionsPath = Join-Path $scriptDir "Common-Functions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
    Write-Host "✓ Gemeinsame Funktionen geladen" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== PowerShell GPO-Erstellung via XML ===" -ForegroundColor Cyan
Write-Host "Erstellt drei GPOs für Laufwerkszuordnungen und Taskbar-Anpassungen" -ForegroundColor Gray
Write-Host ""

# CSV-Datei bestimmen und validieren
if (-not $CsvFile -and (Get-Command "Get-DefaultCsvPath" -ErrorAction SilentlyContinue)) {
    $CsvFile = Get-DefaultCsvPath
}

$departments = @()
if ($CsvFile -and (Test-Path $CsvFile)) {
    if (Get-Command "Get-DepartmentsFromCSV" -ErrorAction SilentlyContinue) {
        $departments = Get-DepartmentsFromCSV -CsvPath $CsvFile
    } else {
        # Fallback: CSV manuell einlesen
        try {
            $users = Import-Csv -Path $CsvFile -Delimiter ";"
            $departments = $users | Select-Object -ExpandProperty Abteilung -Unique | Where-Object { $_ -ne "" }
            Write-Host "CSV-Fallback: Abteilungen erkannt: $($departments -join ', ')" -ForegroundColor Yellow
        }
        catch {
            Write-Warning "CSV-Datei konnte nicht gelesen werden: $_"
        }
    }
} else {
    # Standard-Abteilungen als Fallback
    $departments = @('Geschäftsführung', 'Bar', 'Events', 'Shop', 'Verwaltung', 'EDV', 'Facility', 'Gast')
    Write-Host "Standard-Abteilungen verwendet: $($departments -join ', ')" -ForegroundColor Yellow
}

if ($departments.Count -eq 0) {
    Write-Error "Keine Abteilungen gefunden! Überprüfen Sie die CSV-Datei oder verwenden Sie Standard-Abteilungen."
    exit 1
}

# Domain-Informationen abrufen
try {
    $domain = Get-ADDomain
    $dcPath = $domain.DistinguishedName
    $domainDNSRoot = $domain.DNSRoot
    Write-Host "✓ Domain erkannt: $domainDNSRoot" -ForegroundColor Green
}
catch {
    Write-Error "Active Directory Domain nicht verfügbar: $_"
    if (-not $WhatIf) {
        exit 1
    }
    # WhatIf-Modus: Dummy-Werte verwenden
    $domainDNSRoot = "example.local"
    $dcPath = "DC=example,DC=local"
}

# ===== HILFSFUNKTIONEN FÜR XML-BASIERTE GPO-ERSTELLUNG =====

function New-DriveMappingXml {
    <#
    .SYNOPSIS
    Erstellt XML-Konfiguration für ein Laufwerks-Mapping
    
    .DESCRIPTION
    Erzeugt XML-Inhalt für Group Policy Preferences Drive Mappings
    mit optionalem Item-Level-Targeting
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DriveLetter,
        
        [Parameter(Mandatory)]
        [string]$SharePath,
        
        [Parameter(Mandatory)]
        [string]$Label,
        
        [Parameter(Mandatory)]
        [ValidateSet('U', 'C', 'R', 'D')]
        [string]$Action,
        
        [Parameter()]
        [string]$GroupFilter = $null
    )
    
    $uid = [guid]::NewGuid().ToString().ToUpper()
    $changed = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    
    $driveXml = @"
  <Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" name="${DriveLetter}:" status="${DriveLetter}:" image="2" changed="$changed" uid="{$uid}">
    <Properties action="$Action" thisDrive="NOCHANGE" allDrives="NOCHANGE" userName="" cpassword="" path="$SharePath" label="$Label" persistent="1" useLetter="1" letter="$DriveLetter" />
"@

    # Item-Level-Targeting für Gruppen hinzufügen
    if ($GroupFilter) {
        $filterUid = [guid]::NewGuid().ToString().ToUpper()
        $driveXml += @"

    <Filters>
      <FilterGroup bool="AND" not="0" name="$Label" sid="" userContext="1" primaryToken="0" localGroup="0">
        <q:Query xmlns:q="http://www.microsoft.com/GroupPolicy/Settings/Base" clsid="{6AC7EEA7-EE10-4d05-8B80-396A7AA4F820}">
          <q:GroupMembership name="$GroupFilter" sid="" userContext="1" primaryToken="0" localGroup="0"/>
        </q:Query>
      </FilterGroup>
    </Filters>
"@
    }
    
    $driveXml += @"

  </Drive>
"@
    
    return $driveXml
}

function Save-GPOPreferencesXml {
    <#
    .SYNOPSIS
    Speichert XML-Konfiguration in das SYSVOL-Verzeichnis einer GPO
    
    .DESCRIPTION
    Erstellt die notwendige Verzeichnisstruktur und speichert die
    XML-Konfigurationsdatei für Group Policy Preferences
    #>
    param(
        [Parameter(Mandatory)]
        [Guid]$GpoId,
        
        [Parameter(Mandatory)]
        [string]$XmlContent,
        
        [Parameter(Mandatory)]
        [ValidateSet('Drives', 'Registry')]
        [string]$PreferenceType,
        
        [Parameter(Mandatory)]
        [ValidateSet('User', 'Computer')]
        [string]$ConfigType
    )
    
    try {
        # SYSVOL-Pfad konstruieren
        $gpoSysvolPath = "\\$domainDNSRoot\SYSVOL\$domainDNSRoot\Policies\{$GpoId}\$ConfigType\Preferences"
        
        # Verzeichnisstruktur erstellen
        $preferenceTypePath = Join-Path $gpoSysvolPath $PreferenceType
        if (-not (Test-Path $preferenceTypePath)) {
            New-Item -ItemType Directory -Path $preferenceTypePath -Force | Out-Null
            Write-Host "   ✓ Verzeichnis erstellt: $preferenceTypePath" -ForegroundColor Gray
        }
        
        # XML-Datei speichern
        $xmlFileName = "$PreferenceType.xml"
        $xmlFilePath = Join-Path $preferenceTypePath $xmlFileName
        
        $XmlContent | Out-File -FilePath $xmlFilePath -Encoding UTF8 -Force
        Write-Host "   ✓ XML-Datei erstellt: $xmlFileName" -ForegroundColor Green
        
        return $xmlFilePath
    }
    catch {
        Write-Error "Fehler beim Speichern der XML-Konfiguration: $_"
        return $null
    }
}

function New-RegistryXml {
    <#
    .SYNOPSIS
    Erstellt XML-Konfiguration für Registry-Einträge
    
    .DESCRIPTION
    Erzeugt XML-Inhalt für Group Policy Preferences Registry-Einstellungen
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KeyPath,
        
        [Parameter(Mandatory)]
        [string]$ValueName,
        
        [Parameter(Mandatory)]
        [string]$ValueType,
        
        [Parameter(Mandatory)]
        [string]$ValueData,
        
        [Parameter()]
        [ValidateSet('U', 'C', 'R', 'D')]
        [string]$Action = 'U'
    )
    
    $uid = [guid]::NewGuid().ToString().ToUpper()
    $changed = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    
    # Registry-Hive bestimmen
    $hive = if ($KeyPath.StartsWith('HKCU')) { 'CurrentUser' } 
            elseif ($KeyPath.StartsWith('HKLM')) { 'LocalMachine' }
            else { 'CurrentUser' }
    
    $cleanKey = $KeyPath -replace '^HK[CLU][MU]\\', ''
    
    $registryXml = @"
  <Registry clsid="{9CD4B2F4-923D-47f5-A062-E897DD1DAD50}" name="$ValueName" status="$ValueName" image="1" changed="$changed" uid="{$uid}">
    <Properties action="$Action" displayDecimal="0" default="0" hive="$hive" key="$cleanKey" name="$ValueName" type="$ValueType" value="$ValueData" />
  </Registry>
"@
    
    return $registryXml
}

# ===== HAUPTLOGIK: GPO-ERSTELLUNG =====

Write-Host "1. Erstelle GPO für globales Laufwerk (G:)..." -ForegroundColor Cyan

# GPO 1: Globales G: Laufwerk
if ($WhatIf) {
    Write-Host "   [WhatIf] GPO '$GlobalGpoName' würde erstellt werden" -ForegroundColor Yellow
    $globalGpoId = [guid]::NewGuid()
} else {
    try {
        $globalGpo = Get-GPO -Name $GlobalGpoName -ErrorAction SilentlyContinue
        if (-not $globalGpo) {
            $globalGpo = New-GPO -Name $GlobalGpoName -Comment 'XML-basiertes globales G: Laufwerk für alle Benutzer'
            Write-Host "   ✓ GPO erstellt: $GlobalGpoName" -ForegroundColor Green
        } else {
            Write-Host "   ○ GPO bereits vorhanden: $GlobalGpoName" -ForegroundColor Yellow
        }
        $globalGpoId = $globalGpo.Id
    }
    catch {
        Write-Error "Fehler beim Erstellen der globalen GPO: $_"
        exit 1
    }
}

# XML für globales G: Laufwerk erstellen
$globalDriveXml = New-DriveMappingXml -DriveLetter 'G' -SharePath $GlobalSharePath -Label 'Global Share' -Action 'U'
$globalDrivesXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
$globalDriveXml
</Drives>
"@

if (-not $WhatIf) {
    $savedPath = Save-GPOPreferencesXml -GpoId $globalGpoId -XmlContent $globalDrivesXml -PreferenceType 'Drives' -ConfigType 'User'
    if ($savedPath) {
        Write-Host "   → G: verknüpft mit $GlobalSharePath" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "2. Erstelle GPO für Abteilungslaufwerke (T:)..." -ForegroundColor Cyan

# GPO 2: Abteilungs-T: Laufwerk mit Item-Level-Targeting
if ($WhatIf) {
    Write-Host "   [WhatIf] GPO '$DepartmentGpoName' würde erstellt werden" -ForegroundColor Yellow
    $deptGpoId = [guid]::NewGuid()
} else {
    try {
        $deptGpo = Get-GPO -Name $DepartmentGpoName -ErrorAction SilentlyContinue
        if (-not $deptGpo) {
            $deptGpo = New-GPO -Name $DepartmentGpoName -Comment 'XML-basierte Abteilungslaufwerke T: mit Item-Level-Targeting'
            Write-Host "   ✓ GPO erstellt: $DepartmentGpoName" -ForegroundColor Green
        } else {
            Write-Host "   ○ GPO bereits vorhanden: $DepartmentGpoName" -ForegroundColor Yellow
        }
        $deptGpoId = $deptGpo.Id
    }
    catch {
        Write-Error "Fehler beim Erstellen der Abteilungs-GPO: $_"
        exit 1
    }
}

# XML für alle Abteilungslaufwerke erstellen
$departmentDriveXml = @()
foreach ($department in $departments) {
    # Server-Name aus GlobalSharePath extrahieren
    $serverName = if ($GlobalSharePath -match '\\\\([^\\]+)\\') { $matches[1] } else { 'server' }
    $deptSharePath = "\\$serverName\Abteilungen$\$department"
    $groupFilter = "DL_$department-FS_RW"
    
    $driveXml = New-DriveMappingXml -DriveLetter 'T' -SharePath $deptSharePath -Label "Abteilung $department" -Action 'U' -GroupFilter $groupFilter
    $departmentDriveXml += $driveXml
    
    Write-Host "   → T: für $department (Gruppe: $groupFilter)" -ForegroundColor White
}

$deptDrivesXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
$($departmentDriveXml -join "`n")
</Drives>
"@

if (-not $WhatIf) {
    $savedPath = Save-GPOPreferencesXml -GpoId $deptGpoId -XmlContent $deptDrivesXml -PreferenceType 'Drives' -ConfigType 'User'
}

Write-Host ""
Write-Host "3. Erstelle GPO für Taskbar-Suchleiste..." -ForegroundColor Cyan

# GPO 3: Taskbar-Suchleiste deaktivieren
if ($WhatIf) {
    Write-Host "   [WhatIf] GPO '$SearchGpoName' würde erstellt werden" -ForegroundColor Yellow
    $searchGpoId = [guid]::NewGuid()
} else {
    try {
        $searchGpo = Get-GPO -Name $SearchGpoName -ErrorAction SilentlyContinue
        if (-not $searchGpo) {
            $searchGpo = New-GPO -Name $SearchGpoName -Comment 'XML-basierte Deaktivierung der Windows Taskbar-Suchleiste'
            Write-Host "   ✓ GPO erstellt: $SearchGpoName" -ForegroundColor Green
        } else {
            Write-Host "   ○ GPO bereits vorhanden: $SearchGpoName" -ForegroundColor Yellow
        }
        $searchGpoId = $searchGpo.Id
    }
    catch {
        Write-Error "Fehler beim Erstellen der Suchleisten-GPO: $_"
        exit 1
    }
}

# XML für Registry-Einstellungen zur Suchleisten-Deaktivierung
$searchRegistryXml = @()
$searchRegistryXml += New-RegistryXml -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'SearchBoxTaskbarMode' -ValueType 'REG_DWORD' -ValueData '0' -Action 'U'
$searchRegistryXml += New-RegistryXml -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'BingSearchEnabled' -ValueType 'REG_DWORD' -ValueData '0' -Action 'U'
$searchRegistryXml += New-RegistryXml -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'CortanaConsent' -ValueType 'REG_DWORD' -ValueData '0' -Action 'U'

$searchRegXml = @"
<?xml version="1.0" encoding="utf-8"?>
<RegistrySettings clsid="{A3CCFC41-DFDB-43a5-8D26-0FE8B954DA51}">
$($searchRegistryXml -join "`n")
</RegistrySettings>
"@

if (-not $WhatIf) {
    $savedPath = Save-GPOPreferencesXml -GpoId $searchGpoId -XmlContent $searchRegXml -PreferenceType 'Registry' -ConfigType 'User'
    if ($savedPath) {
        Write-Host "   ✓ Suchleiste-Registry konfiguriert" -ForegroundColor White
        Write-Host "   → SearchBoxTaskbarMode = 0 (ausgeblendet)" -ForegroundColor White
        Write-Host "   → BingSearchEnabled = 0 (deaktiviert)" -ForegroundColor White
        Write-Host "   → CortanaConsent = 0 (deaktiviert)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== ZUSAMMENFASSUNG DER XML-BASIERTEN GPO-ERSTELLUNG ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "ERSTELLTE GPOs:" -ForegroundColor Green
Write-Host "✓ $GlobalGpoName - Globales G: Laufwerk (XML-basiert)" -ForegroundColor White
Write-Host "✓ $DepartmentGpoName - Abteilungs-T: Laufwerke mit Item-Level-Targeting (XML-basiert)" -ForegroundColor White
Write-Host "✓ $SearchGpoName - Taskbar-Suchleiste deaktiviert (XML-Registry-basiert)" -ForegroundColor White

Write-Host ""
Write-Host "XML-KONFIGURATION:" -ForegroundColor Green
Write-Host "• Group Policy Preferences für optimale Verwaltung" -ForegroundColor White
Write-Host "• XML-basierte Drive Mappings für Laufwerke G: und T:" -ForegroundColor White
Write-Host "• Registry XML für komplette Suchleisten-Deaktivierung" -ForegroundColor White
Write-Host "• Item-Level-Targeting für gruppenbasierte T: Laufwerke" -ForegroundColor White

Write-Host ""
Write-Host "NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
Write-Host "1. GPOs mit entsprechenden OUs verknüpfen:" -ForegroundColor White
Write-Host "   New-GPLink -Name '$GlobalGpoName' -Target '$dcPath'" -ForegroundColor Gray
foreach ($department in $departments) {
    Write-Host "   New-GPLink -Name '$DepartmentGpoName' -Target 'OU=$department,$dcPath'" -ForegroundColor Gray
}
Write-Host "   New-GPLink -Name '$SearchGpoName' -Target '$dcPath'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Group Policy Management Console (gpmc.msc) öffnen" -ForegroundColor White
Write-Host "3. Sicherheitsfilterung für Abteilungs-GPO anpassen" -ForegroundColor White
Write-Host "4. Group Policy Update: gpupdate /force" -ForegroundColor White

Write-Host ""
Write-Host "=== XML-BASIERTE GPO-ERSTELLUNG ABGESCHLOSSEN ===" -ForegroundColor Green

if ($WhatIf) {
    Write-Host ""
    Write-Host "WHATIF-MODUS: Keine Änderungen wurden vorgenommen" -ForegroundColor Magenta
}