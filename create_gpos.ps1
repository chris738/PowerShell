#
# Skriptname: create_gpos.ps1
# Beschreibung:
#   Dieses PowerShell‑Skript erstellt drei Gruppenrichtlinienobjekte (GPOs):
#   1. Eine Richtlinie zur Einbindung des globalen Laufwerks G:. Alle Benutzer
#      erhalten dadurch ein Netzlaufwerk mit dem Laufwerksbuchstaben „G“. Der
#      UNC‑Pfad wird als Parameter übergeben.
#   2. Eine Richtlinie zur Einbindung des Abteilungslaufwerks T:. Für jede
#      Abteilung (repräsentiert durch eine Organisationseinheit/OU) wird ein
#      entsprechender UNC‑Pfad bereitgestellt. Die Zuordnung von OU zu Pfad
#      wird als Hashtable übergeben. Das Skript erzeugt eine XML‑Konfiguration
#      (Drives.xml) mit mehreren Einträgen, in denen Item‑Level‑Targeting
#      verwendet wird, sodass jede OU ihr eigenes T:‑Laufwerk erhält.
#   3. Eine Richtlinie zum Deaktivieren der Suchleiste in der Windows‑Taskleiste.
#      Hierzu wird der Registrierungswert „SearchBoxTaskbarMode“ auf „0“
#      gesetzt. Laut Microsoft wird dadurch das Suchfeld ausgeblendet【877728684410536†L31-L36】.
#
# Voraussetzungen:
#   – Die Module „ActiveDirectory“ und „GroupPolicy“ müssen installiert und
#     importierbar sein. Die Module liefern Cmdlets wie New‑GPO,
#     Set‑GPRegistryValue und New‑GPLink【767325073056549†L274-L304】.
#   – Das Skript muss mit ausreichenden Rechten ausgeführt werden, um GPOs
#     anzulegen und Dateien im SYSVOL anzupassen.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$GlobalSharePath,

    [Parameter(Mandatory=$true)]
    [hashtable]$DepartmentSharePaths,

    [Parameter(Mandatory=$false)]
    [string]$GlobalGpoName = 'Map_G_Drive',

    [Parameter(Mandatory=$false)]
    [string]$DepartmentGpoName = 'Map_T_Drive',

    [Parameter(Mandatory=$false)]
    [string]$SearchGpoName = 'Disable_Search_Bar'
)

# Modul importieren
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy    -ErrorAction Stop

Write-Host "Starte die Erstellung der Gruppenrichtlinien…" -ForegroundColor Green

# 1. Globales G‑Laufwerk GPO erstellen
Write-Host "Erstelle GPO '$GlobalGpoName'" -ForegroundColor Cyan
$globalGpo = New-GPO -Name $GlobalGpoName -Comment 'Globales Laufwerk G: für alle Benutzer' -ErrorAction Stop

# 2. Abteilungs‑T‑Laufwerk GPO erstellen
Write-Host "Erstelle GPO '$DepartmentGpoName'" -ForegroundColor Cyan
$deptGpo = New-GPO -Name $DepartmentGpoName -Comment 'Abteilungslaufwerk T: für jede OU' -ErrorAction Stop

# 3. Suchleisten‑GPO erstellen
Write-Host "Erstelle GPO '$SearchGpoName'" -ForegroundColor Cyan
$searchGpo = New-GPO -Name $SearchGpoName -Comment 'Deaktiviert die Windows‑Taskleisten‑Suche' -ErrorAction Stop

# Hilfsfunktion: Erstellt das Laufwerk‑XML für eine einzelne Zuordnung
function New-DriveMappingXml {
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
    # Ein Drive‑Eintrag mit optionalem Item‑Level‑Targeting erstellen
    $driveNode = @()
    $uid = [guid]::NewGuid().ToString()
    $changed = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $driveNode += "  <Drive clsid=\"{935D1B74-9CB8-4e3c-9914-7DD559B7A417}\" name=\"$DriveLetter:\" status=\"$DriveLetter:\" image=\"2\" changed=\"$changed\" uid=\"$uid\">"
    $driveNode += "    <Properties action=\"$Action\" thisDrive=\"NOCHANGE\" allDrives=\"NOCHANGE\" userName=\"\" cpassword=\"\" path=\"$SharePath\" label=\"$Label\" persistent=\"1\" useLetter=\"1\" letter=\"$DriveLetter\" />"
    if ($OUFilter) {
        $driveNode += "    <Filters><User><Query><Filter>$OUFilter</Filter></Query></User></Filters>"
    }
    $driveNode += "  </Drive>"
    return ($driveNode -join "`n")
}

# Funktion: Speichert die XML‑Datei für ein GPO
function Save-DriveMappings {
    param(
        [Parameter(Mandatory)]
        [Guid]$GpoId,
        [Parameter(Mandatory)]
        [string[]]$DriveXmlEntries
    )
    $domain = (Get-ADDomain).DNSRoot
    $gpoPath = "\\$domain\SYSVOL\$domain\Policies\{$GpoId}\User\Preferences\Drives"
    New-Item -ItemType Directory -Path $gpoPath -Force | Out-Null
    $xmlContent = @()
    $xmlContent += "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    $xmlContent += "<Drives clsid=\"{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}\">"
    $xmlContent += $DriveXmlEntries
    $xmlContent += "</Drives>"
    $xmlContent -join "`n" | Out-File -FilePath (Join-Path $gpoPath 'Drives.xml') -Encoding utf8
}

# 1. Laufwerk G: für alle Benutzer
$entriesG = @()
$entriesG += New-DriveMappingXml -DriveLetter 'G' -SharePath $GlobalSharePath -Label 'Global' -Action 'U'
Save-DriveMappings -GpoId $globalGpo.Id -DriveXmlEntries $entriesG

# 2. Laufwerk T: für jede Abteilung (OU)
$entriesT = @()
foreach ($ouDN in $DepartmentSharePaths.Keys) {
    $sharePath = $DepartmentSharePaths[$ouDN]
    # OU‑Name aus DN extrahieren
    $ouName = ($ouDN -split ',')[0] -replace '^OU='''
    # Item‑Level‑Targeting per LDAP‑Filter: Filter überprüft, ob der Benutzer sich in der OU befindet.
    $ldapFilter = "(OU=$ouName)"
    $entriesT += New-DriveMappingXml -DriveLetter 'T' -SharePath $sharePath -Label $ouName -Action 'U' -OUFilter $ldapFilter
}
Save-DriveMappings -GpoId $deptGpo.Id -DriveXmlEntries $entriesT

# 3. Registrierungseintrag zum Deaktivieren der Suchleiste erstellen
Write-Host "Konfiguriere Registry‑Eintrag zur Deaktivierung der Suchleiste…" -ForegroundColor Cyan
Set-GPRegistryValue -Name $SearchGpoName -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'SearchBoxTaskbarMode' -Type DWord -Value 0 -ErrorAction Stop

Write-Host "Alle GPOs wurden erfolgreich erstellt." -ForegroundColor Green
