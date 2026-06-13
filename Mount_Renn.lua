--[[
    ⚡ Renn HUB - Advanced TAS+ with Natural Playback ⚡
    - 60 FPS recording
    - Natural walking to nearest path point before replay
    - Animations (walk/run/jump) preserved
--]]

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== VARIABLES GLOBAL ==========
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local runService = game:GetService("RunService")
local userInput = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")
local tweenService = game:GetService("TweenService")

-- TAS Engine
local recording = false
local recordedFrames = {}      -- {time, cframe, velocity, moveDirection, isJumping}
local startTime = 0
local playing = false
local reverse = false
local loopPlay = false
local playbackSpeed = 1
local playbackThread = nil
local trailObjects = {}
local trailVisible = true
local naturalApproach = true   -- fitur natural approach ke jalur

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

-- ========== FUNGSI NOTIFIKASI ==========
local function notify(msg, duration)
    duration = duration or 2
    Rayfield:Notify({
        Title = "Renn HUB",
        Content = msg,
        Duration = duration
    })
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

-- Trail (line neon)
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

-- ========== NATURAL PLAYBACK (BERJALAN KE TITIK TERDEKAT) ==========
local function findNearestPathPoint(characterPos)
    local nearestDist = math.huge
    local nearestIndex = 1
    for i, frame in ipairs(recordedFrames) do
        local dist = (characterPos - frame.cframe.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestIndex = i
        end
    end
    return nearestIndex, nearestDist
end

local function walkToPosition(targetPos, speed)
    if not humanoid or not hrp then return end
    local originalWS = humanoid.WalkSpeed
    humanoid.WalkSpeed = speed or 16
    humanoid:MoveTo(targetPos)
    -- Tunggu sampai jarak kurang dari 2 studs
    while (hrp.Position - targetPos).Magnitude > 2 and humanoid.MoveToFinished do
        task.wait(0.1)
    end
    humanoid:MoveTo(hrp.Position) -- stop
    humanoid.WalkSpeed = originalWS
end

local function startNaturalPlayback(data, isReverse, isLoop, speed)
    if recording then notify("Stop recording first") return end
    if playing then stopPlayback() end
    if not data or #data < 2 then notify("No recording data") return end

    -- Cari titik terdekat dengan posisi karakter saat ini
    local startIndex, distance = findNearestPathPoint(hrp.Position)
    if distance > 5 then
        notify("Approaching nearest path point...", 2)
        walkToPosition(data[startIndex].cframe.Position, 16)
    end

    -- Sekarang mulai replay dari index terdekat
    -- Potong data agar mulai dari startIndex
    local truncatedData = {}
    if isReverse then
        for i = startIndex, 1, -1 do
            table.insert(truncatedData, data[i])
        end
    else
        for i = startIndex, #data do
            table.insert(truncatedData, data[i])
        end
    end

    -- Panggil fungsi playback internal dengan data yang sudah dipotong
    startPlaybackFromIndex(truncatedData, isReverse, isLoop, speed, startIndex)
end

-- Playback utama (dengan interpolasi)
local function startPlaybackFromIndex(data, isReverse, isLoop, speed, originalStartIndex)
    playing = true
    reverse = isReverse
    loopPlay = isLoop
    playbackSpeed = speed or 1
    local playbackData = data
    local totalTime = playbackData[#playbackData].time
    local startTimeGlobal = os.clock()
    local originalGravity = workspace.Gravity
    workspace.Gravity = 0
    local charNow = getCharacter()
    if charNow and charNow:FindFirstChild("Humanoid") then
        charNow.Humanoid.PlatformStand = true
    end

    playbackThread = coroutine.create(function()
        while playing do
            local now = (os.clock() - startTimeGlobal) * playbackSpeed
            local progress
            if reverse then
                progress = 1 - (now / totalTime)
                if progress <= 0 then
                    if loopPlay then
                        startTimeGlobal = os.clock()
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
                        startTimeGlobal = os.clock()
                        now = 0
                        progress = 0
                    else
                        break
                    end
                end
            end

            -- Interpolasi frame
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
                -- Terapkan MoveDirection untuk animasi
                if humanoid then
                    humanoid:MoveTo(newCF.Position + (playbackData[idx].moveDirection * 5))
                end
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
                if humanoid then
                    humanoid:MoveTo(newCF.Position + (playbackData[idx].moveDirection * 5))
                end
            end

            -- Simulasi lompat
            local currentFrame = playbackData[math.floor(idx)]
            if currentFrame and currentFrame.isJumping and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end

            task.wait(0.016) -- 60 FPS
        end
        workspace.Gravity = originalGravity
        if charNow and charNow:FindFirstChild("Humanoid") then
            charNow.Humanoid.PlatformStand = false
        end
        playing = false
        playbackThread = nil
        notify("Playback finished", 1)
    end)
    coroutine.resume(playbackThread)
end

-- Stop playback
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

-- Wrapper untuk playback dengan natural approach
local function startPlayback(data, isReverse, isLoop, speed)
    startNaturalPlayback(data, isReverse, isLoop, speed)
end

-- ========== TELEPORT & CHECKPOINT ==========
local function saveCurrentPosition(name)
    local charNow = getCharacter()
    if not charNow or not hrp then notify("Can't get position") return end
    local pos = hrp.CFrame
    table.insert(checkpoints, {name = name or "Point_" .. (#checkpoints+1), cframe = pos})
    notify("Saved: " .. (name or "unnamed"), 1)
end

local function teleportToPoint(index)
    if not checkpoints[index] then notify("Invalid checkpoint") return end
    local target = checkpoints[index].cframe
    if hrp and hrp.Parent then
        hrp.CFrame = target
        notify("Teleported to " .. checkpoints[index].name, 1)
    end
end

local function startAutoCheckpoint()
    autoCheckpoint = true
    notify("Auto Checkpoint ON", 1)
    local connection
    connection = runService.RenderStepped:Connect(function()
        if not autoCheckpoint then connection:Disconnect() return end
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
end

local function stopAutoCheckpoint()
    autoCheckpoint = false
    notify("Auto Checkpoint OFF", 1)
end

local function startAutoTeleport()
    if #checkpoints == 0 then notify("No checkpoints saved") return end
    if autoTeleportRunning then notify("Already running") return end
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
    if #checkpoints == 0 then
        notify("No checkpoints saved", 2)
        return
    end
    local str = "Checkpoints:\n"
    for i, cp in ipairs(checkpoints) do
        str = str .. i .. ". " .. cp.name .. "\n"
    end
    notify(str, 5)
end

-- ========== MOVEMENT CHEATS ==========
local function setWalkspeed(speed)
    humanoid.WalkSpeed = speed
    notify("WalkSpeed: " .. speed, 1)
end

local function setJumpPower(power)
    humanoid.JumpPower = power
    notify("JumpPower: " .. power, 1)
end

local function infiniteJump()
    if infiniteJumpConn then infiniteJumpConn:Disconnect() end
    infiniteJumpConn = userInput.JumpRequest:Connect(function()
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    notify("Infinite Jump ON", 1)
end

local function stopInfiniteJump()
    if infiniteJumpConn then infiniteJumpConn:Disconnect(); infiniteJumpConn = nil end
    notify("Infinite Jump OFF", 1)
end

local function startFly(speed)
    flyEnabled = true
    flySpeed = speed or 50
    local bodyGyro = Instance.new("BodyGyro")
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
    bodyGyro.CFrame = hrp.CFrame
    bodyVelocity.MaxForce = Vector3.new(9e4, 9e4, 9e4)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyGyro.Parent = hrp
    bodyVelocity.Parent = hrp
    flyBodyVelocity = bodyVelocity
    userInput.InputBegan:Connect(function(input)
        if not flyEnabled then return end
        if input.KeyCode == Enum.KeyCode.Space then
            bodyVelocity.Velocity = Vector3.new(0, flySpeed, 0)
        end
    end)
    runService.RenderStepped:Connect(function()
        if not flyEnabled or not hrp.Parent then
            bodyGyro:Destroy()
            bodyVelocity:Destroy()
            return
        end
        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new()
        if userInput:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + camera.CFrame.LookVector end
        if userInput:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - camera.CFrame.LookVector end
        if userInput:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - camera.CFrame.RightVector end
        if userInput:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + camera.CFrame.RightVector end
        moveDirection = moveDirection * flySpeed
        bodyVelocity.Velocity = Vector3.new(moveDirection.X, bodyVelocity.Velocity.Y, moveDirection.Z)
        bodyGyro.CFrame = camera.CFrame
    end)
    notify("Fly mode ON (Speed: " .. flySpeed .. ")", 1)
end

local function stopFly()
    flyEnabled = false
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    notify("Fly mode OFF", 1)
end

local function enableNoclip()
    if noclipEnabled then return end
    noclipEnabled = true
    noclipConnect = runService.Stepped:Connect(function()
        if not noclipEnabled then return end
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
    notify("NoClip ON", 1)
end

local function disableNoclip()
    noclipEnabled = false
    if noclipConnect then noclipConnect:Disconnect() end
    local char = getCharacter()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
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
            if v.playing < v.maxPlayers then
                table.insert(servers, v.id)
            end
        end
        if #servers > 0 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player)
        else
            notify("No other servers found", 2)
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
    notify("Script shutdown complete", 2)
end

-- ========== DISCORD EXPORT ==========
local function exportToDiscord(webhook)
    if not webhook or webhook == "" then
        notify("Please set Webhook URL", 2)
        return
    end
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
            description = string.format("Checkpoints: %d\nRecording frames: %d\nDuration: %.2f sec", #checkpoints, #recordedFrames, data.recording.duration),
            color = 16711680,
            fields = {{name = "JSON Data", value = "```json\n" .. json:sub(1, 1000) .. "```"}}
        }}
    }
    local reqFunc = syn and syn.request or (http and http.request) or request
    if not reqFunc then notify("No HTTP request function") return end
    local success, err = pcall(function()
        reqFunc({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = httpService:JSONEncode(payload)
        })
    end)
    if success then
        notify("Data sent to Discord", 2)
    else
        notify("Failed: " .. tostring(err), 3)
    end
end

-- ========== RAYFIELD GUI with Custom Names ==========
local Window = Rayfield:CreateWindow({
    Name = "Renn HUB",  -- Judul diubah
    Icon = "rbxassetid://1234567890",
    LoadingTitle = "Loading Renn HUB",
    LoadingSubtitle = "by Renn",
    Theme = "Default",
    DisableThemeEditor = false
})

-- Tab 1: TAS Engine (Recorder)
local tasTab = Window:CreateTab("🎥 Recorder")  -- Nama tab diubah
tasTab:CreateSection("Recording")
tasTab:CreateButton({Name = "Start Recording (60 FPS)", Callback = startRecording})
tasTab:CreateButton({Name = "Stop Recording", Callback = stopRecording})
tasTab:CreateButton({Name = "Toggle Trail (Line Neon)", Callback = toggleTrail})

tasTab:CreateSection("Playback Controls")
tasTab:CreateButton({Name = "Play Normal (Natural Approach)", Callback = function() startPlayback(recordedFrames, false, false, 1) end})
tasTab:CreateButton({Name = "Play Reverse (Natural)", Callback = function() startPlayback(recordedFrames, true, false, 1) end})
tasTab:CreateButton({Name = "Loop On/Off", Callback = function() loopPlay = not loopPlay; notify("Loop: " .. tostring(loopPlay)) end})
tasTab:CreateButton({Name = "Speed 0.5x", Callback = function() startPlayback(recordedFrames, false, loopPlay, 0.5) end})
tasTab:CreateButton({Name = "Speed 2x", Callback = function() startPlayback(recordedFrames, false, loopPlay, 2) end})
tasTab:CreateButton({Name = "Stop Playback", Callback = stopPlayback})

-- Tab 2: Teleport & Checkpoint
local teleTab = Window:CreateTab("📍 Teleport")
teleTab:CreateSection("Checkpoint Management")
teleTab:CreateButton({Name = "Save Current Position", Callback = function() saveCurrentPosition("Manual") end})
teleTab:CreateButton({Name = "List Checkpoints", Callback = listCheckpoints})
teleTab:CreateButton({Name = "Teleport to #1", Callback = function() teleportToPoint(1) end})
teleTab:CreateButton({Name = "Teleport to Last", Callback = function() teleportToPoint(#checkpoints) end})

teleTab:CreateSection("Auto Features")
teleTab:CreateButton({Name = "Auto Checkpoint ON", Callback = startAutoCheckpoint})
teleTab:CreateButton({Name = "Auto Checkpoint OFF", Callback = stopAutoCheckpoint})
teleTab:CreateButton({Name = "Auto Teleport List (Loop)", Callback = startAutoTeleport})
teleTab:CreateButton({Name = "Stop Auto Teleport", Callback = stopAutoTeleport})

-- Tab 3: TOOLS (ganti dari Movement)
local toolsTab = Window:CreateTab("🛠️ TOOLS")  -- Label Automation diganti TOOLS
toolsTab:CreateSection("WalkSpeed")
toolsTab:CreateButton({Name = "WalkSpeed 50", Callback = function() setWalkspeed(50) end})
toolsTab:CreateButton({Name = "WalkSpeed 100", Callback = function() setWalkspeed(100) end})
toolsTab:CreateButton({Name = "WalkSpeed 250", Callback = function() setWalkspeed(250) end})

toolsTab:CreateSection("JumpPower")
toolsTab:CreateButton({Name = "JumpPower 80", Callback = function() setJumpPower(80) end})
toolsTab:CreateButton({Name = "JumpPower 200", Callback = function() setJumpPower(200) end})

toolsTab:CreateSection("Special Moves")
toolsTab:CreateButton({Name = "Infinite Jump ON", Callback = infiniteJump})
toolsTab:CreateButton({Name = "Infinite Jump OFF", Callback = stopInfiniteJump})
toolsTab:CreateButton({Name = "Fly Mode ON", Callback = function() startFly(50) end})
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

-- Tab 5: Cloud Data
local cloudTab = Window:CreateTab("☁️ Cloud")
cloudTab:CreateSection("Discord Export")
cloudTab:CreateButton({Name = "Export to Discord", Callback = function()
    local input = Rayfield:CreateInput({
        Title = "Discord Webhook",
        Subtitle = "Enter your webhook URL",
        Placeholder = "https://discord.com/api/webhooks/..."
    })
    input:WaitForInput()
    if input.Value and input.Value ~= "" then
        exportToDiscord(input.Value)
    end
end})

-- ========== TAMBAHAN: DRAG & RESIZE UNTUK GUI RAYFIELD ==========
-- Fungsi untuk membuat GUI bisa digeser dan diubah ukuran
local function makeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    local dragInput = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function makeResizable(guiObject, resizeHandle, minSize, maxSize)
    local resizing = false
    local startMouse = Vector2.new()
    local startSize = UDim2.new()

    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            startMouse = input.Position
            startSize = guiObject.Size
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    resizing = false
                end
            end)
        end
    end)

    resizeHandle.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startMouse
            local newWidth = math.clamp(startSize.X.Offset + delta.X, minSize.X.Offset, maxSize.X.Offset)
            local newHeight = math.clamp(startSize.Y.Offset + delta.Y, minSize.Y.Offset, maxSize.Y.Offset)
            guiObject.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)
end

-- Cari frame utama milik Rayfield
local function addDragAndResize()
    task.wait(0.5)
    local rayfieldGui = nil
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        if gui.Name:find("Rayfield") or gui.Name:find("Renn HUB") then
            rayfieldGui = gui
            break
        end
    end
    if not rayfieldGui then
        warn("Tidak menemukan GUI Rayfield, coba lagi nanti")
        return
    end
    
    local mainFrame = nil
    for _, child in ipairs(rayfieldGui:GetDescendants()) do
        if child:IsA("Frame") and child.Name == "Main" then
            mainFrame = child
            break
        end
    end
    if not mainFrame then
        for _, child in ipairs(rayfieldGui:GetDescendants()) do
            if child:IsA("Frame") and child.AbsoluteSize.X > 200 and child.AbsoluteSize.Y > 200 then
                mainFrame = child
                break
            end
        end
    end
    if not mainFrame then
        warn("Tidak menemukan frame utama untuk drag/resize")
        return
    end
    
    local dragHandle = Instance.new("Frame")
    dragHandle.Size = UDim2.new(1, 0, 0, 25)
    dragHandle.BackgroundTransparency = 1
    dragHandle.Parent = mainFrame
    
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Size = UDim2.new(0, 15, 0, 15)
    resizeHandle.Position = UDim2.new(1, -15, 1, -15)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    resizeHandle.BackgroundTransparency = 0.5
    resizeHandle.BorderSizePixel = 0
    resizeHandle.Parent = mainFrame
    
    local triangle = Instance.new("ImageLabel")
    triangle.Size = UDim2.new(1, 0, 1, 0)
    triangle.Image = "rbxasset://textures/ui/ResizeImage.png"
    triangle.BackgroundTransparency = 1
    triangle.Parent = resizeHandle
    
    makeDraggable(mainFrame, dragHandle)
    makeResizable(mainFrame, resizeHandle, UDim2.new(0, 300, 0, 400), UDim2.new(0, 800, 0, 700))
    
    notify("GUI bisa digeser (drag title bar) dan diubah ukuran (pojok kanan bawah)", 3)
end

task.spawn(addDragAndResize)

-- Notifikasi siap
notify("✅ Renn HUB loaded! 60 FPS recording + Natural Playback aktif", 3)