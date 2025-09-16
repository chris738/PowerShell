#
# Skriptname: link_gpos.ps1
# Beschreibung:
#   Dieses PowerShell‑Skript verknüpft bestehende Gruppenrichtlinienobjekte (GPOs) mit
#   den entsprechenden Organisationseinheiten (OUs). Es ist ein Begleitskript zu
#   create_gpos.ps1. Die GPO‑Namen und OUs werden als Parameter übergeben.
#
#   – Das globale GPO (z. B. „Map_G_Drive“) und das Suchleisten‑GPO werden mit
#     allen angegebenen OUs verknüpft.
#   – Das Abteilungs‑GPO (z. B. „Map_T_Drive“) wird mit jeder OU verknüpft,
#     damit die zuvor konfigurierten Item‑Level‑Filter im Drives.xml greifen.
#
#   Die Verknüpfung erfolgt mit dem Cmdlet New‑GPLink. Laut Microsoft wird
#   New‑GPLink zusammen mit Get‑GPO verwendet, um ein GPO an eine OU zu binden【767325073056549†L297-L304】.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$GlobalGpoName,

    [Parameter(Mandatory=$true)]
    [string]$DepartmentGpoName,

    [Parameter(Mandatory=$true)]
    [string]$SearchGpoName,

    # Liste der OUs, die das globale G‑Laufwerk und die Suchleiste erhalten
    [Parameter(Mandatory=$true)]
    [string[]]$GlobalOUs,

    # Hashtable der Abteilungen: Schlüssel = OU‑DistinguishedName, Wert = UNC‑Pfad
    # Der UNC‑Pfad ist hier nicht relevant für die Verknüpfung, wird aber für Konsistenz erwartet.
    [Parameter(Mandatory=$true)]
    [hashtable]$DepartmentOUs,

    # Liste der OUs, mit denen das Suchleisten‑GPO verknüpft wird
    [Parameter(Mandatory=$true)]
    [string[]]$SearchOUs
)

Import-Module GroupPolicy -ErrorAction Stop

Write-Host "Starte Verknüpfung der GPOs…" -ForegroundColor Green

# G‑Laufwerk und Suchleisten‑GPO an die globalen OUs anbinden
foreach ($ou in $GlobalOUs) {
    Write-Host "Verknüpfe GPO '$GlobalGpoName' mit OU '$ou'…" -ForegroundColor Cyan
    New-GPLink -Name $GlobalGpoName -Target $ou -Enforced:$false -LinkEnabled:$true
}

foreach ($ou in $SearchOUs) {
    Write-Host "Verknüpfe GPO '$SearchGpoName' mit OU '$ou'…" -ForegroundColor Cyan
    New-GPLink -Name $SearchGpoName -Target $ou -Enforced:$false -LinkEnabled:$true
}

# Abteilungs‑GPO an jede Abteilungs‑OU binden
foreach ($ou in $DepartmentOUs.Keys) {
    Write-Host "Verknüpfe GPO '$DepartmentGpoName' mit Abteilungs‑OU '$ou'…" -ForegroundColor Cyan
    New-GPLink -Name $DepartmentGpoName -Target $ou -Enforced:$false -LinkEnabled:$true
}

Write-Host "GPO‑Verknüpfung abgeschlossen." -ForegroundColor Green
