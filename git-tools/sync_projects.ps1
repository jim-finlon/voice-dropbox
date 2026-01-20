#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Synchronize local projects with Gitea repositories
.DESCRIPTION
    - Scans D:\Projects for git repositories and fetches latest changes
    - Checks Gitea for all repositories
    - Clones missing repositories from Gitea
    - Optionally syncs with GitHub as well
#>

param(
    [string]$ProjectsPath = "D:\Projects",
    [switch]$IncludeGitHub,
    [switch]$PullChanges,
    [switch]$DryRun
)

# Load Gitea helper functions
$giteaHelperPath = Join-Path $PSScriptRoot "gitea_helper.ps1"
if (Test-Path $giteaHelperPath) {
    . $giteaHelperPath
} else {
    Write-Host "[WARNING] gitea_helper.ps1 not found at $giteaHelperPath. Gitea sync will be skipped." -ForegroundColor Yellow
}

Write-Host "=== Project Synchronization ===" -ForegroundColor Cyan
Write-Host "Projects Path: $ProjectsPath" -ForegroundColor Gray
Write-Host "Dry Run: $DryRun" -ForegroundColor Gray
Write-Host ""

# Get all git repositories in Projects folder
Write-Host "Scanning for existing git repositories..." -ForegroundColor Cyan
$existingRepos = @{}
$projectDirs = Get-ChildItem -Path $ProjectsPath -Directory -ErrorAction SilentlyContinue

foreach ($dir in $projectDirs) {
    $gitDir = Join-Path $dir.FullName ".git"
    if (Test-Path $gitDir) {
        $remoteUrl = $null
        try {
            Push-Location $dir.FullName
            $remotes = git remote -v 2>$null
            if ($remotes) {
                $originLine = $remotes | Select-String "origin" | Select-Object -First 1
                if ($originLine) {
                    $remoteUrl = ($originLine -split '\s+')[1]
                }
            }
        } catch {
            # Not a valid git repo or git not available
        } finally {
            Pop-Location
        }
        
        if ($remoteUrl) {
            $repoName = $dir.Name
            $existingRepos[$repoName] = @{
                Path = $dir.FullName
                RemoteUrl = $remoteUrl
            }
            Write-Host "  Found: $repoName" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Found $($existingRepos.Count) existing git repositories" -ForegroundColor Green
Write-Host ""

# Fetch updates for existing repos
if ($existingRepos.Count -gt 0) {
    Write-Host "=== Fetching Updates ===" -ForegroundColor Cyan
    foreach ($repoName in $existingRepos.Keys) {
        $repo = $existingRepos[$repoName]
        Write-Host "Processing: $repoName" -ForegroundColor Yellow
        
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would fetch: $repoName" -ForegroundColor Gray
            continue
        }
        
        try {
            Push-Location $repo.Path
            Write-Host "  Fetching..." -ForegroundColor Gray
            $fetchOutput = git fetch --all --prune 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Fetched updates" -ForegroundColor Green
                
                if ($PullChanges) {
                    # Check if there are local changes
                    $status = git status --porcelain
                    if (-not $status) {
                        # No local changes, safe to pull
                        $currentBranch = git rev-parse --abbrev-ref HEAD
                        Write-Host "  Pulling $currentBranch..." -ForegroundColor Gray
                        git pull 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  [OK] Pulled latest changes" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "  [SKIP] Local changes detected, not pulling" -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "  [WARNING] Fetch had issues: $($fetchOutput -join ' ')" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [ERROR] Failed to fetch: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            Pop-Location
        }
    }
    Write-Host ""
}

# Sync with Gitea
if (Test-Path $giteaHelperPath) {
    Write-Host "=== Syncing with Gitea ===" -ForegroundColor Cyan
    
    $token = Get-GiteaToken
    if (-not $token) {
        Write-Host "[SKIP] Gitea token not set. Run: Get-GiteaToken -Token 'your-token'" -ForegroundColor Yellow
    } else {
        try {
            $giteaRepos = Get-GiteaRepos
            Write-Host "Found $($giteaRepos.Count) repositories in Gitea" -ForegroundColor Green
            Write-Host ""
            
            $clonedCount = 0
            $missingCount = 0
            
            foreach ($giteaRepo in $giteaRepos) {
                $repoName = $giteaRepo.name
                $repoPath = Join-Path $ProjectsPath $repoName
                
                if ($existingRepos.ContainsKey($repoName)) {
                    Write-Host "  [EXISTS] $repoName" -ForegroundColor Gray
                } else {
                    $missingCount++
                    Write-Host "  [MISSING] $repoName" -ForegroundColor Yellow
                    
                    if ($DryRun) {
                        Write-Host "    [DRY RUN] Would clone: $($giteaRepo.clone_url)" -ForegroundColor Gray
                        continue
                    }
                    
                    # Determine clone URL (prefer SSH if available)
                    $cloneUrl = $giteaRepo.ssh_url
                    if (-not $cloneUrl) {
                        $cloneUrl = $giteaRepo.clone_url
                    }
                    
                    Write-Host "    Cloning from: $cloneUrl" -ForegroundColor Gray
                    try {
                        git clone $cloneUrl $repoPath 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "    [OK] Cloned successfully" -ForegroundColor Green
                            $clonedCount++
                            
                            # Fetch all branches and refs after cloning
                            Write-Host "    Fetching all branches..." -ForegroundColor Gray
                            Push-Location $repoPath
                            git fetch --all --prune 2>&1 | Out-Null
                            Pop-Location
                            Write-Host "    [OK] Fetched all branches" -ForegroundColor Green
                        } else {
                            Write-Host "    [ERROR] Clone failed" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "    [ERROR] Clone exception: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            
            Write-Host ""
            Write-Host "Summary:" -ForegroundColor Cyan
            Write-Host "  Existing repos: $($existingRepos.Count)" -ForegroundColor Gray
            Write-Host "  Missing repos: $missingCount" -ForegroundColor Gray
            if (-not $DryRun) {
                Write-Host "  Cloned: $clonedCount" -ForegroundColor Green
            }
        } catch {
            Write-Host "[ERROR] Failed to sync with Gitea: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Sync with GitHub (optional)
if ($IncludeGitHub) {
    Write-Host "=== Syncing with GitHub ===" -ForegroundColor Cyan
    
    try {
        $ghRepos = gh repo list --limit 1000 --json name,url,sshUrl 2>$null | ConvertFrom-Json
        Write-Host "Found $($ghRepos.Count) repositories in GitHub" -ForegroundColor Green
        Write-Host ""
        
        $clonedCount = 0
        $missingCount = 0
        
        foreach ($ghRepo in $ghRepos) {
            $repoName = $ghRepo.name
            $repoPath = Join-Path $ProjectsPath $repoName
            
            if ($existingRepos.ContainsKey($repoName)) {
                Write-Host "  [EXISTS] $repoName" -ForegroundColor Gray
            } else {
                $missingCount++
                Write-Host "  [MISSING] $repoName" -ForegroundColor Yellow
                
                if ($DryRun) {
                    Write-Host "    [DRY RUN] Would clone: $($ghRepo.sshUrl)" -ForegroundColor Gray
                    continue
                }
                
                $cloneUrl = $ghRepo.sshUrl
                Write-Host "    Cloning from: $cloneUrl" -ForegroundColor Gray
                try {
                    git clone $cloneUrl $repoPath 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    [OK] Cloned successfully" -ForegroundColor Green
                        $clonedCount++
                        
                        # Fetch all branches and refs after cloning
                        Write-Host "    Fetching all branches..." -ForegroundColor Gray
                        Push-Location $repoPath
                        git fetch --all --prune 2>&1 | Out-Null
                        Pop-Location
                        Write-Host "    [OK] Fetched all branches" -ForegroundColor Green
                    } else {
                        Write-Host "    [ERROR] Clone failed" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "    [ERROR] Clone exception: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        
        Write-Host ""
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host "  Missing repos: $missingCount" -ForegroundColor Gray
        if (-not $DryRun) {
            Write-Host "  Cloned: $clonedCount" -ForegroundColor Green
        }
    } catch {
        Write-Host "[ERROR] Failed to sync with GitHub: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Make sure GitHub CLI is authenticated: gh auth status" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "=== Synchronization Complete ===" -ForegroundColor Green
