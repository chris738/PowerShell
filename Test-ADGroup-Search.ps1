# Test-ADGroup-Search.ps1
# Tests AD group search functionality, specifically for Global groups

param(
    [Parameter(Mandatory=$false)]
    [string]$GroupName = "DL_Global-FS_RW"
)

Import-Module ActiveDirectory

Write-Host "Testing AD Group Search for: $GroupName" -ForegroundColor Cyan

# Test 1: Search without SearchBase (domain-wide)
Write-Host "1. Searching domain-wide (no SearchBase)..."
$group1 = Get-ADGroup -Filter {Name -eq $GroupName} -ErrorAction SilentlyContinue
if ($group1) {
    Write-Host "   FOUND: $($group1.Name) in $($group1.DistinguishedName)" -ForegroundColor Green
} else {
    Write-Host "   NOT FOUND: Group does not exist in the domain" -ForegroundColor Red
}

# Test 2: Search with specific OUs where Global groups might be
$searchBases = @(
    "OU=Verwaltung,DC=eHH,DC=de",
    "OU=Gruppen,DC=eHH,DC=de",
    "DC=eHH,DC=de"
)

foreach ($searchBase in $searchBases) {
    Write-Host "2. Searching in: $searchBase"
    try {
        $group2 = Get-ADGroup -Filter {Name -eq $GroupName} -SearchBase $searchBase -ErrorAction SilentlyContinue
        if ($group2) {
            Write-Host "   FOUND: $($group2.Name) in $($group2.DistinguishedName)" -ForegroundColor Green
        } else {
            Write-Host "   NOT FOUND in this OU" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   ERROR searching in $searchBase : $_" -ForegroundColor Red
    }
}

# Test 3: Alternative search using Identity
Write-Host "3. Testing search by Identity..."
try {
    $group3 = Get-ADGroup -Identity $GroupName -ErrorAction SilentlyContinue
    if ($group3) {
        Write-Host "   FOUND: $($group3.Name) using Identity parameter" -ForegroundColor Green
    } else {
        Write-Host "   NOT FOUND using Identity parameter" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ERROR using Identity parameter: $_" -ForegroundColor Red
}

Write-Host "Test completed!" -ForegroundColor Cyan