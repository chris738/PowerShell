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

# Domain Info
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"

# "Domain Admins" / "Domänen-Admins" SID sicher auflösen (unterstützt deutsche und englische Server)
try {
    $adminSid = Get-SafeDomainAdminsIdentity
    Write-Host "Domain Admins SID erfolgreich aufgelöst (Domänen-Admins/Domain Admins)"
}
catch {
    Write-ErrorMessage -Message "Kritischer Fehler: Konnte Domain Admins SID nicht auflösen (Domänen-Admins/Domain Admins)" -Type "Error"
    exit 1
}

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

    try {
        $acl = Get-Acl $path
        $acl.SetAccessRuleProtection($true, $false)

        # Admins Vollzugriff per SID
        $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
        $acl.SetAccessRule($ruleAdmins)

        # RW-Gruppe (Modify)
        if ($groupRW) {
            $rwGroup = Get-ADGroup -Filter {Name -eq $groupRW} -ErrorAction SilentlyContinue
            if (-not $rwGroup) {
                Write-ErrorMessage -Message "Global-Gruppe $groupRW nicht gefunden!" -Type "NotFound"
            } else {
                $rwSid = New-Object System.Security.Principal.SecurityIdentifier $rwGroup.SID
                $ruleRW = New-Object System.Security.AccessControl.FileSystemAccessRule($rwSid,"Modify","ContainerInherit,ObjectInherit","None","Allow")
                $acl.AddAccessRule($ruleRW)
            }
        }

        # R-Gruppe (Read)
        if ($groupR) {
            $rGroup = Get-ADGroup -Filter {Name -eq $groupR} -ErrorAction SilentlyContinue
            if (-not $rGroup) {
                Write-ErrorMessage -Message "Global-Gruppe $groupR nicht gefunden!" -Type "NotFound"
            } else {
                $rSid = New-Object System.Security.Principal.SecurityIdentifier $rGroup.SID
                $ruleR = New-Object System.Security.AccessControl.FileSystemAccessRule($rSid,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
                $acl.AddAccessRule($ruleR)
            }
        }

        Set-Acl -Path $path -AclObject $acl
        $cleanMessage = Remove-EmojiFromString -InputString "Rechte gesetzt auf $path"
        Write-Host $cleanMessage
    }
    catch {
        Write-ErrorMessage -Message "Fehler beim Setzen der Rechte auf $path : $_" -Type "Error"
    }
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
            try {
                New-ADGroup -Name $grp -GroupScope DomainLocal -GroupCategory Security -Path "OU=$dep,$dcPath" -Description "DL Gruppe für $dep Fileshare"
                $cleanMessage = Remove-EmojiFromString -InputString "Gruppe erstellt: $grp"
                Write-Host $cleanMessage
            }
            catch {
                Write-ErrorMessage -Message "Fehler beim Erstellen der Gruppe $grp : $_" -Type "Error"
            }
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
        try {
            # Global groups werden auf Domain-Ebene erstellt für bessere Zugänglichkeit aller OUs
            New-ADGroup -Name $grp -GroupScope DomainLocal -GroupCategory Security -Path $dcPath -Description "DL Gruppe für Global Fileshare"
            $cleanMessage = Remove-EmojiFromString -InputString "Gruppe erstellt: $grp"
            Write-Host $cleanMessage
        }
        catch {
            Write-ErrorMessage -Message "Fehler beim Erstellen der Gruppe $grp : $_" -Type "Error"
        }
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
