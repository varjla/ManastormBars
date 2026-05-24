-- ============================================================
--  ManastormBars - Custom bar for Manastorm loadout slots
--  Server: Ascension | Version: Conquest of Azeroth (3.3.5)
-- ============================================================

local DEFAULTS = {
    rows            = 1,
    cols            = 9,
    scale           = 1.0,
    posX            = 400,
    posY            = 200,
    locked          = false,
    hideBackground  = false,
    consumables     = false,
}

local MAX_SLOTS = 18
local BUTTON_SIZE = 36
local BUTTON_PADDING = 4
local GRAB_WIDTH = 14
local buttons = {}
local buffTimer = 0

-- IDs de Hechizos específicas para asegurar los Tooltips de Ascension
local SPELL_IDS = {
    ["Manastorm: Interrupt Rod"] = 93429,  -- ID real del servidor para el Rod
    ["Manastorm: Taunting Tonic"] = 991868, -- ID real del servidor para el Tonic
}

local function DB()
    return ManastormBarsDB or DEFAULTS
end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function GetSlotSpellID(index)
    return C_Manastorm.GetLoadoutSpellAtIndex(index)
end

local itemIDCache = {}

local function ScanBagsForConsumables()
    local targetItems = {
        ["Endless Manastorm Potion"] = true,
        ["Millhouse's Magical Escape"] = true,
        ["Millhouse's Regeneration Matrix"] = true,
    }
    for k in pairs(itemIDCache) do itemIDCache[k] = nil end
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local name = link:match("%[(.-)%]")
                    if name and targetItems[name] then
                        itemIDCache[name] = itemID
                    end
                end
                local name = GetItemInfo(itemID)
                if name and targetItems[name] then
                    itemIDCache[name] = itemID
                end
            end
        end
    end
end

local function GetItemIDByName(itemName)
    return itemIDCache[itemName]
end

local function GetItemTextureByName(itemName, fallback)
    local tex = select(10, GetItemInfo(itemName))
    if tex then return tex end
    
    local itemID = GetItemIDByName(itemName)
    if itemID then
        tex = select(10, GetItemInfo(itemID))
        if tex then return tex end
    end
    return fallback
end

-- NUEVO ORDEN DE BOTONES (Rod primero a la izquierda)
local function GetButtonAction(i)
    local db = DB()
    if db.consumables then
        if i == 1 then
            return "spell", "Manastorm: Interrupt Rod" -- Primero a la izquierda
        elseif i == 2 then
            return "item", "Endless Manastorm Potion"
        elseif i == 3 then
            return "item", "Millhouse's Magical Escape"
        elseif i == 4 then
            return "item", "Millhouse's Regeneration Matrix"
        elseif i == 5 then
            return "spell", "Manastorm: Taunting Tonic"
        else
            return "spell_slot", i - 5 -- Mantiene el bloque de 4 frascos a la derecha
        end
    else
        return "spell_slot", i
    end
end

local function UpdateGlobalBindingNames()
    BINDING_HEADER_MANASTORMBARS = "ManastormBars"
    for i = 1, MAX_SLOTS do
        local actionType, nameOrSlot = GetButtonAction(i)
        if actionType == "item" or actionType == "spell" then
            _G["BINDING_NAME_CLICK ManastormBarsButton" .. i .. ":LeftButton"] = nameOrSlot
        else
            _G["BINDING_NAME_CLICK ManastormBarsButton" .. i .. ":LeftButton"] = "Use Slot " .. nameOrSlot
        end
    end
end

local function GetBuffRemaining(spellIDOrName)
    if not spellIDOrName or spellIDOrName == 0 or spellIDOrName == "" then return nil end
    local spellName = type(spellIDOrName) == "number" and GetSpellInfo(spellIDOrName) or spellIDOrName
    if not spellName then return nil end
    
    local i = 1
    while true do
        local name, _, _, _, _, duration, expirationTime, _, _, _, id = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if id == spellIDOrName or name == spellName then
            if expirationTime and expirationTime > 0 then
                return expirationTime - GetTime()
            else
                return duration or 0
            end
        end
        i = i + 1
    end
    return nil
end

local function FormatDuration(secs)
    if secs <= 0 then return "" end
    if secs >= 3600 then
        return string.format("%dh", math.floor(secs / 3600))
    elseif secs >= 60 then
        return string.format("%dm", math.floor(secs / 60))
    else
        return string.format("%ds", math.floor(secs))
    end
end

local function UpdateBuffDisplay()
    for i, btn in ipairs(buttons) do
        if btn:IsShown() then
            local actionType, nameOrSlot = GetButtonAction(i)
            local buffQuery = nil
            
            if actionType == "item" or actionType == "spell" then
                buffQuery = nameOrSlot
            else
                local spellID = GetSlotSpellID(nameOrSlot)
                if spellID and spellID ~= 0 then
                    buffQuery = spellID
                end
            end

            if buffQuery then
                local remaining = GetBuffRemaining(buffQuery)
                if remaining then
                    if not btn.borderShown then
                        btn.activeBorder:Show()
                        btn.borderShown = true
                    end
                    local durationStr = FormatDuration(remaining)
                    if durationStr ~= "" then
                        btn.durationText:SetText(durationStr)
                        btn.durationText:Show()
                    else
                        btn.durationText:Hide()
                    end
                else
                    if btn.borderShown then
                        btn.activeBorder:Hide()
                        btn.borderShown = false
                    end
                    btn.durationText:Hide()
                end
            else
                if btn.borderShown then
                    btn.activeBorder:Hide()
                    btn.borderShown = false
                end
                btn.durationText:Hide()
            end
        end
    end
end

local function UpdateKeybindingLabels()
    for i, btn in ipairs(buttons) do
        if btn:IsShown() then
            local key = GetBindingKey("CLICK ManastormBarsButton" .. i .. ":LeftButton")
            btn.hotkey:SetText(key and GetBindingText(key, "KEY_") or "")
            if key then
                btn.label:SetText(i)
                btn.label:Show()
            else
                btn.label:SetText("")
                btn.label:Hide()
            end
        else
            btn.label:SetText("")
            btn.label:Hide()
        end
    end
end

local function UpdateCooldowns()
    for i, btn in ipairs(buttons) do
        if btn:IsShown() then
            local actionType, nameOrSlot = GetButtonAction(i)
            local start, duration = 0, 0
            
            if actionType == "item" then
                local itemID = GetItemIDByName(nameOrSlot)
                if itemID then
                    start, duration = GetItemCooldown(itemID)
                end
            elseif actionType == "spell" then
                start, duration = GetSpellCooldown(nameOrSlot)
            else
                local spellID = GetSlotSpellID(nameOrSlot)
                if spellID and spellID ~= 0 then
                    start, duration = GetSpellCooldown(spellID)
                end
            end

            local cdStart, cdDuration = 0, 0
            if start and start > 0 and duration and duration > 0 then
                cdStart, cdDuration = start, duration
            else
                local gcdStart, gcdDuration = GetSpellCooldown(61304)
                if gcdStart and gcdStart > 0 and gcdDuration and gcdDuration > 0 then
                    cdStart, cdDuration = gcdStart, gcdDuration
                end
            end

            if btn.cooldown.currentStart ~= cdStart or btn.cooldown.currentDuration ~= cdDuration then
                btn.cooldown:SetCooldown(cdStart, cdDuration)
                btn.cooldown.currentStart = cdStart
                btn.cooldown.currentDuration = cdDuration
            end
        end
    end
end

local function UpdateBackgroundVisibility()
    if ManastormBarsFrame and ManastormBarsFrame.bg then
        if DB().hideBackground then
            ManastormBarsFrame.bg:SetTexture(0, 0, 0, 0)
        else
            ManastormBarsFrame.bg:SetTexture(0, 0, 0, 0.5)
        end
    end
end

local function UpdateDragHandleVisibility()
    if ManastormBarsDragHandle then
        local show = not DB().locked
        for _, dot in ipairs(ManastormBarsDragHandle.dots) do
            if show then
                dot:Show()
            else
                dot:Hide()
            end
        end
    end
end

-- ------------------------------------------------------------
-- Button layout
-- ------------------------------------------------------------
local function UpdateButtonSpell(i)
    local btn = buttons[i]
    if not btn then return end
    
    local actionType, nameOrSlot, fallbackTexture = GetButtonAction(i)
    
    if actionType == "item" then
        if btn.currentActionType ~= "item" or btn.currentActionValue ~= nameOrSlot then
            btn.currentActionType = "item"
            btn.currentActionValue = nameOrSlot
            
            local tex = GetItemTextureByName(nameOrSlot, fallbackTexture)
            btn.iconTex:SetTexture(tex)
            
            if not InCombatLockdown() then
                btn:SetAttribute("type", "item")
                btn:SetAttribute("item", nameOrSlot)
                btn.pendingActionUpdate = nil
            else
                btn.pendingActionUpdate = { type = "item", value = nameOrSlot }
            end
        else
            local tex = GetItemTextureByName(nameOrSlot, fallbackTexture)
            btn.iconTex:SetTexture(tex)
        end
    elseif actionType == "spell" then
        if btn.currentActionType ~= "spell_direct" or btn.currentActionValue ~= nameOrSlot then
            btn.currentActionType = "spell_direct"
            btn.currentActionValue = nameOrSlot
            
            local _, _, tex = GetSpellInfo(nameOrSlot)
            btn.iconTex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            
            if not InCombatLockdown() then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", nameOrSlot)
                btn.pendingActionUpdate = nil
            else
                btn.pendingActionUpdate = { type = "spell_direct", value = nameOrSlot }
            end
        else
            local _, _, tex = GetSpellInfo(nameOrSlot)
            if tex then btn.iconTex:SetTexture(tex) end
        end
    else
        local spellID = GetSlotSpellID(nameOrSlot)
        if btn.currentActionType ~= "spell" or btn.currentActionValue ~= spellID then
            btn.currentActionType = "spell"
            btn.currentActionValue = spellID
            
            if spellID and spellID ~= 0 then
                local _, _, tex = GetSpellInfo(spellID)
                btn.iconTex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                btn.iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            if not InCombatLockdown() then
                btn:SetAttribute("type", "spell")
                if spellID and spellID ~= 0 then
                    btn:SetAttribute("spell", spellID)
                else
                    btn:SetAttribute("spell", nil)
                end
                btn.pendingActionUpdate = nil
            else
                btn.pendingActionUpdate = { type = "spell", value = spellID }
            end
        end
    end
end

local function UpdateButtonLayout()
    local db = DB()
    local rows = db.rows
    local cols = db.cols
    local total = rows * cols
    local size  = BUTTON_SIZE * db.scale
    local pad   = BUTTON_PADDING * db.scale
    local grab  = GRAB_WIDTH * db.scale

    ManastormBarsFrame:SetWidth(grab + cols * (size + pad) + pad)
    ManastormBarsFrame:SetHeight(rows * (size + pad) + pad)

    if ManastormBarsDragHandle then
        local dragWidth = 12 * db.scale
        local dragOffset = 2 * db.scale
        ManastormBarsDragHandle:SetWidth(dragWidth)
        ManastormBarsDragHandle:ClearAllPoints()
        ManastormBarsDragHandle:SetPoint("TOPLEFT", ManastormBarsFrame, "TOPLEFT", dragOffset, -dragOffset)
        ManastormBarsDragHandle:SetPoint("BOTTOMLEFT", ManastormBarsFrame, "BOTTOMLEFT", dragOffset, dragOffset)

        for i = 1, 3 do
            local dot = ManastormBarsDragHandle.dots[i]
            if dot then
                dot:SetSize(3 * db.scale, 3 * db.scale)
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", ManastormBarsDragHandle, "CENTER", 0, (i - 2) * 6 * db.scale)
            end
        end
    end

    for i = 1, MAX_SLOTS do
        if i <= total then
			if not buttons[i] then
				local btn = CreateFrame("Button", "ManastormBarsButton" .. i, ManastormBarsFrame, "SecureActionButtonTemplate")
				btn:RegisterForClicks("LeftButtonUp")

				local nt = btn:GetNormalTexture()
				if nt then nt:SetTexture(nil) end
				local pt = btn:GetPushedTexture()
				if pt then pt:SetTexture(nil) end
				btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

				local iconTex = btn:CreateTexture(nil, "BACKGROUND")
				iconTex:SetAllPoints(btn)
				btn.iconTex = iconTex

				local cd = CreateFrame("Cooldown", "ManastormBarsButton" .. i .. "Cooldown", btn, "CooldownFrameTemplate")
				cd:SetAllPoints(btn)
				cd:SetDrawEdge(true)
				cd:SetReverse(false)
				btn.cooldown = cd

				local activeBorder = btn:CreateTexture(nil, "OVERLAY")
				activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
				activeBorder:SetBlendMode("ADD")
				activeBorder:SetVertexColor(0.2, 0.6, 1, 0.9)
				activeBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -8, 8)
				activeBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 8, -8)
				activeBorder:Hide()
				btn.activeBorder = activeBorder
				btn.borderShown = false

				local durationText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				durationText:SetPoint("TOP", btn, "TOP", 0, -2)
				durationText:SetTextColor(0, 1, 0)
				durationText:Hide()
				btn.durationText = durationText

				local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
                btn.label = label

				local hotkey = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
				hotkey:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
				hotkey:SetTextColor(0.9, 0.9, 0.9)
				btn.hotkey = hotkey

				btn:SetScript("OnEnter", function(self)
                    local actionType, nameOrSlot = GetButtonAction(self.slotIndex)
                    if actionType == "item" then
                        local itemID = GetItemIDByName(nameOrSlot)
                        if itemID then
                            local _, link = GetItemInfo(itemID)
                            if link then
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetHyperlink(link)
                                GameTooltip:Show()
                                return
                            end
                        end
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(nameOrSlot, 1, 1, 1)
                        GameTooltip:Show()
                    elseif actionType == "spell" then
                        -- CORRECCIÓN AGRESIVA: Buscamos ID interna o forzamos por base de datos local
                        local spellID = SPELL_IDS[nameOrSlot]
                        if not spellID then
                            _, _, _, _, _, _, spellID = GetSpellInfo(nameOrSlot)
                        end
                        
                        if spellID then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetSpellByID(spellID)
                            GameTooltip:Show()
                            return
                        end
                        
                        -- Fallback si falla todo lo demás
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(nameOrSlot, 1, 1, 1)
                        GameTooltip:Show()
                    else
                        local spellID = GetSlotSpellID(nameOrSlot)
                        if spellID and spellID ~= 0 then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetSpellByID(spellID)
                            GameTooltip:Show()
                            return
                        end
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Manastorm Slot " .. nameOrSlot, 1, 1, 1)
                        GameTooltip:Show()
                    end
				end)
				btn:SetScript("OnLeave", function()
					GameTooltip:Hide()
				end)

				buttons[i] = btn
			end

            local btn = buttons[i]
            btn.slotIndex = i
            btn:SetWidth(size)
            btn:SetHeight(size)

            btn.activeBorder:ClearAllPoints()
            btn.activeBorder:SetPoint("CENTER", btn, "CENTER", 0, 1 * db.scale)
            btn.activeBorder:SetSize(62 * db.scale, 62 * db.scale)

            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", ManastormBarsFrame, "TOPLEFT",
                grab + col * (size + pad),
                -(pad + row * (size + pad)))

            UpdateButtonSpell(i)

            local actionType, nameOrSlot = GetButtonAction(i)
			if actionType == "item" or actionType == "spell" then 
				btn.label:SetText("")
				btn:Show()
			else
				local spellID = GetSlotSpellID(nameOrSlot)
				if spellID and spellID ~= 0 then
					btn.label:SetText(nameOrSlot)
					btn:Show()
				else
					btn.label:SetText("")
					btn:Hide()
				end
			end
        else
            if buttons[i] then buttons[i]:Hide() end
        end
    end

    UpdateKeybindingLabels()
    UpdateCooldowns()
end

-- ------------------------------------------------------------
-- Main frame
-- ------------------------------------------------------------
local function CreateMainFrame()
    local db = DB()
    local f = CreateFrame("Frame", "ManastormBarsFrame", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not DB().locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        DB().posX = self:GetLeft()
        DB().posY = self:GetBottom()
    end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    f.bg = bg
    UpdateBackgroundVisibility()

    local dragHandle = CreateFrame("Frame", "ManastormBarsDragHandle", f)
    dragHandle:SetWidth(12)
    dragHandle:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    dragHandle:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        if not DB().locked then f:StartMoving() end
    end)
    dragHandle:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        DB().posX = f:GetLeft()
        DB().posY = f:GetBottom()
    end)

    dragHandle.dots = {}
    for i = 1, 3 do
        local dot = dragHandle:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(1, 1, 1, 0.5)
        dot:SetSize(3, 3)
        dot:SetPoint("CENTER", dragHandle, "CENTER", 0, (i - 2) * 6)
        table.insert(dragHandle.dots, dot)
    end
    UpdateDragHandleVisibility()

    local gear = CreateFrame("Button", "ManastormBarsGearButton", f)
    gear:SetWidth(18)
    gear:SetHeight(18)
    gear:SetPoint("LEFT", f, "RIGHT", 4, 0)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() ManastormBarsConfig_Toggle() end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("ManastormBars Options", 1, 1, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.posX, db.posY)
    f:Show()
end

-- ------------------------------------------------------------
-- Config window
-- ------------------------------------------------------------
local function CreateConfigFrame()
    local cf = CreateFrame("Frame", "ManastormBarsConfigFrame", UIParent)
    cf:SetSize(360, 320)
    cf:SetPoint("CENTER")
    cf:SetFrameStrata("DIALOG")
    cf:SetMovable(true)
    cf:EnableMouse(true)
    cf:RegisterForDrag("LeftButton")
    cf:SetScript("OnDragStart", function(self) self:StartMoving() end)
    cf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    cf:Hide()

    local bg = cf:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(cf)
    bg:SetTexture(0.05, 0.05, 0.05, 0.92)

    cf:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 26,
        insets = { left = 9, right = 9, top = 9, bottom = 9 },
    })

    local titleBg = cf:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetPoint("TOP", cf, "TOP", 0, 12)
    titleBg:SetWidth(270)
    titleBg:SetHeight(40)

    local titleText = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", cf, "TOP", 0, 2)
    titleText:SetText("ManastormBars Config")

    local xBtn = CreateFrame("Button", "ManastormBarsConfigCloseBtn", cf, "UIPanelCloseButton")
    xBtn:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 1, 1)
    xBtn:SetScript("OnClick", function() cf:Hide() end)

    local function MakeSlider(parent, label, minVal, maxVal, step, yOffset, dbKey)
        local s = CreateFrame("Slider", "ManastormBarsSlider_" .. dbKey, parent, "OptionsSliderTemplate")
        s:SetPoint("TOP", parent, "TOP", 0, yOffset)
        s:SetWidth(260)
        s:SetMinMaxValues(minVal, maxVal)
        s:SetValueStep(step)
        _G[s:GetName() .. "Low"]:SetText(minVal)
        _G[s:GetName() .. "High"]:SetText(maxVal)
        _G[s:GetName() .. "Text"]:SetText(label .. ": " .. DB()[dbKey])
        
        local orig = s:GetScript("OnValueChanged")
        s:SetScript("OnValueChanged", function(self, val)
            if orig then orig(self, val) end
            val = math.floor(val * 10 + 0.5) / 10
            DB()[dbKey] = val
            _G[self:GetName() .. "Text"]:SetText(label .. ": " .. val)
            UpdateButtonLayout()
        end)
        
        s:SetValue(DB()[dbKey])
        return s
    end

    MakeSlider(cf, "Rows",  1,  18,   1,   -50,  "rows")
    MakeSlider(cf, "Cols",  1,  18,   1,   -105, "cols")
    MakeSlider(cf, "Scale", 0.5, 2.0, 0.1, -160, "scale")

    local lockCB = CreateFrame("CheckButton", "ManastormBarsLockCB", cf, "UICheckButtonTemplate")
    lockCB:SetPoint("TOPLEFT", cf, "TOPLEFT", 20, -190)
    _G["ManastormBarsLockCBText"]:SetText("Lock bar position")
    lockCB:SetChecked(DB().locked)
    lockCB:SetScript("OnClick", function(self)
        DB().locked = self:GetChecked() and true or false
        UpdateDragHandleVisibility()
    end)

    local bgCB = CreateFrame("CheckButton", "ManastormBarsBgCB", cf, "UICheckButtonTemplate")
    bgCB:SetPoint("TOPLEFT", cf, "TOPLEFT", 20, -220)
    _G["ManastormBarsBgCBText"]:SetText("Hide background box")
    bgCB:SetChecked(DB().hideBackground)
    bgCB:SetScript("OnClick", function(self)
        DB().hideBackground = self:GetChecked() and true or false
        UpdateBackgroundVisibility()
    end)

    local consCB = CreateFrame("CheckButton", "ManastormBarsConsCB", cf, "UICheckButtonTemplate")
    consCB:SetPoint("TOPLEFT", cf, "TOPLEFT", 20, -250)
    _G["ManastormBarsConsCBText"]:SetText("Add Manastorm Consumables to the list")
    consCB:SetChecked(DB().consumables)
    consCB:SetScript("OnClick", function(self)
        DB().consumables = self:GetChecked() and true or false
        UpdateGlobalBindingNames()
        if not InCombatLockdown() then
            UpdateButtonLayout()
        else
            print("|cffffff00ManastormBars:|r Cannot update layout in combat. Layout will refresh out of combat.")
        end
    end)

    local closeBtn = CreateFrame("Button", nil, cf, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", cf, "BOTTOM", 0, 14)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() cf:Hide() end)

    return cf
end

function ManastormBarsConfig_Toggle()
    if ManastormBarsConfigFrame:IsShown() then
        ManastormBarsConfigFrame:Hide()
    else
        ManastormBarsConfigFrame:Show()
    end
end

-- ------------------------------------------------------------
-- Initialisation
-- ------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
initFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
initFrame:RegisterEvent("UPDATE_BINDINGS")
initFrame:RegisterEvent("BAG_UPDATE")

local addonLoaded = false

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ManastormBars" then
        if not ManastormBarsDB then ManastormBarsDB = {} end
        for k, v in pairs(DEFAULTS) do
            if ManastormBarsDB[k] == nil then
                ManastormBarsDB[k] = v
            end
        end
        addonLoaded = true
    end

    if event == "PLAYER_ENTERING_WORLD" and addonLoaded then
        ScanBagsForConsumables()
        UpdateGlobalBindingNames()
        CreateMainFrame()
        CreateConfigFrame()
        UpdateBackgroundVisibility()
        UpdateDragHandleVisibility()
        UpdateButtonLayout()

        self:SetScript("OnUpdate", function(self, elapsed)
            buffTimer = buffTimer + elapsed
            if buffTimer >= 0.1 then
                buffTimer = 0
                UpdateBuffDisplay()
                UpdateCooldowns()

                local db = DB()
                local total = db.rows * db.cols
                local layoutChanged = false
                for i = 1, total do
                    if buttons[i] then
                        UpdateButtonSpell(i)

                        if not InCombatLockdown() then
                            local actionType, nameOrSlot = GetButtonAction(i)
                            if actionType == "item" or actionType == "spell" then
                                if not buttons[i]:IsShown() then
                                    buttons[i].label:SetText("")
                                    buttons[i]:Show()
                                    layoutChanged = true
                                end
                            else
                                local spellID = GetSlotSpellID(nameOrSlot)
                                if spellID and spellID ~= 0 then
                                    if not buttons[i]:IsShown() then
                                        buttons[i].label:SetText(nameOrSlot)
                                        buttons[i]:Show()
                                        layoutChanged = true
                                    end
                                else
                                    if buttons[i]:IsShown() then
                                        buttons[i].label:SetText("")
                                        buttons[i]:Hide()
                                        layoutChanged = true
                                    end
                                end
                            end
                        end
                    end
                end
                if layoutChanged and not InCombatLockdown() then
                    UpdateButtonLayout()
                end
            end
        end)

        SLASH_MANASTORMBARS1 = "/msb"
        SLASH_MANASTORMBARS2 = "/manastormbars"
        SlashCmdList["MANASTORMBARS"] = function(msg)
            local cmd = strtrim(msg):lower()
            if cmd == "config" or cmd == "" then
                ManastormBarsConfig_Toggle()
            elseif cmd == "lock" then
                DB().locked = not DB().locked
                UpdateDragHandleVisibility()
                print("|cffffff00ManastormBars:|r Bar " .. (DB().locked and "|cff00ff00locked|r" or "|cffff4444unlocked|r") .. ".")
            elseif cmd == "reset" then
                ManastormBarsDB = {}
                for k, v in pairs(DEFAULTS) do ManastormBarsDB[k] = v end
                ManastormBarsFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", DB().posX, DB().posY)
                UpdateBackgroundVisibility()
                UpdateDragHandleVisibility()
                UpdateButtonLayout()
                print("|cffffff00ManastormBars:|r Settings reset to defaults.")
            elseif cmd == "debug" then
                local result = ""
                local numSlots = C_Manastorm.GetNumLoadoutSlots()
                result = result .. "NumLoadoutSlots: " .. tostring(numSlots) .. "\n"
                for i = 1, (numSlots or 4) do
                    local spellID = C_Manastorm.GetLoadoutSpellAtIndex(i)
                    local name = spellID and GetSpellInfo(spellID) or "empty"
                    result = result .. "Slot " .. i .. ": spellID=" .. tostring(spellID) .. " name=" .. tostring(name) .. "\n"
                end
                error(result)
            else
                print("|cffffff00ManastormBars commands:|r")
                print("  /msb          - Open config window")
                print("  /msb lock     - Toggle bar lock")
                print("  /msb reset    - Reset to defaults")
                print("  /msb debug    - Show slot info")
            end
        end

        print("|cffffff00ManastormBars|r loaded. Type |cffffd700/msb|r to configure.")
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        UpdateCooldowns()
    end

    if event == "PLAYER_REGEN_ENABLED" then
        for i, btn in ipairs(buttons) do
            if btn.pendingActionUpdate then
                local update = btn.pendingActionUpdate
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", update.value)
                btn.pendingActionUpdate = nil
            end
        end
        UpdateKeybindingLabels()
        UpdateButtonLayout()
    elseif event == "UPDATE_BINDINGS" then
        UpdateKeybindingLabels()
    elseif event == "BAG_UPDATE" then
        ScanBagsForConsumables()
    end
end)