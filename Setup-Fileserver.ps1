# Setup-Fileserver.ps1
# Erstellt Fileserver-Struktur basierend auf CSV-Abteilungen
# Aufruf: .\Setup-Fileserver.ps1 [pfad-zur-csv-datei]

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

# Laufwerkbasis
$base = "F:\Shares"

# OU für Gruppen
$ou = "OU=Gruppen,DC=eHH,DC=de"

# Admin-Gruppe
$admins = "eHH\Domain Admins"

# Funktion: Ordner anlegen
function Ensure-Folder {
    param([string]$path)
    if (-Not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "Ordner erstellt: $path"
    }
}

# Funktion: NTFS-Rechte setzen
function Set-Permissions {
    param([string]$path, [string]$group, [string]$rights)

    $acl = Get-Acl $path
    $acl.SetAccessRuleProtection($true, $false)

    # Admins Vollzugriff
    $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($admins,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $acl.SetAccessRule($ruleAdmins)

    # Gruppe (Domain Local) Berechtigung
    if ($group -ne "") {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($group,$rights,"ContainerInherit,ObjectInherit","None","Allow")
        $acl.AddAccessRule($rule)
    }

    Set-Acl -Path $path -AclObject $acl
    Write-Host "Rechte gesetzt: $group → $rights auf $path"
}

# Struktur aufbauen
foreach ($dep in $departments) {
    $folder = "$base\Abteilungen\$dep"
    $dlGroup = "DL_${dep}-FS_RW"

    # Ordner erstellen
    Ensure-Folder $folder

    # Domain Local Gruppe anlegen (falls fehlt)
    if (-not (Get-ADGroup -Filter {Name -eq $dlGroup} -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $dlGroup -GroupScope DomainLocal -Path $ou -GroupCategory Security -Description "Domain Local Gruppe RW für $dep auf Fileserver"
        Write-Host "Gruppe erstellt: $dlGroup"
    }

    # Rechte setzen
    Set-Permissions -path $folder -group $dlGroup -rights "Modify"
}

# Globales Verzeichnis
$globalFolder = "$base\Global"
Ensure-Folder $globalFolder
$dlGlobal = "DL_Global-FS_RW"
if (-not (Get-ADGroup -Filter {Name -eq $dlGlobal} -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $dlGlobal -GroupScope DomainLocal -Path $ou -GroupCategory Security -Description "Domain Local Gruppe RW für Global"
    Write-Host "Gruppe erstellt: $dlGlobal"
}
Set-Permissions -path $globalFolder -group $dlGlobal -rights "Modify"

# Home-Verzeichnis
Ensure-Folder "$base\Home"
Write-Host "Home-Verzeichnis erstellt, Rechte werden später pro User vergeben."

# Scripts-Verzeichnis für Logon-Scripts
Ensure-Folder "$base\Scripts"
Write-Host "Scripts-Verzeichnis für Benutzer-Logon-Scripts erstellt."
