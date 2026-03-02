-- Database.lua: Handles saving and loading macro sets
local AddonName, Addon = ...

-- Initialize the database
function Addon:InitializeDatabase()
    -- Initialize SavedVariables if not exists
    if not MacroMonsterDB then
        MacroMonsterDB = {
            sets = {},
            activeSet = nil,
            setPositions = {},  -- Stores macro action bar slots by set
            setSlotMap = {},    -- Stores slot->macroName mapping by set
            specAssignments = { primary = nil, secondary = nil },  -- Dual spec auto-swap
            version = Addon.VERSION
        }
        self:Print("Database initialized.")
    end
    
    -- Migrate old data if needed
    if MacroMonsterDB.version ~= Addon.VERSION then
        self:MigrateDatabase()
    end
    
    -- Initialize setPositions if it doesn't exist
    if not MacroMonsterDB.setPositions then
        MacroMonsterDB.setPositions = {}
    end

    -- Initialize setSlotMap if it doesn't exist
    if not MacroMonsterDB.setSlotMap then
        MacroMonsterDB.setSlotMap = {}
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

-- Count entries in a table
function Addon:CountTableEntries(tbl)
    local count = 0
    if tbl then
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
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
    
    -- Scan main action bars (1-120) plus bonus bars for stances/forms (121-132)
    for slot = 1, 132 do
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

-- Get current slot->macroName mapping for all macro actions on bars
function Addon:GetCurrentMacroSlotMap()
    local slotMap = {}
    -- Scan main action bars (1-120) plus bonus bars for stances/forms (121-132)
    for slot = 1, 132 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            local macroName = GetMacroInfo(id)
            if macroName then
                slotMap[slot] = macroName
            end
        end
    end
    return slotMap
end

-- Count macros that have at least one saved slot
function Addon:GetSavedPositionMacroCount(positions)
    if not positions then
        return 0
    end

    local count = 0
    for _, slots in pairs(positions) do
        if slots and #slots > 0 then
            count = count + 1
        end
    end
    return count
end

-- Merge newly captured positions into existing positions.
-- This avoids wiping good data when a transient snapshot is sparse.
function Addon:MergeMacroPositions(existingPositions, newPositions)
    local merged = {}

    if existingPositions then
        for macroName, slots in pairs(existingPositions) do
            merged[macroName] = slots
        end
    end

    if newPositions then
        for macroName, slots in pairs(newPositions) do
            if slots and #slots > 0 then
                merged[macroName] = slots
            end
        end
    end

    return merged
end

-- Restore macros to their saved action bar positions.
function Addon:RestoreMacroPositions(setName)
    local slotMap = MacroMonsterDB.setSlotMap and MacroMonsterDB.setSlotMap[setName]

    -- Backward compatibility: build slot map from legacy name->slots data
    if (not slotMap or next(slotMap) == nil) and MacroMonsterDB.setPositions and MacroMonsterDB.setPositions[setName] then
        slotMap = {}
        for macroName, slots in pairs(MacroMonsterDB.setPositions[setName]) do
            if type(slots) == "table" then
                for _, slot in ipairs(slots) do
                    if not slotMap[slot] then
                        slotMap[slot] = macroName
                    end
                end
            end
        end
    end

    if not slotMap or next(slotMap) == nil then
        return false
    end

    -- Resolve current macro indices by name (both global and character)
    local macroIndicesByName = {}
    local numGlobalMacros, numCharMacros = GetNumMacros()
    
    -- Scan global macros (indices 1-36)
    for i = 1, numGlobalMacros do
        local name = GetMacroInfo(i)
        if name then
            macroIndicesByName[name] = i
        end
    end
    
    -- Scan character macros (indices 121+)
    for i = 1, numCharMacros do
        local index = 120 + i
        local name = GetMacroInfo(index)
        if name then
            macroIndicesByName[name] = index
        end
    end

    -- Build valid placements first (non-destructive)
    local placements = {}
    local missingCount = 0
    local skippedCount = 0
    for slot, macroName in pairs(slotMap) do
        local macroIndex = macroIndicesByName[macroName]
        if macroIndex then
            table.insert(placements, { slot = slot, macroIndex = macroIndex })
        else
            -- Check if this is an item/spell instead of a macro (from legacy data)
            local actionType, id = GetActionInfo(slot)
            if actionType == "macro" then
                missingCount = missingCount + 1
                if missingCount <= 3 then
                    self:Print("  ✗ Macro '" .. macroName .. "' not found for slot " .. slot)
                end
            else
                skippedCount = skippedCount + 1
                if skippedCount <= 2 then
                    self:Print("  ⊘ Skipping non-macro '" .. macroName .. "' in slot " .. slot .. " (type: " .. (actionType or "empty") .. ")")
                end
            end
        end
    end
    
    if missingCount > 3 then
        self:Print("  ... and " .. (missingCount - 3) .. " more missing macros")
    end
    if skippedCount > 2 then
        self:Print("  ... and " .. (skippedCount - 2) .. " more non-macros")
    end

    if #placements == 0 then
        self:Print("ERROR: No valid placements found for set '" .. setName .. "'")
        return false
    end

    self:Print("Restoring " .. #placements .. " macro placements (skipped " .. skippedCount .. " non-macros, " .. missingCount .. " missing)...")

    -- Clear only slots that we can refill
    for _, placement in ipairs(placements) do
        PickupAction(placement.slot)
        ClearCursor()
    end

    for _, placement in ipairs(placements) do
        PickupMacro(placement.macroIndex)
        PlaceAction(placement.slot)
        ClearCursor()
    end

    return true
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
    MacroMonsterDB.setSlotMap[setName] = self:GetCurrentMacroSlotMap()
    
    if allowOverwrite then
        self:PrintSuccess("Updated set '" .. setName .. "' with " .. #macros .. " character macros")
    else
        self:PrintSuccess("Saved " .. #macros .. " character macros to set '" .. setName .. "'")
    end
    return true
end

-- Snapshot current live macros and bar mappings into an existing set
function Addon:SnapshotSetState(setName)
    if not setName or not MacroMonsterDB.sets[setName] then
        return false
    end

    local liveMacros = self:GetCurrentCharacterMacros()
    if #liveMacros == 0 then
        return false
    end

    local slotMap = self:GetCurrentMacroSlotMap()

    MacroMonsterDB.sets[setName] = liveMacros
    MacroMonsterDB.setSlotMap[setName] = slotMap

    local existingPositions = MacroMonsterDB.setPositions[setName]
    local capturedPositions = self:GetMacroActionBarPositions()
    local existingCount = self:GetSavedPositionMacroCount(existingPositions)
    local capturedCount = self:GetSavedPositionMacroCount(capturedPositions)

    -- Avoid wiping good position data with a sparse capture.
    if existingCount > 0 and capturedCount < existingCount then
        MacroMonsterDB.setPositions[setName] = self:MergeMacroPositions(existingPositions, capturedPositions)
    else
        MacroMonsterDB.setPositions[setName] = capturedPositions
    end

    return true
end

-- Load a macro set with full action bar state management
function Addon:LoadMacroSet(setName, skipActionBarRestore)
    -- Kept for API compatibility with older calls.
    local _ = skipActionBarRestore

    if not self:MacroSetExists(setName) then
        self:PrintError("Macro set '" .. setName .. "' does not exist!")
        return false
    end
    
    -- Check if in combat
    if InCombatLockdown() then
        self:PrintError("Cannot load macro set while in combat!")
        return false
    end
    
    -- Signal to event handlers that we're loading a set (prevent auto-snapshot race conditions)
    MacroMonster:SetLoadingSet(true)
    
    local macros = MacroMonsterDB.sets[setName]

    -- Note: auto-snapshot now happens immediately in OnSpecChanged before bars are cleared,
    -- so we don't need to snapshot the previous set here anymore.
    
    -- Delete ALL current character macros
    local _, numCharMacros = GetNumMacros()
    
    -- Delete ALL current character macros
    for i = 1, numCharMacros do
        DeleteMacro(121)  -- Always delete from index 121 since indices shift
    end
    
    -- Create all macros from the stored set
    for i, macro in ipairs(macros) do
        local index = CreateMacro(macro.name, macro.icon, macro.body, true)
        if not index then
            self:PrintError("Failed to create macro '" .. macro.name .. "'")
        end
    end
    
    -- Restore macros to their saved action bar positions
    -- Use a small delay to let WoW's internal systems fully settle after set load
    C_Timer.After(0.5, function()
        self:RestoreMacroPositions(setName)
    end)
    
    -- Update active set
    MacroMonsterDB.activeSet = setName
    self:PrintSuccess("Loaded macro set '" .. setName .. "'!")
    
    -- Signal that we're done loading (allow auto-snapshots again)
    MacroMonster:SetLoadingSet(false)
    
    return true
end

-- Delete a macro set
function Addon:DeleteMacroSet(setName)
    if not self:MacroSetExists(setName) then
        self:PrintError("Macro set '" .. setName .. "' does not exist!")
        return false
    end
    
    MacroMonsterDB.sets[setName] = nil
    MacroMonsterDB.setPositions[setName] = nil
    MacroMonsterDB.setSlotMap[setName] = nil
    
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

    MacroMonsterDB.setPositions[newName] = MacroMonsterDB.setPositions[oldName]
    MacroMonsterDB.setPositions[oldName] = nil

    MacroMonsterDB.setSlotMap[newName] = MacroMonsterDB.setSlotMap[oldName]
    MacroMonsterDB.setSlotMap[oldName] = nil
    
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
