# Project Synchronization Script

The `sync_projects.ps1` script automatically synchronizes your local `D:\Projects` folder with repositories from Gitea (and optionally GitHub).

## Features

- ✅ **Scans existing repos**: Finds all git repositories in `D:\Projects`
- ✅ **Fetches updates**: Gets latest changes from remotes for existing repos
- ✅ **Syncs with Gitea**: Ensures all Gitea repos are cloned locally
- ✅ **Optional GitHub sync**: Can also sync with GitHub repositories
- ✅ **Dry run mode**: Preview changes without making them
- ✅ **Safe pulling**: Only pulls when there are no local changes

## Usage

### Basic Usage (Gitea only)

```powershell
.\sync_projects.ps1
```

### Include GitHub

```powershell
.\sync_projects.ps1 -IncludeGitHub
```

### Pull Changes (in addition to fetch)

```powershell
.\sync_projects.ps1 -PullChanges
```

### Dry Run (preview only)

```powershell
.\sync_projects.ps1 -DryRun
```

### Custom Projects Path

```powershell
.\sync_projects.ps1 -ProjectsPath "C:\MyProjects"
```

### All Options Combined

```powershell
.\sync_projects.ps1 -IncludeGitHub -PullChanges -DryRun
```

## Prerequisites

1. **Gitea Token**: Set your Gitea API token first
   ```powershell
   . .\gitea_helper.ps1
   Get-GiteaToken -Token "your-token-here"
   ```

2. **GitHub CLI** (optional, for GitHub sync):
   ```powershell
   gh auth status  # Should show authenticated
   ```

## What It Does

1. **Scans `D:\Projects`**: Finds all directories containing `.git` folders
2. **Fetches Updates**: For each existing repo, runs `git fetch --all --prune`
3. **Optionally Pulls**: If `-PullChanges` is used, pulls latest changes (only if no local changes)
4. **Checks Gitea**: Gets list of all repositories from your Gitea instance
5. **Clones Missing**: For each Gitea repo not found locally, clones it
6. **Checks GitHub** (if `-IncludeGitHub`): Same process for GitHub repos

## Example Output

```
=== Project Synchronization ===
Projects Path: D:\Projects
Dry Run: False

Scanning for existing git repositories...
  Found: voice-dropbox
  Found: ai-business-agent
  Found: Unity_Snippet_Extraction

Found 3 existing git repositories

=== Fetching Updates ===
Processing: voice-dropbox
  Fetching...
  [OK] Fetched updates
Processing: ai-business-agent
  Fetching...
  [OK] Fetched updates

=== Syncing with Gitea ===
Found 13 repositories in Gitea

  [EXISTS] voice-dropbox
  [EXISTS] ai-business-agent
  [MISSING] google-drive-mcp
    Cloning from: git@gitea:3000:jfinlon/google-drive-mcp.git
    [OK] Cloned successfully
  [MISSING] security-monitor-mcp
    Cloning from: git@gitea:3000:jfinlon/security-monitor-mcp.git
    [OK] Cloned successfully

Summary:
  Existing repos: 3
  Missing repos: 2
  Cloned: 2

=== Synchronization Complete ===
```

## Safety Features

- **Dry Run Mode**: Use `-DryRun` to preview what would happen
- **No Force Pulls**: Won't pull if there are local uncommitted changes
- **Prune on Fetch**: Removes stale remote-tracking branches
- **Error Handling**: Continues processing even if one repo fails

## Scheduling

You can schedule this to run automatically using Windows Task Scheduler:

```powershell
# Create a scheduled task (runs daily at 9 AM)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File D:\Projects\VoiceDropbox\sync_projects.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -TaskName "Sync Projects" -Action $action -Trigger $trigger
```

## Troubleshooting

### Gitea token not found
```powershell
. .\gitea_helper.ps1
Get-GiteaToken -Token "your-token"
```

### GitHub not authenticated
```powershell
gh auth login
```

### Clone fails (SSH key not added)
Add your SSH key to Gitea: http://gitea:3000/user/settings/keys

### Permission errors
Make sure you have write access to `D:\Projects`
