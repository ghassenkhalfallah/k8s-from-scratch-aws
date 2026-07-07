#!/usr/bin/env bash
# check-prereqs.sh — Validate tools and AWS credentials before terraform apply.
# Usage:  bash scripts/check-prereqs.sh

errors=0

ok()   { printf "  \033[32m[OK]\033[0m  %s\n" "$*"; }
fail() { printf "  \033[31m[!!]\033[0m  %s\n" "$*"; errors=$((errors + 1)); }
warn() { printf "  \033[33m[--]\033[0m  %s\n" "$*"; }

echo ""
echo "=== Checking required tools ==="

if command -v terraform &>/dev/null; then
    ver=$(terraform version 2>/dev/null | head -1)
    ok "terraform: $ver"
else
    fail "terraform not found — https://developer.hashicorp.com/terraform/downloads"
fi

if command -v aws &>/dev/null; then
    ver=$(aws --version 2>&1)
    ok "aws-cli: $ver"
else
    fail "aws CLI not found — https://aws.amazon.com/cli/"
fi

if command -v ansible-playbook &>/dev/null; then
    ver=$(ansible --version 2>/dev/null | head -1)
    ok "ansible: $ver"
else
    warn "ansible not found (only needed for the config phase, not terraform)"
fi

if python3 -c "import sys; sys.exit(0)" &>/dev/null 2>&1; then
    ver=$(python3 --version 2>&1)
    ok "python3: $ver"
else
    warn "python3 not found or is a Windows stub (needed by Ansible, not terraform)"
fi

echo ""
echo "=== Checking AWS credentials ==="

key_id="${AWS_ACCESS_KEY_ID:-}"
secret="${AWS_SECRET_ACCESS_KEY:-}"
region="${AWS_DEFAULT_REGION:-}"

if [ -z "$key_id" ]; then
    fail "AWS_ACCESS_KEY_ID not set — run: source scripts/load-env.sh"
elif echo "$key_id" | grep -qi "example"; then
    fail "AWS_ACCESS_KEY_ID still has placeholder value — edit .env"
else
    ok "AWS_ACCESS_KEY_ID: ${key_id:0:4}..."
fi

if [ -z "$secret" ]; then
    fail "AWS_SECRET_ACCESS_KEY not set"
else
    ok "AWS_SECRET_ACCESS_KEY is set"
fi

if [ -z "$region" ]; then
    warn "AWS_DEFAULT_REGION not set — will fall back to terraform variable default (us-east-1)"
else
    ok "AWS_DEFAULT_REGION: $region"
fi

echo ""
echo "=== Live AWS identity check ==="

if [ -z "$key_id" ] || [ -z "$secret" ]; then
    warn "Skipping live AWS check — credentials not set"
elif ! command -v aws &>/dev/null; then
    warn "Skipping live AWS check — aws CLI not installed"
else
    result=$(aws sts get-caller-identity --output text 2>&1)
    if [ $? -eq 0 ]; then
        ok "AWS auth OK:"
        echo "       $result"
    else
        fail "aws sts get-caller-identity failed:"
        echo "       $result"
    fi
fi

echo ""
if [ $errors -gt 0 ]; then
    printf "\033[31m%d error(s) found. Fix them before running terraform apply.\033[0m\n" "$errors"
else
    printf "\033[32mAll checks passed — ready to deploy.\033[0m\n"
fi
echo ""
