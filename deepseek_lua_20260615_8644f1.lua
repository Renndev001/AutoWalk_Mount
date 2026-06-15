--[[
    Renn Hub - Advanced Automation Script for Blade Ball
    Compatibility: Mobile & PC (Drag/Drop, Minimizable, Scrollable UI)
    Features: Auto Parry (AI prediction), Auto Claim Rewards, Auto Spin, Auto Upgrade, etc.
    Based on extracted configs & network traffic.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInput = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Remote paths (from Blueprint & Traffic)
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local Net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net

-- Helper to safely fire remotes
local function fireRemote(remotePath, ...)
    local remote = Remotes and Remotes:FindFirstChild(remotePath)
    if remote then
        remote:FireServer(...)
        return true
    end
    if Net then
        local netRemote = Net[remotePath]
        if netRemote then
            netRemote:FireServer(...)
            return true
        end
    end
    warn("Remote not found: " .. tostring(remotePath))
    return false
end

local function invokeRemote(remotePath, ...)
    local remote = Remotes and Remotes:FindFirstChild(remotePath)
    if remote then
        return remote:InvokeServer(...)
    end
    if Net then
        local netRemote = Net[remotePath]
        if netRemote then
            return netRemote:InvokeServer(...)
        end
    end
    warn("Invoke remote not found: " .. tostring(remotePath))
end

-- Cooldown management
local cooldowns = {}
local function canUse(key, cd)
    local last = cooldowns[key] or 0
    if tick() - last >= cd then
        cooldowns[key] = tick()
        return true
    end
    return false
end

-- ========================= UI Setup =========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RennHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 380, 0, 500)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Title bar (drag handle)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Renn Hub"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 18
titleText.Parent = titleBar

-- Minimize button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 1, 0)
minimizeBtn.Position = UDim2.new(1, -30, 0, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.new(1,1,1)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.Parent = titleBar

-- Scrollable container
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -30)
scrollFrame.Position = UDim2.new(0, 0, 0, 30)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.Parent = scrollFrame
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0, 8)

-- Helper to create sections
local function createSection(title, order)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -16, 0, 40)
    section.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    section.BorderSizePixel = 0
    section.LayoutOrder = order
    section.Parent = scrollFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Padding = UDim.new(0, 8)
    titleLabel.Parent = section
    
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = section
    
    section.Content = content
    return content
end

local function createToggle(parent, text, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -16, 0, 35)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.Parent = frame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 25)
    toggleBtn.Position = UDim2.new(1, -55, 0.5, -12.5)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    toggleBtn.Text = "OFF"
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Parent = frame
    
    local enabled = false
    toggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80,80,90)
        toggleBtn.Text = enabled and "ON" or "OFF"
        callback(enabled)
    end)
    return toggleBtn
end

local function createButton(parent, text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 35)
    btn.LayoutOrder = order
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.Parent = parent
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- ========================= Core Features =========================
-- Auto Parry
local autoParryEnabled = false
local parryCooldown = 1.3  -- from VisualCD delay in traffic
local lastParryTime = 0

local function getBalls()
    local balls = {}
    local ballsContainer = Workspace:FindFirstChild("Balls")
    if ballsContainer then
        for _, ball in ipairs(ballsContainer:GetChildren()) do
            if ball:IsA("BasePart") then
                table.insert(balls, ball)
            end
        end
    end
    local trainingBalls = Workspace:FindFirstChild("TrainingBalls")
    if trainingBalls then
        for _, ball in ipairs(trainingBalls:GetChildren()) do
            if ball:IsA("BasePart") then
                table.insert(balls, ball)
            end
        end
    end
    return balls
end

local function isBallComingToPlayer(ball, playerPos)
    -- Simple prediction: check if ball's velocity direction points roughly towards player
    local ballVel = ball.AssemblyLinearVelocity
    if ballVel.Magnitude < 5 then return false end
    local dirToPlayer = (playerPos - ball.Position).Unit
    local velDir = ballVel.Unit
    local dot = dirToPlayer:Dot(velDir)
    -- if ball moving towards player (dot > 0) and distance is within threshold
    local distance = (ball.Position - playerPos).Magnitude
    return dot > 0.3 and distance < 25
end

local function parry()
    if not autoParryEnabled then return end
    if tick() - lastParryTime < parryCooldown then return end
    -- Find closest ball that is coming towards player
    local playerPos = rootPart.Position
    local bestBall = nil
    local bestScore = math.huge
    for _, ball in ipairs(getBalls()) do
        if isBallComingToPlayer(ball, playerPos) then
            local dist = (ball.Position - playerPos).Magnitude
            if dist < bestScore then
                bestScore = dist
                bestBall = ball
            end
        end
    end
    if bestBall then
        -- Fire parry attempt
        fireRemote("ParryAttempt", bestBall:FindFirstChild("ParticleShine") or bestBall)
        fireRemote("ParryAttemptAll", bestBall:FindFirstChild("ParticleShine") or bestBall, character)
        lastParryTime = tick()
        -- Optional: Send VisualCD to sync cooldown
        fireRemote("VisualCD", true, true, parryCooldown)
    end
end

-- Auto claim functions (based on discovered remotes)
local function claimDailyRewards()
    fireRemote("ClaimDailyChest")
    fireRemote("ClaimDailyQuest")
    fireRemote("ClaimTournamentReward")
    fireRemote("ClaimRankedLeaderboardReward")
    fireRemote("ClaimLTMStreak")
    fireRemote("ClaimTournamentStreak")
    fireRemote("ClaimPlaytimeReward")
    fireRemote("ClaimSeasonPlaytimeReward")
    fireRemote("ClaimProgressiveReward")
    -- For events
    fireRemote("ChristmasEvent_ClaimDailyLogin")
    fireRemote("CNYEvent_ClaimDailyLogin")
    fireRemote("ClaimEasterDailyStreak")
end

local function claimAllQuests()
    invokeRemote("ClaimAllQuests") or fireRemote("ClaimAllQuests")
    invokeRemote("RedeemAllQuests") or fireRemote("RedeemAllQuests")
end

local function spinWheel(wheelType)
    if wheelType == "Hourly" then
        fireRemote("HourlyWheel/ProcessRoll")
        fireRemote("HourlyWheel/ClaimReward")
    elseif wheelType == "Synth" then
        fireRemote("SynthWheel/ProcessRoll")
        fireRemote("SynthWheel/ClaimReward")
    elseif wheelType == "Summer" then
        fireRemote("SummerWheel/ProcessRoll")
    elseif wheelType == "Easter" then
        fireRemote("EasterWheel/ProcessRoll")
    else
        fireRemote("ProcessLTMRoll")
    end
end

local function openCrates()
    fireRemote("OpenCrate")  -- generic
    fireRemote("OpenPremiumCrate")
    fireRemote("OpenSwordBox")
    fireRemote("OpenPremiumSwordCrate")
    fireRemote("OpenSealCrate")
    fireRemote("OpenGenericCrate")
    fireRemote("OpenGenericCoinCrate")
    fireRemote("OpenReturnCrate")
    fireRemote("ClanCratePurchase")
end

local function upgradeAbilities()
    invokeRemote("RequestAbilityUpgrade") or fireRemote("RequestAbilityUpgrade")
    fireRemote("RequestUpgradeAbility")
end

local function equipBestSword()
    -- Fetch owned swords from Inventory module (simplified: just call equip remote)
    fireRemote("RequestEquipSwordSkin", "BestSword") -- actual name would need inventory check
end

-- Auto spin gacha (example for OwlGacha)
local function spinGacha(gachaName, amount)
    if gachaName == "OwlGacha" then
        for _ = 1, amount do
            fireRemote("GenericGachaFTPSpin", "OwlGacha")
            task.wait(0.5)
        end
    elseif gachaName == "BlossomGacha" then
        for _ = 1, amount do
            fireRemote("GenericGachaFTPSpin", "BlossomGacha")
            task.wait(0.5)
        end
    else
        fireRemote("GenericGachaFTPSpin", gachaName)
    end
end

-- Auto farming loop (claim rewards periodically)
local farmLoopRunning = false
local function startFarmLoop()
    task.spawn(function()
        while farmLoopRunning do
            claimDailyRewards()
            claimAllQuests()
            spinWheel("Hourly")
            spinWheel("Synth")
            openCrates()
            upgradeAbilities()
            task.wait(300) -- every 5 minutes
        end
    end)
end

-- ========================= UI Building =========================
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Combat Tab
local combatTab = createSection("⚔️ Combat", 1)
createToggle(combatTab, "Auto Parry (Smart)", 1, function(state)
    autoParryEnabled = state
    if state then
        -- start parry loop
        task.spawn(function()
            while autoParryEnabled do
                parry()
                task.wait(0.05)
            end
        end)
    end
end)

createToggle(combatTab, "Auto Block (Alternative)", 2, function(state)
    -- same as parry for simplicity
    autoParryEnabled = state
end)

createButton(combatTab, "Force Parry Now", 3, function()
    parry()
end)

-- Auto Farm Tab
local farmTab = createSection("💰 Auto Farm", 2)
createToggle(farmTab, "Auto Claim All Rewards", 1, function(state)
    farmLoopRunning = state
    if state then startFarmLoop() end
end)

createButton(farmTab, "Claim Daily Rewards Now", 2, claimDailyRewards)
createButton(farmTab, "Claim All Quests", 3, claimAllQuests)
createButton(farmTab, "Open All Crates", 4, openCrates)
createButton(farmTab, "Upgrade Abilities", 5, upgradeAbilities)

-- Gacha Tab
local gachaTab = createSection("🎰 Gacha & Spin", 3)
createButton(gachaTab, "Spin Hourly Wheel", 1, function() spinWheel("Hourly") end)
createButton(gachaTab, "Spin Synth Wheel", 2, function() spinWheel("Synth") end)
createButton(gachaTab, "Spin Easter Wheel", 3, function() spinWheel("Easter") end)
createButton(gachaTab, "Open Owl Gacha (1x)", 4, function() spinGacha("OwlGacha", 1) end)
createButton(gachaTab, "Open Owl Gacha (10x)", 5, function() spinGacha("OwlGacha", 10) end)

-- Misc Tab
local miscTab = createSection("🔧 Misc", 4)
createButton(miscTab, "Rejoin Ranked Match", 1, function()
    fireRemote("RejoinRankedMatch")
end)
createButton(miscTab, "Teleport to Training", 2, function()
    invokeRemote("JoinTrainingServer")
end)
createButton(miscTab, "Equip Best Sword", 3, equipBestSword)

-- Minimize functionality
local minimized = false
local originalSize = mainFrame.Size
local originalPos = mainFrame.Position
minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mainFrame:TweenSize(UDim2.new(0, 380, 0, 40), "Out", "Quad", 0.2, true)
        scrollFrame.Visible = false
        minimizeBtn.Text = "+"
    else
        mainFrame:TweenSize(originalSize, "Out", "Quad", 0.2, true)
        scrollFrame.Visible = true
        minimizeBtn.Text = "-"
    end
end)

-- Auto-resize canvas
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 10)
end)

-- Drag functionality (since draggable is true, built-in)
mainFrame.Draggable = true

-- ========================= Initialization =========================
print("Renn Hub Loaded | Features: Auto Parry, Auto Farm, Gacha Spinner")

-- Optional: Hook into ball detection for better parry (listen to BallAdded)
Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Balls" or child.Name == "TrainingBalls" then
        child.ChildAdded:Connect(function(ball)
            if autoParryEnabled then
                -- immediate check if ball is dangerous
                task.wait(0.1)
                parry()
            end
        end)
    end
end)

-- Keep character reference updated
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    rootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Anti-AFK (optional: move camera slightly or send input)
task.spawn(function()
    while true do
        task.wait(60)
        VirtualInput:SendMouseMove(Vector2.new(0, 0), 0)
    end
end)

-- Done
return screenGui