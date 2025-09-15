# Create-HomeFolders.ps1
# Erstellt Home-Ordner für Benutzer basierend auf CSV-Abteilungen
# Aufruf: .\Create-HomeFolders.ps1 [pfad-zur-csv-datei]

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

$homeRoot = "F:\Shares\Home"
$ous = $departments
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"
$server = Get-DomainControllerServer

Write-Host "Verwende Server für Laufwerkszuordnungen: $server" -ForegroundColor Cyan

# Admin/SYSTEM SIDs sicher auflösen
try {
    $adminSid = Get-SafeDomainAdminsIdentity
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18"
    Write-Host "Admin- und System-SIDs erfolgreich aufgelöst"
}
catch {
    Write-ErrorMessage -Message "Kritischer Fehler: Konnte Admin-SIDs nicht auflösen" -Type "Error"
    exit 1
}

# Root sicherstellen
if (-not (Test-Path $homeRoot)) { New-Item -ItemType Directory -Path $homeRoot | Out-Null }

foreach ($ou in $ous) {
    $searchBase = "OU=$ou,$dcPath"
    $users = Get-ADUser -SearchBase $searchBase -Filter * -Properties GivenName,Surname,SamAccountName,SID,Enabled | Where-Object {$_.Enabled -eq $true}

    foreach ($u in $users) {
        $fn = ($u.GivenName -replace '\s+','').Trim()
        $ln = ($u.Surname   -replace '\s+','').Trim()
        if (-not $fn -or -not $ln) { continue }

        # Verwende neue SAM-Namenskonvention
        $sam = Get-SamAccountName -Vorname $fn -Nachname $ln
        $folderName = $sam  # Ordnername entspricht SAM: vorname.nachname
        $userFolder = Join-Path $homeRoot $folderName
        $uncPath    = "\\$server\Home$\$folderName"

        # Ordner explizit anlegen
        if (-not (Test-Path $userFolder)) {
            try {
                New-Item -ItemType Directory -Path $userFolder -Force -ErrorAction Stop | Out-Null
                Write-Host "Ordner erstellt: $userFolder"
            }
            catch {
                Write-Warning "Konnte $userFolder nicht erstellen: $_"
                continue
            }
        }

        if (-not (Test-Path $userFolder)) {
            Write-Warning "Ordner fehlt weiterhin: $userFolder"
            continue
        }

        # ACL setzen
        try {
            $uSid = New-Object System.Security.Principal.SecurityIdentifier $u.SID
            $acl = Get-Acl $userFolder
            $acl.SetAccessRuleProtection($true,$false)
            $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null

            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($uSid,"Modify","ContainerInherit,ObjectInherit","None","Allow")))

            Set-Acl -Path $userFolder -AclObject $acl
            $cleanMessage = Remove-EmojiFromString -InputString "NTFS für $folderName gesetzt."
            Write-Host $cleanMessage
        }
        catch {
            Write-ErrorMessage -Message "ACL-Fehler bei ${userFolder}: $_" -Type "Error"
            continue
        }


        # Home-Laufwerk eintragen
        try {
            Set-ADUser $u -HomeDirectory $uncPath -HomeDrive "H:"
            Write-Host "$($u.SamAccountName): HomeDrive=H: ($uncPath)"
        }
        catch {
            Write-Warning "Konnte HomeDrive für $($u.SamAccountName) nicht setzen: $_"
        }

        # Zusätzliche Laufwerkszuordnungen über ScriptPath setzen
        try {
            # Global-Laufwerk G: und Abteilungs-Laufwerk S: über Logon-Script
            $globalPath = "\\$server\Global$"
            $departmentPath = "\\$server\Abteilungen$\$ou"
            
            # Logon-Script erstellen für Laufwerkszuordnungen
            $scriptContent = @"
@echo off
net use G: "$globalPath" /persistent:yes >nul 2>&1
net use S: "$departmentPath" /persistent:yes >nul 2>&1
"@
            
            # Script-Verzeichnis sicherstellen
            $scriptDir = "F:\Shares\Scripts"
            if (-not (Test-Path $scriptDir)) {
                New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            }
            
            # Benutzer-spezifisches Logon-Script erstellen
            $scriptFileName = "${sam}_logon.bat"
            $scriptFilePath = Join-Path $scriptDir $scriptFileName
            $scriptContent | Out-File -FilePath $scriptFilePath -Encoding ASCII -Force
            
            # Script-Pfad im AD-Benutzer setzen
            Set-ADUser $u -ScriptPath $scriptFileName
            
            $cleanMessage = Remove-EmojiFromString -InputString "${sam}: Laufwerkszuordnungen gesetzt - H: ($uncPath), G: ($globalPath), S: ($departmentPath)"
            Write-Host $cleanMessage
        }
        catch {
            Write-Warning "Konnte Laufwerkszuordnungen für $($u.SamAccountName) nicht setzen: $_"
        }
    }
}
