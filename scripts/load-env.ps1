# load-env.ps1 - Load .env into the current PowerShell session.
# Usage:  . .\scripts\load-env.ps1
#         . .\scripts\load-env.ps1 -EnvFile .env.staging
#
# The leading dot (.) is required so variables are set in the CALLER's scope.

param(
    [string]$EnvFile = ".env"
)

$envPath = Join-Path $PSScriptRoot "..\$EnvFile"

if (-not (Test-Path $envPath)) {
    Write-Error "Env file not found: $envPath`nCopy .env.example to .env and fill in your credentials."
    return
}

$loaded = 0
foreach ($line in Get-Content $envPath) {
    # Skip blank lines and comments
    if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $name  = $Matches[1]
        $value = $Matches[2].Trim()

        # Strip surrounding quotes if present
        if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
            $value = $Matches[1]
        }

        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        $loaded++
    }
}

Write-Host "Loaded $loaded variable(s) from $EnvFile into this session." -ForegroundColor Green

# Sanity-check: warn if the key credentials look like example placeholders
$keyId = $env:AWS_ACCESS_KEY_ID
if ($keyId -like "*EXAMPLE*" -or $keyId -like "*example*") {
    Write-Warning "AWS_ACCESS_KEY_ID still contains 'EXAMPLE' - did you forget to edit .env?"
}
