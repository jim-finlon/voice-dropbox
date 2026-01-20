#!/usr/bin/env pwsh
# Setup script for GitHub and Gitea access
# Configures Git and authentication for both GitHub and Gitea

Write-Host "=== Git Access Setup ===" -ForegroundColor Cyan

# Check SSH key
$sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
$sshKey = $null
if (Test-Path $sshKeyPath) {
    Write-Host ""
    Write-Host "[OK] SSH key found: $sshKeyPath" -ForegroundColor Green
    $sshKey = Get-Content $sshKeyPath -Raw
    $preview = if ($sshKey.Length -gt 50) { $sshKey.Substring(0, 50) + "..." } else { $sshKey }
    Write-Host "Public key: $preview" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "[!] No SSH key found. Generating new ed25519 key..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -C "jfinlon1@gmail.com" -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
    if (Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub") {
        $sshKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" -Raw
        Write-Host "[OK] New SSH key generated" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to generate SSH key" -ForegroundColor Red
        exit 1
    }
}

# Test GitHub SSH
Write-Host ""
Write-Host "Testing GitHub SSH access..." -ForegroundColor Cyan
$githubTest = ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1
if ($githubTest -match "successfully authenticated") {
    Write-Host "[OK] GitHub SSH access working" -ForegroundColor Green
} else {
    Write-Host "[!] GitHub SSH not configured. Add your SSH key at:" -ForegroundColor Yellow
    Write-Host "  https://github.com/settings/keys" -ForegroundColor Cyan
    if ($sshKey) {
        Write-Host ""
        Write-Host "Your public key:" -ForegroundColor Yellow
        Write-Host $sshKey.Trim() -ForegroundColor White
    }
}

# Configure Git URL rewriting for GitHub SSH
Write-Host ""
Write-Host "Configuring Git URL rewriting for GitHub..." -ForegroundColor Cyan
git config --global url."git@github.com:".insteadOf "https://github.com/"
Write-Host "[OK] GitHub URLs will use SSH" -ForegroundColor Green

# Gitea setup
Write-Host ""
Write-Host "=== Gitea Setup ===" -ForegroundColor Cyan
$giteaUrl = "http://gitea:3000"
Write-Host "Gitea URL: $giteaUrl" -ForegroundColor Gray

# Test Gitea connectivity
Write-Host ""
Write-Host "Testing Gitea connectivity..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "$giteaUrl/api/v1/version" -UseBasicParsing -ErrorAction Stop
    Write-Host "[OK] Gitea is accessible" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot reach Gitea at $giteaUrl" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Check if Gitea SSH is configured
if ($sshKey) {
    Write-Host ""
    Write-Host "For Gitea SSH access:" -ForegroundColor Cyan
    Write-Host "1. Add your SSH key at: $giteaUrl/user/settings/keys" -ForegroundColor Yellow
    Write-Host "2. Your public key:" -ForegroundColor Yellow
    Write-Host $sshKey.Trim() -ForegroundColor White
}

# Configure Git credential helper for Gitea (if using HTTPS)
Write-Host ""
Write-Host "Configuring Git credential helper for Gitea..." -ForegroundColor Cyan
git config --global credential.http://gitea:3000.helper manager
git config --global credential.http://gitea:3000.provider generic
Write-Host "[OK] Gitea credential helper configured" -ForegroundColor Green

# GitHub CLI status
Write-Host ""
Write-Host "=== GitHub CLI Status ===" -ForegroundColor Cyan
gh auth status

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Ensure your SSH key is added to GitHub: https://github.com/settings/keys" -ForegroundColor Yellow
Write-Host "2. Ensure your SSH key is added to Gitea: $giteaUrl/user/settings/keys" -ForegroundColor Yellow
Write-Host "3. For Gitea token-based access, create a token at: $giteaUrl/user/settings/applications" -ForegroundColor Yellow
