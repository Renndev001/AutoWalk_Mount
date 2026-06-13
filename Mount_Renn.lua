--[[
    Advanced Motion Recorder (Rayfield-like UI) - No External Library
    Fitur lengkap:
    - Rekam CFrame, Velocity, MoveDirection, lompatan
    - Playback dengan speed, loop, reverse
    - Visual trail neon
    - Save/Load (disimpan di player)
    - Export/Import JSON (clipboard & paste)
    - GUI mirip Rayfield (Window, Tab, Section, dll)
--]]

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")

-- ========== VARIABEL UTAMA ==========
local recording = false
local recordedFrames = {}
local startTime = 0

local playing = false
local reverse = false
local playbackData = nil
local playbackStartTime = 0
local lastJumpFrame = false
local playbackSpeed = 1.0
local loopMode = false
local stopPlaybackFlag = false

-- Trail
local trailParts = {}
local trailActive = false
local trailColor = Color3.fromRGB(0, 255, 255)
local trailInterval = 0.3
local trailTimer = 0

-- Status indikator
local statusLabel = nil

-- Save system
local SAVE_FOLDER = "MotionRecorderSaves"
local currentSaveName = "default"

-- ========== GUI ELEMENTS ==========
local gui = Instance.new("ScreenGui")
gui.Name = "MotionRecorderGUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Window utama
local window = Instance.new("Frame")
window.Size = UDim2.new(0, 450, 0, 500)
window.Position = UDim2.new(0.5, -225, 0.5, -250)
window.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = gui
-- Agar bisa drag
window.Active = true
window.Draggable = true

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = window

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
titleBar.BorderSizePixel = 0
titleBar.Parent = window
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🎥 Motion Recorder Pro"
titleLabel.TextColor3 = Color3.new(1,1,1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 1, 0)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

-- Tab container
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 35)
tabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
tabContainer.BorderSizePixel = 0
tabContainer.Parent = window

-- Content container (tempat tab pages)
local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(1, 0, 1, -75)
contentContainer.Position = UDim2.new(0, 0, 0, 75)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = window

local pages = {} -- {tabName = frame}
local activeTab = nil

-- Fungsi membuat tab
local function createTab(tabName)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 100, 1, 0)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = tabName
    tabBtn.TextColor3 = Color3.fromRGB(200,200,200)
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 14
    tabBtn.Parent = tabContainer
    
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 6
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = contentContainer
    page.Visible = false
    
    -- Layout untuk page
    local uiList = Instance.new("UIListLayout")
    uiList.Padding = UDim.new(0, 10)
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Parent = page
    uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 20)
    end)
    
    pages[tabName] = {btn = tabBtn, page = page}
    
    tabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(pages) do
            p.page.Visible = false
            p.btn.TextColor3 = Color3.fromRGB(200,200,200)
        end
        page.Visible = true
        tabBtn.TextColor3 = Color3.fromRGB(255,255,255)
        activeTab = tabName
    end)
    
    if next(pages) == nil then
        tabBtn.MouseButton1Click:Fire()
    end
    
    return page
end

-- Fungsi membuat section (header)
local function createSection(parent, title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -20, 0, 30)
    section.BackgroundTransparency = 1
    section.Parent = parent
    
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 0, 20)
    line.BackgroundColor3 = Color3.fromRGB(80,80,90)
    line.Parent = section
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 200, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(255,200,100)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section
    
    return section
end

-- Fungsi membuat button
local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(60,60,70)
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.Parent = parent
    local cornerBtn = Instance.new("UICorner")
    cornerBtn.CornerRadius = UDim.new(0, 6)
    cornerBtn.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Fungsi membuat slider
local function createSlider(parent, name, minVal, maxVal, inc, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 60)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(default)
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 4)
    slider.Position = UDim2.new(0, 0, 0, 25)
    slider.BackgroundColor3 = Color3.fromRGB(80,80,90)
    slider.Parent = frame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 2)
    sliderCorner.Parent = slider
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - minVal)/(maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100,150,250)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 2)
    fillCorner.Parent = fill
    
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new((default - minVal)/(maxVal - minVal), -8, -0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Text = ""
    knob.Parent = slider
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local value = default
    local dragging = false
    
    local function updateValue(xPos)
        local relX = math.clamp((xPos - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
        value = minVal + relX * (maxVal - minVal)
        value = math.round(value / inc) * inc
        value = math.clamp(value, minVal, maxVal)
        label.Text = name .. ": " .. string.format("%.2f", value)
        fill.Size = UDim2.new((value - minVal)/(maxVal - minVal), 0, 1, 0)
        knob.Position = UDim2.new((value - minVal)/(maxVal - minVal), -8, -0.5, 0)
        callback(value)
    end
    
    knob.MouseButton1Down:Connect(function()
        dragging = true
        local mouse = player:GetMouse()
        local con
        con = mouse.Move:Connect(function()
            if dragging then
                updateValue(mouse.X)
            end
        end)
        local rel
        rel = mouse.Button1Up:Connect(function()
            dragging = false
            con:Disconnect()
            rel:Disconnect()
        end)
    end)
    
    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateValue(input.Position.X)
        end
    end)
    
    return frame
end

-- Fungsi membuat toggle
local function createToggle(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position = UDim2.new(1, -45, 0.5, -10)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(100,200,100) or Color3.fromRGB(100,100,100)
    toggleBtn.Text = ""
    toggleBtn.Parent = frame
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn
    
    local knobToggle = Instance.new("Frame")
    knobToggle.Size = UDim2.new(0, 16, 0, 16)
    knobToggle.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knobToggle.BackgroundColor3 = Color3.new(1,1,1)
    knobToggle.Parent = toggleBtn
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knobToggle
    
    local state = default
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(100,200,100) or Color3.fromRGB(100,100,100)
        knobToggle.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        callback(state)
    end)
    
    return frame
end

-- Fungsi membuat color picker sederhana
local function createColorPicker(parent, name, defaultColor, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local colorBtn = Instance.new("TextButton")
    colorBtn.Size = UDim2.new(0, 40, 0, 30)
    colorBtn.Position = UDim2.new(1, -45, 0.5, -15)
    colorBtn.BackgroundColor3 = defaultColor
    colorBtn.Text = ""
    colorBtn.Parent = frame
    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 6)
    colorCorner.Parent = colorBtn
    
    -- Simple color picker dialog (RGB sliders)
    local function openColorPicker()
        local dialog = Instance.new("Frame")
        dialog.Size = UDim2.new(0, 250, 0, 200)
        dialog.Position = UDim2.new(0.5, -125, 0.5, -100)
        dialog.BackgroundColor3 = Color3.fromRGB(40,40,50)
        dialog.BorderSizePixel = 0
        dialog.Parent = gui
        local dialogCorner = Instance.new("UICorner")
        dialogCorner.CornerRadius = UDim.new(0, 8)
        dialogCorner.Parent = dialog
        
        local rSlider = createSlider(dialog, "Red", 0, 1, 0.01, defaultColor.R, function(v) end)
        rSlider.Size = UDim2.new(1, -20, 0, 50)
        rSlider.Position = UDim2.new(0, 10, 0, 10)
        local gSlider = createSlider(dialog, "Green", 0, 1, 0.01, defaultColor.G, function(v) end)
        gSlider.Size = UDim2.new(1, -20, 0, 50)
        gSlider.Position = UDim2.new(0, 10, 0, 70)
        local bSlider = createSlider(dialog, "Blue", 0, 1, 0.01, defaultColor.B, function(v) end)
        bSlider.Size = UDim2.new(1, -20, 0, 50)
        bSlider.Position = UDim2.new(0, 10, 0, 130)
        
        local okBtn = Instance.new("TextButton")
        okBtn.Size = UDim2.new(0, 80, 0, 30)
        okBtn.Position = UDim2.new(1, -90, 1, -40)
        okBtn.Text = "OK"
        okBtn.BackgroundColor3 = Color3.fromRGB(70,150,70)
        okBtn.Parent = dialog
        okBtn.MouseButton1Click:Connect(function()
            local newColor = Color3.new(rSlider.Value, gSlider.Value, bSlider.Value)
            colorBtn.BackgroundColor3 = newColor
            callback(newColor)
            dialog:Destroy()
        end)
        
        local cancelBtn = Instance.new("TextButton")
        cancelBtn.Size = UDim2.new(0, 80, 0, 30)
        cancelBtn.Position = UDim2.new(1, -180, 1, -40)
        cancelBtn.Text = "Cancel"
        cancelBtn.BackgroundColor3 = Color3.fromRGB(150,70,70)
        cancelBtn.Parent = dialog
        cancelBtn.MouseButton1Click:Connect(function()
            dialog:Destroy()
        end)
    end
    
    colorBtn.MouseButton1Click:Connect(openColorPicker)
    return frame
end

-- Fungsi membuat input box
local function createInput(parent, placeholder, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 1, 0)
    box.PlaceholderText = placeholder
    box.BackgroundColor3 = Color3.fromRGB(50,50,60)
    box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = frame
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box
    
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            callback(box.Text)
        end
    end)
    return frame
end

-- ========== NOTIFIKASI (TOAST) ==========
local function notif(msg, msgType)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 300, 0, 40)
    toast.Position = UDim2.new(0.5, -150, 1, -50)
    toast.BackgroundColor3 = Color3.fromRGB(30,30,40)
    toast.BorderSizePixel = 0
    toast.Parent = gui
    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 8)
    toastCorner.Parent = toast
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = msg
    text.TextColor3 = Color3.new(1,1,1)
    text.Font = Enum.Font.Gotham
    text.TextSize = 13
    text.Parent = toast
    
    game:GetService("TweenService"):Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5, -150, 1, -60)}):Play()
    task.wait(2)
    game:GetService("TweenService"):Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5, -150, 1, -10)}):Play()
    task.wait(0.3)
    toast:Destroy()
    print("[MotionRec] " .. msg)
end

-- ========== INDIKATOR STATUS ==========
local function createStatusIndicator()
    if statusLabel then return end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 40)
    frame.Position = UDim2.new(0.5, -100, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = frame
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.new(1,1,1)
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
    statusLabel.Parent = frame
end

local function updateStatus(text, color)
    if statusLabel then
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.new(1,1,1)
        statusLabel.Parent.Parent.Visible = (text ~= "")
    end
end

-- ========== FUNGSI TRAIL ==========
local function clearTrail()
    for _, part in pairs(trailParts) do
        if part and part.Parent then part:Destroy() end
    end
    trailParts = {}
end

local function addTrailPoint(pos)
    if not trailActive then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.3, 0.3, 0.3)
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new(trailColor)
    part.Material = Enum.Material.Neon
    part.Parent = workspace
    game:GetService("Debris"):AddItem(part, 10)
    table.insert(trailParts, part)
    if #trailParts > 200 then
        local oldest = table.remove(trailParts, 1)
        if oldest then oldest:Destroy() end
    end
end

local function startTrail()
    trailActive = true
    trailTimer = 0
    clearTrail()
end

local function stopTrail()
    trailActive = false
end

-- Update trail setiap frame
runService.RenderStepped:Connect(function(delta)
    if trailActive and hrp and hrp.Parent then
        trailTimer = trailTimer + delta
        if trailTimer >= trailInterval then
            trailTimer = 0
            addTrailPoint(hrp.Position)
        end
    end
end)

-- ========== REKAM ==========
local function startRecording()
    if recording then notif("Sudah merekam", "error") return end
    if playing then notif("Hentikan playback dulu", "error") return end
    recordedFrames = {}
    startTime = os.clock()
    recording = true
    startTrail()
    updateStatus("🔴 RECORDING", Color3.fromRGB(255,50,50))
    if hrp and hrp.Parent then
        table.insert(recordedFrames, {
            time = 0,
            cframe = hrp.CFrame,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
    notif("Merekam gerakan + lompatan...", "info")
end

local function stopRecording()
    if not recording then notif("Tidak ada rekaman", "error") return end
    recording = false
    stopTrail()
    updateStatus("", Color3.new(1,1,1))
    if #recordedFrames < 2 then
        notif("Rekaman terlalu pendek", "error")
        recordedFrames = {}
        clearTrail()
        return
    end
    local duration = recordedFrames[#recordedFrames].time
    notif(string.format("Berhenti. %d frame, %.2f detik", #recordedFrames, duration), "success")
end

runService.RenderStepped:Connect(function()
    if recording and hrp and hrp.Parent then
        local now = os.clock() - startTime
        table.insert(recordedFrames, {
            time = now,
            cframe = hrp.CFrame,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
end)

-- ========== PLAYBACK ==========
local function stopPlayback()
    if not playing then return end
    stopPlaybackFlag = true
    playing = false
    reverse = false
    playbackData = nil
    workspace.Gravity = 196.2
    humanoid.PlatformStand = false
    updateStatus("", Color3.new(1,1,1))
    notif("Playback dihentikan", "default")
end

local function startPlayback(data, isReverse, speed, loop)
    if recording then notif("Hentikan rekaman dulu", "error") return end
    if playing then stopPlayback() end
    if not data or #data < 2 then notif("Tidak ada data rekaman", "error") return end
    
    stopPlaybackFlag = false
    playing = true
    reverse = isReverse
    playbackData = data
    playbackStartTime = os.clock()
    lastJumpFrame = false
    playbackSpeed = speed or 1.0
    loopMode = loop or false
    
    updateStatus(reverse and "🔁 PLAYING REVERSE" or "▶️ PLAYING", Color3.fromRGB(0,255,0))
    workspace.Gravity = 0
    humanoid.PlatformStand = true
    
    task.spawn(function()
        local totalTime = playbackData[#playbackData].time
        while playing and not stopPlaybackFlag do
            local now = (os.clock() - playbackStartTime) * playbackSpeed
            local progress
            if reverse then
                progress = 1 - (now / totalTime)
                if progress < 0 then progress = 0 end
            else
                progress = now / totalTime
                if progress > 1 then progress = 1 end
            end
            
            if (not reverse and progress >= 1) or (reverse and progress <= 0) then
                if loopMode then
                    playbackStartTime = os.clock()
                else
                    break
                end
            end
            
            local targetTime = progress * totalTime
            local idx = 1
            if reverse then
                for i = #playbackData, 1, -1 do
                    if playbackData[i].time <= targetTime then idx = i; break end
                end
            else
                for i = 1, #playbackData do
                    if playbackData[i].time >= targetTime then idx = i; break end
                end
            end
            
            local frame = playbackData[idx]
            if frame then
                hrp.CFrame = frame.cframe
                hrp.AssemblyLinearVelocity = frame.velocity
                if frame.moveDirection.Magnitude > 0 then
                    humanoid:MoveTo(hrp.Position + frame.moveDirection * 10)
                else
                    humanoid:MoveTo(hrp.Position)
                end
                if frame.isJumping and not lastJumpFrame and humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid.Jump = true
                end
                lastJumpFrame = frame.isJumping
            end
            task.wait(0.016)
        end
        workspace.Gravity = 196.2
        humanoid.PlatformStand = false
        playing = false
        updateStatus("", Color3.new(1,1,1))
        notif("Playback selesai", "success")
    end)
end

-- ========== SAVE/LOAD ==========
local function saveRecording(name)
    if #recordedFrames == 0 then notif("Tidak ada rekaman", "error") return end
    local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
    folder.Name = SAVE_FOLDER
    local val = Instance.new("StringValue")
    val.Name = name
    val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
    val.Parent = folder
    notif("Rekaman '" .. name .. "' disimpan", "success")
end

local function loadRecording(name)
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if not folder then notif("Belum ada rekaman", "error") return false end
    local val = folder:FindFirstChild(name)
    if not val then notif("Tidak ditemukan", "error") return false end
    local success, data = pcall(httpService.JSONDecode, httpService, val.Value)
    if not success then notif("Gagal memuat", "error") return false end
    recordedFrames = data.frames
    notif("Memuat '" .. name .. "' (" .. #recordedFrames .. " frame)", "success")
    return true
end

local function deleteSave(name)
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if folder then
        local val = folder:FindFirstChild(name)
        if val then val:Destroy(); notif("Dihapus: " .. name, "info") end
    end
end

local function resetRecording()
    recordedFrames = {}
    clearTrail()
    notif("Rekaman direset", "info")
end

-- ========== EXPORT/IMPORT ==========
local function exportToClipboard()
    if #recordedFrames == 0 then notif("Tidak ada rekaman", "error") return end
    local json = httpService:JSONEncode({frames = recordedFrames})
    if setclipboard then
        setclipboard(json)
        notif("Data disalin ke clipboard (" .. #json .. " karakter)", "success")
    else
        notif("Clipboard tidak didukung", "error")
    end
end

local function showImportDialog()
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 400, 0, 300)
    dialog.Position = UDim2.new(0.5, -200, 0.5, -150)
    dialog.BackgroundColor3 = Color3.fromRGB(30,30,40)
    dialog.BorderSizePixel = 0
    dialog.Parent = gui
    local dialogCorner = Instance.new("UICorner")
    dialogCorner.CornerRadius = UDim.new(0, 8)
    dialogCorner.Parent = dialog
    
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0.9, 0, 0.7, 0)
    textBox.Position = UDim2.new(0.05, 0, 0.05, 0)
    textBox.BackgroundColor3 = Color3.fromRGB(50,50,60)
    textBox.TextColor3 = Color3.new(1,1,1)
    textBox.Text = "Paste JSON di sini..."
    textBox.TextWrapped = true
    textBox.MultiLine = true
    textBox.ClearTextOnFocus = false
    textBox.Parent = dialog
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = textBox
    
    local importBtn = Instance.new("TextButton")
    importBtn.Size = UDim2.new(0.4, 0, 0.15, 0)
    importBtn.Position = UDim2.new(0.05, 0, 0.8, 0)
    importBtn.Text = "Import"
    importBtn.BackgroundColor3 = Color3.fromRGB(70,150,70)
    importBtn.Parent = dialog
    importBtn.MouseButton1Click:Connect(function()
        local success, data = pcall(httpService.JSONDecode, httpService, textBox.Text)
        if success and data.frames then
            recordedFrames = data.frames
            notif("Import sukses! " .. #recordedFrames .. " frame", "success")
            dialog:Destroy()
        else
            notif("JSON tidak valid", "error")
        end
    end)
    
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.4, 0, 0.15, 0)
    cancelBtn.Position = UDim2.new(0.55, 0, 0.8, 0)
    cancelBtn.Text = "Batal"
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150,70,70)
    cancelBtn.Parent = dialog
    cancelBtn.MouseButton1Click:Connect(function()
        dialog:Destroy()
    end)
end

-- ========== MEMBUAT UI RAYFIELD-LIKE ==========
createStatusIndicator()

-- Tab: Kontrol
local kontrolTab = createTab("🎥 Kontrol")
local section1 = createSection(kontrolTab, "Rekaman")
createButton(section1, "🔴 Mulai Rekam", startRecording)
createButton(section1, "⏹️ Stop Rekam", stopRecording)
createButton(section1, "🗑️ Reset Rekaman", resetRecording)

local section2 = createSection(kontrolTab, "Playback")
createButton(section2, "▶️ Play Normal", function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, false, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
createButton(section2, "🔁 Play Reverse", function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, true, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
createButton(section2, "⏹️ Stop Playback", stopPlayback)

-- Slider kecepatan (ditempatkan langsung di tab)
local speedSliderFrame = Instance.new("Frame")
speedSliderFrame.Size = UDim2.new(1, -20, 0, 60)
speedSliderFrame.BackgroundTransparency = 1
speedSliderFrame.Parent = kontrolTab
createSlider(speedSliderFrame, "Kecepatan Playback", 0.25, 3, 0.05, 1, function(v)
    playbackSpeed = v
    notif("Kecepatan: " .. v .. "x", "default")
end)

-- Toggle Loop
local toggleFrame = Instance.new("Frame")
toggleFrame.Size = UDim2.new(1, -20, 0, 40)
toggleFrame.BackgroundTransparency = 1
toggleFrame.Parent = kontrolTab
createToggle(toggleFrame, "Loop Mode", false, function(v)
    loopMode = v
    notif(loopMode and "Loop ON" or "Loop OFF", "info")
end)

-- Tab: Jejak Neon
local trailTab = createTab("✨ Jejak Neon")
local trailSection = createSection(trailTab, "Visual Trail")
local trailToggleFrame = Instance.new("Frame")
trailToggleFrame.Size = UDim2.new(1, -20, 0, 40)
trailToggleFrame.BackgroundTransparency = 1
trailToggleFrame.Parent = trailTab
createToggle(trailToggleFrame, "Aktifkan Jejak Saat Rekam", true, function(v)
    trailActive = v
    if not v then clearTrail() end
    notif(v and "Jejak aktif" or "Jejak nonaktif", "info")
end)

local colorPickerFrame = Instance.new("Frame")
colorPickerFrame.Size = UDim2.new(1, -20, 0, 40)
colorPickerFrame.BackgroundTransparency = 1
colorPickerFrame.Parent = trailTab
createColorPicker(colorPickerFrame, "Warna Jejak", trailColor, function(c)
    trailColor = c
    for _, part in pairs(trailParts) do
        if part and part.Parent then part.BrickColor = BrickColor.new(c) end
    end
end)

local intervalSliderFrame = Instance.new("Frame")
intervalSliderFrame.Size = UDim2.new(1, -20, 0, 60)
intervalSliderFrame.BackgroundTransparency = 1
intervalSliderFrame.Parent = trailTab
createSlider(intervalSliderFrame, "Interval Titik (detik)", 0.1, 1, 0.05, 0.3, function(v)
    trailInterval = v
end)

createButton(trailTab, "Hapus Semua Jejak", clearTrail)

-- Tab: Save/Load
local saveTab = createTab("💾 Save/Load")
local saveSection = createSection(saveTab, "Simpan & Muat")
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -20, 0, 40)
inputFrame.BackgroundTransparency = 1
inputFrame.Parent = saveTab
createInput(inputFrame, "Nama rekaman", function(text)
    currentSaveName = text
end)
createButton(saveTab, "💾 Simpan Rekaman", function()
    if currentSaveName and currentSaveName ~= "" then saveRecording(currentSaveName)
    else notif("Masukkan nama", "error") end
end)
createButton(saveTab, "📂 Muat Rekaman", function()
    if currentSaveName and currentSaveName ~= "" then loadRecording(currentSaveName)
    else notif("Masukkan nama", "error") end
end)
createButton(saveTab, "🗑️ Hapus Rekaman", function()
    if currentSaveName and currentSaveName ~= "" then deleteSave(currentSaveName)
    else notif("Masukkan nama", "error") end
end)

local exportSection = createSection(saveTab, "Export / Import")
createButton(saveTab, "📋 Export ke Clipboard", exportToClipboard)
createButton(saveTab, "📥 Import JSON (Paste)", showImportDialog)

-- Inisialisasi awal
notif("✅ Motion Recorder Pro siap! (UI tanpa library)", "success")