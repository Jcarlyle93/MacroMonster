# MacroMonster - World of Warcraft Classic AddOn

## Project Overview
MacroMonster is a WoW Classic Anniversary (TBC) AddOn for enhanced macro management. Currently targeting The Burning Crusade Classic (patch 2.5.1).

### Core Feature: Macro Set Switching
Allows players to save and switch between multiple sets of character-specific macros (18 max in TBC). Use case: Warrior with separate PvE tanking and PvP macro sets.

**Workflow:**
1. Player creates 18 character macros for PvE
2. Clicks "Save Set" → stores to SavedVariables as "PvE" set
3. Creates 18 new PvP macros
4. Clicks "Save Set" → stores as "PvP" set
5. Clicks "Load Set: PvE" → deletes current macros, recreates PvE macros from storage

**Initial Implementation:** Focus on Warrior class, expand to other classes later.

## Essential WoW AddOn Structure

### Required Files
- `MacroMonster.toc` - Table of Contents file listing all Lua/XML files and metadata (Title, Author, Version, Interface version)
- Lua files must be listed in load order in the .toc file
- SavedVariables declared in .toc persist between sessions

### Core Architecture Pattern
```lua
-- Namespace pattern to avoid global pollution
local AddonName, Addon = ...
Addon.VERSION = "1.0.0"

-- Event-driven system
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == AddonName then
        Addon:Initialize()
    end
end)
```

## WoW API Conventions

### Key Lifecycle Events
- `ADDON_LOADED` - Initialize addon after TOC loads
- `PLAYER_LOGIN` - User data available, start main functionality
- `PLAYER_LOGOUT` - Save state before exit

### UI Creation
- Use `CreateFrame()` for UI elements - XML optional but Lua is more common
- Anchor frames with `:SetPoint(anchor, relativeTo, relativeAnchor, x, y)`
- TBC Classic has more limited UI APIs compared to retail - avoid Modern WoW-only features
- Ace2 libraries common in TBC era, but Ace3 is compatible

### Data Persistence
```lua
-- In .toc file:
-- ## SavedVariablesPerCharacter: MacroMonsterDB

-- Data structure for macro sets:
MacroMonsterDB = MacroMonsterDB or {
    sets = {
        ["PvE"] = {
            { name = "Charge", icon = 132337, body = "/cast Charge" },
            { name = "Execute", icon = 135358, body = "/cast Execute" },
            -- ... up to 18 macros
        },
        ["PvP"] = {
            -- Another set of up to 18 macros
        }
    },
    activeSet = "PvE"
}
```

### Macro Set Management Architecture
```lua
-- Save current character macros to a named set
function Addon:SaveCurrentMacrosToSet(setName)
    local _, numCharMacros = GetNumMacros()
    local macros = {}
    for i = 37, 36 + numCharMacros do -- Char macros are indices 37-54
        local name, icon, body = GetMacroInfo(i)
        if name then
            table.insert(macros, {name = name, icon = icon, body = body})
        end
    end
    MacroMonsterDB.sets[setName] = macros
end

-- Load a macro set (delete current, create stored)
function Addon:LoadMacroSet(setName)
    -- Delete all character macros (indices 37+)
    local _, numCharMacros = GetNumMacros()
    for i = 1, numCharMacros do
        DeleteMacro(37) -- Always delete first char macro
    end
    
    -- Recreate from stored set
    local macros = MacroMonsterDB.sets[setName]
    for _, macro in ipairs(macros) do
        CreateMacro(macro.name, macro.icon, macro.body, true) -- true = per character
    end
end
```

## Macro-Specific WoW API

### Critical Functions
- `GetNumMacros()` - Returns `(numGlobal, numCharacter)` - global macros (1-36), character macros (37-54)
- `GetMacroInfo(index)` - Returns `(name, icon, body)` for macro at index
- `CreateMacro(name, icon, body, perCharacter)` - Creates macro (perCharacter=true for char-specific)
- `EditMacro(index, name, icon, body)` - Modify existing macro
- `DeleteMacro(index)` - Remove macro (indices shift down after deletion)

### Macro Limitations
- **18 character-specific macros max** (indices 37-54)
- 36 general macros max (indices 1-36)
- 255 character limit per macro body
- Use `/run` for Lua code or conditional logic in macros
- Secure commands (combat actions) restricted - cannot call in combat

### Macro Icon IDs
- Icons are numeric IDs (e.g., 132337 for Charge)
- Use `GetMacroInfo()` to capture existing icons when saving sets
- Icons can be found via `/dump GetMacroItemIcons()` or online databases

## Development Workflow

### Testing
1. Place addon in `Interface/AddOns/MacroMonster/`
2. Launch WoW and check `/console scriptErrors 1` for errors
3. Use `/reload` to reload UI after code changes
4. Check errors with `/dump MacroMonster` or BugSack addon

### Debugging
- Use `print()` or `/dump` command to output to chat
- `DevTool` addon for inspecting tables (if available for TBC Classic)
- Check `WoW/_anniversary_/Logs/` for Lua errors (Classic Anniversary folder)

### Interface Version
Update `## Interface: 20501` in .toc for TBC Classic Anniversary patch 2.5.1

## Code Style

### Naming
- PascalCase for addon functions: `Addon:CreateMacroFrame()`
- camelCase for local functions: `local function buildMacroList()`
- UPPER_CASE for constants: `local MAX_MACROS = 36`

### Error Handling
```lua
local success, result = pcall(CreateMacro, name, icon, body)
if not success then
    print("|cFFFF0000MacroMonster:|r " .. result)
end
```

## External Dependencies
- Avoid external libraries unless necessary - WoW API is comprehensive
- If using Ace3, vendor it in `Libs/` folder and reference in .toc
- Check for library conflicts with `_G` namespace inspection
