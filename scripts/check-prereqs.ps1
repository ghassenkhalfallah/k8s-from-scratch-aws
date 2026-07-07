# check-prereqs.ps1 — Validate that all required tools and credentials are
# present before attempting terraform apply.
# Usage:  .\scripts\check-prereqs.ps1

$errors = 0

function Test-Command($cmd) {
    return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Ok($msg)   { Write-Host "  [OK]  $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  [!!]  $msg" -ForegroundColor Red;   $script:errors++ }
function Warn($msg) { Write-Host "  [--]  $msg" -ForegroundColor Yellow }

Write-Host "`nChecking required tools..." -ForegroundColor Cyan

if (Test-Command terraform) { Ok  "terraform $(terraform version -json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version)" }
else                         { Fail "terraform not found — https://developer.hashicorp.com/terraform/downloads" }

if (Test-Command aws)        { Ok  "aws-cli $(aws --version 2>&1)" }
else                         { Fail "aws CLI not found — https://aws.amazon.com/cli/" }

if (Test-Command ansible-playbook) { Ok  "ansible $(ansible --version | Select-Object -First 1)" }
else                               { Warn "ansible not found — only needed for the configuration phase, not terraform" }

if (Test-Command python3 -or Test-Command python) { Ok "python available" }
else                                               { Warn "python not found — needed by Ansible" }

Write-Host "`nChecking AWS credentials..." -ForegroundColor Cyan

$keyId  = $env:AWS_ACCESS_KEY_ID
$secret = $env:AWS_SECRET_ACCESS_KEY
$region = $env:AWS_DEFAULT_REGION

if ([string]::IsNullOrEmpty($keyId))  { Fail "AWS_ACCESS_KEY_ID is not set. Run: . .\scripts\load-env.ps1" }
elseif ($keyId -like "*EXAMPLE*")     { Fail "AWS_ACCESS_KEY_ID still has placeholder value — edit .env" }
else                                  { Ok  "AWS_ACCESS_KEY_ID is set (${keyId.Substring(0,4)}...)" }

if ([string]::IsNullOrEmpty($secret)) { Fail "AWS_SECRET_ACCESS_KEY is not set" }
else                                  { Ok  "AWS_SECRET_ACCESS_KEY is set" }

if ([string]::IsNullOrEmpty($region)) { Warn "AWS_DEFAULT_REGION not set — terraform will use variable default (us-east-1)" }
else                                  { Ok  "AWS_DEFAULT_REGION = $region" }

if ($errors -eq 0) {
    # Try a live AWS call to confirm credentials are valid
    Write-Host "`nVerifying credentials with AWS STS..." -ForegroundColor Cyan
    try {
        $identity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
        Ok "Authenticated as: $($identity.Arn)"
        Ok "Account ID:       $($identity.Account)"
    } catch {
        Fail "aws sts get-caller-identity failed — credentials may be invalid or expired"
    }
}

Write-Host ""
if ($errors -gt 0) {
    Write-Host "$errors error(s) found. Fix them before running terraform apply." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All checks passed. You are ready to deploy." -ForegroundColor Green
}
