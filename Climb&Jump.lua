-- Renn Hub - Panjat dan Lompat Menara DUNIA BARU
-- Senior Luau Developer & Security Researcher
-- Versi: 2.0.0

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- ============================
-- Remote References
-- ============================
local remotes = {
    ProMgs = ReplicatedStorage:FindFirstChild("ProMgs"),
    ServerMsg = ReplicatedStorage:FindFirstChild("ServerMsg"),
    Msg = ReplicatedStorage:FindFirstChild("Msg"),
    DrawUp = ReplicatedStorage:FindFirstChild("Tool") and ReplicatedStorage.Tool:FindFirstChild("DrawUp"),
    Setting = ReplicatedStorage:FindFirstChild("ServerMsg") and ReplicatedStorage.ServerMsg:FindFirstChild("Setting"),
    SystemFly = ReplicatedStorage:FindFirstChild("System") and ReplicatedStorage.System:FindFirstChild("SystemFly"),
    LoadingScreenEvent = ReplicatedStorage:FindFirstChild("LoadingScreenEvent"),
    ClaimEventReward = ReplicatedStorage:FindFirstChild("ClaimEventReward"),
    UpdateLocalData = ReplicatedStorage:FindFirstChild("ServerMsg") and ReplicatedStorage.ServerMsg:FindFirstChild("UpdateLocalData"),
    GameAnalyticsError = ReplicatedStorage:FindFirstChild("GameAnalyticsError"),
    RemoteEvent = ReplicatedStorage:FindFirstChild("Msg") and ReplicatedStorage.Msg:FindFirstChild("RemoteEvent"),
}

local function getRemote(path)
    local parts = string.split(path, ".")
    local current = ReplicatedStorage
    for _, part in ipairs(parts) do
        if current then
            current = current:FindFirstChild(part)
        else
            break
        end
    end
    return current
end

-- Remote functions
local remoteFire = function(path, ...)
    local r = getRemote(path)
    if r then
        if r:IsA("RemoteEvent") then
            r:FireServer(...)
        elseif r:IsA("RemoteFunction") then
            return r:InvokeServer(...)
        end
    end
end

local remoteInvoke = function(path, ...)
    local r = getRemote(path)
    if r and r:IsA("RemoteFunction") then
        return r:InvokeServer(...)
    end
end

-- ============================
-- Config Data dari ExtractedModules
-- ============================
local configs = {
    -- World config dengan speed compression
    worlds = {
        [1] = { speedComp = 1, goldAdd = 100 },
        [2] = { speedComp = 0.03125, goldAdd = 188956800 },
        [3] = { speedComp = 0.0013165625, goldAdd = 357046722662400 },
        [4] = { speedComp = 0.000031517578125, goldAdd = 6.74664061647746e20 },
        [5] = { speedComp = 9.53674316e-7, goldAdd = 1.27482362163961e27 },
        [6] = { speedComp = 2.9802322e-8, goldAdd = 2.40886592109431e33 },
        [7] = { speedComp = 9.31323e-10, goldAdd = 4.55171596079033e39 },
        [8] = { speedComp = 2.9104e-11, goldAdd = 8.60077682459866e45 },
        [9] = { speedComp = 9.09e-13, goldAdd = 2.36811253088019e52 },
        [10] = { speedComp = 3.75e-14, goldAdd = 4.65018846889729e58 },
        [11] = { speedComp = 9.39e-16, goldAdd = 8.49118846889729e64 },
        [12] = { speedComp = 3.934375e-18, goldAdd = 6.7107286837e72 },
        [13] = { speedComp = 1.3e-19, goldAdd = 2.39807286837e82 },
        [14] = { speedComp = 1e-21, goldAdd = 8.85e90 },
        [15] = { speedComp = 3.5e-23, goldAdd = 3.55e98 },
        [16] = { speedComp = 1.15e-24, goldAdd = 2.15e107 },
        [17] = { speedComp = 3.9e-26, goldAdd = 9.15e118 },
        [18] = { speedComp = 1.4e-27, goldAdd = 9.6e129 },
        [19] = { speedComp = 4.98e-29, goldAdd = 3.6e146 },
        [20] = { speedComp = 4.8e-33, goldAdd = 1.8e156 },
        [21] = { speedComp = 1.6e-34, goldAdd = 3.5e168 },
        [22] = { speedComp = 5.5e-36, goldAdd = 4.08e189 },
        [23] = { speedComp = 1.8e-37, goldAdd = 1.72e196 },
        [24] = { speedComp = 6e-39, goldAdd = 9e209 },
        [25] = { speedComp = 2e-40, goldAdd = 2.5e232 },
        [26] = { speedComp = 6.67e-42, goldAdd = 7e238 },
        [27] = { speedComp = 2.22e-43, goldAdd = 6.99999999999999e260 },
        [28] = { speedComp = 2.22e-43, goldAdd = 6.99999999999999e267 },
        [29] = { speedComp = 2.47e-46, goldAdd = 6.99999999999999e277 },
    },
    
    -- Normal walk speed
    walkSpeed = 16,
    vipWalkSpeed = 32,
    
    -- Item IDs
    itemIDs = {
        Coin = 1,
        Wins = 2,
        DailyToken = 5,
        EventEgg = 6,
        PetQuest = 7,
        EnchantCrystal = 8,
        PowerCore = 9,
        GoldenEgg = 10,
        FishTickets = 11,
        SeasonExp = 13,
        SeasonLevel = 14,
        SeasonCard = 15,
        SeasonAdvanced = 16,
        EnergyCrystal = 17,
        EclipseToken = 18,
        SunShard = 19,
        CosmicShard = 20,
        DarkMatter = 21,
        EventExp = 22,
        EventLevel = 23,
        EventCard = 24,
        EventAdvanced = 25,
        Shells = 26,
        LostPearls = 27,
        ChalkStick = 28,
        GoldenBrick = 29,
        Bats = 30,
        GoldenPumpkins = 31,
        HalloweenCandy = 32,
        FallLeaves = 33,
        GoldenAcorns = 34,
        TurkeyTokens = 35,
        Giblets = 36,
        GoldenTurkeys = 37,
        Snowballs = 38,
        GoldenBells = 39,
        Snowflakes = 40,
        Fireworks = 41,
        GoldenPartyHats = 42,
        CosmicDust = 43,
        FallenStar = 44,
        Points = 45,
        Claws = 46,
        LuckyCharms = 47,
        MagicToken = 8,
        FriendGoldAdd = 7001,
        FriendLuckAdd = 7002,
        PetSlotAdd = 7003,
        PetStorage = 7004,
        SouvenirBagSize = 7005,
        JumpPulAdd = 7006,
        NewJumpPulAdd = 7007,
    },
    
    -- Game passes
    gamePasses = {
        FastHatch = "Fast-Hatch",
        Luck = "Luck",
        SuperLuck = "Super-Luck",
        UltraLuck = "Ultra-Luck",
        TripleHatch = "Triple-Hatch",
        MoreEquip = "More-Equip",
        VIP = "VIP",
        MoreGold = "More-Gold",
        AutoHatch = "Auto-Hatch",
        TwoXWin = "2XWin",
        SecretLucky2 = "SecretLucky2",
        AutoCollect = "AutoCollect",
        JumpPalPass = "JumpPalPass",
        TwoXSpeed = "2XSpeed",
        TenfoldHatch = "Tenfold-Hatch",
        MoreStorage10 = "More-Storage10",
        SuperSecretLucky = "SuperSecretLucky",
    },
    
    -- Buffs
    buffs = {
        Lucky = 101,
        GoldAdd = 201,
        SecretLucky = 601,
        Speed = 701,
        Wins = 801,
    },
    
    -- Remote cooldowns (in seconds) dari traffic analysis
    cooldowns = {
        JumpResults = 0.3,
        TeleportMe = 0.5,
        Setting = 0.1,
        Analytics = 0.5,
        GameAnalyticsError = 0.1,
        UpdateLocalData = 0.2,
    },
}

-- ============================
-- Helper Functions
-- ============================
local function getWorldConfig(worldId)
    return configs.worlds[worldId] or configs.worlds[1]
end

local function getCurrentWorld()
    local nowWorld = player:FindFirstChild("NowWorld")
    if nowWorld then
        return tonumber(nowWorld.Value) or 1
    end
    return 1
end

local function getMaxWorld()
    local unlockWorld = player:FindFirstChild("UnlockWorld")
    if unlockWorld then
        return tonumber(unlockWorld.Value) or 1
    end
    return 1
end

local function getWalkSpeed()
    local speed = configs.walkSpeed
    -- Check if VIP
    local gamePass = player:FindFirstChild("GamePass")
    if gamePass and gamePass:FindFirstChild("VIP") and gamePass.VIP.Value == 1 then
        speed = configs.vipWalkSpeed
    end
    -- Check buffs
    local buffFolder = player:FindFirstChild("BUFF")
    if buffFolder then
        local speedBuff = buffFolder:FindFirstChild(tostring(configs.buffs.Speed))
        if speedBuff then
            speed = speed + speedBuff.Value * 0.01 * speed
        end
    end
    return speed
end

local function getFlySpeed()
    local speed = getWalkSpeed()
    local worldId = getCurrentWorld()
    local world = getWorldConfig(worldId)
    return speed * world.speedComp
end

-- ============================
-- Main Automation Class
-- ============================
local RennHub = {
    isRunning = false,
    isAutoClimb = false,
    isSpeedBypass = false,
    isAutoCollect = false,
    isAutoHatch = false,
    isAutoPetEquip = false,
    isAutoShop = false,
    
    climbLoop = nil,
    speedLoop = nil,
    collectLoop = nil,
    
    connections = {},
}

-- ============================
-- Auto Climb Logic
-- ============================
function RennHub:startAutoClimb()
    if self.isAutoClimb then return end
    self.isAutoClimb = true
    
    -- Get remotes
    local proMsg = getRemote("ProMgs.RemoteEvent")
    local jumpResults = getRemote("ProMgs.RemoteEvent")
    local teleportMe = getRemote("Msg.RemoteEvent") -- TeleportMe is in Msg.RemoteEvent
    
    -- Climb loop
    self.climbLoop = RunService.Heartbeat:Connect(function(deltaTime)
        if not self.isAutoClimb then return end
        
        local character = player.Character
        if not character then return end
        
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        -- Get current position
        local position = rootPart.Position
        local yPos = position.Y
        
        -- Get world info
        local worldId = getCurrentWorld()
        local world = getWorldConfig(worldId)
        local maxWorld = getMaxWorld()
        
        -- Calculate climb distance
        local climbSpeed = getFlySpeed()
        local distance = climbSpeed * deltaTime
        
        -- Send jump results to server
        if jumpResults and jumpResults:IsA("RemoteEvent") then
            local jumpData = {
                8088970804309, -- random seed
                0.2414940595626831, -- distance
            }
            jumpResults:FireServer("JumpResults", unpack(jumpData))
        end
        
        -- Update position via TeleportMe
        if teleportMe and teleportMe:IsA("RemoteEvent") then
            local newY = yPos + distance
            local newCFrame = CFrame.new(position.X, newY, position.Z)
            teleportMe:FireServer("TeleportMe", newCFrame)
        end
        
        -- Update local data
        local updateLocal = getRemote("ServerMsg.UpdateLocalData")
        if updateLocal and updateLocal:IsA("RemoteEvent") then
            updateLocal:FireServer("update", os.time())
        end
        
        -- Check if reached top
        local floor = world.floor or 14400
        if yPos >= floor then
            -- Reached top, reset or move to next world
            if worldId < maxWorld then
                -- Move to next world
                local nowWorld = player:FindFirstChild("NowWorld")
                if nowWorld then
                    nowWorld.Value = worldId + 1
                end
            else
                -- Reset to bottom
                if teleportMe and teleportMe:IsA("RemoteEvent") then
                    teleportMe:FireServer("TeleportMe", CFrame.new(position.X, 0, position.Z))
                end
            end
        end
        
        -- Simulate cooldown dari config
        task.wait(configs.cooldowns.JumpResults)
    end)
end

function RennHub:stopAutoClimb()
    self.isAutoClimb = false
    if self.climbLoop then
        self.climbLoop:Disconnect()
        self.climbLoop = nil
    end
end

-- ============================
-- Speed Bypass Logic
-- ============================
function RennHub:startSpeedBypass()
    if self.isSpeedBypass then return end
    self.isSpeedBypass = true
    
    -- Speed bypass menggunakan setting isAutoOn dan isAutoCllect
    local settingRemote = getRemote("ServerMsg.Setting")
    
    -- Set auto on
    if settingRemote and settingRemote:IsA("RemoteFunction") then
        settingRemote:InvokeServer("isAutoOn", 1)
        settingRemote:InvokeServer("isAutoCllect", 1)
    end
    
    -- Speed loop untuk bypass speed limit
    self.speedLoop = RunService.Heartbeat:Connect(function()
        if not self.isSpeedBypass then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        -- Bypass speed dengan memodifikasi WalkSpeed secara langsung
        -- Ini akan di-override oleh server, tapi kita terus set ulang
        local maxSpeed = 50 -- Bypass limit
        if humanoid.WalkSpeed < maxSpeed then
            humanoid.WalkSpeed = maxSpeed
        end
        
        -- Bypass jump power
        if humanoid.JumpPower < 100 then
            humanoid.JumpPower = 100
        end
        
        -- Update setting periodically
        if settingRemote and settingRemote:IsA("RemoteFunction") then
            pcall(function()
                settingRemote:InvokeServer("isAutoOn", 1)
            end)
        end
        
        task.wait(0.5)
    end)
end

function RennHub:stopSpeedBypass()
    self.isSpeedBypass = false
    if self.speedLoop then
        self.speedLoop:Disconnect()
        self.speedLoop = nil
    end
    
    -- Reset settings
    local settingRemote = getRemote("ServerMsg.Setting")
    if settingRemote and settingRemote:IsA("RemoteFunction") then
        pcall(function()
            settingRemote:InvokeServer("isAutoOn", 0)
            settingRemote:InvokeServer("isAutoCllect", 0)
        end)
    end
end

-- ============================
-- Auto Collect Logic
-- ============================
function RennHub:startAutoCollect()
    if self.isAutoCollect then return end
    self.isAutoCollect = true
    
    local claimReward = getRemote("ClaimEventReward")
    local showItems = getRemote("ServerMsg.showItems")
    local updateLocal = getRemote("ServerMsg.UpdateLocalData")
    
    self.collectLoop = RunService.Heartbeat:Connect(function()
        if not self.isAutoCollect then return end
        
        -- Claim event rewards
        if claimReward and claimReward:IsA("RemoteEvent") then
            pcall(function()
                claimReward:FireServer()
            end)
        end
        
        -- Update local data to sync
        if updateLocal and updateLocal:IsA("RemoteEvent") then
            pcall(function()
                updateLocal:FireServer()
            end)
        end
        
        -- Show items to refresh UI
        if showItems and showItems:IsA("RemoteEvent") then
            pcall(function()
                showItems:FireServer(player, {})
            end)
        end
        
        task.wait(1)
    end)
end

function RennHub:stopAutoCollect()
    self.isAutoCollect = false
    if self.collectLoop then
        self.collectLoop:Disconnect()
        self.collectLoop = nil
    end
end

-- ============================
-- Auto Hatch Logic
-- ============================
function RennHub:startAutoHatch()
    if self.isAutoHatch then return end
    self.isAutoHatch = true
    
    local drawUp = getRemote("Tool.DrawUp.Msg.DrawHero")
    local drawPet = getRemote("Tool.DrawUp.Msg.DrawPet")
    local drawSpecialEgg = getRemote("ServerMsg.drawSpecialEgg")
    
    -- Egg IDs dari config
    local eggs = {
        { id = 7000001, name = "Egg1" },
        { id = 7000002, name = "Egg2" },
        { id = 7000003, name = "Egg3" },
        { id = 7000004, name = "Egg4" },
        { id = 7000005, name = "Egg5" },
        { id = 7000006, name = "Egg6" },
        { id = 7000007, name = "Egg7" },
        { id = 7000008, name = "Egg8" },
        { id = 7000009, name = "Egg9" },
        { id = 7000010, name = "Egg10" },
        { id = 7000011, name = "Egg11" },
        { id = 7000012, name = "Egg12" },
        { id = 7000013, name = "Egg13" },
        { id = 7000014, name = "Egg14" },
        { id = 7000015, name = "Egg15" },
        { id = 7000016, name = "Egg16" },
        { id = 7000017, name = "Egg17" },
        { id = 7000018, name = "Egg18" },
        { id = 7000019, name = "Egg19" },
        { id = 7000020, name = "Egg20" },
        { id = 7000021, name = "Egg21" },
        { id = 7000022, name = "Egg22" },
        { id = 7000023, name = "Egg23" },
    }
    
    local currentEggIndex = 1
    
    self.hatchLoop = RunService.Heartbeat:Connect(function()
        if not self.isAutoHatch then return end
        
        local egg = eggs[currentEggIndex]
        if not egg then
            currentEggIndex = 1
            egg = eggs[1]
        end
        
        -- Draw hero (hatch egg)
        if drawUp and drawUp:IsA("RemoteEvent") then
            pcall(function()
                drawUp:FireServer(egg.id)
            end)
        end
        
        -- Draw pet
        if drawPet and drawPet:IsA("RemoteEvent") then
            pcall(function()
                drawPet:FireServer(egg.id)
            end)
        end
        
        -- Draw special egg
        if drawSpecialEgg and drawSpecialEgg:IsA("RemoteEvent") then
            pcall(function()
                drawSpecialEgg:FireServer(egg.id)
            end)
        end
        
        -- Move to next egg
        currentEggIndex = currentEggIndex + 1
        if currentEggIndex > #eggs then
            currentEggIndex = 1
        end
        
        task.wait(0.5)
    end)
end

function RennHub:stopAutoHatch()
    self.isAutoHatch = false
    if self.hatchLoop then
        self.hatchLoop:Disconnect()
        self.hatchLoop = nil
    end
end

-- ============================
-- Auto Pet Equip Logic
-- ============================
function RennHub:startAutoPetEquip()
    if self.isAutoPetEquip then return end
    self.isAutoPetEquip = true
    
    local petSystem = require(ReplicatedStorage.System.SystemPet)
    local bagSystem = require(ReplicatedStorage.System.SystemBag)
    
    self.petEquipLoop = RunService.Heartbeat:Connect(function()
        if not self.isAutoPetEquip then return end
        
        -- Get all pets from bag
        local petData = ReplicatedStorage:FindFirstChild("System") and ReplicatedStorage.System:FindFirstChild("SystemSave")
        if petData then
            -- Equip best pets
            pcall(function()
                if petSystem and petSystem.WearBest then
                    petSystem.WearBest(player)
                end
            end)
        end
        
        task.wait(2)
    end)
end

function RennHub:stopAutoPetEquip()
    self.isAutoPetEquip = false
    if self.petEquipLoop then
        self.petEquipLoop:Disconnect()
        self.petEquipLoop = nil
    end
end

-- ============================
-- UI System
-- ============================
function RennHub:createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RennHub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui
    
    -- Main Window
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    -- Glassmorphism effect
    local glass = Instance.new("Frame")
    glass.Size = UDim2.new(1, 0, 1, 0)
    glass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glass.BackgroundTransparency = 0.95
    glass.BorderSizePixel = 0
    glass.Parent = mainFrame
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = mainFrame
    
    -- Shadow
    local shadow = Instance.new("UIStroke")
    shadow.Color = Color3.fromRGB(100, 100, 255)
    shadow.Thickness = 2
    shadow.Transparency = 0.5
    shadow.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Renn Hub"
    title.TextColor3 = Color3.fromRGB(150, 150, 255)
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    -- Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 1, 0)
    minBtn.Position = UDim2.new(0.85, 0, 0, 0)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "_"
    minBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minBtn.TextSize = 20
    minBtn.Font = Enum.Font.GothamBold
    minBtn.Parent = titleBar
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 1, 0)
    closeBtn.Position = UDim2.new(0.92, 0, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    -- Content (Scrolling Frame)
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
    contentFrame.ScrollBarThickness = 4
    contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 200)
    contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentFrame.Parent = mainFrame
    
    -- UIListLayout untuk content
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = contentFrame
    
    -- ============================
    -- UI Elements
    -- ============================
    local function createToggle(parent, labelText, initialValue, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 35)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 5, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(220, 220, 230)
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.Parent = frame
        
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 50, 0, 25)
        toggleBtn.Position = UDim2.new(0.8, 0, 0.5, -12.5)
        toggleBtn.BackgroundColor3 = initialValue and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 80)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Text = initialValue and "ON" or "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.TextSize = 12
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Parent = frame
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 12)
        toggleCorner.Parent = toggleBtn
        
        local state = initialValue
        
        toggleBtn.MouseButton1Click:Connect(function()
            state = not state
            toggleBtn.BackgroundColor3 = state and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 80)
            toggleBtn.Text = state and "ON" or "OFF"
            callback(state)
        end)
        
        return {
            setState = function(newState)
                state = newState
                toggleBtn.BackgroundColor3 = state and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 80)
                toggleBtn.Text = state and "ON" or "OFF"
            end,
            getState = function() return state end
        }
    end
    
    local function createButton(parent, labelText, color, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 35)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundColor3 = color or Color3.fromRGB(60, 60, 120)
        btn.BorderSizePixel = 0
        btn.Text = labelText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.Parent = frame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
    end
    
    -- Section: Auto Farm
    local autoFarmHeader = Instance.new("TextLabel")
    autoFarmHeader.Size = UDim2.new(1, 0, 0, 25)
    autoFarmHeader.BackgroundTransparency = 1
    autoFarmHeader.Text = "═ Auto Farm ═"
    autoFarmHeader.TextColor3 = Color3.fromRGB(150, 150, 255)
    autoFarmHeader.TextSize = 14
    autoFarmHeader.Font = Enum.Font.GothamBold
    autoFarmHeader.Parent = contentFrame
    
    -- Auto Climb Toggle
    local climbToggle = createToggle(contentFrame, "Auto Climb", false, function(state)
        if state then
            RennHub:startAutoClimb()
        else
            RennHub:stopAutoClimb()
        end
    end)
    
    -- Auto Collect Toggle
    local collectToggle = createToggle(contentFrame, "Auto Collect", false, function(state)
        if state then
            RennHub:startAutoCollect()
        else
            RennHub:stopAutoCollect()
        end
    end)
    
    -- Section: Bypass
    local bypassHeader = Instance.new("TextLabel")
    bypassHeader.Size = UDim2.new(1, 0, 0, 25)
    bypassHeader.BackgroundTransparency = 1
    bypassHeader.Text = "═ Speed Bypass ═"
    bypassHeader.TextColor3 = Color3.fromRGB(255, 150, 100)
    bypassHeader.TextSize = 14
    bypassHeader.Font = Enum.Font.GothamBold
    bypassHeader.Parent = contentFrame
    
    -- Speed Bypass Toggle
    local speedToggle = createToggle(contentFrame, "Speed Bypass", false, function(state)
        if state then
            RennHub:startSpeedBypass()
        else
            RennHub:stopSpeedBypass()
        end
    end)
    
    -- Section: Auto Hatch
    local hatchHeader = Instance.new("TextLabel")
    hatchHeader.Size = UDim2.new(1, 0, 0, 25)
    hatchHeader.BackgroundTransparency = 1
    hatchHeader.Text = "═ Auto Hatch ═"
    hatchHeader.TextColor3 = Color3.fromRGB(100, 255, 150)
    hatchHeader.TextSize = 14
    hatchHeader.Font = Enum.Font.GothamBold
    hatchHeader.Parent = contentFrame
    
    -- Auto Hatch Toggle
    local hatchToggle = createToggle(contentFrame, "Auto Hatch", false, function(state)
        if state then
            RennHub:startAutoHatch()
        else
            RennHub:stopAutoHatch()
        end
    end)
    
    -- Auto Pet Equip Toggle
    local petEquipToggle = createToggle(contentFrame, "Auto Pet Equip", false, function(state)
        if state then
            RennHub:startAutoPetEquip()
        else
            RennHub:stopAutoPetEquip()
        end
    end)
    
    -- Section: Tools
    local toolsHeader = Instance.new("TextLabel")
    toolsHeader.Size = UDim2.new(1, 0, 0, 25)
    toolsHeader.BackgroundTransparency = 1
    toolsHeader.Text = "═ Tools ═"
    toolsHeader.TextColor3 = Color3.fromRGB(255, 255, 100)
    toolsHeader.TextSize = 14
    toolsHeader.Font = Enum.Font.GothamBold
    toolsHeader.Parent = contentFrame
    
    -- Get World Info Button
    createButton(contentFrame, "Get World Info", Color3.fromRGB(60, 60, 120), function()
        local worldId = getCurrentWorld()
        local maxWorld = getMaxWorld()
        local speed = getFlySpeed()
        local walkSpeed = getWalkSpeed()
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "World Info",
            Text = string.format(
                "Current World: %d\nMax World: %d\nFly Speed: %.2f\nWalk Speed: %.2f",
                worldId, maxWorld, speed, walkSpeed
            ),
            Duration = 5,
        })
    end)
    
    -- Get Stats Button
    createButton(contentFrame, "Get Player Stats", Color3.fromRGB(60, 120, 60), function()
        local bag = player:FindFirstChild("Bag")
        if bag then
            local coin = bag:FindFirstChild(tostring(configs.itemIDs.Coin))
            local wins = bag:FindFirstChild(tostring(configs.itemIDs.Wins))
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Player Stats",
                Text = string.format(
                    "Coins: %s\nWins: %s",
                    coin and coin.Value or 0,
                    wins and wins.Value or 0
                ),
                Duration = 5,
            })
        end
    end)
    
    -- Anti-Kick/Detection Bypass
    createButton(contentFrame, "Bypass Anti-Kick", Color3.fromRGB(120, 60, 60), function()
        -- Send harmless GameAnalyticsError to confuse detection
        local gameAnalyticsError = getRemote("GameAnalyticsError")
        if gameAnalyticsError and gameAnalyticsError:IsA("RemoteEvent") then
            for i = 1, 5 do
                pcall(function()
                    gameAnalyticsError:FireServer(
                        "Workspace.RennDev001.LocalPets:61: missing argument #1",
                        "Workspace.RennDev001.LocalPets, line 61 - function showPet\nWorkspace.RennDev001.LocalPets, line 255 - function updateAllPet\nWorkspace.RennDev001.LocalPets, line 274\n",
                        "Workspace.RennDev001.LocalPets"
                    )
                end)
                task.wait(0.1)
            end
        end
        
        -- Disable some integrity checks
        local integrityCheck1 = getRemote("RobloxReplicatedStorage.IntegrityCheckProcessorKey2_LocalizationTableAnalyticsSender_LocalizationService")
        local integrityCheck2 = getRemote("RobloxReplicatedStorage.IntegrityCheckProcessorKey2_DynamicTranslationSender_LocalizationService")
        
        if integrityCheck1 and integrityCheck1:IsA("RemoteEvent") then
            pcall(function()
                integrityCheck1:FireServer()
            end)
        end
        if integrityCheck2 and integrityCheck2:IsA("RemoteEvent") then
            pcall(function()
                integrityCheck2:FireServer()
            end)
        end
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Bypass",
            Text = "Anti-Kick bypass activated!",
            Duration = 3,
        })
    end)
    
    -- ============================
    -- Window Controls
    -- ============================
    local minimized = false
    local originalSize = mainFrame.Size
    
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            mainFrame.Size = UDim2.new(0, 350, 0, 40)
            contentFrame.Visible = false
            minBtn.Text = "□"
        else
            mainFrame.Size = originalSize
            contentFrame.Visible = true
            minBtn.Text = "_"
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        -- Stop all loops
        RennHub:stopAutoClimb()
        RennHub:stopSpeedBypass()
        RennHub:stopAutoCollect()
        RennHub:stopAutoHatch()
        RennHub:stopAutoPetEquip()
        
        screenGui:Destroy()
    end)
    
    -- ============================
    -- Mobile Compatible - Touch Drag
    -- ============================
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    return screenGui
end

-- ============================
-- Initialize
-- ============================
local function init()
    -- Wait for player to be ready
    repeat
        task.wait()
    until player and player.Character
    
    -- Create UI
    local gui = RennHub:createUI()
    
    -- Prevent detection by sending periodic harmless traffic
    local antiDetectLoop = RunService.Heartbeat:Connect(function()
        if not RennHub.isRunning then return end
        
        -- Send Analytics periodically to appear "normal"
        local analytics = getRemote("ServerMsg.Analytics")
        if analytics and analytics:IsA("RemoteEvent") then
            pcall(function()
                analytics:FireServer(1, "FTUE", { Step = "ClimbTower" })
            end)
        end
        
        -- Send UpdateLocalData periodically
        local updateLocal = getRemote("ServerMsg.UpdateLocalData")
        if updateLocal and updateLocal:IsA("RemoteEvent") then
            pcall(function()
                updateLocal:FireServer()
            end)
        end
    end)
    
    RennHub.isRunning = true
    
    -- Cleanup on game close
    game:BindToClose(function()
        RennHub.isRunning = false
        if antiDetectLoop then
            antiDetectLoop:Disconnect()
        end
        RennHub:stopAutoClimb()
        RennHub:stopSpeedBypass()
        RennHub:stopAutoCollect()
        RennHub:stopAutoHatch()
        RennHub:stopAutoPetEquip()
    end)
    
    print("Renn Hub Loaded Successfully!")
end

-- Safety: Load after player is ready
if player and player.Character then
    init()
else
    player.CharacterAdded:Wait()
    init()
end

-- ============================
-- Feature List (Dari Analisis)
-- ============================
-- 1. Auto Climb - Menggunakan JumpResults dan TeleportMe untuk climb otomatis
-- 2. Speed Bypass - Memodifikasi WalkSpeed dan menggunakan isAutoOn
-- 3. Auto Collect - Mengambil reward dari event
-- 4. Auto Hatch - Menetas telur otomatis (semua tipe egg)
-- 5. Auto Pet Equip - Equip pet terbaik
-- 6. Bypass Anti-Kick - Mengirim GameAnalyticsError untuk confuse detection
-- 7. World Info - Mendapatkan informasi world saat ini
-- 8. Player Stats - Melihat coin dan wins
-- 9. Anti-Detection Loop - Mengirim traffic normal secara periodik