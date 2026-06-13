--[[
    Renn HUB Universal - Motion Recorder Pro
    Fitur:
    - Rekam gerakan + lompat (dengan jeda)
    - Playback normal/reverse, kecepatan, loop
    - Trail neon (on/off)
    - Save/Load rekaman ke lokal (player)
    - Fly (kecepatan slider 1-50)
    - Noclip (toggle)
    - Jump High (slider)
    - God mode (toggle)
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
local recordingPaused = false
local recordedFrames = {}
local startTime = 0
local pauseTimeOffset = 0  -- waktu yang sudah direkam sebelum jeda

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

-- Status indikator
local statusLabel = nil

-- Save system
local SAVE_FOLDER = "RennMotionSaves"
local currentSaveName = ""
local saveDropdown = nil
local saveList = {}

-- Fitur Player
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
    local guiNotif = player.PlayerGui:FindFirstChild("RennHUBGUI")
    if not guiNotif then return end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 300, 0, 40)
    toast.Position = UDim2.new(0.5, -150, 1, -50)
    toast.BackgroundColor3 = Color3.fromRGB(30,30,40)
    toast.BorderSizePixel = 0
    toast.Parent = guiNotif
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
    game:GetService("TweenService"):Create(toast, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -150, 1, -60)}):Play()
    task.wait(2)
    game:GetService("TweenService"):Create(toast, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -150, 1, -10)}):Play()
    task.wait(0.3)
    toast:Destroy()
    print("[RennHUB] " .. msg)
end

-- ========== INDIKATOR STATUS ==========
local function createStatusIndicator()
    local gui = player.PlayerGui:FindFirstChild("RennHUBGUI")
    if not gui then return end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 40)
    frame.Position = UDim2.new(0.5, -110, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
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
        statusLabel.Parent.Visible = (text ~= "")
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
    notif("Merekam gerakan + lompatan...", "info")
end

local function pauseRecording()
    if not recording or recordingPaused then return end
    recordingPaused = true
    pauseTimeOffset = os.clock() - startTime
    updateStatus("⏸️ PAUSED", Color3.fromRGB(255,200,0))
    notif("Rekaman dijeda", "info")
end

local function resumeRecording()
    if not recording or not recordingPaused then return end
    recordingPaused = false
    startTime = os.clock() - pauseTimeOffset
    updateStatus("🔴 RECORDING", Color3.fromRGB(255,50,50))
    notif("Rekaman dilanjutkan", "info")
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
    -- Minta nama file
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 300, 0, 120)
    dialog.Position = UDim2.new(0.5, -150, 0.5, -60)
    dialog.BackgroundColor3 = Color3.fromRGB(40,40,50)
    dialog.BorderSizePixel = 0
    dialog.Parent = player.PlayerGui:FindFirstChild("RennHUBGUI")
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = dialog
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Simpan Rekaman"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = dialog
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.8, 0, 0, 35)
    input.Position = UDim2.new(0.1, 0, 0.35, 0)
    input.PlaceholderText = "Nama rekaman"
    input.BackgroundColor3 = Color3.fromRGB(60,60,70)
    input.TextColor3 = Color3.new(1,1,1)
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    input.Parent = dialog
    local ok = Instance.new("TextButton")
    ok.Size = UDim2.new(0.3, 0, 0, 30)
    ok.Position = UDim2.new(0.1, 0, 0.7, 0)
    ok.Text = "Simpan"
    ok.BackgroundColor3 = Color3.fromRGB(70,150,70)
    ok.Parent = dialog
    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0.3, 0, 0, 30)
    cancel.Position = UDim2.new(0.6, 0, 0.7, 0)
    cancel.Text = "Batal"
    cancel.BackgroundColor3 = Color3.fromRGB(150,70,70)
    cancel.Parent = dialog
    local function saveAndClose()
        local name = input.Text
        if name == "" then name = "rec_" .. os.time() end
        local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
        folder.Name = SAVE_FOLDER
        local val = Instance.new("StringValue")
        val.Name = name
        val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
        val.Parent = folder
        notif("Rekaman '" .. name .. "' disimpan (" .. #recordedFrames .. " frame)", "success")
        dialog:Destroy()
        -- Refresh daftar save
        if saveDropdown then
            local list = {}
            for _, v in pairs(folder:GetChildren()) do
                if v:IsA("StringValue") then table.insert(list, v.Name) end
            end
            saveDropdown:Clear()
            for _, name in ipairs(list) do
                saveDropdown:AddItem(name)
            end
        end
    end
    ok.MouseButton1Click:Connect(saveAndClose)
    cancel.MouseButton1Click:Connect(function() dialog:Destroy() end)
end

-- Loop rekaman (RenderStepped)
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
    -- Trail update
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

local function saveCurrentRecording(name)
    if #recordedFrames == 0 then notif("Tidak ada rekaman", "error") return end
    if name == "" then name = "rec_" .. os.time() end
    local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
    folder.Name = SAVE_FOLDER
    local existing = folder:FindFirstChild(name)
    if existing then existing:Destroy() end
    local val = Instance.new("StringValue")
    val.Name = name
    val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
    val.Parent = folder
    notif("Rekaman '" .. name .. "' disimpan", "success")
    refreshSaveList()
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

-- ========== FITUR PLAYER ==========
-- Fly
local function enableFly()
    if flyEnabled then return end
    flyEnabled = true
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBodyVelocity.Velocity = Vector3.zero
    flyBodyVelocity.Parent = hrp
    humanoid.PlatformStand = true
    -- Control dengan WASD
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
        local camera = workspace.CurrentCamera
        local forward = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local vel = (right * move.X + forward * move.Z + Vector3.new(0, move.Y, 0)) * flySpeed
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

-- Noclip
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

-- Jump High
local function setJumpHigh(state)
    jumpHighEnabled = state
    if jumpHighEnabled then
        humanoid.JumpPower = jumpHighPower
    else
        humanoid.JumpPower = jumpPowerOriginal
    end
end

-- God Mode
local function setGodMode(state)
    godModeEnabled = state
    if godModeEnabled then
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
    if godModeEnabled and humanoid.Health <= 0 then
        humanoid.Health = math.huge
    end
end)

-- ========== MEMBUAT UI RENN HUB ==========
local gui = Instance.new("ScreenGui")
gui.Name = "RennHUBGUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Size = UDim2.new(0, 500, 0, 600)
window.Position = UDim2.new(0.5, -250, 0.5, -300)
window.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
window.BorderSizePixel = 0
window.Active = true
window.Draggable = true
window.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = window

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
titleBar.Parent = window
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Renn HUB Universal"
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 1, 0)
closeBtn.Position = UDim2.new(1, -40, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Tab container
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 40)
tabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
tabContainer.Parent = window

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -80)
content.Position = UDim2.new(0, 0, 0, 80)
content.BackgroundTransparency = 1
content.Parent = window

local tabs = {}
local function createTabButton(name, pageName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200,200,200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = tabContainer
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 6
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = content
    page.Visible = false
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
    tabs[pageName] = {btn = btn, page = page}
    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabs) do
            t.page.Visible = false
            t.btn.TextColor3 = Color3.fromRGB(200,200,200)
        end
        page.Visible = true
        btn.TextColor3 = Color3.fromRGB(255,255,255)
    end)
    return page
end

-- Buat tab
local recTab = createTabButton("Recording & Tools", "rec")
local utilTab = createTabButton("Utility", "util")
local playerTab = createTabButton("Player", "player")
local upcomingTab = createTabButton("Upcoming", "upcoming")

-- Fungsi membuat komponen UI
local function addButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(60,60,70)
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

local function addToggle(parent, text, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 24)
    toggleBtn.Position = UDim2.new(1, -55, 0.5, -12)
    toggleBtn.BackgroundColor3 = defaultValue and Color3.fromRGB(100,200,100) or Color3.fromRGB(100,100,100)
    toggleBtn.Text = defaultValue and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleBtn
    local state = defaultValue
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(100,200,100) or Color3.fromRGB(100,100,100)
        toggleBtn.Text = state and "ON" or "OFF"
        callback(state)
    end)
    return frame
end

local function addSlider(parent, text, minVal, maxVal, inc, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 70)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, 6)
    sliderBg.Position = UDim2.new(0, 0, 0, 35)
    sliderBg.BackgroundColor3 = Color3.fromRGB(80,80,90)
    sliderBg.Parent = frame
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-minVal)/(maxVal-minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100,150,250)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new((default-minVal)/(maxVal-minVal), -9, -0.5, 0)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.Text = ""
    knob.Parent = sliderBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    local value = default
    local dragging = false
    local function updateValue(x)
        local rel = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        value = minVal + rel * (maxVal - minVal)
        value = math.round(value / inc) * inc
        value = math.clamp(value, minVal, maxVal)
        label.Text = text .. ": " .. string.format("%.2f", value)
        fill.Size = UDim2.new((value-minVal)/(maxVal-minVal), 0, 1, 0)
        knob.Position = UDim2.new((value-minVal)/(maxVal-minVal), -9, -0.5, 0)
        callback(value)
    end
    knob.MouseButton1Down:Connect(function()
        dragging = true
        local mouse = player:GetMouse()
        local moveCon, upCon
        moveCon = mouse.Move:Connect(function() if dragging then updateValue(mouse.X) end end)
        upCon = mouse.Button1Up:Connect(function()
            dragging = false
            moveCon:Disconnect()
            upCon:Disconnect()
        end)
    end)
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateValue(input.Position.X)
        end
    end)
    return frame
end

-- === TAB 1: RECORDING & TOOLS ===
addButton(recTab, "Mulai Merekam", startRecording)
addButton(recTab, "Jeda Merekam", pauseRecording)
addButton(recTab, "Lanjutkan Merekam", resumeRecording)
addButton(recTab, "Berhenti & Simpan", stopRecordingWithSave)
addButton(recTab, "Simpan Rekaman (Manual)", function()
    local name = "rec_" .. os.time()
    saveCurrentRecording(name)
end)
-- Load dropdown
local loadFrame = Instance.new("Frame")
loadFrame.Size = UDim2.new(1, -20, 0, 50)
loadFrame.BackgroundTransparency = 1
loadFrame.Parent = recTab
local loadLabel = Instance.new("TextLabel")
loadLabel.Size = UDim2.new(1, 0, 0, 20)
loadLabel.BackgroundTransparency = 1
loadLabel.Text = "Muat Rekaman"
loadLabel.TextColor3 = Color3.new(1,1,1)
loadLabel.Font = Enum.Font.GothamBold
loadLabel.TextSize = 14
loadLabel.Parent = loadFrame
local dropdown = Instance.new("TextButton")
dropdown.Size = UDim2.new(1, 0, 0, 30)
dropdown.Position = UDim2.new(0, 0, 0, 20)
dropdown.BackgroundColor3 = Color3.fromRGB(50,50,60)
dropdown.Text = "Pilih rekaman..."
dropdown.TextColor3 = Color3.new(1,1,1)
dropdown.Font = Enum.Font.Gotham
dropdown.TextSize = 13
dropdown.Parent = loadFrame
local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 6)
dropdownCorner.Parent = dropdown
local dropdownMenu = nil
local function updateDropdownList()
    if dropdownMenu then dropdownMenu:Destroy() end
    local list = refreshSaveList()
    dropdownMenu = Instance.new("Frame")
    dropdownMenu.Size = UDim2.new(1, 0, 0, #list * 30)
    dropdownMenu.Position = UDim2.new(0, 0, 0, 30)
    dropdownMenu.BackgroundColor3 = Color3.fromRGB(40,40,50)
    dropdownMenu.Parent = loadFrame
    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 6)
    menuCorner.Parent = dropdownMenu
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = dropdownMenu
    for _, name in ipairs(list) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(60,60,70)
        btn.Text = name
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = dropdownMenu
        btn.MouseButton1Click:Connect(function()
            loadRecordingByName(name)
            dropdown.Text = name
            dropdownMenu:Destroy()
            dropdownMenu = nil
        end)
    end
end
dropdown.MouseButton1Click:Connect(function()
    if dropdownMenu then dropdownMenu:Destroy(); dropdownMenu = nil
    else updateDropdownList() end
end)
addButton(recTab, "Perbarui Daftar Rekaman", function()
    refreshSaveList()
    if dropdownMenu then dropdownMenu:Destroy(); dropdownMenu = nil end
    notif("Daftar diperbarui", "info")
end)

-- === TAB 2: UTILITY ===
addToggle(utilTab, "Aktifkan Trail Neon", true, function(v) trailActive = v; if not v then clearTrail() end end)
addSlider(utilTab, "Kecepatan Playback", 0.25, 3, 0.05, 1, function(v) playbackSpeed = v end)
-- Reverse & Normal tombol kiri kanan
local speedFrame = Instance.new("Frame")
speedFrame.Size = UDim2.new(1, -20, 0, 50)
speedFrame.BackgroundTransparency = 1
speedFrame.Parent = utilTab
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 20)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Mode Playback"
speedLabel.TextColor3 = Color3.new(1,1,1)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 14
speedLabel.Parent = speedFrame
local btnLeft = Instance.new("TextButton")
btnLeft.Size = UDim2.new(0.45, 0, 0, 30)
btnLeft.Position = UDim2.new(0, 0, 0, 20)
btnLeft.BackgroundColor3 = Color3.fromRGB(70,70,80)
btnLeft.Text = "◀ Reverse"
btnLeft.Font = Enum.Font.GothamBold
btnLeft.TextSize = 13
btnLeft.Parent = speedFrame
local btnRight = Instance.new("TextButton")
btnRight.Size = UDim2.new(0.45, 0, 0, 30)
btnRight.Position = UDim2.new(0.55, 0, 0, 20)
btnRight.BackgroundColor3 = Color3.fromRGB(70,70,80)
btnRight.Text = "Normal ▶"
btnRight.Font = Enum.Font.GothamBold
btnRight.TextSize = 13
btnRight.Parent = speedFrame
btnLeft.MouseButton1Click:Connect(function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, true, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
btnRight.MouseButton1Click:Connect(function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, false, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
addToggle(utilTab, "Loop Mode", false, function(v) loopMode = v end)
addButton(utilTab, "Hentikan Playback", stopPlayback)

-- === TAB 3: PLAYER ===
addToggle(playerTab, "Fly Mode", false, function(v)
    if v then enableFly() else disableFly() end
end)
addSlider(playerTab, "Kecepatan Terbang", 1, 50, 1, 16, function(v) flySpeed = v end)
addToggle(playerTab, "Noclip", false, function(v)
    noclipEnabled = v
    updateNoclip()
end)
addToggle(playerTab, "Jump High", false, function(v) setJumpHigh(v) end)
addSlider(playerTab, "Kekuatan Lompat", 20, 200, 5, 50, function(v)
    jumpHighPower = v
    if jumpHighEnabled then humanoid.JumpPower = v end
end)
addToggle(playerTab, "God Mode", false, function(v) setGodMode(v) end)

-- === TAB 4: UPCOMING ===
local upcomingLabel = Instance.new("TextLabel")
upcomingLabel.Size = UDim2.new(1, -20, 0, 50)
upcomingLabel.Position = UDim2.new(0, 10, 0, 20)
upcomingLabel.BackgroundTransparency = 1
upcomingLabel.Text = "✨ Fitur akan segera hadir ✨\n- Speed Run\n- Ghost Mode\n- Auto Record"
upcomingLabel.TextColor3 = Color3.fromRGB(200,200,200)
upcomingLabel.Font = Enum.Font.GothamBold
upcomingLabel.TextSize = 16
upcomingLabel.TextWrapped = true
upcomingLabel.Parent = upcomingTab

-- Aktifkan tab pertama
for _, t in pairs(tabs) do t.page.Visible = false end
recTab.Visible = true
tabs["rec"].btn.TextColor3 = Color3.fromRGB(255,255,255)

-- Inisialisasi
createStatusIndicator()
notif("Renn HUB Universal - Motion Recorder Pro siap!", "success")