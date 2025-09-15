# Test-NetworkShares.ps1
# Testet die neue Setup-NetworkShares.ps1 Funktionalität

Write-Host "Teste Setup-NetworkShares.ps1..." -ForegroundColor Cyan

# Teste ob das Skript existiert
$scriptPath = Join-Path $PSScriptRoot "Setup-NetworkShares.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Host "FEHLER: Setup-NetworkShares.ps1 nicht gefunden!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Script gefunden: $scriptPath" -ForegroundColor Green

# Teste ob Run-All-Scripts.ps1 den neuen Parameter hat
$runAllPath = Join-Path $PSScriptRoot "Run-All-Scripts.ps1"
$runAllContent = Get-Content $runAllPath -Raw
if ($runAllContent -match "SkipNetworkShares") {
    Write-Host "✓ SkipNetworkShares Parameter in Run-All-Scripts.ps1 gefunden" -ForegroundColor Green
} else {
    Write-Host "FEHLER: SkipNetworkShares Parameter nicht in Run-All-Scripts.ps1 gefunden!" -ForegroundColor Red
    exit 1
}

# Teste ob das neue Script in der Scripts-Liste ist
if ($runAllContent -match "Setup-NetworkShares.ps1") {
    Write-Host "✓ Setup-NetworkShares.ps1 in Scripts-Liste gefunden" -ForegroundColor Green
} else {
    Write-Host "FEHLER: Setup-NetworkShares.ps1 nicht in Scripts-Liste gefunden!" -ForegroundColor Red
    exit 1
}

# Zeige die neue Script-Reihenfolge
Write-Host "`nScript-Reihenfolge in Run-All-Scripts.ps1:" -ForegroundColor Yellow
$matches = [regex]::Matches($runAllContent, '@\{Name="([^"]+)\.ps1"[^}]+Description="([^"]+)"\}')
for ($i = 0; $i -lt $matches.Count; $i++) {
    $scriptName = $matches[$i].Groups[1].Value
    $description = $matches[$i].Groups[2].Value
    $order = $i + 1
    Write-Host "  $order. $scriptName.ps1 - $description"
}

Write-Host "`nAlle Tests bestanden! ✓" -ForegroundColor Green