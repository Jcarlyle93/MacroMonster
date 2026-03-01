# MacroMonster

**Save, load, and auto-swap between multiple character-specific macro sets with dual spec support for WoW Classic TBC**

A professional macro set management addon for World of Warcraft Classic: The Burning Crusade Anniversary Edition. Instantly switch between different macro configurations and automatically load macros when you change specs.

## Features

- 📋 **Save Multiple Macro Sets** - Store up to 30 character-specific macros per set with unlimited configurations
- 🔄 **Quick Load Switching** - Instantly swap between saved macro sets with a single click
- ⚔️ **Dual Spec Auto-Swap** - Automatically load your assigned macro set when you switch between Primary and Secondary specs
- 📍 **Action Bar Position Preservation** - Your macros remember exactly where they were placed on your action bars
- 🎯 **Smart Macro Management** - Intelligently edit, create, and delete macros to prevent action bar conflicts
- 🔒 **Per-Character Storage** - Each character maintains their own macro sets independently
- 🎨 **Clean UI** - Professional interface that attaches directly to your `/macro` window for easy access

## Installation

1. Download the latest release from [Releases](https://github.com/yourusername/MacroMonster/releases)
2. Extract to `World of Warcraft\_anniversary_\Interface\AddOns\MacroMonster\`
3. Restart World of Warcraft (or `/reload`)
4. Type `/mm` to open the interface

## Usage

### Basic Usage

1. **Create a macro set**: Type a name in the "Save Current Macros as Set:" field and click "Save"
   - This saves your current 30 character macros as a named set
2. **Load a macro set**: Click the "Load" button next to any saved set
   - Your current macros are saved, then the selected set is loaded
3. **Update a macro set**: After editing your active macros, click "Update" on the active set
   - Updates that set with your new macro configuration without loading another set

### Dual Spec Setup

1. Create and configure your first macro set (e.g., "PvE")
2. Switch specs and create a second macro set (e.g., "PvP")
3. In the MacroMonster UI, check "Spec 1" next to your PvE set
4. Check "Spec 2" next to your PvP set
5. When you switch specs in-game, MacroMonster automatically loads your assigned macro set

**Note:** Only one macro set can be assigned per spec.

### Commands

- `/mm` or `/mm show` - Toggle the MacroMonster interface
- `/mm scan` - Debug: Scan and display action bars for macros
- `/mm findframe` - Debug: Find macro-related frames
- `/mm help` - Show help text

## How It Works

### Action Bar Preservation

When you load a macro set, MacroMonster:
1. Saves your current macro positions
2. Edits existing macros by name or creates new ones as needed
3. Restores all macros to their previously saved action bar slots
4. Automatically detects index shifts caused by macro creation/deletion

### Spec Auto-Swap

When you change specs:
1. MacroMonster detects the spec change
2. Looks up which macro set is assigned to that spec
3. Waits 0.5 seconds for WoW's built-in action bar swap
4. Edits your character macros in-place (preserving action bar references)

## Requirements

- **WoW Version**: Classic - The Burning Crusade Anniversary (2.5.1)
- **Macros**: Up to 30 character-specific macros per set
- **Specs**: Requires dual spec (requires level 40+)

## Compatibility

- ✅ WoW Classic: The Burning Crusade Anniversary
- ✅ Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid (all classes)
- ✅ Works alongside other macro addons that don't modify macro storage
- ⚠️ Cannot load macro sets while in combat

## Known Limitations

- Cannot modify macros while in combat (WoW restriction)
- Maximum 18 character macros in original TBC; 30 in Anniversary Edition
- Global macro sets are not supported (character-specific only)
- No import/export between characters yet

## Troubleshooting

### Macros not loading
- Check if you're in combat (cannot modify macros in combat)
- Verify the macro set exists (`/mm scan` to debug)
- Try reloading the UI (`/reload`)

### Action bars empty after switching specs
- Make sure you've loaded a macro set first and positioned macros on action bars
- Switch back to the previous spec to verify action bar references are preserved
- Check SavedVariables for corruption: `WTF/Account/[Account]/[Realm]/[Character]/SavedVariables/MacroMonster.lua`

### Buttons not responding
- Check `/console scriptErrors 1` for Lua errors
- Try `/reload` to refresh the UI
- Verify the addon loaded: `/dump MacroMonster.VERSION`

## Support & Feedback

- Report bugs on [GitHub Issues](https://github.com/yourusername/MacroMonster/issues)
- Suggestions welcome via GitHub Discussions
- Check compatibility with patch notes before updating

## License

MIT License - See [LICENSE](LICENSE) file for details

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history

## Credits

- **Author**: Zyxw - Spineshatter (US)
- Built for WoW Classic: The Burning Crusade Anniversary Edition

---

**Version**: 0.1.0-beta  
**Last Updated**: March 1, 2026
