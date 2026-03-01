-- Database.lua: Handles saving and loading macro sets
local AddonName, Addon = ...

-- Initialize the database
function Addon:InitializeDatabase()
    -- Initialize SavedVariables if not exists
    if not MacroMonsterDB then
        MacroMonsterDB = {
            sets = {},
            activeSet = nil,
            setBarStates = {},  -- Stores ENTIRE action bar state for each set
            specAssignments = { primary = nil, secondary = nil },  -- Dual spec auto-swap
            version = Addon.VERSION
        }
        self:Print("Database initialized.")
    end
    
    -- Migrate old data if needed
    if MacroMonsterDB.version ~= Addon.VERSION then
        self:MigrateDatabase()
    end
    
    -- Migrate old setPositions to new setBarStates (for old saves)
    if MacroMonsterDB.setPositions and not MacroMonsterDB.setBarStates then
        MacroMonsterDB.setBarStates = {}
        self:Print("Migrating old position data to new bar state format")
    end
    
    -- Initialize setBarStates if it doesn't exist
    if not MacroMonsterDB.setBarStates then
        MacroMonsterDB.setBarStates = {}
    end
    
    -- Initialize specAssignments if it doesn't exist (for old saves)
    if not MacroMonsterDB.specAssignments then
        MacroMonsterDB.specAssignments = { primary = nil, secondary = nil }
    end
end

-- Migrate database structure if version changed
function Addon:MigrateDatabase()
    -- Future migration logic here
    MacroMonsterDB.version = Addon.VERSION
end

-- Get all saved macro set names
function Addon:GetMacroSetNames()
    local names = {}
    for name, _ in pairs(MacroMonsterDB.sets) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Check if a macro set exists
function Addon:MacroSetExists(setName)
    return MacroMonsterDB.sets[setName] ~= nil
end

-- Get current character-specific macros only
function Addon:GetCurrentCharacterMacros()
    local _, numCharMacros = GetNumMacros()
    local macros = {}
    
    -- Build a map of macro names to their data
    local macrosByName = {}
    for i = 1, numCharMacros do
        local index = 120 + i  -- Character macros start at 121
        local name, icon, body = GetMacroInfo(index)
        if name then
            macrosByName[name] = {
                name = name,
                icon = icon,
                body = body,
                index = index
            }
        end
    end
    
    -- Convert map to array
    for _, macro in pairs(macrosByName) do
        table.insert(macros, macro)
    end
    
    return macros
end

-- Get current action bar positions for all character macros
function Addon:GetMacroActionBarPositions()
    local positions = {}
    
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            local macroName = GetMacroInfo(id)
            if macroName then
                if not positions[macroName] then
                    positions[macroName] = {}
                end
                table.insert(positions[macroName], slot)
            end
        end
    end
    
    return positions
end

-- Capture the ENTIRE action bar state (all skills, items, macros, etc.)
function Addon:CaptureActionBarState()
    local state = {}
    -- Capture all 120 action bar slots
    for slot = 1, 120 do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType then
            state[slot] = {
                type = actionType,
                id = id,
                subType = subType
            }
        end
    end
    return state
end

-- Restore the entire action bar state (simplified - just skip macros)
function Addon:RestoreActionBarState(state)
    if not state then
        self:Print("No action bar state to restore")
        return
    end
    
    self:Print("Note: Action bars are not automatically repositioned (manual placement recommended)")
    return  -- Skip restoration for now - too complex without proper WoW APIs
end

-- Restore macros to their saved action bar positions
function Addon:RestoreMacroPositions(setName)
    if not MacroMonsterDB.setPositions or not MacroMonsterDB.setPositions[setName] then
        self:Print("No saved positions for set '" .. setName .. "'")
        return
    end
    
    local positions = MacroMonsterDB.setPositions[setName]
    self:Print("Restoring macro positions for set '" .. setName .. "'...")
    
    -- Get current macro indices by name
    local macroIndicesByName = {}
    local _, numCharMacros = GetNumMacros()
    for i = 1, numCharMacros do
        local index = 120 + i
        local name = GetMacroInfo(index)
        if name then
            macroIndicesByName[name] = index
        end
    end
    
    local restored = 0
    -- For each saved position
    for macroName, slots in pairs(positions) do
        local macroIndex = macroIndicesByName[macroName]
        if macroIndex then
            for _, slot in ipairs(slots) do
                -- Pick up the macro and place it in the slot
                PickupMacro(macroIndex)
                PlaceAction(slot)
                ClearCursor()
                restored = restored + 1
            end
        end
    end
    
    self:Print("Restored " .. restored .. " macro placements")
end

-- Save current character macros to a named set
function Addon:SaveMacroSet(setName, allowOverwrite)
    setName = string.gsub(setName or "", "^%s*(.-)%s*$", "%1")

    if setName == "" then
        self:PrintError("Set name cannot be empty!")
        return false
    end

    if self:MacroSetExists(setName) and not allowOverwrite then
        self:PrintError("Macro set '" .. setName .. "' already exists! Use Update to overwrite.")
        return false
    end
    
    -- Get current macros
    local macros = self:GetCurrentCharacterMacros()
    
    if #macros == 0 then
        self:PrintError("No character macros found to save!")
        return false
    end
    
    -- Save to database
    MacroMonsterDB.sets[setName] = macros
    MacroMonsterDB.activeSet = setName
    
    -- Also save the action bar positions for this set
    MacroMonsterDB.setPositions[setName] = self:GetMacroActionBarPositions()
    
    if allowOverwrite then
        self:PrintSuccess("Updated set '" .. setName .. "' with " .. #macros .. " character macros")
    else
        self:PrintSuccess("Saved " .. #macros .. " character macros to set '" .. setName .. "'")
    end
    return true
end

-- Load a macro set with full action bar state management
function Addon:LoadMacroSet(setName, skipActionBarRestore)
    if not self:MacroSetExists(setName) then
        self:PrintError("Macro set '" .. setName .. "' does not exist!")
        return false
    end
    
    -- Check if in combat
    if InCombatLockdown() then
        self:PrintError("Cannot load macro set while in combat!")
        return false
    end
    
    local macros = MacroMonsterDB.sets[setName]
    
    -- Delete ALL current character macros
    local _, numCharMacros = GetNumMacros()
    for i = 1, numCharMacros do
        DeleteMacro(121)  -- Always delete from index 121 since indices shift
    end
    
    -- Create all macros from the stored set
    for _, macro in ipairs(macros) do
        local index = CreateMacro(macro.name, macro.icon, macro.body, true)
        if not index then
            self:PrintError("Failed to create macro '" .. macro.name .. "'")
        end
    end
    
    -- Restore macros to their saved action bar positions
    self:RestoreMacroPositions(setName)
    
    -- Update active set
    MacroMonsterDB.activeSet = setName
    self:PrintSuccess("Loaded macro set '" .. setName .. "'!")
    return true
end

-- Delete a macro set
function Addon:DeleteMacroSet(setName)
    if not self:MacroSetExists(setName) then
        self:PrintError("Macro set '" .. setName .. "' does not exist!")
        return false
    end
    
    MacroMonsterDB.sets[setName] = nil
    
    if MacroMonsterDB.activeSet == setName then
        MacroMonsterDB.activeSet = nil
    end
    
    -- Clear spec assignments for this set
    self:UnassignSetFromSpec(setName)
    
    self:PrintSuccess("Deleted macro set '" .. setName .. "'")
    return true
end

-- Clear all character-specific macros
function Addon:ClearCharacterMacros()
    if InCombatLockdown() then
        self:PrintError("Cannot clear macros while in combat!")
        return false
    end
    
    local _, numCharMacros = GetNumMacros()
    
    -- Delete all character macros (from highest index to lowest to avoid index shifting issues)
    for i = 120 + numCharMacros, 121, -1 do
        DeleteMacro(i)
    end
    
    self:PrintSuccess("Cleared " .. numCharMacros .. " character macros. You can now create new ones!")
    return true
end

-- Rename a macro set
function Addon:RenameMacroSet(oldName, newName)
    if not self:MacroSetExists(oldName) then
        self:PrintError("Macro set '" .. oldName .. "' does not exist!")
        return false
    end
    
    if self:MacroSetExists(newName) then
        self:PrintError("Macro set '" .. newName .. "' already exists!")
        return false
    end
    
    MacroMonsterDB.sets[newName] = MacroMonsterDB.sets[oldName]
    MacroMonsterDB.sets[oldName] = nil
    
    if MacroMonsterDB.activeSet == oldName then
        MacroMonsterDB.activeSet = newName
    end
    
    self:PrintSuccess("Renamed macro set '" .. oldName .. "' to '" .. newName .. "'")
    return true
end

-- Get count of macros in a set
function Addon:GetMacroSetCount(setName)
    if not self:MacroSetExists(setName) then
        return 0
    end
    
    return #MacroMonsterDB.sets[setName]
end

-- Get the active set name
function Addon:GetActiveSetName()
    return MacroMonsterDB.activeSet
end

-- Get spec assignment for a set (returns "primary", "secondary", or nil)
function Addon:GetSetSpecAssignment(setName)
    if MacroMonsterDB.specAssignments.primary == setName then
        return "primary"
    elseif MacroMonsterDB.specAssignments.secondary == setName then
        return "secondary"
    end
    return nil
end

-- Assign a set to a spec ("primary" or "secondary")
function Addon:AssignSetToSpec(setName, spec)
    if not self:MacroSetExists(setName) then
        self:PrintError("Macro set '" .. setName .. "' does not exist!")
        return false
    end
    
    if spec ~= "primary" and spec ~= "secondary" then
        self:PrintError("Invalid spec: " .. tostring(spec))
        return false
    end
    
    -- Clear this set from any other spec assignment
    if MacroMonsterDB.specAssignments.primary == setName then
        MacroMonsterDB.specAssignments.primary = nil
    end
    if MacroMonsterDB.specAssignments.secondary == setName then
        MacroMonsterDB.specAssignments.secondary = nil
    end
    
    -- Assign to the new spec
    MacroMonsterDB.specAssignments[spec] = setName
    self:PrintSuccess("Assigned '" .. setName .. "' to " .. spec .. " spec")
    return true
end

-- Unassign a set from its spec
function Addon:UnassignSetFromSpec(setName)
    local changed = false
    if MacroMonsterDB.specAssignments.primary == setName then
        MacroMonsterDB.specAssignments.primary = nil
        changed = true
    end
    if MacroMonsterDB.specAssignments.secondary == setName then
        MacroMonsterDB.specAssignments.secondary = nil
        changed = true
    end
    
    if changed then
        self:Print("Unassigned '" .. setName .. "' from spec")
    end
    return changed
end

-- Get the set assigned to a specific spec
function Addon:GetSpecAssignment(spec)
    if spec == "primary" or spec == 1 then
        return MacroMonsterDB.specAssignments.primary
    elseif spec == "secondary" or spec == 2 then
        return MacroMonsterDB.specAssignments.secondary
    end
    return nil
end
