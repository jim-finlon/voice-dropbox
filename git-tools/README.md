# Git Tools - Reusable PowerShell Scripts

A collection of reusable PowerShell scripts for managing Git repositories across GitHub and Gitea.

## 📦 Contents

### Scripts

- **`gitea_helper.ps1`** - PowerShell functions for Gitea API operations
  - `Get-GiteaToken` - Manage Gitea API tokens
  - `New-GiteaRepo` - Create new repositories
  - `Get-GiteaRepos` - List repositories
  - `Add-GiteaRemote` - Add Gitea as a remote

- **`sync_projects.ps1`** - Synchronize local projects with remote repositories
  - Scans a directory for git repositories
  - Fetches updates for existing repos
  - Clones missing repositories from Gitea/GitHub
  - Supports dry-run mode

- **`check_project_status.ps1`** - Check repository status across projects
  - Finds uncommitted changes
  - Detects unpushed commits
  - Reports repositories needing attention
  - Optional auto-commit and auto-push

- **`setup_git_access.ps1`** - One-time setup script
  - Configures SSH keys
  - Sets up Git URL rewriting for GitHub
  - Configures Gitea credential helpers
  - Tests connectivity

### Configuration

- **`.gitconfig_additions`** - Git configuration snippets for GitHub and Gitea

### Documentation

- **`README_GIT_SETUP.md`** - Comprehensive setup guide
- **`README_SYNC.md`** - Project synchronization guide
- **`GIT_SETUP_SUMMARY.md`** - Quick reference summary

## 🚀 Usage

### Quick Start

```powershell
# Load Gitea helpers
. .\git-tools\gitea_helper.ps1

# Set your Gitea token
Get-GiteaToken -Token "your-token-here"

# Sync projects
.\git-tools\sync_projects.ps1

# Check project status
.\git-tools\check_project_status.ps1
```

### Setup (One-time)

```powershell
.\git-tools\setup_git_access.ps1
```

## 📋 Requirements

- PowerShell 5.1+ or PowerShell Core 7+
- Git installed and configured
- GitHub CLI (`gh`) - optional, for GitHub sync
- Gitea API token - for Gitea operations

## 🔧 Configuration

### Gitea Token

Set your Gitea API token:

```powershell
. .\git-tools\gitea_helper.ps1
Get-GiteaToken -Token "your-token-here"
```

Token is saved to environment variable `GITEA_TOKEN`.

### Custom Projects Path

All scripts default to `D:\Projects` but can be customized:

```powershell
.\git-tools\sync_projects.ps1 -ProjectsPath "C:\MyProjects"
.\git-tools\check_project_status.ps1 -ProjectsPath "C:\MyProjects"
```

## 📝 Examples

### Sync Projects with Gitea

```powershell
# Dry run first
.\git-tools\sync_projects.ps1 -DryRun

# Actually sync
.\git-tools\sync_projects.ps1

# Include GitHub repos too
.\git-tools\sync_projects.ps1 -IncludeGitHub
```

### Check All Projects

```powershell
# Check status
.\git-tools\check_project_status.ps1

# Auto-commit and push
.\git-tools\check_project_status.ps1 -AutoCommit -AutoPush
```

### Create Gitea Repository

```powershell
. .\git-tools\gitea_helper.ps1
New-GiteaRepo -Name "my-new-repo" -Description "My new repository" -AutoInit
```

## 🗂️ Project Structure

```
git-tools/
├── gitea_helper.ps1          # Gitea API functions
├── sync_projects.ps1          # Project synchronization
├── check_project_status.ps1   # Status checker
├── setup_git_access.ps1       # One-time setup
├── .gitconfig_additions       # Git configuration snippets
├── README.md                  # This file
├── README_GIT_SETUP.md        # Setup guide
├── README_SYNC.md             # Sync guide
└── GIT_SETUP_SUMMARY.md       # Quick reference
```

## 🔄 Moving to Standalone Project

These tools are designed to be easily extracted into a standalone project:

1. Copy the `git-tools` folder to a new location
2. Initialize as a git repository
3. Add a proper project README
4. Optionally create a PowerShell module structure

### Suggested Module Structure

```
GitTools/
├── GitTools.psm1            # Module manifest
├── Public/
│   ├── Gitea-Helpers.ps1    # Gitea functions
│   ├── Sync-Projects.ps1    # Sync script
│   └── Check-Status.ps1     # Status checker
├── Private/
│   └── Helper-Functions.ps1 # Internal helpers
└── README.md
```

## 📄 License

These scripts are provided as-is for personal use. Adapt as needed for your environment.

## 🤝 Contributing

Feel free to adapt these scripts for your own use. Suggestions for improvements welcome!
