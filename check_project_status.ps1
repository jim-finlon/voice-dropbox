#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Check all projects in D:\Projects for uncommitted changes and unpushed commits
.DESCRIPTION
    Scans all git repositories and reports which ones have:
    - Uncommitted changes
    - Unpushed commits to origin/main
    - No origin/main branch
#>

param(
    [string]$ProjectsPath = "D:\Projects",
    [switch]$AutoCommit,
    [switch]$AutoPush
)

Write-Host "=== Project Status Check ===" -ForegroundColor Cyan
Write-Host "Projects Path: $ProjectsPath" -ForegroundColor Gray
Write-Host ""

# Get all git repositories
$repos = @()
$projectDirs = Get-ChildItem -Path $ProjectsPath -Directory -ErrorAction SilentlyContinue

Write-Host "Scanning for git repositories..." -ForegroundColor Cyan
foreach ($dir in $projectDirs) {
    $gitDir = Join-Path $dir.FullName ".git"
    if (Test-Path $gitDir) {
        $repos += @{
            Name = $dir.Name
            Path = $dir.FullName
        }
    }
}

Write-Host "Found $($repos.Count) git repositories" -ForegroundColor Green
Write-Host ""

# Check each repository
$issues = @()
$cleanRepos = @()

foreach ($repo in $repos) {
    Write-Host "Checking: $($repo.Name)" -ForegroundColor Yellow
    
    Push-Location $repo.Path
    
    $repoIssues = @()
    $hasUncommitted = $false
    $hasUnpushed = $false
    $noOriginMain = $false
    
    try {
        # Check for uncommitted changes
        $status = git status --porcelain 2>&1
        if ($status -and $LASTEXITCODE -eq 0) {
            $hasUncommitted = $true
            $repoIssues += "Uncommitted changes"
        }
        
        # Check if origin/main exists
        $originMain = git ls-remote --heads origin main 2>&1
        $hasOriginMain = ($originMain -match "refs/heads/main")
        
        if (-not $hasOriginMain) {
            # Check for master branch
            $originMaster = git ls-remote --heads origin master 2>&1
            $hasOriginMaster = ($originMaster -match "refs/heads/master")
            
            if ($hasOriginMaster) {
                # Check unpushed commits to master
                git fetch origin master 2>&1 | Out-Null
                $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
                if ($currentBranch -eq "master") {
                    $localCommit = git rev-parse HEAD 2>&1
                    $remoteCommit = git rev-parse origin/master 2>&1
                    if ($localCommit -ne $remoteCommit) {
                        $ahead = git rev-list --count origin/master..HEAD 2>&1
                        if ([int]$ahead -gt 0) {
                            $hasUnpushed = $true
                            $repoIssues += "Unpushed commits to origin/master ($ahead ahead)"
                        }
                    }
                }
            } else {
                $noOriginMain = $true
                $repoIssues += "No origin/main or origin/master branch"
            }
        } else {
            # Check unpushed commits to main
            git fetch origin main 2>&1 | Out-Null
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
            
            # Check if we're on main or if main exists locally
            $localMain = git rev-parse --verify main 2>&1
            if ($LASTEXITCODE -eq 0) {
                $localCommit = git rev-parse main 2>&1
                $remoteCommit = git rev-parse origin/main 2>&1
                if ($localCommit -ne $remoteCommit) {
                    $ahead = git rev-list --count origin/main..main 2>&1
                    if ([int]$ahead -gt 0) {
                        $hasUnpushed = $true
                        $repoIssues += "Unpushed commits to origin/main ($ahead ahead)"
                    }
                }
            } elseif ($currentBranch -eq "main") {
                $localCommit = git rev-parse HEAD 2>&1
                $remoteCommit = git rev-parse origin/main 2>&1
                if ($localCommit -ne $remoteCommit) {
                    $ahead = git rev-list --count origin/main..HEAD 2>&1
                    if ([int]$ahead -gt 0) {
                        $hasUnpushed = $true
                        $repoIssues += "Unpushed commits to origin/main ($ahead ahead)"
                    }
                }
            }
        }
        
        if ($repoIssues.Count -gt 0) {
            $issues += @{
                Name = $repo.Name
                Path = $repo.Path
                Issues = $repoIssues
                HasUncommitted = $hasUncommitted
                HasUnpushed = $hasUnpushed
                NoOriginMain = $noOriginMain
            }
            Write-Host "  [ISSUES] $($repoIssues -join ', ')" -ForegroundColor Red
        } else {
            $cleanRepos += $repo.Name
            Write-Host "  [OK] Clean and synced" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        $issues += @{
            Name = $repo.Name
            Path = $repo.Path
            Issues = @("Error checking repository: $($_.Exception.Message)")
            HasUncommitted = $false
            HasUnpushed = $false
            NoOriginMain = $false
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total repositories: $($repos.Count)" -ForegroundColor Gray
Write-Host "Clean repositories: $($cleanRepos.Count)" -ForegroundColor Green
Write-Host "Repositories with issues: $($issues.Count)" -ForegroundColor $(if ($issues.Count -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($issues.Count -gt 0) {
    Write-Host "=== Repositories Needing Attention ===" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($issue in $issues) {
        Write-Host "Repository: $($issue.Name)" -ForegroundColor Cyan
        Write-Host "  Path: $($issue.Path)" -ForegroundColor Gray
        foreach ($problem in $issue.Issues) {
            Write-Host "  - $problem" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($AutoCommit -or $AutoPush) {
        Write-Host "=== Auto-Fixing Issues ===" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($issue in $issues) {
            Write-Host "Processing: $($issue.Name)" -ForegroundColor Yellow
            Push-Location $issue.Path
            
            try {
                if ($issue.HasUncommitted -and $AutoCommit) {
                    Write-Host "  Committing changes..." -ForegroundColor Gray
                    git add -A 2>&1 | Out-Null
                    $commitMsg = "Auto-commit: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                    git commit -m $commitMsg 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  [OK] Committed" -ForegroundColor Green
                    } else {
                        Write-Host "  [SKIP] Nothing to commit or commit failed" -ForegroundColor Yellow
                    }
                }
                
                if ($issue.HasUnpushed -and $AutoPush) {
                    Write-Host "  Pushing to origin..." -ForegroundColor Gray
                    $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
                    $originMain = git ls-remote --heads origin main 2>&1
                    $hasOriginMain = ($originMain -match "refs/heads/main")
                    
                    if ($hasOriginMain) {
                        if ($currentBranch -ne "main") {
                            git checkout main 2>&1 | Out-Null
                        }
                        git push origin main 2>&1 | Out-Null
                    } else {
                        # Try master
                        $originMaster = git ls-remote --heads origin master 2>&1
                        $hasOriginMaster = ($originMaster -match "refs/heads/master")
                        if ($hasOriginMaster) {
                            if ($currentBranch -ne "master") {
                                git checkout master 2>&1 | Out-Null
                            }
                            git push origin master 2>&1 | Out-Null
                        }
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  [OK] Pushed" -ForegroundColor Green
                    } else {
                        Write-Host "  [ERROR] Push failed" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
            } finally {
                Pop-Location
            }
            Write-Host ""
        }
    }
} else {
    Write-Host "All repositories are clean and synced!" -ForegroundColor Green
}
