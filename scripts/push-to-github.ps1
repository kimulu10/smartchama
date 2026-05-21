# Push SmartChama to https://github.com/kimulu10/smartchama (clean history, no secrets)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "Checking for secrets in staged files..."
if (git diff --cached --name-only 2>$null | Select-String -Pattern "adminsdk|\.env$|keystore\.properties") {
    Write-Host "ERROR: Remove secret files from staging before push." -ForegroundColor Red
    exit 1
}

$env:FILTER_BRANCH_SQUELCH_WARNING = "1"
Write-Host "Rewriting history to remove Firebase JSON..."
git stash push -u -m "pre-push-stash" 2>$null
git filter-branch -f --index-filter "git rm --cached --ignore-unmatch mpesa-backend/smart-chama-5ecaf-firebase-adminsdk-fbsvc-467347eff7.json" HEAD 2>&1 | Out-Null
git stash pop 2>$null

Write-Host "Pushing to origin main..."
git push -u origin main --force

Write-Host "Done. Open https://github.com/kimulu10/smartchama/actions to download the APK." -ForegroundColor Green
