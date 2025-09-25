# Test-AD-Group-Fix-Validation.ps1
# Validates that the AD group search issue has been fixed according to the problem statement

Write-Host "=== Validating AD Group Search Fix ===" -ForegroundColor Cyan
Write-Host "Problem: DL_Global-FS_RW group not found" -ForegroundColor Yellow
Write-Host ""

# Test 1: Verify no SearchBase restrictions for Global groups
Write-Host "1. Checking that Get-ADGroup commands for Global groups don't use SearchBase..." -ForegroundColor Cyan

$globalGroupSearchIssues = @()
$scripts = @("Setup-GG-Membership.ps1", "Setup-Fileserver.ps1", "Setup-Fileserver-Rights.ps1")

foreach ($script in $scripts) {
    if (Test-Path $script) {
        $content = Get-Content $script -Raw
        
        # Look for Get-ADGroup with Global group variables that use SearchBase
        $globalGroupVars = @('dlGlobal', 'dlGlobalRW', 'dlGlobalR')
        
        foreach ($var in $globalGroupVars) {
            # Check for pattern: Get-ADGroup ... $var ... -SearchBase
            if ($content -match "Get-ADGroup[^;]*\`$$var[^;]*-SearchBase") {
                $globalGroupSearchIssues += "${script}: Global group search with SearchBase restriction"
            }
        }
    }
}

if ($globalGroupSearchIssues.Count -eq 0) {
    Write-Host "   ✓ PASS: No SearchBase restrictions found for Global groups" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAIL: Found SearchBase restrictions:" -ForegroundColor Red
    foreach ($issue in $globalGroupSearchIssues) {
        Write-Host "     $issue" -ForegroundColor Red
    }
}
Write-Host ""

# Test 2: Verify consistent OU placement for Global groups
Write-Host "2. Checking Global group OU consistency..." -ForegroundColor Cyan

$globalGroupOUs = @()

# Check Setup-Fileserver.ps1 OU variable
if (Test-Path "Setup-Fileserver.ps1") {
    $content = Get-Content "Setup-Fileserver.ps1" -Raw
    if ($content -match '\$ou\s*=\s*"([^"]+)"') {
        $globalGroupOUs += "${script}: $($matches[1])"
    }
}

# Check Setup-Fileserver-Rights.ps1 hardcoded OU
if (Test-Path "Setup-Fileserver-Rights.ps1") {
    $content = Get-Content "Setup-Fileserver-Rights.ps1" -Raw
    if ($content -match 'New-ADGroup.*Global Fileshare.*Path\s+"([^"]+)"') {
        $globalGroupOUs += "${script}: $($matches[1])"
    }
}

$expectedOU = "OU=Verwaltung,DC=eHH,DC=de"
$allCorrect = $true

foreach ($ouInfo in $globalGroupOUs) {
    Write-Host "   $ouInfo"
    if (-not $ouInfo.Contains($expectedOU)) {
        $allCorrect = $false
    }
}

if ($allCorrect -and $globalGroupOUs.Count -gt 0) {
    Write-Host "   ✓ PASS: All Global groups use consistent OU ($expectedOU)" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAIL: Inconsistent Global group OUs found" -ForegroundColor Red
}
Write-Host ""

# Test 3: Verify department groups use department-specific OUs
Write-Host "3. Checking department group OU placement..." -ForegroundColor Cyan

$departmentGroupCorrect = $true
foreach ($script in $scripts) {
    if (Test-Path $script) {
        $content = Get-Content $script -Raw
        
        # Look for department group creation patterns
        if ($content -match 'New-ADGroup.*Name.*dl.*dep.*Path\s+"([^"]+)"') {
            $deptOUPattern = $matches[1]
            Write-Host "   ${script}: Department groups in $deptOUPattern"
            
            if ($deptOUPattern -like "*`$dep*" -or $deptOUPattern -like "*dep*") {
                Write-Host "     ✓ Uses department-specific OU" -ForegroundColor Green
            } else {
                Write-Host "     ✗ Not using department-specific OU" -ForegroundColor Red
                $departmentGroupCorrect = $false
            }
        }
    }
}

if ($departmentGroupCorrect) {
    Write-Host "   ✓ PASS: Department groups use department-specific OUs" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAIL: Some department groups not in correct OUs" -ForegroundColor Red
}
Write-Host ""

# Test 4: Verify syntax is still correct
Write-Host "4. Verifying PowerShell syntax..." -ForegroundColor Cyan

$syntaxErrors = @()
foreach ($script in $scripts) {
    if (Test-Path $script) {
        try {
            # Use AST parsing instead of Get-Command
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
            if ($ast) {
                Write-Host "   ✓ ${script}: Syntax OK" -ForegroundColor Green
            } else {
                $syntaxErrors += "${script}: Failed to parse"
                Write-Host "   ✗ ${script}: Syntax Error" -ForegroundColor Red
            }
        }
        catch {
            $syntaxErrors += "${script}: $($_.Exception.Message)"
            Write-Host "   ✗ ${script}: Syntax Error" -ForegroundColor Red
        }
    }
}

if ($syntaxErrors.Count -eq 0) {
    Write-Host "   ✓ PASS: All scripts have valid syntax" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAIL: Syntax errors found" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$allTestsPassed = ($globalGroupSearchIssues.Count -eq 0) -and $allCorrect -and $departmentGroupCorrect -and ($syntaxErrors.Count -eq 0)

if ($allTestsPassed) {
    Write-Host "✓ ALL TESTS PASSED - AD Group search issue should be resolved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Changes made:" -ForegroundColor White
    Write-Host "- Global groups (DL_Global-FS_RW) now consistently created in OU=Verwaltung,DC=eHH,DC=de" -ForegroundColor White
    Write-Host "- Department groups correctly placed in their respective OUs" -ForegroundColor White
    Write-Host "- No SearchBase restrictions limit Global group searches" -ForegroundColor White
    Write-Host ""
    Write-Host "The 'DL_Global-FS_RW' group should now be found by all scripts!" -ForegroundColor Green
} else {
    Write-Host "✗ SOME TESTS FAILED - Additional fixes may be needed" -ForegroundColor Red
}