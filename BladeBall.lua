-- Renn Hub - Blade Ball OP Script
-- Compatible with Delta executor (mobile)
-- Features: Auto Parry, Auto Claim, Auto Spin, Auto Farm, Anti-AFK, UI with drag & scroll

-- // Load services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = (syn and syn.input) or (getrenv and getrenv().VirtualInputManager) or nil

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- // Remote paths (from Blueprint)
local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
local remotes = ReplicatedStorage:FindFirstChild("Remotes")

local ParryAttempt = net and net["ParryAttempt"] or (remotes and remotes.ParryAttempt)
local ParryAttemptAll = net and net["ParryAttemptAll"] or (remotes and remotes.ParryAttemptAll)
local ActivateAbility = remotes and remotes.ActivateAbility
local RequestAbilityUse = remotes and remotes.RequestAbilityUse
local ClaimDailyQuest = net and net["RE/ClaimDailyQuest"]
local ClaimTournamentReward = net and net["RE/ClaimTournamentReward"]
local ClaimPlaytimeReward = net and net["RF/ClaimPlaytimeReward"]
local BuySpinCoins = remotes and remotes.BuySpinCoins
local OpenCrate = remotes and remotes.OpenCrate
local RequestCrateOpen = remotes and remotes.RequestCrateOpen
local ClientPulse = remotes and remotes.ClientPulse
local UpdateSpectateCount = remotes and remotes.UpdateSpectateCount

-- // Fallback if remotes not found
local function getRemote(name)
    local remote = net and net[name] or (remotes and remotes[name])
    if not remote then
        warn("Remote not found: " .. name)
    end
    return remote
end

-- // Settings
local settings = {
    autoParry = false,
    autoClaim = false,
    autoSpin = false,
    autoFarm = false,
    antiAFK = false,
    parryRadius = 18,
    parryCooldown = 1.35, -- from VisualCD
    spinCooldown = 0.5,
    farmInterval = 2,
}

-- // Utility functions
local function fireRemote(remote, ...)
    if remote and remote.FireServer then
        remote:FireServer(...)
    elseif remote and remote.InvokeServer then
        remote:InvokeServer(...)
    end
end

-- // Anti-AFK (send pulse every 30s)
task.spawn(function()
    while task.wait(30) do
        if settings.antiAFK then
            fireRemote(ClientPulse)
            fireRemote(UpdateSpectateCount, 1)
            -- simulate mouse movement if possible
            if VirtualInputManager then
                VirtualInputManager:SendMouseMoveEvent(100, 100, true)
            end
        end
    end
end)

-- // Auto Parry : detects ball within radius and parries
task.spawn(function()
    local lastParry = 0
    while task.wait(0.1) do
        if not settings.autoParry then continue end
        if tick() - lastParry < settings.parryCooldown then continue end
        
        local balls = Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("TrainingBalls")
        if not balls then continue end
        
        local nearestBall = nil
        local nearestDist = settings.parryRadius
        for _, ball in ipairs(balls:GetChildren()) do
            if ball:IsA("BasePart") and ball.Parent ~= character then
                local dist = (ball.Position - humanoidRootPart.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestBall = ball
                end
            end
        end
        
        if nearestBall then
            -- Attempt parry via remote
            fireRemote(ParryAttempt, nil) -- some games require particle object, try nil
            fireRemote(ParryAttemptAll, nil, player.Character)
            -- Also activate Block ability if needed
            fireRemote(ActivateAbility, "Block")
            lastParry = tick()
        end
    end
end)

-- // Auto Claim Rewards (daily, tournament, playtime)
task.spawn(function()
    while task.wait(60) do
        if not settings.autoClaim then continue end
        fireRemote(ClaimDailyQuest)
        fireRemote(ClaimTournamentReward)
        fireRemote(ClaimPlaytimeReward)
        -- Add more if needed: ClaimWeeklyReward, ClaimSeasonReward, etc.
    end
end)

-- // Auto Spin Gacha (uses coins/crate keys)
task.spawn(function()
    while task.wait(settings.spinCooldown) do
        if not settings.autoSpin then continue end
        -- Try buying spin with coins
        fireRemote(BuySpinCoins)
        -- Open crate if available
        fireRemote(OpenCrate)
        fireRemote(RequestCrateOpen)
        -- For generic gacha
        local gachaSpin = net and net["RE/GenericGachaSpinStarted"]
        fireRemote(gachaSpin)
    end
end)

-- // Auto Farm (aimbot using RE/dikg... remote)
-- Send target positions to gain credit/kills (requires target list)
task.spawn(function()
    local targetRemote = net and net["RE/dikg`jfkd=l9f/:6h8039:h3<9p9i2<g"]
    if not targetRemote then return end
    
    while task.wait(settings.farmInterval) do
        if not settings.autoFarm then continue end
        local targets = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                targets[plr.Name] = plr.Character.HumanoidRootPart.Position
            end
        end
        if next(targets) then
            -- Simulate the data packet seen in traffic
            local cframe = humanoidRootPart.CFrame
            local args = {
                "5455ef47-de02-4074-808c-8d82c2cd12ec", -- mock id
                "0B6W7Y",
                0.5,
                cframe,
                targets,
                { 872.76, 220.26 },
                false,
            }
            fireRemote(targetRemote, unpack(args))
        end
    end
end)

-- // UI Creation (Mobile compatible: draggable, scrollable, minimize)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RennHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 480)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Renn Hub"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 1, 0)
minimizeBtn.Position = UDim2.new(1, -60, 0, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 1, 0)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = titleBar

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -30)
scrollFrame.Position = UDim2.new(0, 0, 0, 30)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 400)
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 10)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Parent = scrollFrame

-- Function to create a toggle
local function createToggle(text, settingKey, default)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.BorderSizePixel = 0
    frame.Parent = scrollFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.Parent = frame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 60, 0, 30)
    toggleBtn.Position = UDim2.new(1, -70, 0.5, -15)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    toggleBtn.Text = default and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Parent = frame
    
    settings[settingKey] = default
    toggleBtn.MouseButton1Click:Connect(function()
        settings[settingKey] = not settings[settingKey]
        toggleBtn.BackgroundColor3 = settings[settingKey] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        toggleBtn.Text = settings[settingKey] and "ON" or "OFF"
    end)
end

-- Function to create a slider
local function createSlider(text, settingKey, minVal, maxVal, default)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.BorderSizePixel = 0
    frame.Parent = scrollFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.Parent = frame
    
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, -20, 0, 6)
    slider.Position = UDim2.new(0, 10, 0, 40)
    slider.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    slider.BorderSizePixel = 0
    slider.Parent = frame
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(fill.Size.X.Scale, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Text = ""
    knob.Parent = slider
    
    local value = default
    settings[settingKey] = value
    
    local dragging = false
    knob.MouseButton1Down:Connect(function()
        dragging = true
        while dragging and task.wait() do
            local mousePos = UserInputService:GetMouseLocation()
            local absX = mousePos.X - slider.AbsolutePosition.X
            local percent = math.clamp(absX / slider.AbsoluteSize.X, 0, 1)
            value = minVal + (maxVal - minVal) * percent
            value = math.floor(value * 10) / 10
            settings[settingKey] = value
            fill.Size = UDim2.new(percent, 0, 1, 0)
            knob.Position = UDim2.new(percent, -8, 0.5, -8)
            label.Text = text .. ": " .. tostring(value)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Build UI
createToggle("Auto Parry", "autoParry", true)
createSlider("Parry Radius", "parryRadius", 5, 30, 18)
createToggle("Auto Claim Rewards", "autoClaim", true)
createToggle("Auto Spin Gacha", "autoSpin", false)
createToggle("Auto Farm (Aimbot)", "autoFarm", false)
createToggle("Anti-AFK", "antiAFK", true)

-- Minimize/Maximize
local minimized = false
local originalSize = mainFrame.Size
minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mainFrame.Size = UDim2.new(0, 320, 0, 30)
        scrollFrame.Visible = false
    else
        mainFrame.Size = originalSize
        scrollFrame.Visible = true
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Inject GUI
screenGui.Parent = player:WaitForChild("PlayerGui")

-- // Optional: Notify user
player:SendNotification("Renn Hub Loaded", "Enjoy OP features!", 5)