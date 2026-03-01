-- MacroMonster: Enhanced macro management for WoW TBC Classic
local AddonName, Addon = ...

-- Debug: Check if addon is loading
DEFAULT_CHAT_FRAME:AddMessage("MacroMonster loading... AddonName=" .. tostring(AddonName))

-- Version info
Addon.VERSION = "0.1.0"
Addon.AUTHOR = "Zyxw - Spineshatter"

-- Addon namespace
MacroMonster = Addon

-- Constants
Addon.MAX_CHARACTER_MACROS = 30
Addon.CHAR_MACRO_START_INDEX = 121

-- Create main event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

-- Event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == AddonName then
            Addon:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        Addon:OnPlayerLogin()
    elseif event == "PLAYER_LOGOUT" then
        Addon:OnPlayerLogout()
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        Addon:OnSpecChanged()
    end
end)

-- Initialize addon after it loads
function Addon:OnAddonLoaded()
    -- Initialize database
    self:InitializeDatabase()
    
    print("|cFF00FF00MacroMonster|r v" .. self.VERSION .. " loaded. Type |cFFFFFF00/mm|r for options.")
end

-- Initialize after player logs in
function Addon:OnPlayerLogin()
    -- Create UI
    self:CreateUI()
    
    -- Register slash commands
    self:RegisterSlashCommands()
    
    -- Create a frame to monitor for MacroFrame and hook it
    local hookFrame = CreateFrame("Frame")
    hookFrame:SetScript("OnUpdate", function(self)
        if MacroFrame and not MacroFrame._MacroMonsterHooked then
            Addon:HookMacroFrame()
            self:SetScript("OnUpdate", nil)  -- Stop checking after we hook
        end
    end)
    
    self:Print("Ready! Type /mm to open the interface or use /macro to see both windows.")
end

-- Handle spec changes (dual spec)
function Addon:OnSpecChanged()
    -- Delay checking the spec until WoW has fully switched talent groups
    C_Timer.After(1.0, function()
        local currentSpec = GetActiveTalentGroup()
        local specName = (currentSpec == 1) and "primary" or "secondary"
        local assignedSet = self:GetSpecAssignment(specName)
        
        if assignedSet then
            -- Load the macro set with full action bar state restoration
            if self:LoadMacroSet(assignedSet, false) then  -- false = restore action bars
                if Addon.mainFrame and Addon.mainFrame:IsShown() then
                    self:UpdateUI()
                end
            else
                self:PrintError("Failed to load macro set on spec change!")
            end
        else
            self:Print("Spec changed to " .. specName .. " (no macro set assigned)")
        end
    end)
end

-- Sync MacroMonster height to MacroFrame height
function Addon:SyncMainFrameHeight()
    if not Addon.mainFrame or not MacroFrame then
        return
    end

    local macroFrameHeight = MacroFrame:GetHeight()
    if macroFrameHeight and macroFrameHeight > 0 then
        Addon.mainFrame:SetHeight(macroFrameHeight)
    end
end

-- Position MacroMonster to the right of MacroFrame, accounting for MacroPopupFrame when visible
function Addon:PositionMainFrame()
    if not Addon.mainFrame or not MacroFrame then
        return
    end

    local xOffset = 10

    -- When creating/editing a macro, MacroPopupFrame appears to the right.
    -- Move our window farther right by the popup's actual runtime width.
    if MacroPopupFrame and MacroPopupFrame:IsShown() then
        local popupWidth = MacroPopupFrame:GetWidth() or 0
        if popupWidth <= 0 then
            popupWidth = 320 -- safe fallback if width isn't resolved yet
        end
        xOffset = xOffset + popupWidth + 8
    end

    Addon.mainFrame:ClearAllPoints()
    Addon.mainFrame:SetPoint("TOPLEFT", MacroFrame, "TOPRIGHT", xOffset, 0)
end

-- Hook popup show/hide so MacroMonster repositions when macro editor pops out
function Addon:HookMacroPopupFrame()
    if not MacroPopupFrame or MacroPopupFrame._MacroMonsterHooked then
        return
    end

    MacroPopupFrame._MacroMonsterHooked = true

    hooksecurefunc(MacroPopupFrame, "Show", function()
        if Addon.mainFrame and Addon.mainFrame:IsShown() then
            Addon:PositionMainFrame()
            Addon:SyncMainFrameHeight()
        end
    end)

    hooksecurefunc(MacroPopupFrame, "Hide", function()
        if Addon.mainFrame and Addon.mainFrame:IsShown() then
            Addon:PositionMainFrame()
            Addon:SyncMainFrameHeight()
        end
    end)
end

-- Hook MacroFrame to show/hide MacroMonster automatically
function Addon:HookMacroFrame()
    if not MacroFrame then
        return
    end
    
    -- Mark as hooked to avoid multiple hooks
    MacroFrame._MacroMonsterHooked = true
    
    -- Use hooksecurefunc - most reliable for Classic/TBC
    -- This is a POST-hook, so it fires AFTER MacroFrame's Show/Hide
    hooksecurefunc(MacroFrame, "Show", function()
        if Addon.mainFrame then
            Addon.mainFrame:Show()
            -- Ensure proper positioning to the right of MacroFrame (and popup if visible)
            Addon:PositionMainFrame()
            -- Sync height with MacroFrame - schedule with small delay to ensure frame sizes are finalized
            C_Timer.After(0.1, function()
                if Addon.mainFrame and MacroFrame then
                    Addon:SyncMainFrameHeight()
                    Addon:PositionMainFrame()
                end
            end)
            Addon:UpdateUI()
        end
    end)
    
    hooksecurefunc(MacroFrame, "Hide", function()
        if Addon.mainFrame then
            Addon.mainFrame:Hide()
        end
    end)
    
    -- Sync current state - if MacroFrame is already shown, show MacroMonster
    if MacroFrame:IsShown() then
        if Addon.mainFrame then
            Addon.mainFrame:Show()
            Addon:PositionMainFrame()
            Addon:SyncMainFrameHeight()
            Addon:UpdateUI()
        end
    end

    -- Hook popup now if available, or shortly after if it's created lazily
    Addon:HookMacroPopupFrame()
    C_Timer.After(0.2, function()
        Addon:HookMacroPopupFrame()
    end)
end

-- Register slash commands
function Addon:RegisterSlashCommands()
    DEFAULT_CHAT_FRAME:AddMessage("Registering slash commands...")
    
    SLASH_MACROMONSTER1 = "/mm"
    SLASH_MACROMONSTER2 = "/macromonster"
    
    SlashCmdList["MACROMONSTER"] = function(msg)
        DEFAULT_CHAT_FRAME:AddMessage("Slash command triggered: " .. tostring(msg))
        Addon:HandleSlashCommand(msg)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("Slash commands registered!")
end

-- Handle slash commands
function Addon:HandleSlashCommand(msg)
    -- Trim whitespace manually (string.trim not available in TBC)
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    msg = string.lower(msg)
    
    if msg == "" or msg == "show" then
        self:ToggleUI()
    elseif msg == "scan" then
        self:ScanActionBars()
    elseif msg == "findframe" then
        self:FindMacroFrame()
    elseif msg == "help" then
        self:PrintHelp()
    else
        self:PrintHelp()
    end
end

-- Find macro frame by scanning for it
function Addon:FindMacroFrame()
    self:Print("Scanning for macro-related frames...")
    
    -- Check common frame names
    local frameNames = {
        "MacroFrame",
        "MacroMainFrame", 
        "MacroPopupFrame",
        "MacroFrameTab1",
        "MacroScrollFrame"
    }
    
    for _, name in ipairs(frameNames) do
        local frame = _G[name]
        if frame then
            self:Print("Found frame: " .. name .. " (shown: " .. tostring(frame:IsShown()) .. ")")
        end
    end
    
    -- Try to find frames by searching globals
    self:Print("Searching global _G for 'Macro' frames...")
    local count = 0
    for name, frame in pairs(_G) do
        if type(frame) == "table" and string.find(name, "Macro") and frame.IsShown then
            count = count + 1
            if count <= 20 then
                self:Print("  - " .. name)
            end
        end
    end
    if count > 20 then
        self:Print("  ... and " .. (count - 20) .. " more")
    end
end

-- Scan action bars to debug macro detection
function Addon:ScanActionBars()
    self:Print("Scanning action bars for macros...")
    local found = 0
    for slot = 1, 120 do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "macro" then
            local name = GetMacroInfo(id)
            self:Print("Slot " .. slot .. ": macro id=" .. tostring(id) .. " name=" .. tostring(name))
            found = found + 1
        end
    end
    if found == 0 then
        self:Print("No macros found on action bars!")
    else
        self:Print("Found " .. found .. " macros total")
    end
end

-- Print help text
function Addon:PrintHelp()
    print("|cFF00FF00MacroMonster|r Commands:")
    print("  |cFFFFFF00/mm|r or |cFFFFFF00/mm show|r - Toggle UI")
    print("  |cFFFFFF00/mm scan|r - Scan action bars for macros (debug)")
    print("  |cFFFFFF00/mm findframe|r - Find macro-related frames")
    print("  |cFFFFFF00/mm help|r - Show this help")
end

-- Utility function to print with addon prefix
function Addon:Print(msg, color)
    color = color or "FFFFFF"
    print("|cFF00FF00MacroMonster:|r |cFF" .. color .. msg .. "|r")
end

-- Utility function to print errors
function Addon:PrintError(msg)
    self:Print(msg, "FF0000")
end

-- Utility function to print success messages
function Addon:PrintSuccess(msg)
    self:Print(msg, "00FF00")
end

-- User feedback for successful set update
function Addon:NotifySetUpdated(setName)
    local msg = "Macro List updated"
    if setName and setName ~= "" then
        msg = msg .. ": " .. setName
    end

    -- Center-screen feedback (Classic-safe call signature)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        local ok = pcall(function()
            UIErrorsFrame:AddMessage(msg)
        end)

        if not ok and RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["SYSTEM"] then
            RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["SYSTEM"])
        end
    elseif RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["SYSTEM"] then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["SYSTEM"])
    end

    -- Chat feedback
    self:PrintSuccess(msg)

    -- Equip-like confirmation sound (with safe fallback)
    if PlaySound then
        local ok = pcall(PlaySound, "ITEMGENERICSOUND")
        if not ok then
            pcall(PlaySound, "igMainMenuOptionCheckBoxOn")
        end
    end
end
