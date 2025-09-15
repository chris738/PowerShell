# Setup-SharePermissions.ps1
# Fügt Freigaben zu den richtigen Gruppen hinzu
# Aufruf: .\Setup-SharePermissions.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

# Module importieren
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module SmbShare -ErrorAction Stop
}
catch {
    Write-Warning "Erforderliche Module (ActiveDirectory, SmbShare) nicht verfügbar."
    Write-Host "Dieses Skript funktioniert nur auf Windows Servern mit Active Directory und SMB-Features." -ForegroundColor Yellow
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

Write-Host "Konfiguriere Freigabe-Berechtigungen für Gruppen..." -ForegroundColor Cyan

# Basis-Pfad für Shares
$basePath = "F:\Shares"

# Funktion: Share-Berechtigungen setzen
function Set-SharePermission {
    param(
        [string]$ShareName,
        [string]$GroupName,
        [string]$AccessRight = "Full"
    )
    
    try {
        # Prüfen ob Share existiert
        $share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
        if (-not $share) {
            Write-Warning "Share '$ShareName' nicht gefunden. Überspringe Berechtigung für $GroupName."
            return
        }
        
        # Prüfen ob Gruppe existiert
        $group = Get-ADGroup -Filter {Name -eq $GroupName} -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Warning "Gruppe '$GroupName' nicht gefunden. Überspringe Share-Berechtigung."
            return
        }
        
        # Existierende Berechtigung prüfen
        $existingAccess = Get-SmbShareAccess -Name $ShareName | Where-Object { $_.AccountName -eq $GroupName }
        if ($existingAccess) {
            Write-Host "Share-Berechtigung bereits vorhanden: $ShareName -> $GroupName ($($existingAccess.AccessRight))" -ForegroundColor Yellow
            return
        }
        
        # Share-Berechtigung hinzufügen
        Grant-SmbShareAccess -Name $ShareName -AccountName $GroupName -AccessRight $AccessRight -Force
        Write-Host "Share-Berechtigung hinzugefügt: $ShareName -> $GroupName ($AccessRight)" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler beim Setzen der Share-Berechtigung für $ShareName -> $GroupName - $_"
    }
}

# 1. Globale Share-Berechtigungen konfigurieren
Write-Host "Konfiguriere globale Share-Berechtigungen..." -ForegroundColor Yellow

# Global$ Share für alle Benutzer
$globalGroupRW = "DL_Global-FS_RW"
$globalGroupR = "DL_Global-FS_R"

Set-SharePermission -ShareName "Global$" -GroupName $globalGroupRW -AccessRight "Full"
Set-SharePermission -ShareName "Global$" -GroupName $globalGroupR -AccessRight "Read"

# 2. Abteilungs-Share-Berechtigungen konfigurieren
Write-Host "Konfiguriere Abteilungs-Share-Berechtigungen..." -ForegroundColor Yellow

foreach ($dep in $departments) {
    $shareName = "Abteilungen$"  # Alle Abteilungen unter einem Share
    $groupRW = "DL_${dep}-FS_RW"
    $groupR = "DL_${dep}-FS_R"
    
    # Abteilungsgruppen zur Abteilungen$-Freigabe hinzufügen
    Set-SharePermission -ShareName $shareName -GroupName $groupRW -AccessRight "Full"
    Set-SharePermission -ShareName $shareName -GroupName $groupR -AccessRight "Read"
    
    Write-Host "Abteilungs-Share konfiguriert für: $dep" -ForegroundColor Green
}

# 3. Home-Share-Berechtigungen prüfen
Write-Host "Prüfe Home-Share-Berechtigungen..." -ForegroundColor Yellow

try {
    $homeShare = Get-SmbShare -Name "Home$" -ErrorAction SilentlyContinue
    if ($homeShare) {
        # Admin-Gruppe für Home-Share
        $adminIdentity = Get-SafeDomainAdminsIdentity
        $adminName = $adminIdentity.Translate([System.Security.Principal.NTAccount]).Value
        
        $existingAdminAccess = Get-SmbShareAccess -Name "Home$" | Where-Object { $_.AccountName -eq $adminName }
        if (-not $existingAdminAccess) {
            Grant-SmbShareAccess -Name "Home$" -AccountName $adminName -AccessRight "Full" -Force
            Write-Host "Admin-Berechtigung für Home$ hinzugefügt: $adminName" -ForegroundColor Green
        } else {
            Write-Host "Admin-Berechtigung für Home$ bereits vorhanden: $adminName" -ForegroundColor Yellow
        }
        
        # Authentifizierte Benutzer für Home$ (damit jeder auf sein eigenes Home zugreifen kann)
        $authUsersName = Get-LocalizedAccountName -WellKnownAccount "Authenticated Users"
        $existingAuthAccess = Get-SmbShareAccess -Name "Home$" | Where-Object { $_.AccountName -eq $authUsersName }
        if (-not $existingAuthAccess) {
            Grant-SmbShareAccess -Name "Home$" -AccountName $authUsersName -AccessRight "Change" -Force
            Write-Host "Authentifizierte Benutzer-Berechtigung für Home$ hinzugefügt: $authUsersName" -ForegroundColor Green
        } else {
            Write-Host "Authentifizierte Benutzer-Berechtigung für Home$ bereits vorhanden: $authUsersName" -ForegroundColor Yellow
        }
    } else {
        Write-Warning "Home$ Share nicht gefunden."
    }
}
catch {
    Write-Error "Fehler bei Home-Share-Konfiguration - $_"
}

# 4. Übersicht der konfigurierten Share-Berechtigungen anzeigen
Write-Host "=== Übersicht der Share-Berechtigungen ===" -ForegroundColor Cyan

$shareNames = @("Global$", "Abteilungen$", "Home$")
foreach ($shareName in $shareNames) {
    $share = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
    if ($share) {
        Write-Host "Share: $shareName" -ForegroundColor White
        $permissions = Get-SmbShareAccess -Name $shareName
        foreach ($perm in $permissions) {
            Write-Host "  -> $($perm.AccountName): $($perm.AccessRight)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

Write-Host "=== Share-Berechtigungen Setup abgeschlossen ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "HINWEISE:" -ForegroundColor Yellow
Write-Host "1. Share-Berechtigungen sind auf SMB-Ebene konfiguriert" -ForegroundColor White
Write-Host "2. NTFS-Berechtigungen werden separat über Setup-Fileserver-Rights.ps1 verwaltet" -ForegroundColor White
Write-Host "3. Benutzer benötigen beide Berechtigungsebenen für Vollzugriff" -ForegroundColor White
Write-Host "4. Laufwerkszuordnungen erfolgen über Group Policy (siehe Setup-GPO-DriveMapping.ps1)" -ForegroundColor White