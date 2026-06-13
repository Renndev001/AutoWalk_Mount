--[[
    Renn HUB Universal - Motion Recorder Pro
    Fitur lengkap dengan GUI modern:
    - Accordion menu (4 menu utama: Recording & Tools, Utility, Player, Upcoming)
    - Window dapat di-resize (seret pojok kanan bawah)
    - Minimize ke title bar
    - Status RECORDING bisa di-drag
    - Semua fitur sebelumnya (rekam, jeda, playback, trail, fly, noclip, dll)
--]]

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

-- ========== VARIABEL FITUR ==========
local recording = false
local recordingPaused = false
local recordedFrames = {}
local startTime = 0
local pauseTimeOffset = 0

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
local trailActive = true
local trailColor = Color3.fromRGB(0, 255, 255)
local trailInterval = 0.3
local trailTimer = 0

-- Save system
local SAVE_FOLDER = "RennMotionSaves"
local currentSaveName = ""
local saveDropdown = nil

-- Player features
local flyEnabled = false
local flySpeed = 16
local flyBodyVelocity = nil
local noclipEnabled = false
local originalCanCollide = {}
local jumpPowerOriginal = humanoid.JumpPower
local jumpHighEnabled = false
local jumpHighPower = 50
local godModeEnabled = false

-- ========== NOTIFIKASI ==========
local function notif(msg, msgType)
    local gui = player.PlayerGui:FindFirstChild("RennHUB")
    if not gui then return end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 280, 0, 36)
    toast.Position = UDim2.new(0.5, -140, 1, -50)
    toast.BackgroundColor3 = Color3.fromRGB(30,30,40)
    toast.BorderSizePixel = 0
    toast.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toast
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = msg
    text.TextColor3 = Color3.new(1,1,1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 13
    text.Parent = toast
    tweenService:Create(toast, TweenInfo.new(0.2), {Position = UDim2.new(0.5, -140, 1, -60)}):Play()
    task.wait(2)
    tweenService:Create(toast, TweenInfo.new(0.2), {Position = UDim2.new(0.5, -140, 1, -10)}):Play()
    task.wait(0.2)
    toast:Destroy()
    print("[RennHUB] " .. msg)
end

-- ========== STATUS INDICATOR (DRAGABLE) ==========
local statusFrame = nil
local function createStatusIndicator()
    local gui = player.PlayerGui:FindFirstChild("RennHUB")
    if not gui then return end
    statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(0, 140, 0, 36)
    statusFrame.Position = UDim2.new(0.02, 0, 0.1, 0)
    statusFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    statusFrame.BackgroundTransparency = 0.4
    statusFrame.BorderSizePixel = 0
    statusFrame.Active = true
    statusFrame.Draggable = true
    statusFrame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = statusFrame
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = ""
    text.TextColor3 = Color3.new(1,1,1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Parent = statusFrame
    return text
end
local statusLabel = createStatusIndicator()
local function updateStatus(msg, color)
    if statusLabel then
        statusLabel.Text = msg
        statusLabel.TextColor3 = color or Color3.new(1,1,1)
        statusFrame.Visible = (msg ~= "")
    end
end

-- ========== TRAIL ==========
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
    if #trailParts > 300 then
        local oldest = table.remove(trailParts, 1)
        if oldest then oldest:Destroy() end
    end
end

-- ========== REKAM ==========
local function startRecording()
    if recording then notif("Sudah merekam", "error") return end
    if playing then notif("Hentikan playback dulu", "error") return end
    recordedFrames = {}
    startTime = os.clock()
    pauseTimeOffset = 0
    recording = true
    recordingPaused = false
    trailActive = true
    clearTrail()
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
    notif("Merekam...", "info")
end
local function pauseRecording()
    if not recording or recordingPaused then return end
    recordingPaused = true
    pauseTimeOffset = os.clock() - startTime
    updateStatus("⏸️ PAUSED", Color3.fromRGB(255,200,0))
    notif("Jeda rekaman", "info")
end
local function resumeRecording()
    if not recording or not recordingPaused then return end
    recordingPaused = false
    startTime = os.clock() - pauseTimeOffset
    updateStatus("🔴 RECORDING", Color3.fromRGB(255,50,50))
    notif("Lanjut rekam", "info")
end
local function stopRecordingWithSave()
    if not recording then notif("Tidak ada rekaman aktif", "error") return end
    recording = false
    recordingPaused = false
    trailActive = false
    updateStatus("", Color3.new(1,1,1))
    if #recordedFrames < 2 then
        notif("Rekaman terlalu pendek", "error")
        recordedFrames = {}
        return
    end
    -- Dialog minta nama
    local gui = player.PlayerGui:FindFirstChild("RennHUB")
    if not gui then return end
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 280, 0, 110)
    dialog.Position = UDim2.new(0.5, -140, 0.5, -55)
    dialog.BackgroundColor3 = Color3.fromRGB(40,40,50)
    dialog.BorderSizePixel = 0
    dialog.Parent = gui
    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(0, 8)
    dCorner.Parent = dialog
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Simpan Rekaman"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = dialog
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.8, 0, 0, 32)
    input.Position = UDim2.new(0.1, 0, 0.35, 0)
    input.PlaceholderText = "Nama rekaman"
    input.BackgroundColor3 = Color3.fromRGB(60,60,70)
    input.TextColor3 = Color3.new(1,1,1)
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    input.Parent = dialog
    local ok = Instance.new("TextButton")
    ok.Size = UDim2.new(0.3, 0, 0, 28)
    ok.Position = UDim2.new(0.1, 0, 0.7, 0)
    ok.Text = "Simpan"
    ok.BackgroundColor3 = Color3.fromRGB(70,150,70)
    ok.Font = Enum.Font.GothamBold
    ok.Parent = dialog
    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0.3, 0, 0, 28)
    cancel.Position = UDim2.new(0.6, 0, 0.7, 0)
    cancel.Text = "Batal"
    cancel.BackgroundColor3 = Color3.fromRGB(150,70,70)
    cancel.Font = Enum.Font.GothamBold
    cancel.Parent = dialog
    ok.MouseButton1Click:Connect(function()
        local name = input.Text
        if name == "" then name = "rec_" .. os.time() end
        local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
        folder.Name = SAVE_FOLDER
        local val = Instance.new("StringValue")
        val.Name = name
        val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
        val.Parent = folder
        notif("Tersimpan: " .. name, "success")
        dialog:Destroy()
    end)
    cancel.MouseButton1Click:Connect(function() dialog:Destroy() end)
end

-- Loop rekam dan trail
runService.RenderStepped:Connect(function()
    if recording and not recordingPaused and hrp and hrp.Parent then
        local now = os.clock() - startTime
        table.insert(recordedFrames, {
            time = now,
            cframe = hrp.CFrame,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
    if trailActive and hrp and hrp.Parent and (recording or playing) then
        trailTimer = trailTimer + runService.RenderStepped:Wait()
        if trailTimer >= trailInterval then
            trailTimer = 0
            addTrailPoint(hrp.Position)
        end
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
    notif("Playback berhenti", "default")
end
local function startPlayback(data, isReverse, speed, loop)
    if recording then notif("Hentikan rekaman", "error") return end
    if playing then stopPlayback() end
    if not data or #data < 2 then notif("Data kosong", "error") return end
    stopPlaybackFlag = false
    playing = true
    reverse = isReverse
    playbackData = data
    playbackStartTime = os.clock()
    lastJumpFrame = false
    playbackSpeed = speed or 1.0
    loopMode = loop or false
    updateStatus(reverse and "🔁 REVERSE" or "▶️ PLAYING", Color3.fromRGB(0,255,0))
    workspace.Gravity = 0
    humanoid.PlatformStand = true
    task.spawn(function()
        local totalTime = playbackData[#playbackData].time
        while playing and not stopPlaybackFlag do
            local now = (os.clock() - playbackStartTime) * playbackSpeed
            local progress = reverse and (1 - now/totalTime) or (now/totalTime)
            if progress <= 0 or progress >= 1 then
                if loopMode then
                    playbackStartTime = os.clock()
                else break end
            end
            local targetTime = math.clamp(progress, 0, 1) * totalTime
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

-- ========== SAVE/LOAD MANUAL ==========
local function refreshSaveList()
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if not folder then return {} end
    local list = {}
    for _, v in pairs(folder:GetChildren()) do
        if v:IsA("StringValue") then table.insert(list, v.Name) end
    end
    table.sort(list)
    return list
end
local function loadRecordingByName(name)
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if not folder then notif("Belum ada rekaman", "error") return end
    local val = folder:FindFirstChild(name)
    if not val then notif("Tidak ditemukan", "error") return end
    local success, data = pcall(httpService.JSONDecode, httpService, val.Value)
    if not success then notif("Gagal memuat", "error") return end
    recordedFrames = data.frames
    notif("Memuat '" .. name .. "' (" .. #recordedFrames .. " frame)", "success")
end
local function saveCurrentRecordingManually()
    if #recordedFrames == 0 then notif("Tidak ada rekaman", "error") return end
    local name = "rec_" .. os.time()
    local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
    folder.Name = SAVE_FOLDER
    local val = Instance.new("StringValue")
    val.Name = name
    val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
    val.Parent = folder
    notif("Disimpan sebagai " .. name, "success")
end

-- ========== FITUR PLAYER ==========
local function enableFly()
    if flyEnabled then return end
    flyEnabled = true
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBodyVelocity.Parent = hrp
    humanoid.PlatformStand = true
    local function updateFly()
        if not flyEnabled then return end
        local move = Vector3.zero
        if userInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0,0,-1) end
        if userInputService:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0,0,1) end
        if userInputService:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1,0,0) end
        if userInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1,0,0) end
        if userInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
        if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move + Vector3.new(0,-1,0) end
        if move.Magnitude > 0 then move = move.Unit end
        local cam = workspace.CurrentCamera
        local vel = (cam.CFrame.LookVector * move.Z + cam.CFrame.RightVector * move.X + Vector3.new(0, move.Y, 0)) * flySpeed
        flyBodyVelocity.Velocity = vel
    end
    local conn = runService.RenderStepped:Connect(updateFly)
    flyBodyVelocity.Destroying:Connect(function() conn:Disconnect() end)
end
local function disableFly()
    if not flyEnabled then return end
    flyEnabled = false
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    humanoid.PlatformStand = false
end
local function updateNoclip()
    if noclipEnabled then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                originalCanCollide[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    else
        for part, col in pairs(originalCanCollide) do
            if part and part.Parent then part.CanCollide = col end
        end
        originalCanCollide = {}
    end
end
char.ChildAdded:Connect(updateNoclip)
char.ChildRemoved:Connect(updateNoclip)
local function setJumpHigh(state)
    jumpHighEnabled = state
    humanoid.JumpPower = state and jumpHighPower or jumpPowerOriginal
end
local function setGodMode(state)
    godModeEnabled = state
    if state then
        humanoid.Health = math.huge
        humanoid.MaxHealth = math.huge
        humanoid.BreakJointsOnDeath = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    else
        humanoid.MaxHealth = 100
        humanoid.Health = 100
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
    end
end
humanoid.HealthChanged:Connect(function()
    if godModeEnabled and humanoid.Health <= 0 then humanoid.Health = math.huge end
end)

-- ========== GUI MODERN (ACCORDION + RESIZE + MINIMIZE) ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RennHUB"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Size = UDim2.new(0, 360, 0, 480)
window.Position = UDim2.new(0.5, -180, 0.5, -240)
window.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = screenGui
local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 12)
winCorner.Parent = window

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleBar.Parent = window
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -90, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Renn HUB Universal"
titleText.TextColor3 = Color3.fromRGB(255, 200, 100)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 16
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar
-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 35, 1, 0)
minBtn.Position = UDim2.new(1, -70, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "−"
minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 20
minBtn.Parent = titleBar
-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 1, 0)
closeBtn.Position = UDim2.new(1, -35, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar
-- Minimize logic
local minimized = false
local originalHeight = window.Size.Y.Scale
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetHeight = minimized and 38 or 480
    tweenService:Create(window, TweenInfo.new(0.2), {Size = UDim2.new(0, 360, 0, targetHeight)}):Play()
end)
closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

-- Drag window (title bar)
local dragging = false
local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = window.Position
    end
end)
userInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
userInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Resize handle (kanan bawah)
local resizeHandle = Instance.new("Frame")
resizeHandle.Size = UDim2.new(0, 15, 0, 15)
resizeHandle.Position = UDim2.new(1, -15, 1, -15)
resizeHandle.BackgroundColor3 = Color3.fromRGB(80,80,90)
resizeHandle.BackgroundTransparency = 0.5
resizeHandle.Parent = window
local handleCorner = Instance.new("UICorner")
handleCorner.CornerRadius = UDim.new(0, 3)
handleCorner.Parent = resizeHandle
local resizing = false
local startMouse, startSize
resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        startMouse = input.Position
        startSize = window.AbsoluteSize
    end
end)
userInputService.InputChanged:Connect(function(input)
    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - startMouse
        local newWidth = math.clamp(startSize.X + delta.X, 300, 600)
        local newHeight = math.clamp(startSize.Y + delta.Y, 300, 700)
        window.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)
userInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
end)

-- Scrollable content container
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -38)
scrollFrame.Position = UDim2.new(0, 0, 0, 38)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = window
local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 8)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Parent = scrollFrame
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 20)
end)

-- Fungsi membuat accordion section
local function createSection(parent, title)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -16, 0, 0)
    container.BackgroundTransparency = 1
    container.Parent = parent
    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    header.Text = "   " .. title
    header.TextColor3 = Color3.fromRGB(255,255,255)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 15
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = container
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 30, 1, 0)
    arrow.Position = UDim2.new(1, -35, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = Color3.new(1,1,1)
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 18
    arrow.Parent = header
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = container
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = content
    local expanded = true
    local function updateHeight()
        local h = contentLayout.AbsoluteContentSize.Y
        content.Size = UDim2.new(1, 0, 0, expanded and h or 0)
        container.Size = UDim2.new(1, -16, 0, 40 + (expanded and h or 0))
    end
    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateHeight)
    header.MouseButton1Click:Connect(function()
        expanded = not expanded
        arrow.Text = expanded and "▼" or "▶"
        updateHeight()
    end)
    updateHeight()
    return content
end

-- Helper: tombol, toggle, slider
local function addButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = parent
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end
local function addToggle(parent, labelText, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 42)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 60, 0, 28)
    toggleBtn.Position = UDim2.new(1, -65, 0.5, -14)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(80,180,80) or Color3.fromRGB(120,120,130)
    toggleBtn.Text = default and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleBtn
    local state = default
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(80,180,80) or Color3.fromRGB(120,120,130)
        toggleBtn.Text = state and "ON" or "OFF"
        callback(state)
    end)
    return frame
end
local function addSlider(parent, labelText, minVal, maxVal, inc, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 70)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 24)
    label.BackgroundTransparency = 1
    label.Text = labelText .. ": " .. tostring(default)
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, 5)
    sliderBg.Position = UDim2.new(0, 0, 0, 35)
    sliderBg.BackgroundColor3 = Color3.fromRGB(80,80,90)
    sliderBg.Parent = frame
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-minVal)/(maxVal-minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100,180,250)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new((default-minVal)/(maxVal-minVal), -8, -0.5, 0)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.Text = ""
    knob.Parent = sliderBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    local val = default
    local dragging = false
    local function updateValue(xPos)
        local rel = math.clamp((xPos - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        val = minVal + rel * (maxVal - minVal)
        val = math.round(val / inc) * inc
        val = math.clamp(val, minVal, maxVal)
        label.Text = labelText .. ": " .. string.format("%.2f", val)
        fill.Size = UDim2.new((val-minVal)/(maxVal-minVal), 0, 1, 0)
        knob.Position = UDim2.new((val-minVal)/(maxVal-minVal), -8, -0.5, 0)
        callback(val)
    end
    knob.MouseButton1Down:Connect(function()
        dragging = true
        local mouse = player:GetMouse()
        local moveConn = mouse.Move:Connect(function() if dragging then updateValue(mouse.X) end end)
        local upConn = mouse.Button1Up:Connect(function() dragging = false; moveConn:Disconnect(); upConn:Disconnect() end)
    end)
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateValue(input.Position.X)
        end
    end)
    return frame
end
local function addDropdown(parent, placeholder, items, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 44)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(60,65,75)
    btn.Text = placeholder
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    local menu = nil
    btn.MouseButton1Click:Connect(function()
        if menu then menu:Destroy(); menu = nil; return end
        menu = Instance.new("Frame")
        menu.Size = UDim2.new(1, 0, 0, #items * 32)
        menu.Position = UDim2.new(0, 0, 0, 34)
        menu.BackgroundColor3 = Color3.fromRGB(50,55,65)
        menu.Parent = frame
        local menuCorner = Instance.new("UICorner")
        menuCorner.CornerRadius = UDim.new(0, 6)
        menuCorner.Parent = menu
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.Parent = menu
        for _, item in ipairs(items) do
            local itemBtn = Instance.new("TextButton")
            itemBtn.Size = UDim2.new(1, -10, 0, 30)
            itemBtn.BackgroundColor3 = Color3.fromRGB(70,75,85)
            itemBtn.Text = item
            itemBtn.TextColor3 = Color3.new(1,1,1)
            itemBtn.Font = Enum.Font.Gotham
            itemBtn.TextSize = 12
            itemBtn.Parent = menu
            itemBtn.MouseButton1Click:Connect(function()
                btn.Text = item
                callback(item)
                menu:Destroy()
                menu = nil
            end)
        end
    end)
    return frame
end

-- ========== MEMBUAT ACCORDION MENU ==========
-- Menu 1: Recording & Tools
local recSection = createSection(scrollFrame, "🎥 Recording & Tools")
addButton(recSection, "Mulai Merekam", startRecording)
addButton(recSection, "Jeda Merekam", pauseRecording)
addButton(recSection, "Lanjutkan Merekam", resumeRecording)
addButton(recSection, "Berhenti & Simpan", stopRecordingWithSave)
addButton(recSection, "Simpan Rekaman (Manual)", saveCurrentRecordingManually)
-- Dropdown load
local loadItems = {"Pilih rekaman..."}
local dropdownLoad = addDropdown(recSection, "Pilih rekaman...", {}, function(name)
    if name ~= "Pilih rekaman..." then
        loadRecordingByName(name)
    end
end)
local function refreshLoadDropdown()
    local list = refreshSaveList()
    if #list == 0 then list = {"Pilih rekaman..."} end
    dropdownLoad:Destroy()
    dropdownLoad = addDropdown(recSection, "Pilih rekaman...", list, function(name)
        if name ~= "Pilih rekaman..." then loadRecordingByName(name) end
    end)
end
addButton(recSection, "Perbarui Daftar Rekaman", refreshLoadDropdown)

-- Menu 2: Utility
local utilSection = createSection(scrollFrame, "⚙️ Utility")
addToggle(utilSection, "Trail Neon", true, function(v) trailActive = v; if not v then clearTrail() end end)
addSlider(utilSection, "Kecepatan Playback", 0.25, 3, 0.05, 1, function(v) playbackSpeed = v end)
-- Mode playback (Reverse/Normal)
local modeFrame = Instance.new("Frame")
modeFrame.Size = UDim2.new(1, -20, 0, 50)
modeFrame.BackgroundTransparency = 1
modeFrame.Parent = utilSection
local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(1, 0, 0, 20)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Mode Playback"
modeLabel.TextColor3 = Color3.new(1,1,1)
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 14
modeLabel.Parent = modeFrame
local btnRev = Instance.new("TextButton")
btnRev.Size = UDim2.new(0.45, 0, 0, 28)
btnRev.Position = UDim2.new(0, 0, 0, 22)
btnRev.BackgroundColor3 = Color3.fromRGB(70,70,80)
btnRev.Text = "◀ Reverse"
btnRev.Font = Enum.Font.GothamBold
btnRev.TextSize = 13
btnRev.Parent = modeFrame
local btnNorm = Instance.new("TextButton")
btnNorm.Size = UDim2.new(0.45, 0, 0, 28)
btnNorm.Position = UDim2.new(0.55, 0, 0, 22)
btnNorm.BackgroundColor3 = Color3.fromRGB(70,70,80)
btnNorm.Text = "Normal ▶"
btnNorm.Font = Enum.Font.GothamBold
btnNorm.TextSize = 13
btnNorm.Parent = modeFrame
btnRev.MouseButton1Click:Connect(function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, true, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
btnNorm.MouseButton1Click:Connect(function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, false, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
addToggle(utilSection, "Loop Mode", false, function(v) loopMode = v end)
addButton(utilSection, "Hentikan Playback", stopPlayback)

-- Menu 3: Player
local playerSection = createSection(scrollFrame, "👤 Player")
addToggle(playerSection, "Fly Mode", false, function(v) if v then enableFly() else disableFly() end end)
addSlider(playerSection, "Kecepatan Terbang", 1, 50, 1, 16, function(v) flySpeed = v end)
addToggle(playerSection, "Noclip", false, function(v) noclipEnabled = v; updateNoclip() end)
addToggle(playerSection, "Jump High", false, function(v) setJumpHigh(v) end)
addSlider(playerSection, "Kekuatan Lompat", 20, 200, 5, 50, function(v) jumpHighPower = v; if jumpHighEnabled then humanoid.JumpPower = v end end)
addToggle(playerSection, "God Mode", false, function(v) setGodMode(v) end)

-- Menu 4: Upcoming
local upSection = createSection(scrollFrame, "📌 Upcoming")
local comingText = Instance.new("TextLabel")
comingText.Size = UDim2.new(1, -20, 0, 60)
comingText.Position = UDim2.new(0, 10, 0, 10)
comingText.BackgroundTransparency = 1
comingText.Text = "✨ Fitur mendatang:\n- Speed Run\n- Ghost Mode\n- Auto Record"
comingText.TextColor3 = Color3.fromRGB(200,200,200)
comingText.Font = Enum.Font.GothamBold
comingText.TextSize = 14
comingText.TextWrapped = true
comingText.Parent = upSection

-- Final
notif("Renn HUB Universal - Motion Recorder Pro siap!", "success")