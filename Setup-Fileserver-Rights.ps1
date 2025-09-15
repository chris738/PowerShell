# Setup-Fileserver-Rights.ps1
# Setzt Fileserver-Rechte basierend auf CSV-Abteilungen
# Aufruf: .\Setup-Fileserver-Rights.ps1 [pfad-zur-csv-datei]

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

Import-Module ActiveDirectory

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

# Basis-Laufwerk
$base = "F:\Shares"

# "Domain Admins" SID automatisch auflösen
$domainAdmins = Get-ADGroup "Domain Admins"
$adminSid = New-Object System.Security.Principal.SecurityIdentifier $domainAdmins.SID
Write-Host "Verwende Admin-SID: $($domainAdmins.SID)"

# Funktion: Ordner anlegen
function Ensure-Folder {
    param([string]$path)
    if (-Not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "Ordner erstellt: $path"
    }
}

# Funktion: Rechte setzen (Admins, RW-Gruppe, R-Gruppe)
function Set-Permissions {
    param([string]$path, [string]$groupRW, [string]$groupR)

    $acl = Get-Acl $path
    $acl.SetAccessRuleProtection($true, $false)

    # Admins Vollzugriff per SID
    $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $acl.SetAccessRule($ruleAdmins)

    # RW-Gruppe (Modify)
    if ($groupRW) {
        $ruleRW = New-Object System.Security.AccessControl.FileSystemAccessRule($groupRW,"Modify","ContainerInherit,ObjectInherit","None","Allow")
        $acl.AddAccessRule($ruleRW)
    }

    # R-Gruppe (Read)
    if ($groupR) {
        $ruleR = New-Object System.Security.AccessControl.FileSystemAccessRule($groupR,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
        $acl.AddAccessRule($ruleR)
    }

    Set-Acl -Path $path -AclObject $acl
    Write-Host "Rechte gesetzt auf $path"
}

# --- Abteilungen ---
$abteilungRoot = "$base\Abteilungen"
Ensure-Folder $abteilungRoot

foreach ($dep in $departments) {
    $folder = "$abteilungRoot\$dep"

    Ensure-Folder $folder

    # Gruppen definieren
    $dlGroupRW = "DL_${dep}-FS_RW"
    $dlGroupR  = "DL_${dep}-FS_R"

    # Domain Local Gruppen anlegen (falls nicht vorhanden)
    foreach ($grp in @($dlGroupRW, $dlGroupR)) {
        if (-not (Get-ADGroup -Filter {Name -eq $grp} -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $grp -GroupScope DomainLocal -GroupCategory Security -Path "OU=$dep,DC=eHH,DC=de" -Description "DL Gruppe für $dep Fileshare"
            Write-Host "Gruppe erstellt: $grp"
        }
    }

    # Rechte setzen
    Set-Permissions -path $folder -groupRW $dlGroupRW -groupR $dlGroupR
}

# --- Global ---
$globalFolder = "$base\Global"
Ensure-Folder $globalFolder
$dlGlobalRW = "DL_Global-FS_RW"
$dlGlobalR  = "DL_Global-FS_R"

foreach ($grp in @($dlGlobalRW, $dlGlobalR)) {
    if (-not (Get-ADGroup -Filter {Name -eq $grp} -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $grp -GroupScope DomainLocal -GroupCategory Security -Path "OU=Verwaltung,DC=eHH,DC=de" -Description "DL Gruppe für Global Fileshare"
        Write-Host "Gruppe erstellt: $grp"
    }
}
Set-Permissions -path $globalFolder -groupRW $dlGlobalRW -groupR $dlGlobalR

# --- Home ---
$homeFolder = "$base\Home"
Ensure-Folder $homeFolder

# Rechte: Nur Admins standardmäßig
$acl = Get-Acl $homeFolder
$acl.SetAccessRuleProtection($true, $false)
$ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$acl.SetAccessRule($ruleAdmins)
Set-Acl -Path $homeFolder -AclObject $acl
Write-Host "Rechte für Home-Root: nur Admins"
Write-Host "Benutzerrechte für einzelne Home-Ordner werden separat pro User vergeben."

# --- Scripts ---
$scriptsFolder = "$base\Scripts"
Ensure-Folder $scriptsFolder

# Rechte: Admins Vollzugriff, alle Benutzer Lesen+Ausführen
$acl = Get-Acl $scriptsFolder
$acl.SetAccessRuleProtection($true, $false)
$ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$acl.SetAccessRule($ruleAdmins)

# Authenticated Users: Lesen und Ausführen für Logon-Scripts
$authenticatedUsers = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-11"
$ruleUsers = New-Object System.Security.AccessControl.FileSystemAccessRule($authenticatedUsers,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($ruleUsers)

Set-Acl -Path $scriptsFolder -AclObject $acl
Write-Host "Rechte für Scripts-Root: Admins Vollzugriff, Benutzer Lesen+Ausführen"
