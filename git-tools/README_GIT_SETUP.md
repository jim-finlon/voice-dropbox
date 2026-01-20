# Git Access Setup Guide

This guide helps you set up seamless access to both GitHub and Gitea.

## Current Status

✅ **GitHub CLI**: Authenticated as `jim-finlon`  
✅ **SSH Key**: ed25519 key exists and works with GitHub  
✅ **Gitea**: Accessible at http://gitea:3000  

## Quick Setup

Run the setup script to configure everything:

```powershell
.\setup_git_access.ps1
```

## Manual Setup

### 1. GitHub Access

GitHub CLI is already authenticated. To use SSH for Git operations:

```powershell
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

This makes all GitHub URLs use SSH automatically.

### 2. Gitea Access

#### Option A: SSH (Recommended)

1. Copy your SSH public key:
   ```powershell
   Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard
   ```

2. Add it to Gitea:
   - Go to: http://gitea:3000/user/settings/keys
   - Paste your public key
   - Save

3. Clone repositories using SSH:
   ```powershell
   git clone git@gitea:3000:jim-finlon/repo-name.git
   ```

#### Option B: Token-based (HTTPS)

1. Create a token:
   - Go to: http://gitea:3000/user/settings/applications
   - Generate new token with `repo` scope
   - Copy the token

2. Use the token:
   ```powershell
   git clone http://gitea:3000/jim-finlon/repo-name.git
   # When prompted, use your username and the token as password
   ```

3. Or configure credential helper:
   ```powershell
   git config --global credential.http://gitea:3000.helper manager
   ```

### 3. Gitea Helper Script

Load the helper functions:

```powershell
. .\gitea_helper.ps1
```

Then use:

```powershell
# Set your token (one time)
Get-GiteaToken -Token "your-gitea-token-here"

# Create a new repository
New-GiteaRepo -Name "my-repo" -Description "My new repo" -AutoInit

# List your repositories
Get-GiteaRepos

# Add Gitea as a remote to current repo
Add-GiteaRemote -RepoName "my-repo"
```

## Testing Access

### Test GitHub SSH:
```powershell
ssh -T git@github.com
# Should see: Hi jim-finlon! You've successfully authenticated...
```

### Test Gitea:
```powershell
# Test API access
Invoke-WebRequest -Uri "http://gitea:3000/api/v1/version" -UseBasicParsing

# Test SSH (if configured)
ssh -T git@gitea:3000
```

## Common Operations

### Push to both GitHub and Gitea:

```powershell
# Add Gitea as a remote
git remote add gitea http://gitea:3000/jim-finlon/voice-dropbox.git

# Push to both
git push origin main
git push gitea main
```

### Or use multiple push URLs:

```powershell
git remote set-url --add --push origin git@github.com:jim-finlon/voice-dropbox.git
git remote set-url --add --push origin git@gitea:3000:jim-finlon/voice-dropbox.git

# Then a single push goes to both
git push origin main
```

## Troubleshooting

### GitHub SSH not working:
1. Check if key is added: https://github.com/settings/keys
2. Test: `ssh -T git@github.com`

### Gitea access issues:
1. Verify Gitea is accessible: `Invoke-WebRequest http://gitea:3000/api/v1/version`
2. Check token permissions if using HTTPS
3. Verify SSH key is added in Gitea settings

### Credential issues:
- Windows Credential Manager: `control /name Microsoft.CredentialManager`
- Clear cached credentials if needed
