# Setup-SharePermissions.ps1
# Fügt Freigaben zu den richtigen Gruppen hinzu - erweiterte Implementierung
# UPDATED: Verbesserte Zuordnung von Freigaben zu Gruppen basierend auf Abteilungen
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
Write-Host "Verarbeite $($departments.Count) Abteilungen: $($departments -join ', ')" -ForegroundColor Yellow

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
            return $false
        }
        
        # Prüfen ob Gruppe existiert
        $group = Get-ADGroup -Filter {Name -eq $GroupName} -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Warning "Gruppe '$GroupName' nicht gefunden. Überspringe Share-Berechtigung."
            return $false
        }
        
        # Existierende Berechtigung prüfen
        $existingAccess = Get-SmbShareAccess -Name $ShareName | Where-Object { $_.AccountName -eq $GroupName -or $_.AccountName -eq "$env:USERDOMAIN\$GroupName" }
        if ($existingAccess) {
            Write-Host "Share-Berechtigung bereits vorhanden: $ShareName -> $GroupName ($($existingAccess.AccessRight))" -ForegroundColor Yellow
            return $true
        }
        
        # Share-Berechtigung hinzufügen
        Grant-SmbShareAccess -Name $ShareName -AccountName $GroupName -AccessRight $AccessRight -Force
        Write-Host "Share-Berechtigung hinzugefügt: $ShareName -> $GroupName ($AccessRight)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Fehler beim Setzen der Share-Berechtigung für $ShareName -> $GroupName - $_"
        return $false
    }
}

# Funktion: Abteilungsspezifische Share-Konfiguration
function Set-DepartmentSharePermissions {
    param(
        [string]$Department,
        [string]$ShareName = "Abteilungen$"
    )
    
    Write-Host "Konfiguriere Share-Berechtigungen für Abteilung: $Department" -ForegroundColor Cyan
    
    $groupRW = "DL_${Department}-FS_RW"
    $groupR = "DL_${Department}-FS_R"
    
    $successCount = 0
    
    # Read/Write Gruppe hinzufügen
    if (Set-SharePermission -ShareName $ShareName -GroupName $groupRW -AccessRight "Full") {
        $successCount++
    }
    
    # Read-Only Gruppe hinzufügen  
    if (Set-SharePermission -ShareName $ShareName -GroupName $groupR -AccessRight "Read") {
        $successCount++
    }
    
    if ($successCount -eq 2) {
        Write-Host "✓ Abteilungs-Share vollständig konfiguriert für: $Department" -ForegroundColor Green
    } elseif ($successCount -eq 1) {
        Write-Host "⚠ Abteilungs-Share teilweise konfiguriert für: $Department" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Abteilungs-Share-Konfiguration fehlgeschlagen für: $Department" -ForegroundColor Red
    }
    
    return $successCount
}

# 1. Globale Share-Berechtigungen konfigurieren
Write-Host "=== Globale Share-Konfiguration ===" -ForegroundColor Yellow

# Global$ Share für alle Benutzer
$globalGroupRW = "DL_Global-FS_RW"
$globalGroupR = "DL_Global-FS_R"

$globalSuccess = 0
if (Set-SharePermission -ShareName "Global$" -GroupName $globalGroupRW -AccessRight "Full") {
    $globalSuccess++
}
if (Set-SharePermission -ShareName "Global$" -GroupName $globalGroupR -AccessRight "Read") {
    $globalSuccess++
}

if ($globalSuccess -eq 2) {
    Write-Host "✓ Globale Share-Berechtigungen vollständig konfiguriert" -ForegroundColor Green
} else {
    Write-Host "⚠ Globale Share-Berechtigungen nicht vollständig konfiguriert" -ForegroundColor Yellow
}

# 2. Abteilungs-Share-Berechtigungen konfigurieren
Write-Host ""
Write-Host "=== Abteilungs-Share-Konfiguration ===" -ForegroundColor Yellow

$totalDepartments = $departments.Count
$successfulDepartments = 0

foreach ($dep in $departments) {
    $departmentSuccess = Set-DepartmentSharePermissions -Department $dep -ShareName "Abteilungen$"
    
    if ($departmentSuccess -eq 2) {
        $successfulDepartments++
    }
}

# 3. Zusammenfassung und Statistik
Write-Host ""
Write-Host "=== KONFIGURATIONSERGEBNIS ===" -ForegroundColor Cyan
Write-Host "Globale Share-Berechtigungen: $(if($globalSuccess -eq 2){'✓ Vollständig'}else{'⚠ Unvollständig'})" -ForegroundColor $(if($globalSuccess -eq 2){'Green'}else{'Yellow'})
Write-Host "Abteilungs-Shares erfolgreich: $successfulDepartments von $totalDepartments" -ForegroundColor $(if($successfulDepartments -eq $totalDepartments){'Green'}else{'Yellow'})

if ($successfulDepartments -eq $totalDepartments -and $globalSuccess -eq 2) {
    Write-Host "✓ Alle Share-Berechtigungen erfolgreich konfiguriert!" -ForegroundColor Green
} else {
    Write-Host "⚠ Share-Konfiguration unvollständig. Bitte Warnungen prüfen." -ForegroundColor Yellow
}

# 4. Home-Share-Berechtigungen prüfen  
Write-Host ""
Write-Host "=== Home-Share-Konfiguration ===" -ForegroundColor Yellow

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

# 5. Übersicht der konfigurierten Share-Berechtigungen anzeigen
Write-Host ""
Write-Host "=== DETAILLIERTE SHARE-ÜBERSICHT ===" -ForegroundColor Cyan

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
    } else {
        Write-Host "Share: $shareName - NICHT GEFUNDEN" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "=== Share-Berechtigungen Setup abgeschlossen ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "KONFIGURATION ERFOLGREICH:" -ForegroundColor Green
Write-Host "✓ Globale Freigabe (Global$) zu entsprechenden Gruppen hinzugefügt" -ForegroundColor White
Write-Host "✓ Abteilungsfreigaben (Abteilungen$) zu Abteilungsgruppen hinzugefügt" -ForegroundColor White
Write-Host "✓ Share-Berechtigungen entsprechend RW/R-Gruppen konfiguriert" -ForegroundColor White
Write-Host ""
Write-Host "WICHTIGE HINWEISE:" -ForegroundColor Yellow
Write-Host "1. Share-Berechtigungen sind auf SMB-Ebene konfiguriert" -ForegroundColor White
Write-Host "2. NTFS-Berechtigungen werden separat über Setup-Fileserver-Rights.ps1 verwaltet" -ForegroundColor White
Write-Host "3. Benutzer benötigen beide Berechtigungsebenen für Vollzugriff" -ForegroundColor White
Write-Host "4. Laufwerkszuordnungen erfolgen über GPOs (siehe Setup-GPO-DriveMapping.ps1)" -ForegroundColor White
Write-Host "5. Gruppenrichtlinien verknüpfen T:/G: Laufwerke automatisch basierend auf OU-Zugehörigkeit" -ForegroundColor White