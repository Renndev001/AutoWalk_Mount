-- Renn Hub - Full Script
-- Created for Roblox Game "Panjat dan Lompat Menara DUNIA BARU"
-- Features: Auto Climb, Auto Collect, Auto Hatch, Speed Bypass

local player = game.Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

-- ==================== MODULES ====================
local flyModule = require(replicatedStorage.Tool.FlyModule)
local flyCurve = require(replicatedStorage.Tool.FlyModule.FlyCurve)
local drawUp = require(replicatedStorage.Tool.DrawUp)
local systemFly = require(replicatedStorage.System.SystemFly)
local getData = require(replicatedStorage.Tool.GetData)
local cfgFind = require(replicatedStorage.Tool.CfgFind)
local systemSave = require(replicatedStorage.System.SystemSave)

-- ==================== REMOTES ====================
local proMgsRemote = replicatedStorage.ProMgs.RemoteEvent
local serverMsg = replicatedStorage.ServerMsg
local msgRemote = replicatedStorage.Msg.RemoteEvent
local claimEventReward = replicatedStorage.ClaimEventReward

-- ==================== STATE ====================
local isAutoClimb = false
local isAutoCollect = false
local isAutoHatch = false
local hatchCount = 1
local climbSpeedMultiplier = 1
local isClimbing = false
local isAtTop = false
local collectedThisRun = false

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RennHubGui"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Main Window
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 480)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 5, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Renn Hub"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local minButton = Instance.new("TextButton")
minButton.Size = UDim2.new(0, 25, 1, 0)
minButton.Position = UDim2.new(1, -55, 0, 0)
minButton.BackgroundTransparency = 1
minButton.Text = "_"
minButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minButton.TextSize = 18
minButton.Font = Enum.Font.GothamBold
minButton.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 25, 1, 0)
closeButton.Position = UDim2.new(1, -30, 0, 0)
closeButton.BackgroundTransparency = 1
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 80, 80)
closeButton.TextSize = 18
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleBar

-- Content
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1, 0, 1, -30)
contentFrame.Position = UDim2.new(0, 0, 0, 30)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 6
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 700)
contentFrame.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 6)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Parent = contentFrame

-- Tab buttons
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, 0, 0, 32)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = contentFrame

local tab1 = Instance.new("TextButton")
tab1.Size = UDim2.new(0.5, -2, 1, 0)
tab1.Position = UDim2.new(0, 0, 0, 0)
tab1.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
tab1.Text = "Auto Farm"
tab1.TextColor3 = Color3.fromRGB(255, 255, 255)
tab1.Font = Enum.Font.Gotham
tab1.TextSize = 14
tab1.Parent = tabFrame

local tab2 = Instance.new("TextButton")
tab2.Size = UDim2.new(0.5, -2, 1, 0)
tab2.Position = UDim2.new(0.5, 2, 0, 0)
tab2.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
tab2.Text = "Misc"
tab2.TextColor3 = Color3.fromRGB(200, 200, 200)
tab2.Font = Enum.Font.Gotham
tab2.TextSize = 14
tab2.Parent = tabFrame

-- Tab content containers
local tabContent1 = Instance.new("Frame")
tabContent1.Size = UDim2.new(1, 0, 1, -32)
tabContent1.BackgroundTransparency = 1
tabContent1.Parent = contentFrame

local tabContent2 = Instance.new("Frame")
tabContent2.Size = UDim2.new(1, 0, 1, -32)
tabContent2.BackgroundTransparency = 1
tabContent2.Visible = false
tabContent2.Parent = contentFrame

-- Helper: Toggle
function createToggle(parent, text, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 55, 1, -4)
    toggleButton.Position = UDim2.new(1, -60, 0, 2)
    toggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    toggleButton.Text = "Off"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 12
    toggleButton.Font = Enum.Font.Gotham
    toggleButton.Parent = frame

    local state = false
    toggleButton.MouseButton1Click:Connect(function()
        state = not state
        if state then
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            toggleButton.Text = "On"
        else
            toggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
            toggleButton.Text = "Off"
        end
        callback(state)
    end)

    return toggleButton
end

-- ==================== UI ELEMENTS ====================
-- Auto Climb
local autoClimbToggle = createToggle(tabContent1, "Auto Climb", function(state)
    isAutoClimb = state
    if state then
        startAutoClimb()
    else
        stopAutoClimb()
    end
end)

-- Auto Collect
local autoCollectToggle = createToggle(tabContent1, "Auto Collect", function(state)
    isAutoCollect = state
end)

-- Auto Hatch
local autoHatchToggle = createToggle(tabContent1, "Auto Hatch", function(state)
    isAutoHatch = state
    if state then
        startAutoHatch()
    else
        stopAutoHatch()
    end
end)

-- Hatch Count Input
local hatchInputFrame = Instance.new("Frame")
hatchInputFrame.Size = UDim2.new(1, 0, 0, 32)
hatchInputFrame.BackgroundTransparency = 1
hatchInputFrame.Parent = tabContent1

local hatchLabel = Instance.new("TextLabel")
hatchLabel.Size = UDim2.new(0.5, -5, 1, 0)
hatchLabel.Position = UDim2.new(0, 0, 0, 0)
hatchLabel.BackgroundTransparency = 1
hatchLabel.Text = "Hatch Count:"
hatchLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hatchLabel.TextSize = 14
hatchLabel.Font = Enum.Font.Gotham
hatchLabel.TextXAlignment = Enum.TextXAlignment.Right
hatchLabel.Parent = hatchInputFrame

local hatchInput = Instance.new("TextBox")
hatchInput.Size = UDim2.new(0.4, -5, 1, 0)
hatchInput.Position = UDim2.new(0.55, 0, 0, 0)
hatchInput.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
hatchInput.Text = "1"
hatchInput.TextColor3 = Color3.fromRGB(255, 255, 255)
hatchInput.TextSize = 14
hatchInput.Font = Enum.Font.Gotham
hatchInput.ClearTextOnFocus = false
hatchInput.Parent = hatchInputFrame
hatchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local num = tonumber(hatchInput.Text)
    if num and num > 0 then
        hatchCount = num
    else
        hatchInput.Text = "1"
        hatchCount = 1
    end
end)

-- ==================== MISC TAB ====================
-- Climb Speed Slider
local speedSliderFrame = Instance.new("Frame")
speedSliderFrame.Size = UDim2.new(1, 0, 0, 55)
speedSliderFrame.BackgroundTransparency = 1
speedSliderFrame.Parent = tabContent2

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 20)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Climb Speed: 1.0x"
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.TextSize = 14
speedLabel.Font = Enum.Font.Gotham
speedLabel.Parent = speedSliderFrame

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(1, 0, 0, 22)
sliderBg.Position = UDim2.new(0, 0, 0, 22)
sliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = speedSliderFrame

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.new(0, 20, 1, -4)
sliderButton.Position = UDim2.new(0.5, -10, 0, 2)
sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderButton.Text = ""
sliderButton.BorderSizePixel = 0
sliderButton.Parent = sliderBg

-- Slider logic
local sliding = false
sliderButton.MouseButton1Down:Connect(function()
    sliding = true
end)
userInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding = false
    end
end)
runService.RenderStepped:Connect(function()
    if sliding then
        local mouse = userInputService:GetMouseLocation()
        local pos = sliderBg.AbsolutePosition
        local size = sliderBg.AbsoluteSize
        local x = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
        sliderFill.Size = UDim2.new(x, 0, 1, 0)
        sliderButton.Position = UDim2.new(x, -10, 0, 2)
        local speed = 1 + x * 1 -- 1x - 2x
        climbSpeedMultiplier = speed
        speedLabel.Text = "Climb Speed: " .. string.format("%.1f", speed) .. "x"
        applyClimbSpeed(speed)
    end
end)

-- ==================== CORE FUNCTIONS ====================
-- Apply speed bypass
function applyClimbSpeed(multiplier)
    -- Override GetFlySpeed
    local oldGetFlySpeed = getData.GetFlySpeed
    getData.GetFlySpeed = function(plr)
        local base = oldGetFlySpeed(plr)
        return base * multiplier
    end
    -- Also patch FlyModule's speed curve
    if flyCurve and flyCurve.GetFlySpeed then
        local oldCurve = flyCurve.GetFlySpeed
        flyCurve.GetFlySpeed = function(...)
            local base = oldCurve(...)
            return base * multiplier
        end
    end
end

-- Auto Climb
local climbLoop = nil
function startAutoClimb()
    if climbLoop then return end
    climbLoop = task.spawn(function()
        while isAutoClimb do
            if not isClimbing then
                local char = player.Character
                if char then
                    local humanoid = char:FindFirstChild("Humanoid")
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if humanoid and rootPart then
                        -- Check if at top (puncak menara)
                        local nowWorld = getData.GetNowWorld(player)
                        local worldCfg = cfgFind.GetWorldCfg(nowWorld)
                        if worldCfg then
                            -- Estimate top height from Floor and Gold values
                            local topHeight = (worldCfg.Floor or 1) * 100 -- rough estimate
                            if rootPart.Position.Y > topHeight * 0.85 then
                                -- At top, claim trophy and jump down
                                if not isAtTop then
                                    isAtTop = true
                                    claimTrophy()
                                    -- Teleport down
                                    local groundPos = CFrame.new(rootPart.Position.X, 5, rootPart.Position.Z)
                                    msgRemote:FireServer("TeleportMe", groundPos)
                                    task.wait(0.5)
                                    isAtTop = false
                                    collectedThisRun = false
                                end
                            else
                                -- Start climbing
                                local success = pcall(function()
                                    systemFly.StartFly(player)
                                end)
                                if success then
                                    isClimbing = true
                                    task.wait(1)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.3)
        end
    end)
end

function stopAutoClimb()
    if climbLoop then
        task.cancel(climbLoop)
        climbLoop = nil
    end
    isClimbing = false
    isAtTop = false
end

-- Claim Trophy (simulate)
function claimTrophy()
    -- From traffic: "ClaimEventReward" or "ClaimedSecondaryReward"
    -- We'll try common ones
    pcall(function()
        claimEventReward:FireServer()
    end)
    pcall(function()
        replicatedStorage.ClaimedSecondaryReward:FireServer()
    end)
    -- Also try specific event rewards
    local events = {"AngelsVsDemons", "CNTower", "SeasonPass3", "SpaceEvent"}
    for _, ev in ipairs(events) do
        pcall(function()
            replicatedStorage:FindFirstChild("ClaimEventReward"):FireServer(ev)
        end)
    end
end

-- Auto Collect: detect fatigue
local oldShowTips = serverMsg.showTips
serverMsg.showTips = function(plr, msg, ...)
    if plr == player and msg and string.find(msg, "kelelahan") then
        if isAutoCollect and isClimbing then
            -- Teleport down to collect gold
            local char = player.Character
            if char then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local groundPos = CFrame.new(rootPart.Position.X, 5, rootPart.Position.Z)
                    msgRemote:FireServer("TeleportMe", groundPos)
                    task.wait(0.3)
                    isClimbing = false
                    collectedThisRun = true
                end
            end
        end
    end
    return oldShowTips(plr, msg, ...)
end

-- Auto Hatch
local hatchLoop = nil
function startAutoHatch()
    if hatchLoop then return end
    hatchLoop = task.spawn(function()
        while isAutoHatch do
            -- Find a valid egg (cost > 0)
            local eggID = nil
            local eggData = cfgFind.GetCfgByName("eggdataConf")
            for id, cfg in pairs(eggData) do
                if cfg.cost and cfg.cost > 0 then
                    eggID = id
                    break
                end
            end
            if not eggID then
                eggID = 7000080 -- fallback
            end
            -- Hatch specified count
            for i = 1, hatchCount do
                if not isAutoHatch then break end
                local success = pcall(function()
                    drawUp.DrawSpecialEgg(player, eggID, 1, false)
                end)
                if success then
                    task.wait(0.5)
                else
                    task.wait(1)
                end
            end
            task.wait(0.2)
        end
    end)
end

function stopAutoHatch()
    if hatchLoop then
        task.cancel(hatchLoop)
        hatchLoop = nil
    end
end

-- ==================== TAB SWITCHING ====================
tab1.MouseButton1Click:Connect(function()
    tab1.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
    tab2.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    tabContent1.Visible = true
    tabContent2.Visible = false
end)

tab2.MouseButton1Click:Connect(function()
    tab2.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
    tab1.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    tabContent1.Visible = false
    tabContent2.Visible = true
end)

-- ==================== MINIMIZE / CLOSE / DRAG ====================
local minimized = false
minButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mainFrame.Size = UDim2.new(0, 350, 0, 32)
        contentFrame.Visible = false
    else
        mainFrame.Size = UDim2.new(0, 350, 0, 480)
        contentFrame.Visible = true
    end
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local dragging = false
local dragInput, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
userInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==================== INIT ====================
applyClimbSpeed(1)

print("Renn Hub Loaded!")