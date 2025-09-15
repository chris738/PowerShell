# Test-Global-Group-Consistency.ps1
# Tests that Global groups are created consistently across scripts

Write-Host "Testing Global Group Creation Consistency..." -ForegroundColor Cyan

# Test 1: Check Setup-Fileserver.ps1 for Global group OU
Write-Host "1. Checking Setup-Fileserver.ps1 Global group creation..."
$setupFileserverContent = Get-Content "Setup-Fileserver.ps1" -Raw

# Check the $ou variable definition
if ($setupFileserverContent -match '\$ou\s*=\s*"([^"]+)"') {
    $ouVariable = $matches[1]
    Write-Host "   OU variable in Setup-Fileserver.ps1: $ouVariable"
    if ($ouVariable -eq "OU=Verwaltung,DC=eHH,DC=de") {
        Write-Host "   ✓ Correct OU variable for Global groups" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Incorrect OU variable: $ouVariable" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Could not find OU variable definition" -ForegroundColor Red
}

# Check that Global group creation uses $ou variable
if ($setupFileserverContent -match 'New-ADGroup.*Name.*dlGlobal.*Path\s+\$ou') {
    Write-Host "   ✓ Global group creation uses OU variable" -ForegroundColor Green
} else {
    Write-Host "   ✗ Global group creation doesn't use OU variable" -ForegroundColor Red
}

# Test 2: Check Setup-Fileserver-Rights.ps1 for Global group OU
Write-Host "2. Checking Setup-Fileserver-Rights.ps1 Global group creation..."
$setupRightsContent = Get-Content "Setup-Fileserver-Rights.ps1" -Raw
if ($setupRightsContent -match 'New-ADGroup.*Name.*grp.*Path\s+"([^"]+)".*Global Fileshare') {
    $globalGroupOU2 = $matches[1]
    Write-Host "   Global group OU in Setup-Fileserver-Rights.ps1: $globalGroupOU2"
    if ($globalGroupOU2 -eq "OU=Verwaltung,DC=eHH,DC=de") {
        Write-Host "   ✓ Correct OU for Global groups" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Incorrect OU for Global groups: $globalGroupOU2" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Could not find Global group creation pattern" -ForegroundColor Red
}

# Test 3: Check that department groups are created in correct OUs
Write-Host "3. Checking department group creation OUs..."
$departmentGroupPattern = 'New-ADGroup.*Name.*dlGroup.*Path\s+"([^"]+)"'
if ($setupFileserverContent -match $departmentGroupPattern) {
    $deptGroupOU = $matches[1]
    Write-Host "   Department group OU in Setup-Fileserver.ps1: $deptGroupOU"
    if ($deptGroupOU -like "OU=*dep*" -or $deptGroupOU -eq "OU=`$dep,DC=eHH,DC=de") {
        Write-Host "   ✓ Department groups use department-specific OU" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Department groups not using department-specific OU: $deptGroupOU" -ForegroundColor Red
    }
}

# Test 4: Check that Get-ADGroup commands for Global groups don't use SearchBase
Write-Host "4. Checking Global group searches don't use SearchBase..."
$globalGroupSearches = @()
$allScripts = Get-ChildItem "*.ps1" | Where-Object { $_.Name -ne "Test-Global-Group-Consistency.ps1" }

foreach ($script in $allScripts) {
    $content = Get-Content $script.Name -Raw
    # Look for Get-ADGroup commands with Global group variables
    if ($content -match 'Get-ADGroup[^}]*dlGlobal[^}]*SearchBase') {
        $globalGroupSearches += "$($script.Name): Found SearchBase with Global group"
        Write-Host "   ✗ $($script.Name): Global group search uses SearchBase" -ForegroundColor Red
    }
}

if ($globalGroupSearches.Count -eq 0) {
    Write-Host "   ✓ No Global group searches use SearchBase" -ForegroundColor Green
} else {
    foreach ($search in $globalGroupSearches) {
        Write-Host "   $search" -ForegroundColor Red
    }
}

Write-Host "Consistency test completed!" -ForegroundColor Cyan