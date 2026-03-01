# MacroMonster CurseForge Setup Guide

## Publishing to CurseForge

Follow these steps to publish MacroMonster as a beta addon on CurseForge:

### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Name: `MacroMonster`
3. Description: `Save, load, and auto-swap between multiple character-specific macro sets with dual spec support for WoW Classic TBC`
4. Visibility: Public
5. Initialize with README (we've created one)
6. Add .gitignore: Select "Lua" template (we've created one)
7. Add License: MIT

### Step 2: Upload Files to GitHub

```powershell
# From your MacroMonster addon folder
git init
git add .
git commit -m "Initial commit: MacroMonster beta v0.1.0"
git branch -M main
git remote add origin https://github.com/yourusername/MacroMonster.git
git push -u origin main
```

### Step 3: Create CurseForge Project

1. Go to https://www.curseforge.com/wow/addons/create
2. **Project Name**: MacroMonster
3. **Primary Category**: Macro
4. **Game Version**: World of Warcraft (select "Classic - The Burning Crusade Anniversary")
5. **Summary**: Save, load, and auto-swap between multiple character-specific macro sets with dual spec support
6. **Description**: Copy from README.md (or paste the full description from CurseForge editing panel)

### Step 4: Add Project Logo

1. Generate logo (see main README for suggestions)
2. In CurseForge project settings: **Upload Attachment** (256×256px PNG recommended)
3. Set as project avatar

### Step 5: Link GitHub Repository

1. In CurseForge project settings: **Links & Metadata**
2. **Source Code URL**: https://github.com/yourusername/MacroMonster
3. **Documentation URL**: https://github.com/yourusername/MacroMonster#readme

### Step 6: Create Release on CurseForge

1. Go to **Upload File** in your project
2. **File Name**: MacroMonster-0.1.0-beta.zip (or let CurseForge auto-name)
3. **Release Type**: Beta
4. **Game Versions**: 
   - Select "Classic - The Burning Crusade Anniversary (2.5.1)"
5. **Release Notes**:
```
Initial beta release of MacroMonster!

Features:
- Save and load multiple character-specific macro sets
- Dual spec auto-swap functionality
- Smart macro management with position preservation
- Clean UI attached to /macro window

See README for full documentation: https://github.com/yourusername/MacroMonster
```

### Step 7: Auto-Update Setup (Optional but Recommended)

For automatic updates when you tag releases on GitHub:

1. Install CurseForge packaging tools locally:
```powershell
# Install via Curse's CLI tool or use GitHub Actions
# (Instructions for CI/CD setup below)
```

2. **GitHub Actions** (Automatic on Release Tag):
   - Create `.github/workflows/publish.yml` in your repo
   - Add workflow to automatically push releases to CurseForge when you tag

**Example GitHub Actions workflow** (`.github/workflows/publish.yml`):
```yaml
name: Publish to CurseForge

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Publish to CurseForge
        uses: Actions-R-Us/actions-toc-addon-packager@master
        with:
          curse-token: ${{ secrets.CURSEFORGE_TOKEN }}
          addon-id: '000000'  # Replace with your CurseForge project ID
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

**To get your CurseForge Token:**
1. Log into CurseForge
2. Go to Account Settings > API Tokens
3. Create a new token, copy it
4. Add as GitHub Secret: Settings > Secrets > New > Name: `CURSEFORGE_TOKEN`

## Manual File Structure for CurseForge

CurseForge will auto-detect:
- `MacroMonster.toc` - Addon manifest
- `*.lua` files listed in TOC
- Will zip everything automatically

## Version Tagging

When ready to release new versions:

```powershell
# Update version in MacroMonster.toc
# Update CHANGELOG.md
git add .
git commit -m "Version 0.2.0"
git tag v0.2.0
git push origin main --tags
```

CurseForge will automatically create a release from the GitHub tag (if CI/CD configured).

## Testing Before Publishing

1. Create a clean WoW Classic test account
2. Extract addon to `Interface/AddOns/MacroMonster`
3. Launch game, test all features
4. Check for Lua errors: `/console scriptErrors 1`
5. Verify SavedVariables format

## Post-Publish Checklist

- [ ] GitHub repo created and linked
- [ ] CurseForge project created
- [ ] Logo/avatar uploaded
- [ ] First beta release published
- [ ] README visible on both GitHub and CurseForge
- [ ] CHANGELOG available for version history
- [ ] Links work (source code URL, documentation)
- [ ] Support for beta feedback enabled

## Support Resources

- **CurseForge Addon Hub**: https://www.curseforge.com/wow/addons/
- **CurseForge API**: https://docs.curse.com/
- **WoW Addon Development**: https://www.curseforge.com/wow/addons/development

---

**Project ID Needed**: You'll get a numeric project ID from CurseForge after creating the project (visible in project URL).
