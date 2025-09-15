Import-Module ActiveDirectory

$homeRoot = "F:\Shares\Home"
$ous = @("IT","Events","Facility","Vorstand","Shop","Verwaltung","Gast")
$domain = (Get-ADDomain)
$dcPath = "DC=$($domain.DNSRoot.Replace('.',',DC='))"
$server = $env:COMPUTERNAME

# Admin/SYSTEM SIDs
$domainAdmins = Get-ADGroup "Domain Admins"
$adminSid = New-Object System.Security.Principal.SecurityIdentifier $domainAdmins.SID
$systemSid = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18"

# Root sicherstellen
if (-not (Test-Path $homeRoot)) { New-Item -ItemType Directory -Path $homeRoot | Out-Null }

foreach ($ou in $ous) {
    $searchBase = "OU=$ou,$dcPath"
    $users = Get-ADUser -SearchBase $searchBase -Filter * -Properties GivenName,Surname,SamAccountName,SID,Enabled | Where-Object {$_.Enabled -eq $true}

    foreach ($u in $users) {
        $fn = ($u.GivenName -replace '\s+','').Trim()
        $ln = ($u.Surname   -replace '\s+','').Trim()
        if (-not $fn -or -not $ln) { continue }

        $folderName = "$fn.$ln"
        $userFolder = Join-Path $homeRoot $folderName
        $uncPath    = "\\$server\Home$\$folderName"

        # Ordner explizit anlegen
        if (-not (Test-Path $userFolder)) {
            try {
                New-Item -ItemType Directory -Path $userFolder -Force -ErrorAction Stop | Out-Null
                Write-Host "📂 Ordner erstellt: $userFolder"
            }
            catch {
                Write-Warning "⚠️ Konnte $userFolder nicht erstellen: $_"
                continue
            }
        }

        if (-not (Test-Path $userFolder)) {
            Write-Warning "⚠️ Ordner fehlt weiterhin: $userFolder"
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
			Write-Host "✔ NTFS für $folderName gesetzt."
		}
		catch {
			Write-Warning "⚠️ ACL-Fehler bei ${userFolder}: $_"
			continue
		}


        # Home-Laufwerk eintragen
        try {
            Set-ADUser $u -HomeDirectory $uncPath -HomeDrive "H:"
            Write-Host "✔ $($u.SamAccountName): HomeDrive=H: ($uncPath)"
        }
        catch {
            Write-Warning "⚠️ Konnte HomeDrive für $($u.SamAccountName) nicht setzen: $_"
        }
    }
}
