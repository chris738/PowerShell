# Link-ThreeGPOs-XML.ps1
# Begleitskript für Create-ThreeGPOs-XML.ps1
# Verknüpft die drei erstellten GPOs mit den entsprechenden Organisationseinheiten
#
# Aufruf:
#   .\Link-ThreeGPOs-XML.ps1
#   .\Link-ThreeGPOs-XML.ps1 -CsvFile "alternative.csv"
#

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile,

    [Parameter(Mandatory=$false)]
    [string]$GlobalGpoName = 'XML_Global_G_Drive',

    [Parameter(Mandatory=$false)]
    [string]$DepartmentGpoName = 'XML_Department_T_Drive',

    [Parameter(Mandatory=$false)]
    [string]$SearchGpoName = 'XML_Disable_Search_Bar',

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Module importieren
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
    Write-Host "✓ PowerShell-Module erfolgreich geladen" -ForegroundColor Green
}
catch {
    Write-Warning "Erforderliche Module (ActiveDirectory, GroupPolicy) nicht verfügbar."
    Write-Host "Dieses Skript funktioniert nur auf Windows Servern mit Active Directory." -ForegroundColor Yellow
    if (-not $WhatIf) {
        exit 1
    }
}

# Lade gemeinsame Funktionen
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$commonFunctionsPath = Join-Path $scriptDir "Common-Functions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
    Write-Host "✓ Gemeinsame Funktionen geladen" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== GPO-Verknüpfung für XML-basierte GPOs ===" -ForegroundColor Cyan
Write-Host ""

# CSV-Datei und Abteilungen laden
if (-not $CsvFile -and (Get-Command "Get-DefaultCsvPath" -ErrorAction SilentlyContinue)) {
    $CsvFile = Get-DefaultCsvPath
}

$departments = @()
if ($CsvFile -and (Test-Path $CsvFile) -and (Get-Command "Get-DepartmentsFromCSV" -ErrorAction SilentlyContinue)) {
    $departments = Get-DepartmentsFromCSV -CsvPath $CsvFile
} else {
    $departments = @('Geschäftsführung', 'Bar', 'Events', 'Shop', 'Verwaltung', 'EDV', 'Facility', 'Gast')
    Write-Host "Standard-Abteilungen verwendet: $($departments -join ', ')" -ForegroundColor Yellow
}

# Domain-Informationen
try {
    $domain = Get-ADDomain
    $dcPath = $domain.DistinguishedName
    Write-Host "✓ Domain erkannt: $($domain.DNSRoot)" -ForegroundColor Green
}
catch {
    Write-Error "Active Directory Domain nicht verfügbar: $_"
    if (-not $WhatIf) {
        exit 1
    }
    # WhatIf-Modus: Dummy-Werte verwenden
    $dcPath = "DC=example,DC=local"
}

function New-GPOLink {
    param(
        [string]$GpoName,
        [string]$TargetOU,
        [string]$Description = ""
    )
    
    if ($WhatIf) {
        Write-Host "   [WhatIf] GPO '$GpoName' würde mit '$TargetOU' verknüpft" -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Prüfen ob OU existiert
        $ouExists = Get-ADOrganizationalUnit -Filter {DistinguishedName -eq $TargetOU} -ErrorAction SilentlyContinue
        if (-not $ouExists -and $TargetOU -ne $dcPath) {
            Write-Warning "OU nicht gefunden: $TargetOU"
            return $false
        }
        
        # Prüfen ob GPO existiert
        $gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
        if (-not $gpo) {
            Write-Warning "GPO nicht gefunden: $GpoName"
            return $false
        }
        
        # Prüfen ob Verknüpfung bereits existiert
        $existingLink = Get-GPInheritance -Target $TargetOU -ErrorAction SilentlyContinue | 
                       Where-Object { $_.GpoLinks.DisplayName -eq $GpoName }
        if ($existingLink) {
            Write-Host "   ○ GPO '$GpoName' bereits verknüpft mit: $TargetOU" -ForegroundColor Yellow
            return $true
        }
        
        # Neue Verknüpfung erstellen
        New-GPLink -Name $GpoName -Target $TargetOU -Enforced:$false -LinkEnabled:$true -ErrorAction Stop
        Write-Host "   ✓ GPO '$GpoName' verknüpft mit: $TargetOU" -ForegroundColor Green
        if ($Description) {
            Write-Host "     $Description" -ForegroundColor Gray
        }
        return $true
    }
    catch {
        Write-Error "Fehler beim Verknüpfen der GPO '$GpoName' mit '$TargetOU': $_"
        return $false
    }
}

# Verknüpfungen erstellen
$linkResults = @()

Write-Host "1. Verknüpfe globales Laufwerk GPO..." -ForegroundColor Cyan
$result = New-GPOLink -GpoName $GlobalGpoName -TargetOU $dcPath -Description "Globales G: Laufwerk für alle Benutzer"
$linkResults += @{GPO = $GlobalGpoName; Target = "Domain"; Success = $result}

Write-Host ""
Write-Host "2. Verknüpfe Abteilungslaufwerk GPO..." -ForegroundColor Cyan
foreach ($department in $departments) {
    $ouPath = "OU=$department,$dcPath"
    $result = New-GPOLink -GpoName $DepartmentGpoName -TargetOU $ouPath -Description "T: Laufwerk für Abteilung $department"
    $linkResults += @{GPO = $DepartmentGpoName; Target = $department; Success = $result}
}

Write-Host ""
Write-Host "3. Verknüpfe Suchleisten-GPO..." -ForegroundColor Cyan
$result = New-GPOLink -GpoName $SearchGpoName -TargetOU $dcPath -Description "Taskbar-Suchleiste für alle Benutzer deaktiviert"
$linkResults += @{GPO = $SearchGpoName; Target = "Domain"; Success = $result}

# Ergebnisse anzeigen
Write-Host ""
Write-Host "=== VERKNÜPFUNGSERGEBNISSE ===" -ForegroundColor Green
Write-Host ""

$successfulLinks = ($linkResults | Where-Object { $_.Success -eq $true }).Count
$totalLinks = $linkResults.Count

Write-Host "ERFOLGREICH VERKNÜPFT: $successfulLinks von $totalLinks GPO-Links" -ForegroundColor Green
Write-Host ""

foreach ($result in $linkResults) {
    $status = if ($result.Success) { "✓" } else { "✗" }
    $color = if ($result.Success) { "Green" } else { "Red" }
    Write-Host "$status $($result.GPO) → $($result.Target)" -ForegroundColor $color
}

Write-Host ""
Write-Host "NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
Write-Host "1. Group Policy Management Console (gpmc.msc) öffnen" -ForegroundColor White
Write-Host "2. Sicherheitsfilterung für '$DepartmentGpoName' anpassen" -ForegroundColor White
Write-Host "3. WMI-Filter bei Bedarf hinzufügen" -ForegroundColor White
Write-Host "4. Group Policy Update ausführen: gpupdate /force" -ForegroundColor White
Write-Host ""
Write-Host "=== GPO-VERKNÜPFUNG ABGESCHLOSSEN ===" -ForegroundColor Green

if ($WhatIf) {
    Write-Host ""
    Write-Host "WHATIF-MODUS: Keine Verknüpfungen wurden erstellt" -ForegroundColor Magenta
}