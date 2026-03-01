# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0-beta] - 2026-03-01

### Added
- Initial beta release
- Save and load multiple character-specific macro sets
- Dual spec auto-swap functionality
- Smart macro management (edit, create, delete with position preservation)
- Action bar position tracking and restoration
- Clean UI interface attached to /macro window
- Spec assignment checkboxes (one set per spec)
- Automatic spec change detection
- Update button for overwriting active macro sets
- Sound and visual feedback for successful updates
- Comprehensive slash commands (/mm, /mm scan, /mm findframe, /mm help)
- Per-character SavedVariables storage

### Features
- Support for up to 30 character-specific macros per set
- Unlimited macro set storage (per character)
- Automatic position preservation when switching between sets
- Spec-aware macro loading with action bar preservation
- Macro index re-scanning after edits to prevent conflicts
- Database migration support for future versions

### Known Issues
- Cannot modify macros while in combat (WoW API restriction)
- No import/export functionality yet
- No support for global macro sets (character-specific only)

### Technical Details
- Built for WoW Classic: The Burning Crusade Anniversary (Patch 2.5.1)
- Interface Version: 20501
- Language: Lua
- Storage: SavedVariablesPerCharacter
