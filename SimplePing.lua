-- SimplePing
-- Simple latency display for WoW 1.12 / Turtle WoW / OctoWoW
-- RIP Turtle WoW

--------------------------------------------------
-- Configuration
--------------------------------------------------

local UPDATE_INTERVAL = 1.0

-- Ping colours:
-- Green:  < 150 ms
-- Yellow: 150-299 ms
-- Red:    >= 300 ms

local GREEN_LIMIT  = 150
local YELLOW_LIMIT = 300

--------------------------------------------------
-- Frame
--------------------------------------------------

local frame = CreateFrame("Frame", "SimplePingFrame", UIParent)

frame:SetWidth(80)
frame:SetHeight(24)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)

frame:SetMovable(true)
frame:EnableMouse(false)
frame:RegisterForDrag("LeftButton")

-- Hidden until SavedVariables have loaded.
frame:Hide()

--------------------------------------------------
-- Background
-- Only shown while moving the frame.
--------------------------------------------------

local background = frame:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(frame)
background:SetTexture(0, 0, 0, 0.55)
background:Hide()

--------------------------------------------------
-- Ping text
--------------------------------------------------

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER", frame, "CENTER", 0, 0)
text:SetText("0 ms")

--------------------------------------------------
-- State
--------------------------------------------------

local unlocked = false
local elapsedTime = 0

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99SimplePing|r: " .. message
    )
end

local function GetCurrentPing()
    -- Vanilla 1.12 normally provides:
    --
    -- download, upload, latency = GetNetStats()
    --
    -- Some extended clients can provide a fourth "world"
    -- latency value. OctoWoW may return 0 for that value,
    -- so only use it when it contains a real value.

    local download, upload, latency, worldLatency = GetNetStats()

    latency = tonumber(latency) or 0
    worldLatency = tonumber(worldLatency) or 0

    if worldLatency > 0 then
        latency = worldLatency
    end

    return math.floor(latency + 0.5)
end

local function UpdatePing()
    local ping = GetCurrentPing()

    text:SetText(ping .. " ms")

    if ping < GREEN_LIMIT then
        -- Green
        text:SetTextColor(0, 1, 0)

    elseif ping < YELLOW_LIMIT then
        -- Yellow
        text:SetTextColor(1, 0.82, 0)

    else
        -- Red
        text:SetTextColor(1, 0, 0)
    end
end

--------------------------------------------------
-- Position saving
--------------------------------------------------

local function SavePosition()
    if type(SimplePingDB) ~= "table" then
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint()

    SimplePingDB.point = point or "CENTER"
    SimplePingDB.relativePoint = relativePoint or "CENTER"
    SimplePingDB.x = x or 0
    SimplePingDB.y = y or 0
end

local function RestorePosition()
    frame:ClearAllPoints()

    if SimplePingDB.point then
        frame:SetPoint(
            SimplePingDB.point,
            UIParent,
            SimplePingDB.relativePoint or SimplePingDB.point,
            SimplePingDB.x or 0,
            SimplePingDB.y or 0
        )
    else
        frame:SetPoint(
            "CENTER",
            UIParent,
            "CENTER",
            0,
            -180
        )
    end
end

local function ResetPosition()
    frame:ClearAllPoints()

    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        0,
        -180
    )

    SavePosition()

    Print("position reset.")
end

--------------------------------------------------
-- Moving / locking
--------------------------------------------------

local function UnlockFrame()
    unlocked = true

    frame:Show()
    frame:EnableMouse(true)
    background:Show()

    SimplePingDB.visible = true

    Print("unlocked. Left-click and drag it, then use /sping lock.")
end

local function LockFrame()
    -- Stop moving if necessary.
    -- StopMovingOrSizing() is safe for Vanilla 1.12 and avoids
    -- using the unsupported Frame:IsMoving() method.
    frame:StopMovingOrSizing()

    -- Save the current position before locking.
    SavePosition()

    unlocked = false

    frame:EnableMouse(false)
    background:Hide()

    Print("locked.")
end

frame:SetScript("OnDragStart", function()
    if unlocked then
        frame:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()

    if unlocked then
        SavePosition()
    end
end)

--------------------------------------------------
-- Ping updater
--------------------------------------------------

frame:SetScript("OnUpdate", function()
    elapsedTime = elapsedTime + (arg1 or 0)

    if elapsedTime >= UPDATE_INTERVAL then
        elapsedTime = 0
        UpdatePing()
    end
end)

--------------------------------------------------
-- SavedVariables initialization
--------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("VARIABLES_LOADED")

eventFrame:SetScript("OnEvent", function()
    if event ~= "VARIABLES_LOADED" then
        return
    end

    if type(SimplePingDB) ~= "table" then
        SimplePingDB = {}
    end

    RestorePosition()

    -- Default to visible the first time the addon loads.
    if SimplePingDB.visible == nil then
        SimplePingDB.visible = true
    end

    if SimplePingDB.visible then
        frame:Show()
    else
        frame:Hide()
    end

    UpdatePing()

    eventFrame:UnregisterEvent("VARIABLES_LOADED")
end)

--------------------------------------------------
-- Slash commands
--------------------------------------------------

SLASH_SIMPLEPING1 = "/sping"
SLASH_SIMPLEPING2 = "/simpleping"

SlashCmdList["SIMPLEPING"] = function(msg)
    msg = string.lower(msg or "")

    -- Remove leading/trailing spaces.
    -- This makes "/sping lock " behave the same as "/sping lock".
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")

    if msg == "" then

        if frame:IsShown() then
            frame:Hide()
            SimplePingDB.visible = false
        else
            frame:Show()
            SimplePingDB.visible = true
            UpdatePing()
        end

    elseif msg == "show" then

        frame:Show()
        SimplePingDB.visible = true
        UpdatePing()

    elseif msg == "hide" then

        frame:Hide()
        SimplePingDB.visible = false

    elseif msg == "move" or msg == "unlock" then

        UnlockFrame()

    elseif msg == "lock" then

        LockFrame()

    elseif msg == "reset" then

        ResetPosition()
        frame:Show()
        SimplePingDB.visible = true
        UpdatePing()

    elseif msg == "help" then

        Print("commands:")
        Print("/sping - toggle display")
        Print("/sping show - show ping")
        Print("/sping hide - hide ping")
        Print("/sping move - unlock and move")
        Print("/sping lock - lock position")
        Print("/sping reset - reset position")

    else

        Print("unknown command. Use /sping help")

    end
end
