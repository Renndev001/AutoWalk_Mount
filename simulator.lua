-- Renn Hub - Advanced Automation Script for Peningkatan Keabadian
-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") or ReplicatedStorage:FindFirstChild("RemoteEvent")

if not RemoteEvents then
    warn("RemoteEvents not found!")
    return
end

-- ============================================
-- REMOTE EVENTS REFERENCE
-- ============================================
local Remote = {
    EssenceMarkPress = RemoteEvents:FindFirstChild("EssenceMarkPress"),
    InsightMarkPress = RemoteEvents:FindFirstChild("InsightMarkPress"),
    SoulfireMarkPress = RemoteEvents:FindFirstChild("SoulfireMarkPress"),
    KarmaMarkPress = RemoteEvents:FindFirstChild("KarmaMarkPress"),
    StarsMarkPress = RemoteEvents:FindFirstChild("StarsMarkPress"),
    NebulaMarkPress = RemoteEvents:FindFirstChild("NebulaMarkPress"),
    QuasarMarkPress = RemoteEvents:FindFirstChild("QuasarMarkPress"),
    MiasmaMarkPress = RemoteEvents:FindFirstChild("MiasmaMarkPress"),
    AshMarkPress = RemoteEvents:FindFirstChild("AshMarkPress"),
    LawsMarkPress = RemoteEvents:FindFirstChild("LawsMarkPress"),
    FaithMarkPress = RemoteEvents:FindFirstChild("FaithMarkPress"),
    PurchaseUpgrade = RemoteEvents:FindFirstChild("PurchaseUpgrade"),
    ClaimRefinement = RemoteEvents:FindFirstChild("ClaimRefinement"),
    RollBloodline = RemoteEvents:FindFirstChild("RollBloodline"),
    UpgradeBloodline = RemoteEvents:FindFirstChild("UpgradeBloodline"),
    ConvertCitizensToFaith = RemoteEvents:FindFirstChild("ConvertCitizensToFaith"),
    ToggleAutoFaithConvert = RemoteEvents:FindFirstChild("ToggleAutoFaithConvert"),
    RealmPress = RemoteEvents:FindFirstChild("RealmPress"),
    GainMiasma = RemoteEvents:FindFirstChild("GainMiasma"),
    BeastHuntGainFeedback = RemoteEvents:FindFirstChild("BeastHuntGainFeedback"),
    PurchaseAsh = RemoteEvents:FindFirstChild("PurchaseAsh"),
    PurchaseLaws = RemoteEvents:FindFirstChild("PurchaseLaws"),
}

-- Button references
local function getMarkButton(markName)
    local mark = Workspace:FindFirstChild(markName .. "MarkButton")
    if mark then
        return mark:FindFirstChild(markName .. "MarkButtonTop")
    end
    return nil
end

local MarkButtons = {
    Essence = getMarkButton("Essence"),
    Insight = getMarkButton("Insight"),
    Soulfire = getMarkButton("Soulfire"),
    Karma = getMarkButton("Karma"),
    Stars = getMarkButton("Stars"),
    Nebula = getMarkButton("Nebula"),
    Quasar = getMarkButton("Quasar"),
    Miasma = getMarkButton("Miasma"),
    Ash = getMarkButton("Ash"),
    Laws = getMarkButton("Laws"),
    Faith = getMarkButton("Faith"),
}

-- ============================================
-- CONFIGURATION DATA (from extracted modules)
-- ============================================
local MARK_INTERVAL = 0.5           -- baseOpenIntervalSeconds
local ESSENCE_MOTE_INTERVAL = 0.9   -- spawn interval, but we use 0.5 for press
local UPGRADE_DELAY = 0.8
local BLOODLINE_ROLL_DELAY = 1.5

-- Upgrade IDs per board
local UpgradeIDs = {
    Essence = {
        "EssenceYield",
        "MoteFlow",
        "CauldronFocus",
        "RefinementLink",
        "EssenceLuckMultiplier",
        "EssenceQiMultiplier",
        "EssenceInsightMultiplier"
    },
    Insight = {
        "InsightMultiplier",
        "InsightQiMultiplier",
        "InsightLuckMultiplier",
        "InsightMarkSpeed"
    },
    Soulfire = {
        "SoulEssenceMultiplier",
        "SoulLuckMultiplier",
        "SoulQiMultiplier",
        "SoulfireKarmaMultiplier",
        "SoulAutomationUnlock",
        "SoulAutoBreakthrough",
        "SoulAutoBuyQiUpgrades",
        "SoulAutoInsightGain",
        "SoulAutoBuyInsightUpgrades",
        "SoulAutoBuyEssenceUpgrades"
    },
    Miasma = {
        "MiasmaMiasmaMultiplier",
        "MiasmaLuckMultiplier",
        "MiasmaQiMultiplier",
        "MiasmaManualLuckMultiplier",
        "MiasmaQuasarBoost",
        "MiasmaBeastDamageCap"
    },
    Ash = {
        "AshAutoMiasma",
        "AshMiasmaMultiplier",
        "AshAshMultiplier",
        "AshLuckMultiplier",
        "AshQiMultiplier",
        "AshQuasarMultiplier"
    },
    Laws = {
        "LawsLawsMultiplier",
        "LawsAshMultiplier",
        "LawsQiMultiplier",
        "LawsLuckMultiplier",
        "LawsBoardII",
        "LawsLawsMultiplierII",
        "LawsAshMultiplierII",
        "LawsQiMultiplierII",
        "LawsLuckMultiplierII"
    },
    Divinity = {
        "DivinityMoreCitizens",
        "DivinityMoreDivinity",
        "DivinityMoreDiscipleLuck",
        "DivinityMoreQi",
        "DivinityBoardII",
        "DivinityStrongerQi",
        "DivinityMoreMarkBulk",
        "DivinityUnlockKarmaMilestone",
        "DivinityUnlockOriginChallenge"
    },
    Faith = {
        "InnerWorldSize",
        "InnerWorldCitizenMulti",
        "InnerWorldFaithSpeed",
        "InnerWorldFaithPower",
        "InnerWorldFaithLawsMultiplier",
        "InnerWorldFaithMarksBoost",
        "InnerWorldFaithKarmaMilestoneI",
        "InnerWorldFaithDiscipleTraining",
        "InnerWorldFaithUnlockDivinity"
    }
}

-- ============================================
-- UI CREATION
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Renn Hub",
    LoadingTitle = "Renn Hub",
    LoadingSubtitle = "by Renn",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RennHub",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvite",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {
        Title = "Renn Hub",
        Subtitle = "Key System",
        Note = "No key required",
        FileName = "Key",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"Hello"}
    }
})

-- Tabs
local TabFarm = Window:CreateTab("Auto Farm", 4483362458)
local TabUpgrades = Window:CreateTab("Auto Upgrades", 4483362458)
local TabMisc = Window:CreateTab("Auto Misc", 4483362458)

-- ============================================
-- STATE VARIABLES
-- ============================================
local toggles = {
    Essence = false,
    Insight = false,
    Soulfire = false,
    Karma = false,
    Stars = false,
    Nebula = false,
    Quasar = false,
    Miasma = false,
    Ash = false,
    Laws = false,
    Faith = false,
    AutoBuyEssence = false,
    AutoBuyInsight = false,
    AutoBuySoulfire = false,
    AutoBuyMiasma = false,
    AutoBuyAsh = false,
    AutoBuyLaws = false,
    AutoBuyDivinity = false,
    AutoBuyFaith = false,
    AutoConvertFaith = false,
    AutoRollBloodline = false,
    AutoUpgradeBloodline = false,
    AutoClaimRefinement = false,
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function safeFire(remote, ...)
    if remote then
        pcall(function()
            remote:FireServer(...)
        end)
    end
end

local function safeInvoke(remote, ...)
    if remote then
        return pcall(function()
            return remote:InvokeServer(...)
        end)
    end
    return false, nil
end

-- ============================================
-- MARK PRESS LOOPS
-- ============================================
local function startMarkLoop(markName, markEvent, buttonPart)
    task.spawn(function()
        while toggles[markName] do
            if markEvent and buttonPart then
                safeFire(markEvent, buttonPart)
            end
            task.wait(MARK_INTERVAL)
        end
    end)
end

-- Create toggles for each mark
local markNames = {"Essence","Insight","Soulfire","Karma","Stars","Nebula","Quasar","Miasma","Ash","Laws","Faith"}
for _, name in ipairs(markNames) do
    local displayName = name .. " Mark"
    if name == "Soulfire" then displayName = "Soulfire Mark" end
    if name == "Miasma" then displayName = "Miasma Mark" end
    if name == "Laws" then displayName = "Laws Mark" end
    if name == "Faith" then displayName = "Faith Mark" end

    TabFarm:CreateToggle({
        Name = "Auto Open " .. displayName,
        CurrentValue = false,
        Flag = "Auto" .. name,
        Callback = function(Value)
            toggles[name] = Value
            if Value then
                startMarkLoop(name, Remote[name .. "MarkPress"], MarkButtons[name])
            end
        end
    })
end

-- ============================================
-- UPGRADE BUYING LOOPS
-- ============================================
local function startUpgradeLoop(upgradeList, toggleKey)
    task.spawn(function()
        local index = 1
        while toggles[toggleKey] do
            local id = upgradeList[index]
            if id then
                safeFire(Remote.PurchaseUpgrade, id)
            end
            index = index % #upgradeList + 1
            task.wait(UPGRADE_DELAY)
        end
    end)
end

TabUpgrades:CreateToggle({
    Name = "Auto Buy Essence Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyEssence",
    Callback = function(Value)
        toggles.AutoBuyEssence = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Essence, "AutoBuyEssence")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Insight Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyInsight",
    Callback = function(Value)
        toggles.AutoBuyInsight = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Insight, "AutoBuyInsight")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Soulfire Upgrades",
    CurrentValue = false,
    Flag = "AutoBuySoulfire",
    Callback = function(Value)
        toggles.AutoBuySoulfire = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Soulfire, "AutoBuySoulfire")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Miasma Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyMiasma",
    Callback = function(Value)
        toggles.AutoBuyMiasma = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Miasma, "AutoBuyMiasma")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Ash Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyAsh",
    Callback = function(Value)
        toggles.AutoBuyAsh = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Ash, "AutoBuyAsh")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Laws Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyLaws",
    Callback = function(Value)
        toggles.AutoBuyLaws = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Laws, "AutoBuyLaws")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Divinity Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyDivinity",
    Callback = function(Value)
        toggles.AutoBuyDivinity = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Divinity, "AutoBuyDivinity")
        end
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Buy Faith Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyFaith",
    Callback = function(Value)
        toggles.AutoBuyFaith = Value
        if Value then
            startUpgradeLoop(UpgradeIDs.Faith, "AutoBuyFaith")
        end
    end
})

-- ============================================
-- MISC AUTOMATIONS
-- ============================================
-- Auto Convert Citizens to Faith
TabMisc:CreateToggle({
    Name = "Auto Convert Citizens to Faith",
    CurrentValue = false,
    Flag = "AutoConvertFaith",
    Callback = function(Value)
        toggles.AutoConvertFaith = Value
        task.spawn(function()
            while toggles.AutoConvertFaith do
                safeFire(Remote.ConvertCitizensToFaith)
                task.wait(2)
            end
        end)
    end
})

-- Auto Roll Bloodline
TabMisc:CreateToggle({
    Name = "Auto Roll Bloodline",
    CurrentValue = false,
    Flag = "AutoRollBloodline",
    Callback = function(Value)
        toggles.AutoRollBloodline = Value
        task.spawn(function()
            while toggles.AutoRollBloodline do
                safeInvoke(Remote.RollBloodline)
                task.wait(BLOODLINE_ROLL_DELAY)
            end
        end)
    end
})

-- Auto Upgrade Bloodline
TabMisc:CreateToggle({
    Name = "Auto Upgrade Bloodline",
    CurrentValue = false,
    Flag = "AutoUpgradeBloodline",
    Callback = function(Value)
        toggles.AutoUpgradeBloodline = Value
        task.spawn(function()
            while toggles.AutoUpgradeBloodline do
                safeInvoke(Remote.UpgradeBloodline)
                task.wait(UPGRADE_DELAY)
            end
        end)
    end
})

-- Auto Claim Refinement
TabMisc:CreateToggle({
    Name = "Auto Claim Refinement",
    CurrentValue = false,
    Flag = "AutoClaimRefinement",
    Callback = function(Value)
        toggles.AutoClaimRefinement = Value
        task.spawn(function()
            while toggles.AutoClaimRefinement do
                safeFire(Remote.ClaimRefinement)
                task.wait(1)
            end
        end)
    end
})

-- ============================================
-- ADDITIONAL UTILITY BUTTONS
-- ============================================
TabFarm:CreateButton({
    Name = "Press All Marks Once",
    Callback = function()
        for _, name in ipairs(markNames) do
            local ev = Remote[name .. "MarkPress"]
            local btn = MarkButtons[name]
            if ev and btn then
                safeFire(ev, btn)
            end
            task.wait(0.1)
        end
    end
})

TabUpgrades:CreateButton({
    Name = "Buy All Essence Upgrades Once",
    Callback = function()
        for _, id in ipairs(UpgradeIDs.Essence) do
            safeFire(Remote.PurchaseUpgrade, id)
            task.wait(0.3)
        end
    end
})

TabMisc:CreateButton({
    Name = "Enable All Automations",
    Callback = function()
        -- Toggle all marks on
        for _, name in ipairs(markNames) do
            toggles[name] = true
            startMarkLoop(name, Remote[name .. "MarkPress"], MarkButtons[name])
        end
        -- Toggle all upgrades
        toggles.AutoBuyEssence = true
        startUpgradeLoop(UpgradeIDs.Essence, "AutoBuyEssence")
        toggles.AutoBuyInsight = true
        startUpgradeLoop(UpgradeIDs.Insight, "AutoBuyInsight")
        toggles.AutoBuySoulfire = true
        startUpgradeLoop(UpgradeIDs.Soulfire, "AutoBuySoulfire")
        toggles.AutoBuyMiasma = true
        startUpgradeLoop(UpgradeIDs.Miasma, "AutoBuyMiasma")
        toggles.AutoBuyAsh = true
        startUpgradeLoop(UpgradeIDs.Ash, "AutoBuyAsh")
        toggles.AutoBuyLaws = true
        startUpgradeLoop(UpgradeIDs.Laws, "AutoBuyLaws")
        toggles.AutoBuyDivinity = true
        startUpgradeLoop(UpgradeIDs.Divinity, "AutoBuyDivinity")
        toggles.AutoBuyFaith = true
        startUpgradeLoop(UpgradeIDs.Faith, "AutoBuyFaith")
        toggles.AutoConvertFaith = true
        toggles.AutoRollBloodline = true
        toggles.AutoUpgradeBloodline = true
        toggles.AutoClaimRefinement = true
    end
})

TabMisc:CreateButton({
    Name = "Disable All Automations",
    Callback = function()
        for _, name in ipairs(markNames) do
            toggles[name] = false
        end
        toggles.AutoBuyEssence = false
        toggles.AutoBuyInsight = false
        toggles.AutoBuySoulfire = false
        toggles.AutoBuyMiasma = false
        toggles.AutoBuyAsh = false
        toggles.AutoBuyLaws = false
        toggles.AutoBuyDivinity = false
        toggles.AutoBuyFaith = false
        toggles.AutoConvertFaith = false
        toggles.AutoRollBloodline = false
        toggles.AutoUpgradeBloodline = false
        toggles.AutoClaimRefinement = false
    end
})

-- ============================================
-- STATUS DISPLAY
-- ============================================
local statusLabel = TabFarm:CreateLabel("Status: Idle")
task.spawn(function()
    while true do
        local active = {}
        for _, name in ipairs(markNames) do
            if toggles[name] then table.insert(active, name) end
        end
        local status = #active > 0 and "Running: " .. table.concat(active, ", ") or "Idle"
        statusLabel:Set(status)
        task.wait(1)
    end
end)

print("Renn Hub loaded successfully!")