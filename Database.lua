-- Database.lua: Handles saving and loading macro sets
local AddonName, Addon = ...

-- Initialize the database
function Addon:InitializeDatabase()
    -- Initialize SavedVariables if not exists
    if not MacroMonsterDB then
        MacroMonsterDB = {
            sets = {},
            activeSet = nil,
            setPositions = {},  -- Stores action bar positions for each set
            specAssignments = { primary = nil, secondary = nil },  -- Dual spec auto-swap
            version = Addon.VERSION
        }
        self:Print("Database initialized.")
    end
    
    -- Migrate old data if needed
    if MacroMonsterDB.version ~= Addon.VERSION then
        self:MigrateDatabase()
    end
    
    -- Initialize setPositions if it doesn't exist (for old saves)
    if not MacroMonsterDB.setPositions then
        MacroMonsterDB.setPositions = {}
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
    
    if allowOverwrite then
        self:PrintSuccess("Updated set '" .. setName .. "' with " .. #macros .. " character macros")
    else
        self:PrintSuccess("Saved " .. #macros .. " character macros to set '" .. setName .. "'")
    end
    return true
end

-- Load a macro set (intelligently edits existing or creates new to preserve action bars)
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
    
    if skipActionBarRestore then
        -- SPEC CHANGE MODE: Only edit existing macros, don't delete/create
        -- This preserves action bar references since we keep macro indices stable
        self:Print("Loading set in spec-change mode (edit-in-place)...")
        
        local currentMacros = self:GetCurrentCharacterMacros()
        local currentMacrosByName = {}
        for _, macro in ipairs(currentMacros) do
            currentMacrosByName[macro.name] = macro.index
        end
        
        -- Edit all macros that exist by name
        local edited = 0
        for _, macro in ipairs(macros) do
            if currentMacrosByName[macro.name] then
                local index = currentMacrosByName[macro.name]
                EditMacro(index, macro.name, macro.icon, macro.body)
                edited = edited + 1
            end
        end
        
        self:Print("Spec-change load: edited " .. edited .. " macros (action bars preserved)")
    else
        -- MANUAL LOAD MODE: Preserve action bar positions
        
        -- FIRST: Save the current macro positions BEFORE we swap them
        if MacroMonsterDB.activeSet then
            MacroMonsterDB.setPositions[MacroMonsterDB.activeSet] = self:GetMacroActionBarPositions()
            self:Print("Saved action bar positions for set '" .. MacroMonsterDB.activeSet .. "'")
        end
        
        -- Get current character macros to match names
        local currentMacros = self:GetCurrentCharacterMacros()
        local currentMacrosByName = {}
        for _, macro in ipairs(currentMacros) do
            currentMacrosByName[macro.name] = macro.index
        end
        
        -- First pass: edit existing macros with matching names
        local processedIndices = {}
        local macroIndicesByName = {}
        for _, macro in ipairs(macros) do
            if currentMacrosByName[macro.name] then
                local index = currentMacrosByName[macro.name]
                EditMacro(index, macro.name, macro.icon, macro.body)
                processedIndices[index] = true
                macroIndicesByName[macro.name] = index
            end
        end
        
        -- Second pass: delete macros that don't match any in the set
        local _, numCharMacros = GetNumMacros()
        for i = 120 + numCharMacros, 121, -1 do
            if not processedIndices[i] then
                DeleteMacro(i)
            end
        end
        
        -- Third pass: create new macros that didn't exist
        for _, macro in ipairs(macros) do
            if not currentMacrosByName[macro.name] then
                local index = CreateMacro(macro.name, macro.icon, macro.body, true)
                if index then
                    macroIndicesByName[macro.name] = index
                else
                    self:PrintError("Failed to create macro '" .. macro.name .. "'")
                end
            end
        end
        
        -- RE-SCAN: Get fresh macro indices because they may have shifted after edits/deletes/creates
        macroIndicesByName = {}
        local _, numCharMacrosAfter = GetNumMacros()
        for i = 1, numCharMacrosAfter do
            local index = 120 + i
            local name = GetMacroInfo(index)
            if name then
                macroIndicesByName[name] = index
            end
        end
        
        -- Fourth pass: restore macros to their saved action bar slots
        if MacroMonsterDB.setPositions[setName] then
            local positions = MacroMonsterDB.setPositions[setName]
            
            self:Print("DEBUG: Restoring positions for set '" .. setName .. "':")
            for macroName, slots in pairs(positions) do
                self:Print("  - " .. macroName .. ": slots " .. table.concat(slots, ","))
            end
            
            -- First, clear all the slots we're about to fill
            for macroName, slots in pairs(positions) do
                for _, slot in ipairs(slots) do
                    PickupAction(slot)
                    ClearCursor()
                end
            end
            
            -- Now place each macro in its saved slots
            for macroName, slots in pairs(positions) do
                if macroIndicesByName[macroName] then
                    local macroIndex = macroIndicesByName[macroName]
                    self:Print("  Placing " .. macroName .. " (index " .. macroIndex .. ") in slots: " .. table.concat(slots, ","))
                    for _, slot in ipairs(slots) do
                        PickupMacro(macroIndex)
                        PlaceAction(slot)
                        ClearCursor()
                    end
                end
            end
            self:Print("Restored action bar positions from previous session")
        else
            self:Print("No saved action bar positions yet - position your macros and switch sets!")
        end
        
        self:PrintSuccess("Loaded macro set '" .. setName .. "'")
    end
    
    MacroMonsterDB.activeSet = setName
    
    self:PrintSuccess("Loaded macro set '" .. setName .. "'")
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
