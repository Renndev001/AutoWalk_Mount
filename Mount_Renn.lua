--[[
    Renn HUB Universal - Motion Recorder Pro
    GUI Manual (tanpa dependensi eksternal)
    Fitur: Rekam, Playback dgn Path Recovery, Trail, Save/Load, Player Features
--]]

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
    local gui = player.PlayerGui:FindFirstChild("RennHUB")
    if not gui then return end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 280, 0, 40)
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
    text.TextWrapped = true
    text.Parent = toast
    tweenService:Create(toast, TweenInfo.new(0.2), {Position = UDim2.new(0.5, -140, 1, -60)}):Play()
    task.wait(2)
    tweenService:Create(toast, TweenInfo.new(0.2), {Position = UDim2.new(0.5, -140, 1, -10)}):Play()
    task.wait(0.2)
    toast:Destroy()
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
    -- Dialog sederhana pakai input box buatan sendiri
    local gui = player.PlayerGui:FindFirstChild("RennHUB")
    if not gui then return end
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 280, 0, 120)
    dialog.Position = UDim2.new(0.5, -140, 0.5, -60)
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
    ok.Font = Enum.Font.GothamBold
    ok.Parent = dialog
    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0.3, 0, 0, 30)
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
        local existing = folder:FindFirstChild(name)
        if existing then existing:Destroy() end
        local val = Instance.new("StringValue")
        val.Name = name
        val.Value = httpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
        val.Parent = folder
        notif("Tersimpan: " .. name, "success")
        dialog:Destroy()
        if refreshSaveListCallback then refreshSaveListCallback() end
    end)
    cancel.MouseButton1Click:Connect(function() dialog:Destroy() end)
end

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
    if recoveryThread then task.cancel(recoveryThread) recoveryThread = nil end
    recoveryActive = false
    recoveryWaitingForUser = false
    humanoid.PlatformStand = false
    humanoid.AutoRotate = true
    if hrp:FindFirstChild("BodyVelocity") then hrp:FindFirstChild("BodyVelocity"):Destroy() end
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
        
        -- Dialog pilihan manual
        local gui = player.PlayerGui:FindFirstChild("RennHUB")
        if gui then
            local dialog = Instance.new("Frame")
            dialog.Size = UDim2.new(0, 300, 0, 150)
            dialog.Position = UDim2.new(0.5, -150, 0.5, -75)
            dialog.BackgroundColor3 = Color3.fromRGB(40,40,50)
            dialog.BorderSizePixel = 0
            dialog.Parent = gui
            local dCorner = Instance.new("UICorner")
            dCorner.CornerRadius = UDim.new(0, 8)
            dCorner.Parent = dialog
            
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 40)
            title.BackgroundTransparency = 1
            title.Text = string.format("Jarak terlalu jauh: %.1f studs", distance)
            title.TextColor3 = Color3.new(1,1,1)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 14
            title.TextWrapped = true
            title.Parent = dialog
            
            local btn1 = Instance.new("TextButton")
            btn1.Size = UDim2.new(0.28, 0, 0, 35)
            btn1.Position = UDim2.new(0.05, 0, 0.65, 0)
            btn1.Text = "Pulihkan"
            btn1.BackgroundColor3 = Color3.fromRGB(70,150,70)
            btn1.Font = Enum.Font.GothamBold
            btn1.Parent = dialog
            
            local btn2 = Instance.new("TextButton")
            btn2.Size = UDim2.new(0.28, 0, 0, 35)
            btn2.Position = UDim2.new(0.36, 0, 0.65, 0)
            btn2.Text = "Batalkan"
            btn2.BackgroundColor3 = Color3.fromRGB(150,70,70)
            btn2.Font = Enum.Font.GothamBold
            btn2.Parent = dialog
            
            local btn3 = Instance.new("TextButton")
            btn3.Size = UDim2.new(0.28, 0, 0, 35)
            btn3.Position = UDim2.new(0.67, 0, 0.65, 0)
            btn3.Text = "Teleport"
            btn3.BackgroundColor3 = Color3.fromRGB(70,70,150)
            btn3.Font = Enum.Font.GothamBold
            btn3.Parent = dialog
            
            btn1.MouseButton1Click:Connect(function()
                dialog:Destroy()
                recoveryWaitingForUser = false
                if wasPlaying then startPathRecovery(false) else cancelRecovery() end
            end)
            btn2.MouseButton1Click:Connect(function()
                dialog:Destroy()
                recoveryWaitingForUser = false
                stopPlayback()
                cancelRecovery()
            end)
            btn3.MouseButton1Click:Connect(function()
                dialog:Destroy()
                recoveryWaitingForUser = false
                if wasPlaying then startPathRecovery(true) else cancelRecovery() end
            end)
        else
            -- fallback
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
        startPathRecovery(true)
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

local function setTrailColor(color)
    trailColor = color
    for _, part in pairs(trailParts) do
        if part and part.Parent then
            part.BrickColor = BrickColor.new(trailColor)
        end
    end
end

-- ========== MEMBANGUN GUI MANUAL (MODERN, DRAGABLE, RESIZABLE) ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RennHUB"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Size = UDim2.new(0, 380, 0, 520)
window.Position = UDim2.new(0.5, -190, 0.5, -260)
window.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = screenGui
local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 12)
winCorner.Parent = window

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleBar.Parent = window
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -90, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Renn HUB - Motion Recorder"
titleText.TextColor3 = Color3.fromRGB(255, 200, 100)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 15
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 35, 1, 0)
minBtn.Position = UDim2.new(1, -70, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "−"
minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 20
minBtn.Parent = titleBar
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 1, 0)
closeBtn.Position = UDim2.new(1, -35, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetHeight = minimized and 40 or 520
    tweenService:Create(window, TweenInfo.new(0.2), {Size = UDim2.new(0, 380, 0, targetHeight)}):Play()
end)
closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

-- Drag window
local dragStartPos, dragStartMousePos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStartPos = window.Position
        dragStartMousePos = input.Position
        local moveConn, upConn
        moveConn = userInputService.InputChanged:Connect(function(inp)
            if inp.UserInputType == input.UserInputType and dragStartPos then
                local delta = inp.Position - dragStartMousePos
                window.Position = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
            end
        end)
        upConn = userInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == input.UserInputType then
                dragStartPos = nil
                moveConn:Disconnect()
                upConn:Disconnect()
            end
        end)
    end
end)

-- Resize handle
local resizeHandle = Instance.new("Frame")
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.BackgroundColor3 = Color3.fromRGB(80,80,90)
resizeHandle.BackgroundTransparency = 0.6
resizeHandle.Parent = window
local handleCorner = Instance.new("UICorner")
handleCorner.CornerRadius = UDim.new(0, 4)
handleCorner.Parent = resizeHandle

local resizing = false
local startSize, startMouseResize
resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        startSize = window.AbsoluteSize
        startMouseResize = input.Position
        local moveConn, upConn
        moveConn = userInputService.InputChanged:Connect(function(inp)
            if resizing and inp.UserInputType == input.UserInputType then
                local delta = inp.Position - startMouseResize
                local newWidth = math.clamp(startSize.X + delta.X, 300, 600)
                local newHeight = math.clamp(startSize.Y + delta.Y, 400, 650)
                window.Size = UDim2.new(0, newWidth, 0, newHeight)
            end
        end)
        upConn = userInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == input.UserInputType then
                resizing = false
                moveConn:Disconnect()
                upConn:Disconnect()
            end
        end)
    end
end)

-- Scrollable content
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -40)
scrollFrame.Position = UDim2.new(0, 0, 0, 40)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = window
local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 10)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Parent = scrollFrame
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 20)
end)

-- Helper: buat section accordion
local function createSection(parent, title)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -16, 0, 0)
    container.BackgroundTransparency = 1
    container.Parent = parent
    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 42)
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
        container.Size = UDim2.new(1, -16, 0, 42 + (expanded and h or 0))
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
    frame.Size = UDim2.new(1, -20, 0, 44)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 65, 0, 32)
    toggleBtn.Position = UDim2.new(1, -70, 0.5, -16)
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
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new((default-minVal)/(maxVal-minVal), -9, -0.5, 0)
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
        knob.Position = UDim2.new((val-minVal)/(maxVal-minVal), -9, -0.5, 0)
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
    frame.Size = UDim2.new(1, -20, 0, 46)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
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
    local function showMenu()
        if menu then menu:Destroy(); menu = nil; return end
        local currentItems = refreshSaveList()
        if #currentItems == 0 then currentItems = {"(kosong)"} end
        menu = Instance.new("Frame")
        menu.Size = UDim2.new(1, 0, 0, #currentItems * 34)
        menu.Position = UDim2.new(0, 0, 0, 36)
        menu.BackgroundColor3 = Color3.fromRGB(50,55,65)
        menu.Parent = frame
        local menuCorner = Instance.new("UICorner")
        menuCorner.CornerRadius = UDim.new(0, 6)
        menuCorner.Parent = menu
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.Parent = menu
        for _, item in ipairs(currentItems) do
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
    end
    btn.MouseButton1Click:Connect(showMenu)
    return frame, function()
        if menu then menu:Destroy(); menu = nil end
        btn.Text = placeholder
    end
end

local function addColorPicker(parent, title, defaultColor, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 44)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local colorBtn = Instance.new("TextButton")
    colorBtn.Size = UDim2.new(0, 65, 0, 32)
    colorBtn.Position = UDim2.new(1, -70, 0.5, -16)
    colorBtn.BackgroundColor3 = defaultColor
    colorBtn.Text = ""
    colorBtn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = colorBtn
    colorBtn.MouseButton1Click:Connect(function()
        -- Color picker sederhana (pilih dari beberapa preset)
        local gui = screenGui
        local cp = Instance.new("Frame")
        cp.Size = UDim2.new(0, 200, 0, 150)
        cp.Position = UDim2.new(0.5, -100, 0.5, -75)
        cp.BackgroundColor3 = Color3.fromRGB(40,40,50)
        cp.Parent = gui
        local cpCorner = Instance.new("UICorner")
        cpCorner.CornerRadius = UDim.new(0, 8)
        cpCorner.Parent = cp
        local colors = {
            Color3.fromRGB(255,50,50), -- merah
            Color3.fromRGB(50,255,50), -- hijau
            Color3.fromRGB(50,50,255), -- biru
            Color3.fromRGB(255,255,50), -- kuning
            Color3.fromRGB(255,50,255), -- ungu
            Color3.fromRGB(50,255,255), -- cyan
            Color3.fromRGB(255,128,0), -- orange
            Color3.fromRGB(255,255,255) -- putih
        }
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Parent = cp
        for _, col in ipairs(colors) do
            local btnCol = Instance.new("TextButton")
            btnCol.Size = UDim2.new(0, 40, 0, 40)
            btnCol.BackgroundColor3 = col
            btnCol.Text = ""
            btnCol.Parent = cp
            local btnCor = Instance.new("UICorner")
            btnCor.CornerRadius = UDim.new(0, 6)
            btnCor.Parent = btnCol
            btnCol.MouseButton1Click:Connect(function()
                colorBtn.BackgroundColor3 = col
                callback(col)
                cp:Destroy()
            end)
        end
        local cancelBtn = Instance.new("TextButton")
        cancelBtn.Size = UDim2.new(0, 80, 0, 30)
        cancelBtn.Position = UDim2.new(0.5, -40, 1, -40)
        cancelBtn.Text = "Batal"
        cancelBtn.BackgroundColor3 = Color3.fromRGB(150,70,70)
        cancelBtn.Font = Enum.Font.GothamBold
        cancelBtn.Parent = cp
        cancelBtn.MouseButton1Click:Connect(function() cp:Destroy() end)
    end)
    return frame
end

-- ========== MEMBANGUN UI ==========
-- Section 1: Motion Recorder
local recSection = createSection(scrollFrame, "1. Motion Recorder")
addButton(recSection, "Start Record", startRecording)
addButton(recSection, "Pause Record", pauseRecording)
addButton(recSection, "Resume Record", resumeRecording)
addButton(recSection, "Stop Record", stopRecording)

-- Section 2: Playback
local playSection = createSection(scrollFrame, "2. Playback")
addButton(playSection, "Play Normal ▶", function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, false, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
addButton(playSection, "Play Reverse ◀", function()
    if #recordedFrames >= 2 then startPlayback(recordedFrames, true, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end)
addButton(playSection, "Stop Playback", stopPlayback)
addSlider(playSection, "Playback Speed", 0.25, 3, 0.05, 1, function(v) playbackSpeed = v end)
addToggle(playSection, "Loop Mode", false, function(v) loopMode = v end)

-- Section 3: Saves
local saveSection = createSection(scrollFrame, "3. Saves")
addButton(saveSection, "Save Recording", saveCurrentRecordingManually)

-- Load dropdown
local loadDropdownFrame, refreshDropdown = addDropdown(saveSection, "Pilih rekaman...", {}, function(name)
    if name ~= "(kosong)" then loadRecordingByName(name) end
end)

-- Delete with input
local deleteFrame = Instance.new("Frame")
deleteFrame.Size = UDim2.new(1, -20, 0, 46)
deleteFrame.BackgroundTransparency = 1
deleteFrame.Parent = saveSection
local deleteLabel = Instance.new("TextLabel")
deleteLabel.Size = UDim2.new(1, -80, 1, 0)
deleteLabel.BackgroundTransparency = 1
deleteLabel.Text = "Hapus Rekaman"
deleteLabel.TextColor3 = Color3.new(1,1,1)
deleteLabel.Font = Enum.Font.GothamBold
deleteLabel.TextSize = 14
deleteLabel.TextXAlignment = Enum.TextXAlignment.Left
deleteLabel.Parent = deleteFrame
local deleteInput = Instance.new("TextBox")
deleteInput.Size = UDim2.new(0, 120, 0, 32)
deleteInput.Position = UDim2.new(1, -125, 0.5, -16)
deleteInput.PlaceholderText = "Nama file"
deleteInput.BackgroundColor3 = Color3.fromRGB(60,65,75)
deleteInput.TextColor3 = Color3.new(1,1,1)
deleteInput.Font = Enum.Font.Gotham
deleteInput.TextSize = 12
deleteInput.Parent = deleteFrame
local deleteBtn = Instance.new("TextButton")
deleteBtn.Size = UDim2.new(0, 55, 0, 32)
deleteBtn.Position = UDim2.new(1, -65, 0.5, -16)
deleteBtn.Text = "Hapus"
deleteBtn.BackgroundColor3 = Color3.fromRGB(180,70,70)
deleteBtn.Font = Enum.Font.GothamBold
deleteBtn.TextSize = 12
deleteBtn.Parent = deleteFrame
deleteBtn.MouseButton1Click:Connect(function()
    local name = deleteInput.Text
    if name ~= "" then
        deleteRecording(name)
        deleteInput.Text = ""
    else
        notif("Masukkan nama", "error")
    end
end)

addButton(saveSection, "Refresh List", function()
    refreshDropdown()
    notif("Daftar diperbarui", "info")
end)

refreshSaveListCallback = refreshDropdown

-- Section 4: Visual & Player
local visualSection = createSection(scrollFrame, "4. Visual & Player")
addToggle(visualSection, "Aktifkan Trail", true, function(v) 
    trailActive = v
    if not v then clearTrail() end
end)
addColorPicker(visualSection, "Warna Trail", Color3.fromRGB(255,50,50), function(color)
    setTrailColor(color)
end)
addButton(visualSection, "Clear Trail", clearTrail)

addToggle(visualSection, "Fly Mode", false, function(v) if v then enableFly() else disableFly() end end)
addSlider(visualSection, "Fly Speed", 1, 50, 1, 16, function(v) flySpeed = v end)
addToggle(visualSection, "Noclip", false, function(v) noclipEnabled = v; updateNoclip() end)
addToggle(visualSection, "Jump High", false, function(v) setJumpHigh(v) end)
addSlider(visualSection, "Jump Power", 20, 200, 5, 50, function(v) jumpHighPower = v; if jumpHighEnabled then humanoid.JumpPower = v end end)
addToggle(visualSection, "God Mode", false, function(v) setGodMode(v) end)

-- Section 5: About / Upcoming
local aboutSection = createSection(scrollFrame, "5. About / Upcoming")
local aboutText = Instance.new("TextLabel")
aboutText.Size = UDim2.new(1, -20, 0, 100)
aboutText.BackgroundTransparency = 1
aboutText.Text = "Renn HUB Universal - Motion Recorder Pro\nVersion 3.0 dengan Path Recovery\n\nFitur mendatang:\n- Speed Run Mode\n- Ghost Mode\n- Auto Record on Death\n- Export/Import rekaman"
aboutText.TextColor3 = Color3.fromRGB(200,200,200)
aboutText.Font = Enum.Font.GothamBold
aboutText.TextSize = 13
aboutText.TextWrapped = true
aboutText.Parent = aboutSection

notif("Renn HUB Universal - Motion Recorder Pro siap!", "success")