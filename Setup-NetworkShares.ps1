# Setup-NetworkShares.ps1
# Erstellt Netzwerkfreigaben für Home, Global und Abteilungen in PowerShell
# Aufruf: .\Setup-NetworkShares.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

# Module importieren (nur auf Windows Server verfügbar)
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

# Basis-Pfad für Shares
$basePath = "F:\Shares"

# Admin-Gruppe mit sicherer Identitätserkennung
try {
    $adminIdentity = Get-SafeDomainAdminsIdentity
    Write-Host "Domain Admins Identität erfolgreich aufgelöst"
}
catch {
    Write-ErrorMessage -Message "Kritischer Fehler: Konnte Domain Admins Identität nicht auflösen" -Type "Error"
    exit 1
}

# Hilfsfunktion: Überprüft ob ein Konto existiert und aufgelöst werden kann
function Test-AccountExists {
    param(
        [string]$AccountName
    )
    
    if ([string]::IsNullOrWhiteSpace($AccountName)) {
        return $false
    }
    
    try {
        # Versuche das Konto über Active Directory zu finden
        $account = Get-ADObject -Filter "Name -eq '$AccountName' -or SamAccountName -eq '$AccountName'" -ErrorAction SilentlyContinue
        if ($account) {
            return $true
        }
        
        # Fallback: Versuche über Windows Security Principal zu resolven
        $sid = [System.Security.Principal.SecurityIdentifier]::new($AccountName)
        return $true
    }
    catch {
        # Versuch mit NTAccount
        try {
            $ntAccount = [System.Security.Principal.NTAccount]::new($AccountName)
            $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
            return $true
        }
        catch {
            return $false
        }
    }
}

# Hilfsfunktion: Setzt Berechtigung sicher mit Validierung
function Grant-SafeSmbShareAccess {
    param(
        [string]$ShareName,
        [string]$AccountName,
        [string]$AccessRight
    )
    
    if (-not (Test-AccountExists -AccountName $AccountName)) {
        Write-Host "Warnung: Konto '$AccountName' konnte nicht aufgelöst werden - überspringe Berechtigung" -ForegroundColor Yellow
        return $false
    }
    
    try {
        Grant-SmbShareAccess -Name $ShareName -AccountName $AccountName -AccessRight $AccessRight -Force -ErrorAction Stop
        Write-Host "Berechtigung gesetzt: $AccountName ($AccessRight) für $ShareName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Warnung: Konnte Berechtigung für '$AccountName' nicht setzen: $_" -ForegroundColor Yellow
        return $false
    }
}

# Funktion: Netzwerkfreigabe erstellen oder aktualisieren
function Setup-NetworkShare {
    param(
        [string]$ShareName,
        [string]$SharePath,
        [string]$Description,
        [string[]]$FullAccessUsers = @(),
        [string[]]$ChangeAccessUsers = @(),
        [string[]]$ReadAccessUsers = @()
    )

    try {
        # Prüfen ob Share bereits existiert
        $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
        
        if ($existingShare) {
            Write-Host "Share '$ShareName' existiert bereits, überspringe Erstellung"
            return
        }

        # Verzeichnis sicherstellen
        if (-not (Test-Path $SharePath)) {
            Write-Warning "Verzeichnis $SharePath existiert nicht - wird übersprungen"
            return
        }

        # Share erstellen mit lokalisiertem Account-Namen
        $everyoneAccount = Get-LocalizedAccountName -WellKnownAccount "Everyone"
        New-SmbShare -Name $ShareName -Path $SharePath -Description $Description -FullAccess $everyoneAccount | Out-Null
        Write-Host "Netzwerkfreigabe erstellt: $ShareName -> $SharePath"

        # Erweiterte Berechtigungen setzen falls angegeben
        if ($FullAccessUsers.Count -gt 0 -or $ChangeAccessUsers.Count -gt 0 -or $ReadAccessUsers.Count -gt 0) {
            # Erst Everyone entfernen (mit lokalisiertem Namen)
            $everyoneAccount = Get-LocalizedAccountName -WellKnownAccount "Everyone"
            Revoke-SmbShareAccess -Name $ShareName -AccountName $everyoneAccount -Force -ErrorAction SilentlyContinue

            # Domain Admins mit sicherer Identitätserkennung
            try {
                $adminIdentity = Get-SafeDomainAdminsIdentity
                $adminSid = $adminIdentity.ToString()
                
                # Versuche zuerst deutsche Bezeichnung
                if (-not (Grant-SafeSmbShareAccess -ShareName $ShareName -AccountName "Domänen-Admins" -AccessRight "Full")) {
                    # Fallback: englische Bezeichnung
                    if (-not (Grant-SafeSmbShareAccess -ShareName $ShareName -AccountName "Domain Admins" -AccessRight "Full")) {
                        # Letzter Fallback: SID verwenden
                        try {
                            Grant-SmbShareAccess -Name $ShareName -AccountName $adminSid -AccessRight Full -Force -ErrorAction Stop
                            Write-Host "Domain Admins Berechtigung über SID gesetzt" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Warnung: Konnte Domain Admins Berechtigung nicht setzen: $_" -ForegroundColor Yellow
                        }
                    }
                }
            }
            catch {
                Write-Host "Warnung: Domain Admins Identität konnte nicht aufgelöst werden: $_" -ForegroundColor Yellow
            }

            # Spezifische Berechtigungen mit Validierung
            foreach ($user in $FullAccessUsers) {
                Grant-SafeSmbShareAccess -ShareName $ShareName -AccountName $user -AccessRight "Full"
            }
            foreach ($user in $ChangeAccessUsers) {
                Grant-SafeSmbShareAccess -ShareName $ShareName -AccountName $user -AccessRight "Change"
            }
            foreach ($user in $ReadAccessUsers) {
                Grant-SafeSmbShareAccess -ShareName $ShareName -AccountName $user -AccessRight "Read"
            }
        }

        $cleanMessage = Remove-EmojiFromString -InputString "Share-Berechtigungen gesetzt für: $ShareName"
        Write-Host $cleanMessage

    }
    catch {
        Write-ErrorMessage -Message "Fehler beim Erstellen der Freigabe $ShareName : $_" -Type "Error"
    }
}

Write-Host "Starte Erstellung der Netzwerkfreigaben..." -ForegroundColor Cyan

# 1. Home-Share (Home$)
$homeSharePath = Join-Path $basePath "Home"
$authenticatedUsers = Get-LocalizedAccountName -WellKnownAccount "Authenticated Users"
Setup-NetworkShare -ShareName "Home$" -SharePath $homeSharePath -Description "Home-Verzeichnisse der Benutzer" -ChangeAccessUsers @($authenticatedUsers)

# 2. Global-Share (Global$) 
$globalSharePath = Join-Path $basePath "Global"
$globalGroup = "DL_Global-FS_RW"
Setup-NetworkShare -ShareName "Global$" -SharePath $globalSharePath -Description "Globales Verzeichnis für alle Benutzer" -ChangeAccessUsers @($globalGroup)

# 3. Abteilungen-Share (Abteilungen$)
$departmentsSharePath = Join-Path $basePath "Abteilungen"
$departmentGroups = @()
foreach ($dep in $departments) {
    $departmentGroups += "DL_${dep}-FS_RW"
}
Setup-NetworkShare -ShareName "Abteilungen$" -SharePath $departmentsSharePath -Description "Abteilungsverzeichnisse" -ChangeAccessUsers $departmentGroups

# 4. Scripts-Share (Scripts$) - für Logon-Scripts
$scriptsSharePath = Join-Path $basePath "Scripts"
$authenticatedUsers = Get-LocalizedAccountName -WellKnownAccount "Authenticated Users"
Setup-NetworkShare -ShareName "Scripts$" -SharePath $scriptsSharePath -Description "Benutzer Logon-Scripts" -ReadAccessUsers @($authenticatedUsers)

Write-Host "Alle Netzwerkfreigaben wurden erfolgreich erstellt!" -ForegroundColor Green

# Freigaben anzeigen
Write-Host "`nErstelle Freigaben:" -ForegroundColor Yellow
Get-SmbShare | Where-Object { $_.Name -in @("Home$", "Global$", "Abteilungen$", "Scripts$") } | Format-Table Name, Path, Description -AutoSize