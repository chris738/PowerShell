# Common-Functions.ps1
# Gemeinsame Funktionen für alle PowerShell-Skripte

function Get-DepartmentsFromCSV {
    <#
    .SYNOPSIS
    Liest eindeutige Abteilungen aus der CSV-Datei
    
    .PARAMETER CsvPath
    Pfad zur CSV-Datei mit Benutzerdaten
    
    .RETURNS
    Array mit eindeutigen Abteilungsnamen
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )
    
    if (-Not (Test-Path $CsvPath)) {
        Write-Error "CSV-Datei $CsvPath nicht gefunden!"
        return @()
    }
    
    try {
        $users = Import-Csv -Path $CsvPath -Delimiter ";"
        $departments = $users | Select-Object -ExpandProperty Abteilung -Unique | Where-Object { $_ -ne "" }
        Write-Host "Gefundene Abteilungen aus CSV: $($departments -join ', ')" -ForegroundColor Green
        return $departments
    }
    catch {
        Write-Error "Fehler beim Lesen der CSV-Datei: $_"
        return @()
    }
}

function Get-DefaultCsvPath {
    <#
    .SYNOPSIS
    Gibt den Standard-Pfad zur CSV-Datei zurück
    #>
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    return Join-Path $scriptDir "Userlist-EchtHamburg.csv"
}

function Test-CsvFile {
    <#
    .SYNOPSIS
    Überprüft, ob die CSV-Datei die erforderlichen Spalten enthält
    
    .PARAMETER CsvPath
    Pfad zur CSV-Datei
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )
    
    if (-Not (Test-Path $CsvPath)) {
        Write-Error "CSV-Datei $CsvPath nicht gefunden!"
        return $false
    }
    
    try {
        $sample = Import-Csv -Path $CsvPath -Delimiter ";" | Select-Object -First 1
        $requiredColumns = @('Vorname', 'Nachname', 'Abteilung', 'E-Mail')
        
        foreach ($col in $requiredColumns) {
            if (-not $sample.PSObject.Properties.Name.Contains($col)) {
                Write-Error "Erforderliche Spalte '$col' fehlt in der CSV-Datei!"
                return $false
            }
        }
        
        Write-Host "CSV-Datei Format ist korrekt" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Fehler beim Validieren der CSV-Datei: $_"
        return $false
    }
}

function Get-DomainControllerServer {
    <#
    .SYNOPSIS
    Ermittelt den Domain Controller Server für Laufwerkszuordnungen
    
    .DESCRIPTION
    Versucht zuerst den aktuellen Server zu verwenden (wo das Script läuft),
    dann den Domain Controller, und falls nötig eine IP-Adresse
    
    .RETURNS
    Servername oder IP-Adresse für UNC-Pfade
    #>
    try {
        # Zuerst: Aktueller Server (wo Script läuft)
        $currentServer = $env:COMPUTERNAME
        if ($currentServer) {
            Write-Host "Verwende aktuellen Server: $currentServer" -ForegroundColor Green
            return $currentServer
        }
        
        # Fallback: Domain Controller ermitteln
        $domain = Get-ADDomain -ErrorAction SilentlyContinue
        if ($domain -and $domain.PDCEmulator) {
            $dcServer = $domain.PDCEmulator.Split('.')[0]  # Nur Hostname ohne Domain
            Write-Host "Domain Controller ermittelt: $dcServer" -ForegroundColor Green
            return $dcServer
        }
        
        # Letzter Fallback: localhost
        Write-Warning "Konnte keinen Server ermitteln, verwende localhost"
        return "localhost"
    }
    catch {
        Write-Warning "Fehler bei Server-Ermittlung: $_"
        # Notfall-Fallback: localhost
        return "localhost"
    }
}

function Get-SamAccountName {
    <#
    .SYNOPSIS
    Erstellt SAM Account Name im Format Vorname.Nachname
    
    .PARAMETER Vorname
    Vorname des Benutzers
    
    .PARAMETER Nachname  
    Nachname des Benutzers
    
    .RETURNS
    SAM Account Name im Format "vorname.nachname" (lowercase)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Vorname,
        
        [Parameter(Mandatory=$true)]
        [string]$Nachname
    )
    
    $cleanVorname = ($Vorname -replace '\s+','').Trim()
    $cleanNachname = ($Nachname -replace '\s+','').Trim()
    
    if (-not $cleanVorname -or -not $cleanNachname) {
        throw "Vorname und Nachname dürfen nicht leer sein"
    }
    
    return "$cleanVorname.$cleanNachname".ToLower()
}

function Remove-EmojiFromString {
    <#
    .SYNOPSIS
    Entfernt Emojis aus einem String
    
    .PARAMETER InputString
    Der String, aus dem Emojis entfernt werden sollen
    
    .RETURNS
    String ohne Emojis
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString
    )
    
    # Häufige Emoji-Zeichen entfernen (einfache Zeichen)
    # $commonEmojis = @('🎉', '✅', '📂', '🔗', '🌍', '➕', '❌', '⚠️', '✨', '🚀', '💡', '📋', '📊', '🎯', '🔧', '⭐', '🏠', '👤', '👥', '💼', '📁', '🗂️', '📄', '📈', '📉', '🔑', '🛡️', '⚙️', '🔄', '▶️', '⏸️', '⏹️', '🔴', '🟡', '🟢', '🔵', '⚪', '⚫')
    
    $result = $InputString
    foreach ($emoji in $commonEmojis) {
        $result = $result.Replace($emoji, '')
    }
    
    # Entferne auch andere Unicode-Symbole die als Emojis verwendet werden könnten
    $result = $result -replace '[\u2600-\u26FF]', ''  # Verschiedene Symbole
    $result = $result -replace '[\u2700-\u27BF]', ''  # Dingbats
    
    return $result.Trim()
}

function Write-ErrorMessage {
    <#
    .SYNOPSIS
    Schreibt formatierte Fehlermeldungen ohne Emojis
    
    .PARAMETER Message
    Die Fehlermeldung
    
    .PARAMETER Type
    Art des Fehlers: NotFound (rot) oder AlreadyExists (gelb)
    
    .PARAMETER AdditionalInfo
    Zusätzliche Informationen (z.B. Benutzername bei bereits vorhandenen Accounts)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("NotFound", "AlreadyExists", "Error")]
        [string]$Type = "Error",
        
        [Parameter(Mandatory=$false)]
        [string]$AdditionalInfo
    )
    
    # Emojis entfernen
    $cleanMessage = Remove-EmojiFromString -InputString $Message
    
    switch ($Type) {
        "NotFound" {
            Write-Host $cleanMessage -ForegroundColor Red
            if ($AdditionalInfo) {
                Write-Host $AdditionalInfo -ForegroundColor Red
            }
        }
        "AlreadyExists" {
            Write-Host $cleanMessage -ForegroundColor Yellow
            if ($AdditionalInfo) {
                Write-Host "Betroffener Benutzer: $AdditionalInfo" -ForegroundColor Yellow
            }
        }
        "Error" {
            Write-Host $cleanMessage -ForegroundColor Red
            if ($AdditionalInfo) {
                Write-Host $AdditionalInfo -ForegroundColor Red
            }
        }
    }
}

function Get-SafeDomainAdminsIdentity {
    <#
    .SYNOPSIS
    Ruft die Domain Admins Gruppe sicher ab und gibt eine verwendbare Identität zurück
    Unterstützt sowohl deutsche ("Domänen-Admins") als auch englische ("Domain Admins") Serverumgebungen
    
    .RETURNS
    SecurityIdentifier-Objekt für Domain Admins
    #>
    try {
        # Versuche zuerst die deutsche Bezeichnung für deutsche Server
        $domainAdmins = Get-ADGroup -Identity "Domänen-Admins" -ErrorAction SilentlyContinue
        if ($domainAdmins) {
            Write-Host "Deutsche Domain Admins Gruppe 'Domänen-Admins' gefunden" -ForegroundColor Green
            return New-Object System.Security.Principal.SecurityIdentifier $domainAdmins.SID
        }
        
        # Fallback: Englische Bezeichnung für internationale Server
        $domainAdmins = Get-ADGroup -Identity "Domain Admins" -ErrorAction SilentlyContinue
        if ($domainAdmins) {
            Write-Host "Englische Domain Admins Gruppe 'Domain Admins' gefunden" -ForegroundColor Green
            return New-Object System.Security.Principal.SecurityIdentifier $domainAdmins.SID
        }
        
        # Fallback: Suche über Filter (deutsch)
        $domainAdmins = Get-ADGroup -Filter {Name -eq "Domänen-Admins"} -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($domainAdmins) {
            Write-Host "Deutsche Domain Admins Gruppe über Filter gefunden" -ForegroundColor Green
            return New-Object System.Security.Principal.SecurityIdentifier $domainAdmins.SID
        }
        
        # Fallback: Suche über Filter (englisch)
        $domainAdmins = Get-ADGroup -Filter {Name -eq "Domain Admins"} -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($domainAdmins) {
            Write-Host "Englische Domain Admins Gruppe über Filter gefunden" -ForegroundColor Green
            return New-Object System.Security.Principal.SecurityIdentifier $domainAdmins.SID
        }
        
        # Letzter Fallback: Verwende die bekannte SID für Domain Admins
        $domain = Get-ADDomain
        $domainSid = $domain.DomainSID
        $domainAdminsSid = "$domainSid-512"  # Domain Admins haben immer RID 512
        Write-Host "Domain Admins über bekannte SID aufgelöst" -ForegroundColor Yellow
        return New-Object System.Security.Principal.SecurityIdentifier $domainAdminsSid
    }
    catch {
        Write-ErrorMessage -Message "Fehler beim Abrufen der Domain Admins Gruppe (Domänen-Admins/Domain Admins): $_" -Type "Error"
        throw
    }
}

function Get-LocalizedAccountName {
    <#
    .SYNOPSIS
    Ruft den lokalisierten Kontonamen für Well-Known Security Principals ab
    Unterstützt deutsche und englische Lokalisierungen
    
    .PARAMETER WellKnownAccount
    Der Well-Known Account Name (z.B. "Everyone", "Authenticated Users")
    
    .RETURNS
    Lokalisierter Account Name oder SID falls Name nicht aufgelöst werden kann
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$WellKnownAccount
    )
    
    try {
        # Mapping für bekannte Accounts
        $accountMapping = @{
            "Everyone" = @("Jeder", "Everyone", "S-1-1-0")
            "Authenticated Users" = @("Authentifizierte Benutzer", "Authenticated Users", "S-1-5-11") 
            "Users" = @("Benutzer", "Users", "S-1-5-32-545")
            "Administrators" = @("Administratoren", "Administrators", "S-1-5-32-544")
        }
        
        if (-not $accountMapping.ContainsKey($WellKnownAccount)) {
            Write-Host "Warnung: Unbekannter Well-Known Account '$WellKnownAccount'" -ForegroundColor Yellow
            return $WellKnownAccount
        }
        
        $possibleNames = $accountMapping[$WellKnownAccount]
        
        # Versuche jeden möglichen Namen
        foreach ($name in $possibleNames) {
            try {
                # Teste ob der Account aufgelöst werden kann
                if ($name.StartsWith("S-1-")) {
                    # Es ist eine SID - versuche sie direkt zu verwenden
                    $sid = New-Object System.Security.Principal.SecurityIdentifier $name
                    $account = $sid.Translate([System.Security.Principal.NTAccount])
                    Write-Host "Account '$WellKnownAccount' erfolgreich über SID aufgelöst: $($account.Value)" -ForegroundColor Green
                    return $account.Value
                } else {
                    # Es ist ein Name - versuche ihn zu einer SID aufzulösen
                    $ntAccount = New-Object System.Security.Principal.NTAccount $name
                    $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
                    Write-Host "Account '$WellKnownAccount' erfolgreich aufgelöst: $name" -ForegroundColor Green
                    return $name
                }
            }
            catch {
                # Dieser Name funktioniert nicht, versuche den nächsten
                continue
            }
        }
        
        # Fallback: Verwende die SID direkt
        $sidValue = $possibleNames | Where-Object { $_.StartsWith("S-1-") } | Select-Object -First 1
        if ($sidValue) {
            Write-Host "Fallback: Verwende SID für '$WellKnownAccount': $sidValue" -ForegroundColor Yellow
            return $sidValue
        }
        
        # Letzter Fallback: Originaler Name
        Write-Host "Warnung: Konnte '$WellKnownAccount' nicht auflösen, verwende Originalname" -ForegroundColor Yellow
        return $WellKnownAccount
    }
    catch {
        Write-Host "Fehler beim Auflösen von '$WellKnownAccount': $_" -ForegroundColor Red
        return $WellKnownAccount
    }
}