Import-Module ActiveDirectory

# OUs / Abteilungen
$departments = @("IT","Events","Facility","Vorstand","Shop","Verwaltung","Gast")

# Domain Info
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"

foreach ($dep in $departments) {
    $ouPath = "OU=$dep,$dcPath"

    # GG erstellen
    $ggName = "GG_${dep}-MA"
    if (-not (Get-ADGroup -Filter {Name -eq $ggName} -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $ggName -GroupScope Global -GroupCategory Security -Path $ouPath -Description "Globale Mitarbeitergruppe $dep"
        Write-Host "👥 GG erstellt: $ggName"
    } else {
        Write-Host "ℹ️ GG existiert: $ggName"
    }

    # Benutzer der OU in GG schieben
    $users = Get-ADUser -SearchBase $ouPath -Filter * -ErrorAction SilentlyContinue
    foreach ($u in $users) {
        try {
            Add-ADGroupMember -Identity $ggName -Members $u.SamAccountName -ErrorAction Stop
            Write-Host "➕ User $($u.SamAccountName) → $ggName"
        }
        catch {
            Write-Host "⚠️ User $($u.SamAccountName) ist evtl. schon Mitglied in $ggName"
        }
    }

    # DLs definieren
    $dlRW = "DL_${dep}-FS_RW"
    $dlR  = "DL_${dep}-FS_R"

    # GG in DL_RW aufnehmen
    if (Get-ADGroup -Filter {Name -eq $dlRW} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlRW -Members $ggName -ErrorAction Stop
            Write-Host "🔗 $ggName → $dlRW"
        } catch { Write-Host "⚠️ $ggName evtl. schon in $dlRW" }
    }

    # GG in DL_R aufnehmen (optional: nur wenn nötig)
    if (Get-ADGroup -Filter {Name -eq $dlR} -ErrorAction SilentlyContinue) {
        try {
            Add-ADGroupMember -Identity $dlR -Members $ggName -ErrorAction Stop
            Write-Host "🔗 $ggName → $dlR"
        } catch { Write-Host "⚠️ $ggName evtl. schon in $dlR" }
    }
}

Write-Host "✅ Setup abgeschlossen."
