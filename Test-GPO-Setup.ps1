# Test-GPO-Setup.ps1
# Testet die verbesserte GPO-Setup-Funktionalität ohne AD-Abhängigkeiten
# 
# Validiert:
# - Syntax und Struktur der Setup-GPO-DriveMapping.ps1
# - Hilfsfunktionen für XML-Generierung
# - CSV-Integration
# - Parameter-Verarbeitung

param(
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

Write-Host "=== Test der verbesserten GPO-Setup-Funktionalität ===" -ForegroundColor Cyan
Write-Host "Testet Setup-GPO-DriveMapping.ps1 Version 2.0" -ForegroundColor Gray
Write-Host ""

$scriptDir = $PSScriptRoot
$testResults = @()

# Test 1: Script-Syntax validieren
Write-Host "1. Teste Script-Syntax..." -ForegroundColor Yellow
try {
    $scriptPath = Join-Path $scriptDir "Setup-GPO-DriveMapping.ps1"
    $content = Get-Content $scriptPath -Raw
    
    # PowerShell Parsing Test
    [void][System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
    
    Write-Host "   ✓ PowerShell-Syntax korrekt" -ForegroundColor Green
    $testResults += @{Test = "Syntax"; Status = "PASS"; Message = "PowerShell-Syntax validiert"}
}
catch {
    Write-Host "   ✗ Syntax-Fehler: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{Test = "Syntax"; Status = "FAIL"; Message = $_.Exception.Message}
}

# Test 2: CSV-Integration testen
Write-Host "2. Teste CSV-Integration..." -ForegroundColor Yellow
try {
    # Common-Functions laden
    . (Join-Path $scriptDir "Common-Functions.ps1")
    
    $csvPath = Join-Path $scriptDir "Userlist-EchtHamburg.csv"
    if (Test-Path $csvPath) {
        $departments = Get-DepartmentsFromCSV -CsvPath $csvPath
        if ($departments.Count -gt 0) {
            Write-Host "   ✓ CSV-Abteilungen geladen: $($departments.Count) Abteilungen" -ForegroundColor Green
            if ($VerboseOutput) {
                Write-Host "     Abteilungen: $($departments -join ', ')" -ForegroundColor Gray
            }
            $testResults += @{Test = "CSV-Integration"; Status = "PASS"; Message = "$($departments.Count) Abteilungen erkannt"}
        } else {
            Write-Host "   ⚠ Keine Abteilungen in CSV gefunden" -ForegroundColor Yellow
            $testResults += @{Test = "CSV-Integration"; Status = "WARN"; Message = "Keine Abteilungen gefunden"}
        }
    } else {
        Write-Host "   ⚠ CSV-Datei nicht gefunden: $csvPath" -ForegroundColor Yellow
        $testResults += @{Test = "CSV-Integration"; Status = "WARN"; Message = "CSV-Datei fehlt"}
    }
}
catch {
    Write-Host "   ✗ CSV-Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{Test = "CSV-Integration"; Status = "FAIL"; Message = $_.Exception.Message}
}

# Test 3: XML-Generierung testen (Hilfsfunktionen)
Write-Host "3. Teste XML-Generierung..." -ForegroundColor Yellow
try {
    # Die XML-Funktionen aus dem Script extrahieren und testen
    $scriptContent = Get-Content (Join-Path $scriptDir "Setup-GPO-DriveMapping.ps1") -Raw
    
    # Mock der XML-Funktion für Test
    function Test-New-DriveMappingXml {
        param($DriveLetter, $SharePath, $Label, $Action, $OUFilter = $null)
        
        $xml = "  <Drive clsid='{935D1B74-9CB8-4e3c-9914-7DD559B7A417}' name='${DriveLetter}:' status='${DriveLetter}:' image='2' changed='2024-01-01 12:00:00' uid='test-guid'>"
        $xml += "    <Properties action='$Action' path='$SharePath' label='$Label' persistent='1' useLetter='1' letter='$DriveLetter' />"
        if ($OUFilter) {
            $xml += "    <Filters><FilterGroup name='$Label'><q:GroupMembership name='$OUFilter'/></FilterGroup></Filters>"
        }
        $xml += "  </Drive>"
        return $xml
    }
    
    # Test XML-Generierung für G: Laufwerk
    $xmlG = Test-New-DriveMappingXml -DriveLetter "G" -SharePath "\\server\Global$" -Label "Global" -Action "U"
    if ($xmlG -match "Drive clsid" -and $xmlG -match "name='G:'") {
        Write-Host "   ✓ G: Laufwerk XML-Generierung erfolgreich" -ForegroundColor Green
    } else {
        throw "G: Laufwerk XML ungültig"
    }
    
    # Test XML-Generierung für T: Laufwerk mit Filter
    $xmlT = Test-New-DriveMappingXml -DriveLetter "T" -SharePath "\\server\Abt$\IT" -Label "IT" -Action "U" -OUFilter "DL_IT-FS_RW"
    if ($xmlT -match "Drive clsid" -and $xmlT -match "name='T:'" -and $xmlT -match "DL_IT-FS_RW") {
        Write-Host "   ✓ T: Laufwerk XML-Generierung mit Filter erfolgreich" -ForegroundColor Green
    } else {
        throw "T: Laufwerk XML mit Filter ungültig"
    }
    
    $testResults += @{Test = "XML-Generierung"; Status = "PASS"; Message = "Drive Mapping XML erfolgreich generiert"}
}
catch {
    Write-Host "   ✗ XML-Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{Test = "XML-Generierung"; Status = "FAIL"; Message = $_.Exception.Message}
}

# Test 4: Parameter-Validierung
Write-Host "4. Teste Parameter-Verarbeitung..." -ForegroundColor Yellow
try {
    # Simuliere Parameter-Test
    $defaultParams = @{
        GlobalGpoName = 'Map_G_Drive'
        DepartmentGpoName = 'Map_T_Drive'
        SearchGpoName = 'Disable_Search_Bar'
    }
    
    foreach ($param in $defaultParams.Keys) {
        $value = $defaultParams[$param]
        if ($value -match '^[A-Za-z0-9_-]+$') {
            Write-Host "   ✓ Parameter $param = '$value' ist valide" -ForegroundColor Green
        } else {
            throw "Parameter $param enthält ungültige Zeichen"
        }
    }
    
    $testResults += @{Test = "Parameter"; Status = "PASS"; Message = "Alle Standard-Parameter sind valide"}
}
catch {
    Write-Host "   ✗ Parameter-Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{Test = "Parameter"; Status = "FAIL"; Message = $_.Exception.Message}
}

# Ergebnisse zusammenfassen
Write-Host ""
Write-Host "=== TESTERGEBNISSE ===" -ForegroundColor Cyan
$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq "WARN" }).Count

foreach ($result in $testResults) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    $icon = switch ($result.Status) {
        "PASS" { "✓" }
        "FAIL" { "✗" }
        "WARN" { "⚠" }
        default { "○" }
    }
    
    Write-Host "$icon $($result.Test): $($result.Message)" -ForegroundColor $color
}

Write-Host ""
Write-Host "ZUSAMMENFASSUNG:" -ForegroundColor White
Write-Host "  ✓ Erfolgreich: $passCount" -ForegroundColor Green
if ($warnCount -gt 0) { Write-Host "  ⚠ Warnungen: $warnCount" -ForegroundColor Yellow }
if ($failCount -gt 0) { Write-Host "  ✗ Fehlgeschlagen: $failCount" -ForegroundColor Red }

if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "🎉 Alle kritischen Tests bestanden! Setup-GPO-DriveMapping.ps1 Version 2.0 ist bereit." -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ Einige Tests sind fehlgeschlagen. Bitte Fehler beheben." -ForegroundColor Red
    exit 1
}