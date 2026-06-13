--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                      RENN HUB - FINAL                        ║
    ║         TAS Engine (60 FPS) + Teleport + Movement            ║
    ║          Utilities + Cloud Export + DRAG & RESIZE            ║
    ║                 Compatible for Mobile & PC                    ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== GLOBAL VARIABLES ==========
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local runService = game:GetService("RunService")
local userInput = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")

-- TAS Engine
local recording = false
local recordedFrames = {}
local startTime = 0
local playing = false
local reverse = false
local loopPlay = false
local playbackSpeed = 1
local playbackThread = nil
local trailObjects = {}
local trailVisible = true

-- Teleport & Checkpoint
local checkpoints = {}
local autoCheckpoint = false
local lastCheckpointPos = nil
local teleportIndex = 1
local autoTeleportRunning = false

-- Movement
local originalWS = humanoid.WalkSpeed
local originalJP = humanoid.JumpPower
local noclipEnabled = false
local noclipConnect = nil
local flyEnabled = false
local flySpeed = 50
local flyBodyVelocity = nil
local infiniteJumpConn = nil

-- Utilities
local antiAFKEnabled = false
local antiAfkConnection = nil

-- ========== HELPER FUNCTIONS ==========
local function notify(msg, duration)
    duration = duration or 2
    Rayfield:Notify({Title = "Renn HUB", Content = msg, Duration = duration})
    print("[Renn HUB] " .. msg)
end

local function getCharacter()
    return player.Character
end

-- ========== TAS ENGINE (60 FPS) ==========
local function startRecording()
    if recording then notify("Already recording") return end
    if playing then notify("Stop playback first") return end
    recordedFrames = {}
    startTime = os.clock()
    recording = true
    local charNow = getCharacter()
    if charNow and charNow:FindFirstChild("HumanoidRootPart") then
        local root = charNow.HumanoidRootPart
        local hum = charNow:FindFirstChild("Humanoid")
        table.insert(recordedFrames, {
            time = 0,
            cframe = root.CFrame,
            velocity = root.AssemblyLinearVelocity,
            moveDirection = hum and hum.MoveDirection or Vector3.new(),
            isJumping = (hum and hum.FloorMaterial == Enum.Material.Air) or false
        })
    end
    notify("🔴 Recording started (60 FPS)", 1)
end

local function stopRecording()
    if not recording then notify("No active recording") return end
    recording = false
    if #recordedFrames < 2 then
        notify("Recording too short", 1)
        recordedFrames = {}
        return
    end
    local duration = recordedFrames[#recordedFrames].time
    notify(string.format("⏹️ Stopped (%d frames, %.2f sec)", #recordedFrames, duration), 2)
end

-- Trail (Line Neon)
local function clearTrail()
    for _, obj in ipairs(trailObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    trailObjects = {}
end

local function updateTrail()
    if not trailVisible then return end
    clearTrail()
    if #recordedFrames < 2 then return end
    for _, frame in ipairs(recordedFrames) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Shape = Enum.PartType.Ball
        part.BrickColor = BrickColor.new("Bright red")
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.CanCollide = false
        part.Position = frame.cframe.Position
        part.Parent = workspace
        table.insert(trailObjects, part)
        game:GetService("Debris"):AddItem(part, 60)
    end
    notify("Trail updated: " .. #recordedFrames .. " points", 1)
end

local function toggleTrail()
    trailVisible = not trailVisible
    if trailVisible then
        updateTrail()
        notify("Trail ON", 1)
    else
        clearTrail()
        notify("Trail OFF", 1)
    end
end

-- Natural Playback: cari titik terdekat lalu berjalan ke sana
local function findNearestPathPoint(pos)
    local nearestDist = math.huge
    local nearestIdx = 1
    for i, frame in ipairs(recordedFrames) do
        local dist = (pos - frame.cframe.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestIdx = i
        end
    end
    return nearestIdx, nearestDist
end

local function walkToPosition(targetPos, speed)
    if not humanoid or not hrp then return end
    local oldSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = speed or 16
    humanoid:MoveTo(targetPos)
    while (hrp.Position - targetPos).Magnitude > 2 and humanoid.MoveToFinished do
        task.wait(0.1)
    end
    humanoid:MoveTo(hrp.Position)
    humanoid.WalkSpeed = oldSpeed
end

local function stopPlayback()
    if playbackThread then
        coroutine.close(playbackThread)
        playbackThread = nil
    end
    playing = false
    reverse = false
    loopPlay = false
    local charNow = getCharacter()
    if charNow and charNow:FindFirstChild("Humanoid") then
        charNow.Humanoid.PlatformStand = false
    end
    workspace.Gravity = 196.2
    notify("Playback stopped", 1)
end

local function startPlayback(data, isReverse, isLoop, speed)
    if recording then notify("Stop recording first") return end
    if playing then stopPlayback() end
    if not data or #data < 2 then notify("No recording data") return end

    -- Natural approach: berjalan ke titik terdekat
    local startIdx, dist = findNearestPathPoint(hrp.Position)
    if dist > 5 then
        notify("Moving to nearest path point...", 2)
        walkToPosition(data[startIdx].cframe.Position, 16)
    end

    -- Potong data dari startIdx
    local truncated = {}
    if isReverse then
        for i = startIdx, 1, -1 do
            table.insert(truncated, data[i])
        end
    else
        for i = startIdx, #data do
            table.insert(truncated, data[i])
        end
    end

    playing = true
    reverse = isReverse
    loopPlay = isLoop
    playbackSpeed = speed or 1
    local playbackData = truncated
    local totalTime = playbackData[#playbackData].time
    local startGlobal = os.clock()
    local origGravity = workspace.Gravity
    workspace.Gravity = 0
    local charNow = getCharacter()
    if charNow and charNow:FindFirstChild("Humanoid") then
        charNow.Humanoid.PlatformStand = true
    end

    playbackThread = coroutine.create(function()
        while playing do
            local now = (os.clock() - startGlobal) * playbackSpeed
            local progress
            if reverse then
                progress = 1 - (now / totalTime)
                if progress <= 0 then
                    if loopPlay then
                        startGlobal = os.clock()
                        now = 0
                        progress = 1
                    else
                        break
                    end
                end
            else
                progress = now / totalTime
                if progress >= 1 then
                    if loopPlay then
                        startGlobal = os.clock()
                        now = 0
                        progress = 0
                    else
                        break
                    end
                end
            end

            local idx = 1
            if reverse then
                for i = #playbackData, 1, -1 do
                    if playbackData[i].time <= progress * totalTime then
                        idx = i
                        break
                    end
                end
                if idx >= #playbackData then idx = #playbackData - 1 end
                local t = (progress * totalTime - playbackData[idx].time) / (playbackData[idx+1].time - playbackData[idx].time)
                t = math.clamp(t, 0, 1)
                local newCF = playbackData[idx+1].cframe:Lerp(playbackData[idx].cframe, t)
                if hrp and hrp.Parent then hrp.CFrame = newCF end
                if humanoid then humanoid:MoveTo(newCF.Position + (playbackData[idx].moveDirection * 5)) end
            else
                for i = 1, #playbackData-1 do
                    if playbackData[i+1].time >= progress * totalTime then
                        idx = i
                        break
                    end
                end
                local t = (progress * totalTime - playbackData[idx].time) / (playbackData[idx+1].time - playbackData[idx].time)
                t = math.clamp(t, 0, 1)
                local newCF = playbackData[idx].cframe:Lerp(playbackData[idx+1].cframe, t)
                if hrp and hrp.Parent then hrp.CFrame = newCF end
                if humanoid then humanoid:MoveTo(newCF.Position + (playbackData[idx].moveDirection * 5)) end
            end

            local cur = playbackData[math.floor(idx)]
            if cur and cur.isJumping and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end
            task.wait(0.016)
        end
        workspace.Gravity = origGravity
        if charNow and charNow:FindFirstChild("Humanoid") then
            charNow.Humanoid.PlatformStand = false
        end
        playing = false
        playbackThread = nil
        notify("Playback finished", 1)
    end)
    coroutine.resume(playbackThread)
end

-- ========== TELEPORT & CHECKPOINT ==========
local function saveCurrentPosition(name)
    if not hrp then notify("Can't get position") return end
    table.insert(checkpoints, {name = name or "Point_" .. (#checkpoints+1), cframe = hrp.CFrame})
    notify("Saved: " .. (name or "unnamed"), 1)
end

local function teleportToPoint(idx)
    if not checkpoints[idx] then notify("Invalid checkpoint") return end
    hrp.CFrame = checkpoints[idx].cframe
    notify("Teleported to " .. checkpoints[idx].name, 1)
end

local function startAutoCheckpoint()
    if autoCheckpoint then return end
    autoCheckpoint = true
    local conn
    conn = runService.RenderStepped:Connect(function()
        if not autoCheckpoint then conn:Disconnect() return end
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():find("checkpoint") or part.Name:lower():find("stage")) then
                if hrp and (hrp.Position - part.Position).Magnitude < 5 then
                    if lastCheckpointPos ~= part.Position then
                        lastCheckpointPos = part.Position
                        saveCurrentPosition("Auto_" .. part.Name)
                    end
                end
            end
        end
    end)
    notify("Auto Checkpoint ON", 1)
end

local function stopAutoCheckpoint()
    autoCheckpoint = false
    notify("Auto Checkpoint OFF", 1)
end

local function startAutoTeleport()
    if #checkpoints == 0 then notify("No checkpoints") return end
    if autoTeleportRunning then return end
    autoTeleportRunning = true
    teleportIndex = 1
    task.spawn(function()
        while autoTeleportRunning and teleportIndex <= #checkpoints do
            teleportToPoint(teleportIndex)
            teleportIndex = teleportIndex + 1
            task.wait(1)
        end
        autoTeleportRunning = false
        notify("Auto teleport finished", 1)
    end)
end

local function stopAutoTeleport()
    autoTeleportRunning = false
    notify("Auto teleport stopped", 1)
end

local function listCheckpoints()
    if #checkpoints == 0 then notify("No checkpoints") return end
    local str = "Checkpoints:\n"
    for i, cp in ipairs(checkpoints) do
        str = str .. i .. ". " .. cp.name .. "\n"
    end
    notify(str, 5)
end

-- ========== MOVEMENT CHEATS ==========
local function setWalkspeed(s)
    humanoid.WalkSpeed = s
    notify("WalkSpeed: " .. s, 1)
end
local function setJumpPower(p)
    humanoid.JumpPower = p
    notify("JumpPower: " .. p, 1)
end
local function infiniteJump()
    if infiniteJumpConn then infiniteJumpConn:Disconnect() end
    infiniteJumpConn = userInput.JumpRequest:Connect(function()
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
    notify("Infinite Jump ON", 1)
end
local function stopInfiniteJump()
    if infiniteJumpConn then infiniteJumpConn:Disconnect(); infiniteJumpConn = nil end
    notify("Infinite Jump OFF", 1)
end
local function startFly()
    if flyEnabled then return end
    flyEnabled = true
    local bg = Instance.new("BodyGyro")
    local bv = Instance.new("BodyVelocity")
    bg.P = 9e4
    bg.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
    bg.CFrame = hrp.CFrame
    bv.MaxForce = Vector3.new(9e4, 9e4, 9e4)
    bv.Velocity = Vector3.new(0, 0, 0)
    bg.Parent = hrp
    bv.Parent = hrp
    flyBodyVelocity = bv
    userInput.InputBegan:Connect(function(input)
        if not flyEnabled then return end
        if input.KeyCode == Enum.KeyCode.Space then bv.Velocity = Vector3.new(0, flySpeed, 0) end
    end)
    runService.RenderStepped:Connect(function()
        if not flyEnabled or not hrp.Parent then
            bg:Destroy(); bv:Destroy(); return
        end
        local cam = workspace.CurrentCamera
        local dir = Vector3.new()
        if userInput:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if userInput:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if userInput:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if userInput:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        dir = dir * flySpeed
        bv.Velocity = Vector3.new(dir.X, bv.Velocity.Y, dir.Z)
        bg.CFrame = cam.CFrame
    end)
    notify("Fly ON (Speed " .. flySpeed .. ")", 1)
end
local function stopFly()
    flyEnabled = false
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    notify("Fly OFF", 1)
end
local function enableNoclip()
    if noclipEnabled then return end
    noclipEnabled = true
    noclipConnect = runService.Stepped:Connect(function()
        if not noclipEnabled then return end
        local c = getCharacter()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
    notify("NoClip ON", 1)
end
local function disableNoclip()
    noclipEnabled = false
    if noclipConnect then noclipConnect:Disconnect() end
    local c = getCharacter()
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
    notify("NoClip OFF", 1)
end
local function resetMovement()
    humanoid.WalkSpeed = originalWS
    humanoid.JumpPower = originalJP
    if flyEnabled then stopFly() end
    if noclipEnabled then disableNoclip() end
    if infiniteJumpConn then stopInfiniteJump() end
    notify("Movement reset", 1)
end

-- ========== UTILITIES ==========
local function startAntiAFK()
    if antiAFKEnabled then return end
    antiAFKEnabled = true
    local vu = game:GetService("VirtualUser")
    antiAfkConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    notify("Anti AFK ON", 1)
end
local function stopAntiAFK()
    antiAFKEnabled = false
    if antiAfkConnection then antiAfkConnection:Disconnect() end
    notify("Anti AFK OFF", 1)
end
local function serverHop()
    local servers = {}
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"))
    end)
    if success and data then
        for _, v in ipairs(data.data) do
            if v.playing < v.maxPlayers then table.insert(servers, v.id) end
        end
        if #servers > 0 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player)
        else
            notify("No other servers", 2)
        end
    else
        notify("Failed to fetch servers", 2)
    end
end
local function rejoin()
    game:GetService("TeleportService"):Teleport(game.PlaceId, player)
end
local function loadInfiniteYield()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
    notify("Infinite Yield loaded", 1)
end
local function shutdownScript()
    if recording then stopRecording() end
    if playing then stopPlayback() end
    if autoTeleportRunning then stopAutoTeleport() end
    if flyEnabled then stopFly() end
    if noclipEnabled then disableNoclip() end
    if antiAFKEnabled then stopAntiAFK() end
    if infiniteJumpConn then stopInfiniteJump() end
    resetMovement()
    clearTrail()
    Rayfield:Destroy()
    notify("Shutdown complete", 2)
end

-- ========== DISCORD EXPORT ==========
local function exportToDiscord(webhook)
    if not webhook or webhook == "" then notify("Webhook required") return end
    local data = {
        checkpoints = {},
        recording = {frames = #recordedFrames, duration = recordedFrames[#recordedFrames] and recordedFrames[#recordedFrames].time or 0},
        timestamp = os.time()
    }
    for i, cp in ipairs(checkpoints) do
        table.insert(data.checkpoints, {name = cp.name, pos = {cp.cframe.Position.X, cp.cframe.Position.Y, cp.cframe.Position.Z}})
    end
    local json = httpService:JSONEncode(data)
    local payload = {
        content = "**Renn HUB Data Export**",
        embeds = {{
            title = "Recorded Data",
            description = string.format("Checkpoints: %d\nFrames: %d\nDuration: %.2f sec", #checkpoints, #recordedFrames, data.recording.duration),
            color = 16711680,
            fields = {{name = "JSON", value = "```json\n" .. json:sub(1, 1000) .. "```"}}
        }}
    }
    local reqFunc = syn and syn.request or (http and http.request) or request
    if not reqFunc then notify("No HTTP request") return end
    local success = pcall(function()
        reqFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = httpService:JSONEncode(payload)})
    end)
    notify(success and "Data sent to Discord" or "Export failed", 2)
end

-- ========== RAYFIELD GUI ==========
local Window = Rayfield:CreateWindow({
    Name = "Renn HUB",
    Icon = "rbxassetid://1234567890",
    LoadingTitle = "Loading Renn HUB",
    LoadingSubtitle = "by Renn",
    Theme = "Default",
    DisableThemeEditor = false
})

-- Tab 1: Recorder
local recTab = Window:CreateTab("🎥 Recorder")
recTab:CreateSection("Recording")
recTab:CreateButton({Name = "Start Recording (60 FPS)", Callback = startRecording})
recTab:CreateButton({Name = "Stop Recording", Callback = stopRecording})
recTab:CreateButton({Name = "Toggle Trail (Line Neon)", Callback = toggleTrail})
recTab:CreateSection("Playback")
recTab:CreateButton({Name = "Play Normal (Natural Approach)", Callback = function() startPlayback(recordedFrames, false, false, 1) end})
recTab:CreateButton({Name = "Play Reverse (Natural)", Callback = function() startPlayback(recordedFrames, true, false, 1) end})
recTab:CreateButton({Name = "Loop On/Off", Callback = function() loopPlay = not loopPlay; notify("Loop: " .. tostring(loopPlay)) end})
recTab:CreateButton({Name = "Speed 0.5x", Callback = function() startPlayback(recordedFrames, false, loopPlay, 0.5) end})
recTab:CreateButton({Name = "Speed 2x", Callback = function() startPlayback(recordedFrames, false, loopPlay, 2) end})
recTab:CreateButton({Name = "Stop Playback", Callback = stopPlayback})

-- Tab 2: Teleport
local teleTab = Window:CreateTab("📍 Teleport")
teleTab:CreateSection("Checkpoint Management")
teleTab:CreateButton({Name = "Save Current Position", Callback = function() saveCurrentPosition("Manual") end})
teleTab:CreateButton({Name = "List Checkpoints", Callback = listCheckpoints})
teleTab:CreateButton({Name = "Teleport to #1", Callback = function() teleportToPoint(1) end})
teleTab:CreateButton({Name = "Teleport to Last", Callback = function() teleportToPoint(#checkpoints) end})
teleTab:CreateSection("Auto Features")
teleTab:CreateButton({Name = "Auto Checkpoint ON", Callback = startAutoCheckpoint})
teleTab:CreateButton({Name = "Auto Checkpoint OFF", Callback = stopAutoCheckpoint})
teleTab:CreateButton({Name = "Auto Teleport List", Callback = startAutoTeleport})
teleTab:CreateButton({Name = "Stop Auto Teleport", Callback = stopAutoTeleport})

-- Tab 3: TOOLS (Movement)
local toolsTab = Window:CreateTab("🛠️ TOOLS")
toolsTab:CreateSection("WalkSpeed")
toolsTab:CreateButton({Name = "WalkSpeed 50", Callback = function() setWalkspeed(50) end})
toolsTab:CreateButton({Name = "WalkSpeed 100", Callback = function() setWalkspeed(100) end})
toolsTab:CreateButton({Name = "WalkSpeed 250", Callback = function() setWalkspeed(250) end})
toolsTab:CreateSection("JumpPower")
toolsTab:CreateButton({Name = "JumpPower 80", Callback = function() setJumpPower(80) end})
toolsTab:CreateButton({Name = "JumpPower 200", Callback = function() setJumpPower(200) end})
toolsTab:CreateSection("Special")
toolsTab:CreateButton({Name = "Infinite Jump ON", Callback = infiniteJump})
toolsTab:CreateButton({Name = "Infinite Jump OFF", Callback = stopInfiniteJump})
toolsTab:CreateButton({Name = "Fly Mode ON", Callback = startFly})
toolsTab:CreateButton({Name = "Fly Mode OFF", Callback = stopFly})
toolsTab:CreateButton({Name = "NoClip ON", Callback = enableNoclip})
toolsTab:CreateButton({Name = "NoClip OFF", Callback = disableNoclip})
toolsTab:CreateButton({Name = "Reset Movement", Callback = resetMovement})

-- Tab 4: Utilities
local utilTab = Window:CreateTab("⚙️ Utilities")
utilTab:CreateSection("Anti AFK")
utilTab:CreateButton({Name = "Anti AFK ON", Callback = startAntiAFK})
utilTab:CreateButton({Name = "Anti AFK OFF", Callback = stopAntiAFK})
utilTab:CreateSection("Server")
utilTab:CreateButton({Name = "Server Hop", Callback = serverHop})
utilTab:CreateButton({Name = "Rejoin", Callback = rejoin})
utilTab:CreateSection("External")
utilTab:CreateButton({Name = "Load Infinite Yield", Callback = loadInfiniteYield})
utilTab:CreateButton({Name = "Shutdown Script", Callback = shutdownScript})

-- Tab 5: Cloud
local cloudTab = Window:CreateTab("☁️ Cloud")
cloudTab:CreateSection("Discord Export")
cloudTab:CreateButton({Name = "Export to Discord", Callback = function()
    local input = Rayfield:CreateInput({
        Title = "Discord Webhook",
        Subtitle = "Enter your webhook URL",
        Placeholder = "https://discord.com/api/webhooks/..."
    })
    input:WaitForInput()
    if input.Value and input.Value ~= "" then exportToDiscord(input.Value) end
end})

-- ========== DRAG & RESIZE MOBILE-FRIENDLY ==========
-- Membuat fungsi untuk menangani sentuhan dengan area yang lebih besar
task.spawn(function()
    task.wait(1) -- Tunggu GUI termuat
    local rayfieldGui
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g.Name:find("Rayfield") or g.Name:find("Renn HUB") then
            rayfieldGui = g
            break
        end
    end
    if not rayfieldGui then return end
    
    local mainFrame
    for _, child in ipairs(rayfieldGui:GetDescendants()) do
        if child:IsA("Frame") and child.Name == "Main" then
            mainFrame = child
            break
        end
    end
    if not mainFrame then
        for _, child in ipairs(rayfieldGui:GetDescendants()) do
            if child:IsA("Frame") and child.Parent == rayfieldGui and child.AbsoluteSize.X > 200 then
                mainFrame = child
                break
            end
        end
    end
    if not mainFrame then return end
    
    -- Bersihkan handle lama jika ada
    for _, v in ipairs(mainFrame:GetChildren()) do
        if v.Name == "CustomDragHandle" or v.Name == "CustomResizeHandle" then v:Destroy() end
    end
    
    -- Drag handle (area atas yang lebih besar untuk sentuhan jari)
    local dragHandle = Instance.new("Frame")
    dragHandle.Name = "CustomDragHandle"
    dragHandle.Size = UDim2.new(1, 0, 0, 45)
    dragHandle.BackgroundTransparency = 1
    dragHandle.Parent = mainFrame
    
    -- Resize handle (pojok kanan bawah ukuran 45x45 agar mudah disentuh)
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Name = "CustomResizeHandle"
    resizeHandle.Size = UDim2.new(0, 45, 0, 45)
    resizeHandle.Position = UDim2.new(1, -45, 1, -45)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    resizeHandle.BackgroundTransparency = 0.4
    resizeHandle.BorderSizePixel = 0
    resizeHandle.Parent = mainFrame
    
    -- Ikon resize
    local triangle = Instance.new("ImageLabel")
    triangle.Size = UDim2.new(1, 1, 1, 1)
    triangle.Image = "rbxasset://textures/ui/ResizeImage.png"
    triangle.BackgroundTransparency = 1
    triangle.Parent = resizeHandle
    
    -- Fungsi drag
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- Fungsi resize
    local resizing = false
    local resizeStart = Vector2.new()
    local startSize = UDim2.new()
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = mainFrame.Size
        end
    end)
    resizeHandle.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            local newW = math.clamp(startSize.X.Offset + delta.X, 320, 900)
            local newH = math.clamp(startSize.Y.Offset + delta.Y, 450, 800)
            mainFrame.Size = UDim2.new(0, newW, 0, newH)
        end
    end)
    resizeHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
    
    notify("✓ Geser: sentuh area atas lalu gerakkan", 2)
    notify("✓ Ubah ukuran: sentuh pojok kanan bawah lalu tarik", 2)
end)

notify("✅ Renn HUB siap! Rekam gerakan 60 FPS, playback natural", 3)