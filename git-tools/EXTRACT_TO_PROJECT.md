# Extracting git-tools as Standalone Project

This folder contains reusable Git management scripts that can be extracted into a standalone project.

## Quick Extract Steps

1. **Copy the folder:**
   ```powershell
   Copy-Item "D:\Projects\VoiceDropbox\git-tools" "D:\Projects\GitTools" -Recurse
   ```

2. **Initialize as git repository:**
   ```powershell
   cd D:\Projects\GitTools
   git init
   git add .
   git commit -m "Initial commit: Git management tools"
   ```

3. **Create remote repositories:**
   ```powershell
   # Gitea
   . .\gitea_helper.ps1
   New-GiteaRepo -Name "git-tools" -Description "Reusable Git management scripts" -AutoInit
   
   # GitHub
   gh repo create git-tools --public --source=. --remote=origin
   ```

4. **Push to remotes:**
   ```powershell
   git remote add gitea http://gitea:3000/jfinlon/git-tools.git
   git push -u origin main
   git push -u gitea main
   ```

## Optional: Convert to PowerShell Module

To make it a proper PowerShell module:

1. **Create module structure:**
   ```
   GitTools/
   ├── GitTools.psd1          # Module manifest
   ├── GitTools.psm1          # Module file
   ├── Public/
   │   ├── Gitea-Helpers.ps1
   │   ├── Sync-Projects.ps1
   │   └── Check-Status.ps1
   └── Private/
       └── Helper-Functions.ps1
   ```

2. **Create GitTools.psd1:**
   ```powershell
   @{
       ModuleVersion = '1.0.0'
       RootModule = 'GitTools.psm1'
       FunctionsToExport = @(
           'Get-GiteaToken',
           'New-GiteaRepo',
           'Get-GiteaRepos',
           'Add-GiteaRemote'
       )
       ScriptsToProcess = @(
           'Public\Gitea-Helpers.ps1',
           'Public\Sync-Projects.ps1',
           'Public\Check-Status.ps1'
       )
   }
   ```

3. **Install locally:**
   ```powershell
   Copy-Item GitTools $env:PSModulePath.Split(';')[0]\GitTools -Recurse
   Import-Module GitTools
   ```

## Current Contents

- ✅ 4 PowerShell scripts (fully functional)
- ✅ 4 documentation files
- ✅ 1 configuration file (.gitconfig_additions)
- ✅ Self-contained (no external dependencies beyond Git/GitHub CLI)

## Usage After Extract

```powershell
# From new location
cd D:\Projects\GitTools

# Load helpers
. .\gitea_helper.ps1

# Use scripts
.\sync_projects.ps1
.\check_project_status.ps1
```
