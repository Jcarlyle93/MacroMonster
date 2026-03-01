-- UI.lua: User interface for managing macro sets
local AddonName, Addon = ...

-- Constants
local MIN_FRAME_HEIGHT = 280
local MAX_FRAME_HEIGHT = 800
local LIST_TOP_OFFSET = 210
local LIST_BOTTOM_OFFSET = 20

-- Create the main UI frame
function Addon:CreateUI()
    if Addon.mainFrame then
        return
    end
    
    -- Main frame
    local mainFrame = CreateFrame("Frame", "MacroMonsterFrame", UIParent)
    mainFrame:SetWidth(380)
    
    -- Temporary default until we sync to MacroFrame height
    mainFrame:SetHeight(520)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetFrameLevel(100)
    
    -- Store on Addon table so it's accessible everywhere
    Addon.mainFrame = mainFrame
    
    -- Dedicated backdrop layer
    local backdropLayer = CreateFrame("Frame", nil, mainFrame)
    backdropLayer:SetPoint("TOPLEFT", 0, 0)
    backdropLayer:SetPoint("BOTTOMRIGHT", 0, 0)
    backdropLayer:SetFrameLevel(mainFrame:GetFrameLevel())

    -- Background
    local bg = backdropLayer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(backdropLayer)
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0.04, 0.04, 0.04, 0.9)

    -- Gold border
    local borderTop = backdropLayer:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(2)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetTexture("Interface\\Buttons\\WHITE8x8")
    borderTop:SetVertexColor(0.95, 0.78, 0.25, 0.95)

    local borderBottom = backdropLayer:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(2)
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    borderBottom:SetVertexColor(0.95, 0.78, 0.25, 0.95)

    local borderLeft = backdropLayer:CreateTexture(nil, "BORDER")
    borderLeft:SetWidth(2)
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    borderLeft:SetVertexColor(0.95, 0.78, 0.25, 0.95)

    local borderRight = backdropLayer:CreateTexture(nil, "BORDER")
    borderRight:SetWidth(2)
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    borderRight:SetVertexColor(0.95, 0.78, 0.25, 0.95)
    
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetScript("OnHide", function(self)
        if self.setNameInput then
            self.setNameInput:SetText("")
            self.setNameInput:ClearFocus()
        end
    end)
    mainFrame:Hide()
    
    table.insert(UISpecialFrames, "MacroMonsterFrame")
    
    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -20)
    title:SetText("MacroMonster")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    
    -- Current macros info
    local infoText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", 10, -50)
    infoText:SetText("Character Macros: 0/30")
    mainFrame.infoText = infoText
    
    -- Active set display
    local activeSetText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    activeSetText:SetPoint("TOPLEFT", 10, -70)
    activeSetText:SetText("Active Set: None")
    activeSetText:SetTextColor(0.2, 1, 0.2)
    mainFrame.activeSetText = activeSetText
    
    -- Create Blank Macro List button
    local newSetButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    newSetButton:SetWidth(170)
    newSetButton:SetHeight(24)
    newSetButton:SetPoint("TOPLEFT", 10, -95)
    newSetButton:SetText("Create Blank Macro List")
    newSetButton:SetScript("OnClick", function()
        StaticPopup_Show("MACROMONSTER_NEW_SET")
    end)
    
    -- Save new set section
    local saveLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveLabel:SetPoint("TOPLEFT", 10, -130)
    saveLabel:SetText("Save Current Macros as Set:")
    
    -- Set name input box
    local setNameInput = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    setNameInput:SetWidth(200)
    setNameInput:SetHeight(20)
    setNameInput:SetPoint("TOPLEFT", 10, -155)
    setNameInput:SetAutoFocus(false)
    setNameInput:SetMaxLetters(30)
    mainFrame.setNameInput = setNameInput
    
    -- Save button (no Update button in this section)
    local saveButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    saveButton:SetWidth(70)
    saveButton:SetHeight(22)
    saveButton:SetPoint("LEFT", setNameInput, "RIGHT", 5, 0)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        Addon:OnSaveButtonClicked(false)
    end)
    
    -- Macro sets list label
    local listLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 10, -190)
    listLabel:SetText("Saved Macro Sets:")
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "MacroMonsterScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -LIST_TOP_OFFSET)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, LIST_BOTTOM_OFFSET)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(330)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild
    mainFrame.scrollFrame = scrollFrame
    mainFrame.scrollBar = _G["MacroMonsterScrollFrameScrollBar"]
    
    -- Initial update
    self:UpdateUI()
end

-- Toggle UI visibility
function Addon:ToggleUI()
    if not Addon.mainFrame then
        self:CreateUI()
    end
    
    if Addon.mainFrame:IsShown() then
        Addon.mainFrame:Hide()
    else
        self:UpdateUI()
        Addon.mainFrame:Show()
    end
end

-- Show UI
function Addon:ShowUI()
    if not Addon.mainFrame then
        self:CreateUI()
    end
    
    self:UpdateUI()
    Addon.mainFrame:Show()
end

-- Hide UI
function Addon:HideUI()
    if Addon.mainFrame then
        Addon.mainFrame:Hide()
    end
end

-- Update UI with current data
function Addon:UpdateUI()
    if not Addon.mainFrame then
        return
    end
    
    -- Update current macro count (character-specific only)
    local _, numCharMacros = GetNumMacros()
    Addon.mainFrame.infoText:SetText("Character Macros: " .. numCharMacros .. "/" .. Addon.MAX_CHARACTER_MACROS)
    
    -- Update active set
    local activeSet = self:GetActiveSetName()
    if activeSet then
        Addon.mainFrame.activeSetText:SetText("Active Set: " .. activeSet)
    else
        Addon.mainFrame.activeSetText:SetText("Active Set: None")
    end
    
    -- Rebuild set list
    self:BuildSetList()
end

-- Build the list of macro sets
function Addon:BuildSetList()
    -- Clear existing buttons
    local scrollChild = Addon.mainFrame.scrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local setNames = self:GetMacroSetNames()
    local yOffset = 0
    
    for i, setName in ipairs(setNames) do
        local setFrame = self:CreateSetFrame(scrollChild, setName, yOffset)
        yOffset = yOffset - 50
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(1, #setNames * 50))
    self:UpdateLayout(#setNames)
end

-- Adjust frame height and scrollbar visibility based on content
function Addon:UpdateLayout(setCount)
    if not Addon.mainFrame then
        return
    end

    setCount = setCount or #self:GetMacroSetNames()
    local listContentHeight = math.max(1, setCount * 50)
    local frameHeight = Addon.mainFrame:GetHeight()
    if not frameHeight or frameHeight <= 0 then
        local desiredHeight = LIST_TOP_OFFSET + listContentHeight + LIST_BOTTOM_OFFSET
        frameHeight = math.max(MIN_FRAME_HEIGHT, math.min(MAX_FRAME_HEIGHT, desiredHeight))
        Addon.mainFrame:SetHeight(frameHeight)
    end

    local visibleListHeight = frameHeight - LIST_TOP_OFFSET - LIST_BOTTOM_OFFSET
    local needsScroll = listContentHeight > visibleListHeight

    if Addon.mainFrame.scrollBar then
        if needsScroll then
            Addon.mainFrame.scrollBar:Show()
            Addon.mainFrame.scrollFrame:ClearAllPoints()
            Addon.mainFrame.scrollFrame:SetPoint("TOPLEFT", 10, -LIST_TOP_OFFSET)
            Addon.mainFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -40, LIST_BOTTOM_OFFSET)
        else
            Addon.mainFrame.scrollBar:Hide()
            Addon.mainFrame.scrollFrame:ClearAllPoints()
            Addon.mainFrame.scrollFrame:SetPoint("TOPLEFT", 10, -LIST_TOP_OFFSET)
            Addon.mainFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -18, LIST_BOTTOM_OFFSET)
            Addon.mainFrame.scrollFrame:SetVerticalScroll(0)
        end
    end
end

-- Create a frame for a macro set
function Addon:CreateSetFrame(parent, setName, yOffset)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(330)
    frame:SetHeight(45)
    frame:SetPoint("TOPLEFT", 5, yOffset)
    
    -- Check if this is the active set
    local isActive = (Addon:GetActiveSetName() == setName)
    
    -- Background texture - highlight if active
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    if isActive then
        bg:SetTexture(0.2, 0.4, 0.2, 0.8)  -- Green highlight for active set
    else
        bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    end
    
    -- Set name
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", 35, -8)
    if isActive then
        nameText:SetTextColor(0.2, 1, 0.2)  -- Green text for active
        nameText:SetText(setName .. " (ACTIVE)")
    else
        nameText:SetText(setName)
    end
    
    -- Macro count
    local count = self:GetMacroSetCount(setName)
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOPLEFT", 35, -23)
    countText:SetText(count .. " macros")
    
    -- Spec assignment checkboxes (Primary and Secondary)
    local specAssignment = self:GetSetSpecAssignment(setName)
    
    -- Check if other sets are assigned to each spec (for greyout)
    local primaryAssignedToOther = false
    local secondaryAssignedToOther = false
    for _, otherSetName in ipairs(self:GetMacroSetNames()) do
        if otherSetName ~= setName then
            local otherAssignment = self:GetSetSpecAssignment(otherSetName)
            if otherAssignment == "primary" then
                primaryAssignedToOther = true
            elseif otherAssignment == "secondary" then
                secondaryAssignedToOther = true
            end
        end
    end
    
    -- Primary spec checkbox
    local primaryCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    primaryCheck:SetSize(20, 20)
    primaryCheck:SetPoint("TOPLEFT", 180, -8)
    primaryCheck:SetChecked(specAssignment == "primary")
    -- Disable if another set has this spec (unless this set already has it)
    primaryCheck:SetEnabled(not (primaryAssignedToOther and specAssignment ~= "primary"))
    primaryCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            Addon:AssignSetToSpec(setName, "primary")
        else
            Addon:UnassignSetFromSpec(setName)
        end
        Addon:UpdateUI()
    end)
    
    local primaryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    primaryLabel:SetPoint("LEFT", primaryCheck, "RIGHT", 2, 0)
    if primaryAssignedToOther and specAssignment ~= "primary" then
        primaryLabel:SetTextColor(0.5, 0.5, 0.5)  -- Grey text when disabled
    end
    primaryLabel:SetText("Spec 1")
    
    -- Secondary spec checkbox
    local secondaryCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    secondaryCheck:SetSize(20, 20)
    secondaryCheck:SetPoint("TOPLEFT", 180, -23)
    secondaryCheck:SetChecked(specAssignment == "secondary")
    -- Disable if another set has this spec (unless this set already has it)
    secondaryCheck:SetEnabled(not (secondaryAssignedToOther and specAssignment ~= "secondary"))
    secondaryCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            Addon:AssignSetToSpec(setName, "secondary")
        else
            Addon:UnassignSetFromSpec(setName)
        end
        Addon:UpdateUI()
    end)
    
    local secondaryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    secondaryLabel:SetPoint("LEFT", secondaryCheck, "RIGHT", 2, 0)
    if secondaryAssignedToOther and specAssignment ~= "secondary" then
        secondaryLabel:SetTextColor(0.5, 0.5, 0.5)  -- Grey text when disabled
    end
    secondaryLabel:SetText("Spec 2")
    
    -- Load button (vertical stack on right side)
    local loadButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    loadButton:SetWidth(50)
    loadButton:SetHeight(20)
    loadButton:SetPoint("TOPRIGHT", -5, -5)
    loadButton:SetText("Load")
    loadButton:SetScript("OnClick", function()
        Addon:LoadMacroSet(setName)
        Addon:UpdateUI()
    end)
    
    -- Update button (only on active set, stacked above Load)
    if isActive then
        local updateButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        updateButton:SetWidth(50)
        updateButton:SetHeight(20)
        updateButton:SetPoint("TOPRIGHT", -5, -27)
        updateButton:SetText("Update")
        updateButton:SetScript("OnClick", function()
            -- Overwrite this set directly from current character macros
            if Addon:SaveMacroSet(setName, true) then
                Addon:UpdateUI()
                Addon:NotifySetUpdated(setName)
            end
        end)
    end
    
    -- Delete button (X button on the left)
    local deleteButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    deleteButton:SetSize(24, 24)
    deleteButton:SetPoint("LEFT", -2, 0)
    deleteButton:SetScript("OnClick", function()
        -- Confirmation - pass setName for text format AND as data
        local dialog = StaticPopup_Show("MACROMONSTER_DELETE_SET", setName)
        if dialog then
            dialog.data = setName
        end
    end)
    
    return frame
end

-- Handle save button click
function Addon:OnSaveButtonClicked(allowOverwrite)
    local setName = Addon.mainFrame.setNameInput:GetText()
    
    if self:SaveMacroSet(setName, allowOverwrite) then
        Addon.mainFrame.setNameInput:SetText("")
        self:UpdateUI()
    end
end

-- Delete confirmation dialog
StaticPopupDialogs["MACROMONSTER_DELETE_SET"] = {
    text = "Delete macro set '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self)
        local setName = self.data
        Addon:DeleteMacroSet(setName)
        Addon:UpdateUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- New Set confirmation dialog
StaticPopupDialogs["MACROMONSTER_NEW_SET"] = {
    text = "Delete all character macros and start a new set?",
    button1 = "Yes, Clear",
    button2 = "Cancel",
    OnAccept = function(self)
        Addon:ClearCharacterMacros()
        Addon:UpdateUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
