--[[
    Renn HUB Universal - Motion Recorder Pro
    Dengan sistem Path Recovery
    FIX: Perbaikan loading WindUI dan error handling
--]]

-- ========== LOAD WINDUI DENGAN ERROR HANDLING ==========
local WindUI
local loadSuccess, loadErr = pcall(function()
    -- Gunakan raw URL yang benar dari GitHub
    WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"))()
end)

if not loadSuccess then
    -- Fallback: buat notifikasi sederhana dengan GUI sendiri
    warn("Gagal load WindUI: " .. tostring(loadErr))
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RennHUB_Error"
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.5, -150, 0.5, -50)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    frame.Parent = ScreenGui
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1,0,1,0)
    text.BackgroundTransparency = 1
    text.Text = "Gagal memuat WindUI!\n" .. tostring(loadErr):sub(1, 100)
    text.TextColor3 = Color3.new(1,1,1)
    text.TextWrapped = true
    text.Parent = frame
    error("WindUI tidak dapat dimuat: " .. tostring(loadErr))
end

-- ========== VARIABEL GLOBAL ==========
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local pathfindingService = game:GetService("PathfindingService")
local tweenService = game:GetService("TweenService")

-- Recording
local recording = false
local recordingPaused = false
local recordedFrames = {}
local startTime = 0
local pauseTimeOffset = 0

-- Playback
local playing = false
local reverse = false
local playbackThread = nil
local playbackSpeed = 1.0
local loopMode = false
local currentPlaybackData = nil
local playbackStartTime = 0
local playbackTotalTime = 0

-- Path Recovery
local recoveryActive = false
local recoveryThread = nil
local recoveryTargetFrame = nil
local recoveryTargetTime = 0
local recoveryStartPos = nil
local recoveryPath = nil
local recoveryConnection = nil
local recoveryWaitingForUser = false

-- Trail
local trailParts = {}
local trailActive = true
local trailColor = Color3.fromRGB(255, 50, 50)
local lastTrailPos = nil

-- Save system
local SAVE_FOLDER = "RennMotionSaves"

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

-- ========== FUNGSI NOTIFIKASI ==========
local function notif(msg, msgType)
    if WindUI and WindUI.Notify then
        local title = msgType == "error" and "Error" or (msgType == "success" and "Success" or "Info")
        WindUI:Notify({
            Title = title,
            Description = msg,
            Duration = 2
        })
    end
    print("[RennHUB] " .. msg)
end

-- ========== TRAIL ==========
local function clearTrail()
    for _, part in pairs(trailParts) do
        if part and part.Parent then part:Destroy() end
    end
    trailParts = {}
    lastTrailPos = nil
end

local function addTrailSegment(pos)
    if not trailActive then return end
    if lastTrailPos then
        local distance = (pos - lastTrailPos).Magnitude
        if distance < 0.1 then return end
        local midPoint = (lastTrailPos + pos) / 2
        local length = distance
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.2, 0.2, length)
        part.CFrame = CFrame.new(midPoint, pos) * CFrame.new(0, 0, -length/2)
        part.Anchored = true
        part.CanCollide = false
        part.BrickColor = BrickColor.new(trailColor)
        part.Material = Enum.Material.Neon
        part.Parent = workspace
        game:GetService("Debris"):AddItem(part, 3600)
        table.insert(trailParts, part)
    end
    lastTrailPos = pos
end

local function updateTrail()
    if trailActive and hrp and hrp.Parent then
        addTrailSegment(hrp.Position)
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
    if hrp and hrp.Parent then
        table.insert(recordedFrames, {
            time = 0,
            cframe = hrp.CFrame,
            position = hrp.Position,
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
    notif("Jeda rekaman", "info")
end

local function resumeRecording()
    if not recording or not recordingPaused then return end
    recordingPaused = false
    startTime = os.clock() - pauseTimeOffset
    notif("Lanjut rekam", "info")
end

local function stopRecording()
    if not recording then notif("Tidak ada rekaman aktif", "error") return end
    recording = false
    recordingPaused = false
    notif("Rekaman dihentikan", "info")
end

local function saveCurrentRecordingManually()
    if #recordedFrames == 0 then notif("Tidak ada rekaman", "error") return end
    if WindUI and WindUI.Input then
        local dialog = WindUI:Input({
            Title = "Simpan Rekaman",
            Description = "Masukkan nama rekaman",
            Placeholder = "Nama rekaman"
        })
        dialog.OnSubmit = function(name)
            if name == "" then name = "rec_" .. os.time() end
            local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
            folder.Name = SAVE_FOLDER
            local existing = folder:FindFirstChild(name)
            if existing then existing:Destroy() end
            local val = Instance.new("StringValue")
            val.Name = name
            val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
            val.Parent = folder
            notif("Tersimpan: " .. name, "success")
            if refreshSaveListCallback then refreshSaveListCallback() end
        end
    else
        -- Fallback tanpa dialog
        local name = "rec_" .. os.time()
        local folder = player:FindFirstChild(SAVE_FOLDER) or Instance.new("Folder", player)
        folder.Name = SAVE_FOLDER
        local val = Instance.new("StringValue")
        val.Name = name
        val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
        val.Parent = folder
        notif("Tersimpan: " .. name, "success")
        if refreshSaveListCallback then refreshSaveListCallback() end
    end
end

-- Rekam loop
runService.RenderStepped:Connect(function()
    if recording and not recordingPaused and hrp and hrp.Parent then
        local now = os.clock() - startTime
        table.insert(recordedFrames, {
            time = now,
            cframe = hrp.CFrame,
            position = hrp.Position,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
    updateTrail()
end)

-- ========== PATH RECOVERY ==========
local function findNearestFrame(pos, data)
    local nearestIdx = 1
    local nearestDist = (data[1].position - pos).Magnitude
    for i = 2, #data do
        local dist = (data[i].position - pos).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestIdx = i
        end
    end
    return nearestIdx, data[nearestIdx].time, nearestDist
end

local function cancelRecovery()
    if recoveryConnection then recoveryConnection:Disconnect() recoveryConnection = nil end
    if recoveryThread then task.cancel(recoveryThread) recoveryThread = nil end
    recoveryActive = false
    recoveryWaitingForUser = false
    humanoid.PlatformStand = false
    humanoid.AutoRotate = true
    if hrp:FindFirstChild("BodyVelocity") then hrp:FindFirstChild("BodyVelocity"):Destroy() end
    if hrp:FindFirstChild("BodyPosition") then hrp:FindFirstChild("BodyPosition"):Destroy() end
end

local function startPathRecovery(forceTeleport)
    if recoveryActive or not currentPlaybackData or not playing then return end
    
    local currentPos = hrp.Position
    local nearestIdx, targetTime, distance = findNearestFrame(currentPos, currentPlaybackData)
    local targetPos = currentPlaybackData[nearestIdx].position
    
    if forceTeleport then
        hrp.CFrame = currentPlaybackData[nearestIdx].cframe
        hrp.AssemblyLinearVelocity = Vector3.zero
        playbackStartTime = os.clock() - (targetTime / playbackSpeed)
        notif("Teleport ke jalur", "info")
        cancelRecovery()
        return
    end
    
    if distance > 150 and not recoveryWaitingForUser then
        recoveryWaitingForUser = true
        local wasPlaying = playing
        if playing then
            playing = false
            if playbackThread then task.cancel(playbackThread) end
        end
        
        if WindUI and WindUI.Dialog then
            local dialog = WindUI:Dialog({
                Title = "Jarak terlalu jauh",
                Description = string.format("Jarak ke jalur rekaman: %.1f studs. Pilih tindakan:", distance),
                Buttons = {
                    {Text = "Pulihkan otomatis", Callback = function()
                        recoveryWaitingForUser = false
                        if wasPlaying then startPathRecovery(false) else cancelRecovery() end
                    end},
                    {Text = "Batalkan Replay", Callback = function()
                        recoveryWaitingForUser = false
                        stopPlayback()
                        cancelRecovery()
                    end},
                    {Text = "Teleport ke jalur", Callback = function()
                        recoveryWaitingForUser = false
                        if wasPlaying then startPathRecovery(true) else cancelRecovery() end
                    end}
                }
            })
        else
            -- Fallback: langsung teleport
            recoveryWaitingForUser = false
            startPathRecovery(true)
        end
        return
    end
    
    recoveryActive = true
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    
    local path = pathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45
    })
    
    local success, err = pcall(function()
        path:ComputeAsync(currentPos, targetPos)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        notif("Tidak dapat menemukan jalur, coba teleport", "error")
        recoveryActive = false
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        if WindUI and WindUI.Dialog then
            WindUI:Dialog({
                Title = "Jalur terhalang",
                Description = "Pathfinding gagal. Teleport ke jalur terdekat?",
                Buttons = {
                    {Text = "Teleport", Callback = function() startPathRecovery(true) end},
                    {Text = "Batalkan", Callback = function() stopPlayback() end}
                }
            })
        else
            startPathRecovery(true)
        end
        return
    end
    
    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        notif("Tidak ada waypoint", "error")
        recoveryActive = false
        humanoid.PlatformStand = false
        return
    end
    
    notif("Memulihkan jalur...", "info")
    
    recoveryThread = task.spawn(function()
        for i, waypoint in ipairs(waypoints) do
            if not recoveryActive then break end
            local targetWp = waypoint.Position
            local bodyVel = Instance.new("BodyVelocity")
            bodyVel.MaxForce = Vector3.new(4000, 4000, 4000)
            bodyVel.Velocity = (targetWp - hrp.Position).Unit * 16
            bodyVel.Parent = hrp
            
            repeat
                runService.RenderStepped:Wait()
                if not recoveryActive then break end
                local newDir = (targetWp - hrp.Position).Unit
                bodyVel.Velocity = newDir * 16
                hrp.CFrame = CFrame.new(hrp.Position, targetWp)
            until (hrp.Position - targetWp).Magnitude < 3 or not recoveryActive
            
            bodyVel:Destroy()
        end
        
        if recoveryActive then
            hrp.CFrame = currentPlaybackData[nearestIdx].cframe
            hrp.AssemblyLinearVelocity = Vector3.zero
            playbackStartTime = os.clock() - (targetTime / playbackSpeed)
            notif("Kembali ke jalur, melanjutkan replay", "success")
            cancelRecovery()
            if currentPlaybackData then
                startPlayback(currentPlaybackData, reverse, playbackSpeed, loopMode)
            end
        end
    end)
end

-- ========== PLAYBACK ==========
local function stopPlayback()
    if playing then
        if playbackThread then task.cancel(playbackThread) end
        playing = false
        if recoveryActive then cancelRecovery() end
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        currentPlaybackData = nil
        notif("Playback dihentikan", "info")
    end
end

local function startPlayback(data, isReverse, speed, loop)
    if recording then notif("Hentikan rekaman dulu", "error") return end
    if playing then stopPlayback() end
    if not data or #data < 2 then notif("Data kosong", "error") return end
    
    playing = true
    reverse = isReverse
    currentPlaybackData = data
    playbackSpeed = speed
    loopMode = loop
    local totalTime = data[#data].time
    playbackTotalTime = totalTime
    playbackStartTime = os.clock()
    local lastJump = false
    humanoid.PlatformStand = true
    humanoid.AutoRotate = true
    
    playbackThread = task.spawn(function()
        while playing and not recoveryActive do
            local now = (os.clock() - playbackStartTime) * playbackSpeed
            local progress
            if reverse then
                progress = 1 - (now / totalTime)
                if progress < 0 then
                    if loop then
                        playbackStartTime = os.clock()
                        now = 0
                        progress = 1
                    else
                        break
                    end
                end
            else
                progress = now / totalTime
                if progress > 1 then
                    if loop then
                        playbackStartTime = os.clock()
                        now = 0
                        progress = 0
                    else
                        break
                    end
                end
            end
            progress = math.clamp(progress, 0, 1)
            local targetTime = progress * totalTime
            
            local idx1, idx2
            for i = 1, #data-1 do
                if data[i].time <= targetTime and data[i+1].time >= targetTime then
                    idx1 = i
                    idx2 = i+1
                    break
                end
            end
            if not idx1 then
                if targetTime <= data[1].time then idx1, idx2 = 1, 2
                else idx1, idx2 = #data-1, #data end
            end
            
            local f1 = data[idx1]
            local f2 = data[idx2]
            local alpha = (targetTime - f1.time) / (f2.time - f1.time)
            alpha = math.clamp(alpha, 0, 1)
            
            local newCFrame = f1.cframe:Lerp(f2.cframe, alpha)
            local newVelocity = f1.velocity:Lerp(f2.velocity, alpha)
            local moveDir = f1.moveDirection:Lerp(f2.moveDirection, alpha)
            
            hrp.CFrame = newCFrame
            hrp.AssemblyLinearVelocity = newVelocity
            
            if moveDir.Magnitude > 0 then
                humanoid:MoveTo(hrp.Position + moveDir * 10)
            else
                humanoid:MoveTo(hrp.Position)
            end
            
            local isJumpingNow = alpha > 0.5 and f2.isJumping or f1.isJumping
            if isJumpingNow and not lastJump and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end
            lastJump = isJumpingNow
            
            -- Cek penyimpangan setiap 30 frame
            if math.random(1, 30) == 1 then
                local currentPos = hrp.Position
                local expectedPos = f1.position:Lerp(f2.position, alpha)
                local deviation = (currentPos - expectedPos).Magnitude
                if deviation > 15 and not recoveryActive then
                    startPathRecovery(false)
                    break
                end
            end
            
            runService.RenderStepped:Wait()
        end
        if playing and not recoveryActive then
            playing = false
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            notif("Playback selesai", "success")
        end
    end)
end

-- ========== SAVE/LOAD/DELETE ==========
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

local function deleteRecording(name)
    if name == "" then notif("Masukkan nama", "error") return end
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if folder then
        local val = folder:FindFirstChild(name)
        if val then 
            val:Destroy()
            notif("Dihapus: " .. name, "success")
            if refreshSaveListCallback then refreshSaveListCallback() end
        else
            notif("Tidak ditemukan", "error")
        end
    end
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

-- Character respawn
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    jumpPowerOriginal = humanoid.JumpPower
    if flyEnabled then disableFly() end
    if noclipEnabled then updateNoclip() end
    if jumpHighEnabled then setJumpHigh(true) end
    if godModeEnabled then setGodMode(true) end
    clearTrail()
end)

-- ========== TRAIL COLOR ==========
local function setTrailColor(color)
    trailColor = color
    for _, part in pairs(trailParts) do
        if part and part.Parent then
            part.BrickColor = BrickColor.new(trailColor)
        end
    end
end

-- ========== MEMBANGUN GUI DENGAN WINDUI ==========
-- Tunggu sebentar agar player siap
task.wait(1)

local win = WindUI:Window({
    Title = "Renn HUB Universal - Motion Recorder Pro",
    SubTitle = "Dengan Path Recovery",
    Size = UDim2.fromOffset(400, 550),
    Center = true,
    ShowClose = true,
    Draggable = true
})

-- Tab 1: Motion Recorder
local recTab = win:Tab("Motion Recorder")
local recGroup = recTab:Group("Kontrol Rekam", true)
recGroup:Button("Start Record", function() startRecording() end)
recGroup:Button("Pause Record", function() pauseRecording() end)
recGroup:Button("Resume Record", function() resumeRecording() end)
recGroup:Button("Stop Record", function() stopRecording() end)

-- Tab 2: Playback
local playTab = win:Tab("Playback")
local playGroup = playTab:Group("Kontrol Playback", true)
playGroup:Button("Play Normal ▶", function()
    if #recordedFrames >= 2 then
        startPlayback(recordedFrames, false, playbackSpeed, loopMode)
    else
        notif("Rekam dulu", "error")
    end
end)
playGroup:Button("Play Reverse ◀", function()
    if #recordedFrames >= 2 then
        startPlayback(recordedFrames, true, playbackSpeed, loopMode)
    else
        notif("Rekam dulu", "error")
    end
end)
playGroup:Button("Stop Playback", function() stopPlayback() end)
playGroup:Slider({
    Title = "Playback Speed",
    Min = 0.25,
    Max = 3,
    Default = 1,
    Precision = 2
}, function(value)
    playbackSpeed = value
    if playing and not recoveryActive and currentPlaybackData then
        local wasPlaying = playing
        local wasReverse = reverse
        local wasLoop = loopMode
        local data = currentPlaybackData
        if data then
            stopPlayback()
            startPlayback(data, wasReverse, value, wasLoop)
        end
    end
end)
playGroup:Toggle({
    Title = "Loop Mode",
    Default = false
}, function(value)
    loopMode = value
end)

-- Tab 3: Saves
local saveTab = win:Tab("Saves")
local saveGroup = saveTab:Group("Manajemen Rekaman", true)
saveGroup:Button("Save Recording", function() saveCurrentRecordingManually() end)

local saveList = refreshSaveList()
local loadDropdown = saveGroup:Dropdown({
    Title = "Load Recording",
    Values = #saveList > 0 and saveList or {"(kosong)"},
    Multi = false
})
loadDropdown.OnChanged = function(value)
    if value ~= "(kosong)" then
        loadRecordingByName(value)
    end
end

local deleteInput = saveGroup:Input({
    Title = "Delete Recording",
    Placeholder = "Nama rekaman"
})
saveGroup:Button("Delete", function()
    deleteRecording(deleteInput.Value)
end)
saveGroup:Button("Refresh List", function()
    local newList = refreshSaveList()
    if #newList == 0 then newList = {"(kosong)"} end
    loadDropdown:SetValues(newList)
    notif("Daftar diperbarui", "info")
end)

local refreshSaveListCallback = function()
    local newList = refreshSaveList()
    if #newList == 0 then newList = {"(kosong)"} end
    loadDropdown:SetValues(newList)
end

-- Tab 4: Visual & Player
local visualTab = win:Tab("Visual & Player")
local trailGroup = visualTab:Group("Trail", true)
trailGroup:Toggle({
    Title = "Aktifkan Trail",
    Default = true
}, function(value)
    trailActive = value
    if not value then clearTrail() end
end)
trailGroup:ColorPicker({
    Title = "Warna Trail",
    Default = Color3.fromRGB(255, 50, 50)
}, function(color)
    setTrailColor(color)
end)
trailGroup:Button("Clear Trail", function() clearTrail() end)

local playerGroup = visualTab:Group("Player Features", true)
playerGroup:Toggle({
    Title = "Fly Mode",
    Default = false
}, function(value)
    if value then enableFly() else disableFly() end
end)
playerGroup:Slider({
    Title = "Fly Speed",
    Min = 1,
    Max = 50,
    Default = 16,
    Precision = 0
}, function(value)
    flySpeed = value
end)
playerGroup:Toggle({
    Title = "Noclip",
    Default = false
}, function(value)
    noclipEnabled = value
    updateNoclip()
end)
playerGroup:Toggle({
    Title = "Jump High",
    Default = false
}, function(value)
    setJumpHigh(value)
end)
playerGroup:Slider({
    Title = "Jump Power",
    Min = 20,
    Max = 200,
    Default = 50,
    Precision = 0
}, function(value)
    jumpHighPower = value
    if jumpHighEnabled then humanoid.JumpPower = value end
end)
playerGroup:Toggle({
    Title = "God Mode",
    Default = false
}, function(value)
    setGodMode(value)
end)

-- Tab 5: About / Upcoming
local aboutTab = win:Tab("About")
local infoGroup = aboutTab:Group("Informasi Script", true)
infoGroup:Label("Renn HUB Universal - Motion Recorder Pro")
infoGroup:Label("Version 3.0 dengan Path Recovery")
infoGroup:Label("Fitur lengkap: Rekam, Playback, Trail, Save/Load, Player mods")
infoGroup:Label("Sistem pemulihan jalur otomatis jika karakter keluar")
local upcomingGroup = aboutTab:Group("Fitur Mendatang", true)
upcomingGroup:Label("✨ Speed Run Mode")
upcomingGroup:Label("✨ Ghost Mode")
upcomingGroup:Label("✨ Auto Record on Death")
upcomingGroup:Label("✨ Export/Import rekaman")

notif("Renn HUB Universal - Motion Recorder Pro siap!", "success")