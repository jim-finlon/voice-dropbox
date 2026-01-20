#!/usr/bin/env pwsh
# Helper functions for Gitea operations
# Provides PowerShell functions for common Gitea operations via API

$GiteaUrl = "http://gitea:3000"
$script:GiteaToken = $env:GITEA_TOKEN

function Get-GiteaToken {
    <#
    .SYNOPSIS
        Get or set Gitea API token
    #>
    param(
        [string]$Token
    )
    
    if ($Token) {
        $script:GiteaToken = $Token
        [Environment]::SetEnvironmentVariable("GITEA_TOKEN", $Token, "User")
        $env:GITEA_TOKEN = $Token
        Write-Host "Gitea token saved to environment variable" -ForegroundColor Green
        return $Token
    } elseif ($script:GiteaToken) {
        Write-Host "Using token from script variable" -ForegroundColor Gray
        return $script:GiteaToken
    } elseif ($env:GITEA_TOKEN) {
        $script:GiteaToken = $env:GITEA_TOKEN
        Write-Host "Using token from environment variable" -ForegroundColor Gray
        return $env:GITEA_TOKEN
    } else {
        Write-Host "No Gitea token found. Set it with:" -ForegroundColor Yellow
        Write-Host "  Get-GiteaToken -Token 'your-token-here'" -ForegroundColor Cyan
        Write-Host "Or create one at: $GiteaUrl/user/settings/applications" -ForegroundColor Cyan
        return $null
    }
}

function New-GiteaRepo {
    <#
    .SYNOPSIS
        Create a new repository in Gitea
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [string]$Description = "",
        [switch]$Private,
        [switch]$AutoInit,
        [string]$Owner = "jim-finlon"
    )
    
    $token = Get-GiteaToken
    if (-not $token) {
        Write-Error "Gitea token not set. Use Get-GiteaToken -Token 'your-token'"
        return
    }
    
    $body = @{
        name = $Name
        description = $Description
        private = $Private.IsPresent
        auto_init = $AutoInit.IsPresent
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "token $token"
        "Content-Type" = "application/json"
    }
    
    $uri = "$GiteaUrl/api/v1/user/repos"
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ErrorAction Stop
        
        Write-Host "[OK] Repository created: $($response.full_name)" -ForegroundColor Green
        Write-Host "  Clone URL: $($response.clone_url)" -ForegroundColor Gray
        Write-Host "  SSH URL: $($response.ssh_url)" -ForegroundColor Gray
        
        return $response
    } catch {
        Write-Error "Failed to create repository: $($_.Exception.Message)"
        return $null
    }
}

function Get-GiteaRepos {
    <#
    .SYNOPSIS
        List repositories in Gitea
    #>
    param(
        [string]$Owner = "jim-finlon"
    )
    
    $token = Get-GiteaToken
    if (-not $token) {
        Write-Error "Gitea token not set. Use Get-GiteaToken -Token 'your-token'"
        return
    }
    
    $headers = @{
        "Authorization" = "token $token"
    }
    
    $uri = "$GiteaUrl/api/v1/user/repos"
    
    try {
        $repos = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
        return $repos
    } catch {
        Write-Error "Failed to list repositories: $($_.Exception.Message)"
        return @()
    }
}

function Add-GiteaRemote {
    <#
    .SYNOPSIS
        Add Gitea as a remote to current Git repository
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepoName,
        
        [string]$RemoteName = "gitea",
        [string]$Owner = "jim-finlon"
    )
    
    $remoteUrl = "http://gitea:3000/$Owner/$RepoName.git"
    git remote add $RemoteName $remoteUrl
    Write-Host "[OK] Added Gitea remote '$RemoteName': $remoteUrl" -ForegroundColor Green
}

Write-Host "Gitea helper functions loaded. Use Get-Help <FunctionName> for details." -ForegroundColor Green
