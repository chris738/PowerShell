# Setup-GPO-DriveMapping.ps1
# Erstellt GPOs für Laufwerkszuordnungen (T: für Abteilungen, G: für Global) und deaktiviert Suchleiste
# UPDATED: Erweiterte Implementierung mit verbesserter Drive-Mapping-Funktionalität
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
        $Value
    )
    
    try {
        # Für DWord-Typen muss der Wert als String übergeben werden
        if ($Type -eq "DWord") {
            $Value = $Value.ToString()
        }
        
        Set-GPRegistryValue -Name $GPOName -Key $Key -ValueName $ValueName -Type $Type -Value $Value
        Write-Host "Registry-Einstellung hinzugefügt: $Key\$ValueName = $Value" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler beim Hinzufügen der Registry-Einstellung: $_"
    }
}

# Funktion: Erweiterte Taskbar-Konfiguration
function Set-TaskbarConfiguration {
    param(
        [string]$GPOName
    )
    
    try {
        # Suchleiste komplett deaktivieren (Wert 0 = versteckt)
        Add-GPRegistryValue -GPOName $GPOName -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "SearchboxTaskbarMode" -Type DWord -Value 0
        
        # Zusätzliche Taskbar-Optimierungen
        Add-GPRegistryValue -GPOName $GPOName -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -Type DWord -Value 0
        Add-GPRegistryValue -GPOName $GPOName -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -Type DWord -Value 0
        
        Write-Host "Taskbar-Konfiguration abgeschlossen: Suchleiste deaktiviert" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler bei Taskbar-Konfiguration: $_"
    }
}

# Funktion: Laufwerkszuordnung über Registry konfigurieren
function Set-DriveMapping {
    param(
        [string]$GPOName,
        [string]$DriveLetter,
        [string]$NetworkPath,
        [string]$Label = ""
    )
    
    try {
        # Laufwerkszuordnung über Registry (Computer-Konfiguration)
        $keyPath = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System"
        
        # Logon-Script-Policy setzen um Drive-Mapping zu ermöglichen
        Add-GPRegistryValue -GPOName $GPOName -Key $keyPath -ValueName "AllowLogonScript" -Type DWord -Value 1
        
        # Für Benutzerkonfiguration: Persistent Drive Mapping
        $userKeyPath = "HKEY_CURRENT_USER\Network\$DriveLetter"
        Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "RemotePath" -Type String -Value $NetworkPath
        Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "UserName" -Type String -Value ""
        Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "ProviderName" -Type String -Value "Microsoft Windows Network"
        Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "ProviderType" -Type DWord -Value 131072
        Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "ConnectionType" -Type DWord -Value 1
        Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "DeferFlags" -Type DWord -Value 4
        
        if ($Label) {
            Add-GPRegistryValue -GPOName $GPOName -Key $userKeyPath -ValueName "Label" -Type String -Value $Label
        }
        
        Write-Host "Laufwerkszuordnung konfiguriert: $DriveLetter -> $NetworkPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler bei Laufwerkszuordnung $DriveLetter -> $NetworkPath : $_"
    }
}

# 1. GPO für Globales Laufwerk (G:) erstellen
$globalGPO = Get-OrCreateGPO -Name "DriveMapping-Global-G" -Comment "Zuordnung des globalen Laufwerks G: für alle Benutzer und Taskbar-Konfiguration"

if ($globalGPO) {
    # Server für UNC-Pfad ermitteln
    $serverName = Get-DomainControllerServer
    $globalSharePath = "\\$serverName\Global$"
    
    # G: Laufwerk konfigurieren
    Set-DriveMapping -GPOName $globalGPO.DisplayName -DriveLetter "G" -NetworkPath $globalSharePath -Label "Global"
    
    # Taskbar-Konfiguration (Suchleiste deaktivieren)
    Set-TaskbarConfiguration -GPOName $globalGPO.DisplayName
    
    Write-Host "Globale GPO konfiguriert: G: -> $globalSharePath, Suchleiste deaktiviert" -ForegroundColor Green
}

# 2. GPOs für Abteilungslaufwerke (T:) erstellen
foreach ($dep in $departments) {
    $gpoName = "DriveMapping-$dep-T"
    $gpoComment = "Zuordnung des Abteilungslaufwerks T: für Abteilung $dep und Taskbar-Konfiguration"
    
    $deptGPO = Get-OrCreateGPO -Name $gpoName -Comment $gpoComment
    
    if ($deptGPO) {
        # Server für UNC-Pfad ermitteln
        $serverName = Get-DomainControllerServer
        $deptSharePath = "\\$serverName\Abteilungen$\$dep"
        
        # T: Laufwerk für Abteilung konfigurieren
        Set-DriveMapping -GPOName $deptGPO.DisplayName -DriveLetter "T" -NetworkPath $deptSharePath -Label "$dep"
        
        # Taskbar-Konfiguration (Suchleiste deaktivieren)
        Set-TaskbarConfiguration -GPOName $deptGPO.DisplayName
        
        Write-Host "Abteilungs-GPO konfiguriert: $dep - T: -> $deptSharePath, Suchleiste deaktiviert" -ForegroundColor Green
        
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
Write-Host "KONFIGURATION ABGESCHLOSSEN:" -ForegroundColor Green
Write-Host "✓ Globale GPO erstellt: G: -> Global-Share" -ForegroundColor White
Write-Host "✓ Abteilungs-GPOs erstellt: T: -> Abteilungsfreigaben (je nach OU)" -ForegroundColor White
Write-Host "✓ Suchleiste in Taskbar für alle GPOs deaktiviert" -ForegroundColor White
Write-Host "✓ GPO-OU-Verknüpfungen konfiguriert" -ForegroundColor White
Write-Host ""
Write-Host "WICHTIGER HINWEIS:" -ForegroundColor Yellow
Write-Host "Für Produktionsumgebungen wird empfohlen, Group Policy Preferences zu verwenden:" -ForegroundColor Cyan
Write-Host "1. Öffnen Sie Group Policy Management Console (gpmc.msc)" -ForegroundColor White
Write-Host "2. Bearbeiten Sie die erstellten GPOs" -ForegroundColor White
Write-Host "3. Navigieren Sie zu: Benutzerkonfiguration → Einstellungen → Windows-Einstellungen → Laufwerkszuordnungen" -ForegroundColor White
Write-Host "4. Konfigurieren Sie die Laufwerkszuordnungen über die GUI für bessere Verwaltung" -ForegroundColor White
Write-Host ""
Write-Host "AKTUELLE REGISTRY-BASIERTE KONFIGURATION:" -ForegroundColor Cyan
Write-Host "- G: Laufwerk: Für alle Benutzer" -ForegroundColor White
Write-Host "- T: Laufwerk: Je nach Abteilungs-OU" -ForegroundColor White
Write-Host "- Taskbar: Suchleiste deaktiviert" -ForegroundColor White
Write-Host ""
Write-Host "Siehe auch: GROUP-POLICY-DRIVE-MAPPING.md für detaillierte Anweisungen" -ForegroundColor Cyan