# Beispiel-Verwendung: Complete-GPO-Setup-XML.ps1
# Vollständiges Setup der drei XML-basierten GPOs
# 
# Dieses Skript demonstriert die Verwendung von Create-ThreeGPOs-XML.ps1 und Link-ThreeGPOs-XML.ps1
# für ein komplettes GPO-Setup in einem Durchgang.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$GlobalSharePath,

    [Parameter(Mandatory=$false)]
    [string]$CsvFile,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "=== VOLLSTÄNDIGES XML-GPO-SETUP ===" -ForegroundColor Cyan
Write-Host "Erstellt und verknüpft drei GPOs für Laufwerkszuordnungen und Taskbar-Anpassungen" -ForegroundColor Gray
Write-Host ""

# Parameter für nachgelagerte Skripte vorbereiten
$scriptParams = @{
    'GlobalSharePath' = $GlobalSharePath
}

if ($CsvFile) {
    $scriptParams['CsvFile'] = $CsvFile
}

if ($WhatIf) {
    $scriptParams['WhatIf'] = $true
}

try {
    Write-Host "Phase 1: GPO-Erstellung" -ForegroundColor Yellow
    Write-Host "=======================" -ForegroundColor Yellow
    
    $createScript = Join-Path $scriptDir "Create-ThreeGPOs-XML.ps1"
    if (Test-Path $createScript) {
        & $createScript @scriptParams
        
        if (-not $WhatIf) {
            Write-Host ""
            Write-Host "✓ GPO-Erstellung erfolgreich abgeschlossen" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
    } else {
        Write-Error "Create-ThreeGPOs-XML.ps1 nicht gefunden in: $scriptDir"
        exit 1
    }

    Write-Host ""
    Write-Host "Phase 2: GPO-Verknüpfung" -ForegroundColor Yellow
    Write-Host "=========================" -ForegroundColor Yellow
    
    $linkScript = Join-Path $scriptDir "Link-ThreeGPOs-XML.ps1"
    if (Test-Path $linkScript) {
        $linkParams = @{}
        if ($CsvFile) {
            $linkParams['CsvFile'] = $CsvFile
        }
        if ($WhatIf) {
            $linkParams['WhatIf'] = $true
        }
        
        & $linkScript @linkParams
        
        if (-not $WhatIf) {
            Write-Host ""
            Write-Host "✓ GPO-Verknüpfung erfolgreich abgeschlossen" -ForegroundColor Green
        }
    } else {
        Write-Error "Link-ThreeGPOs-XML.ps1 nicht gefunden in: $scriptDir"
        exit 1
    }

    Write-Host ""
    Write-Host "=== VOLLSTÄNDIGES SETUP ABGESCHLOSSEN ===" -ForegroundColor Green
    Write-Host ""
    
    if (-not $WhatIf) {
        Write-Host "ERGEBNIS:" -ForegroundColor Cyan
        Write-Host "✓ Drei GPOs erstellt und konfiguriert" -ForegroundColor White
        Write-Host "✓ XML-basierte Drive Mappings eingerichtet" -ForegroundColor White
        Write-Host "✓ Registry-Einstellungen für Suchleiste konfiguriert" -ForegroundColor White
        Write-Host "✓ GPOs mit entsprechenden OUs verknüpft" -ForegroundColor White
        Write-Host ""
        Write-Host "NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
        Write-Host "1. Group Policy Management Console (gpmc.msc) öffnen" -ForegroundColor White
        Write-Host "2. GPO-Konfiguration überprüfen und anpassen" -ForegroundColor White
        Write-Host "3. Testbenutzer für Validierung verwenden" -ForegroundColor White
        Write-Host "4. Group Policy Update: gpupdate /force" -ForegroundColor White
        Write-Host "5. Benutzeranmeldung testen" -ForegroundColor White
    } else {
        Write-Host "WHATIF-MODUS AKTIV: Keine Änderungen wurden vorgenommen" -ForegroundColor Magenta
        Write-Host "Führen Sie das Skript ohne -WhatIf aus, um die Änderungen anzuwenden." -ForegroundColor Yellow
    }

} catch {
    Write-Error "Fehler beim GPO-Setup: $_"
    Write-Host ""
    Write-Host "FEHLERBEHANDLUNG:" -ForegroundColor Red
    Write-Host "1. Überprüfen Sie die Berechtigungen für GPO-Erstellung" -ForegroundColor White
    Write-Host "2. Stellen Sie sicher, dass ActiveDirectory und GroupPolicy Module verfügbar sind" -ForegroundColor White
    Write-Host "3. Kontrollieren Sie die Netzwerkverbindung zum Domain Controller" -ForegroundColor White
    Write-Host "4. Verwenden Sie -WhatIf zum Testen ohne Änderungen" -ForegroundColor White
    exit 1
}