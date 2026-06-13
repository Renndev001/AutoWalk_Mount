--[[
    ⚡ TAS+ Utility - Rayfield Edition ⚡
    Semua fitur dalam satu script dengan GUI elegan.
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

-- ========== FUNGSI NOTIFIKASI ==========
local function notify(msg, duration)
    duration = duration or 2
    Rayfield:Notify({
        Title = "TAS+ Utility",
        Content = msg,
        Duration = duration
    })
    print("[TAS+] " .. msg)
end

local function getCharacter()
    return player.Character
end

-- ========== TAS ENGINE ==========
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
    notify("🔴 Recording started", 1)
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
                local cf1 = playbackData[idx+1].cframe
                local cf2 = playbackData[idx].cframe
                local newCF = cf1:Lerp(cf2, t)
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

            local currentFrame = playbackData[math.floor(idx)]
            if currentFrame and currentFrame.isJumping and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end

            task.wait(0.016)
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
        content = "**TAS+ Data Export**",
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

-- ========== RAYFIELD GUI ==========
local Window = Rayfield:CreateWindow({
    Name = "TAS+ Utility",
    Icon = "rbxassetid://1234567890", -- optional, ganti jika punya icon
    LoadingTitle = "Loading TAS+",
    LoadingSubtitle = "by AI",
    Theme = "Default",
    DisableThemeEditor = false
})

-- Tab 1: TAS Engine
local tasTab = Window:CreateTab("🎥 TAS Engine")
tasTab:CreateSection("Recording")
tasTab:CreateButton({Name = "Start Recording", Callback = startRecording})
tasTab:CreateButton({Name = "Stop Recording", Callback = stopRecording})
tasTab:CreateButton({Name = "Toggle Trail (Show/Hide)", Callback = toggleTrail})

tasTab:CreateSection("Playback Controls")
tasTab:CreateButton({Name = "Play Normal", Callback = function() startPlayback(recordedFrames, false, false, 1) end})
tasTab:CreateButton({Name = "Play Reverse", Callback = function() startPlayback(recordedFrames, true, false, 1) end})
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

-- Tab 3: Movement Cheats
local moveTab = Window:CreateTab("⚡ Movement")
moveTab:CreateSection("WalkSpeed")
moveTab:CreateButton({Name = "WalkSpeed 50", Callback = function() setWalkspeed(50) end})
moveTab:CreateButton({Name = "WalkSpeed 100", Callback = function() setWalkspeed(100) end})
moveTab:CreateButton({Name = "WalkSpeed 250", Callback = function() setWalkspeed(250) end})

moveTab:CreateSection("JumpPower")
moveTab:CreateButton({Name = "JumpPower 80", Callback = function() setJumpPower(80) end})
moveTab:CreateButton({Name = "JumpPower 200", Callback = function() setJumpPower(200) end})

moveTab:CreateSection("Special Moves")
moveTab:CreateButton({Name = "Infinite Jump ON", Callback = infiniteJump})
moveTab:CreateButton({Name = "Infinite Jump OFF", Callback = stopInfiniteJump})
moveTab:CreateButton({Name = "Fly Mode ON", Callback = function() startFly(50) end})
moveTab:CreateButton({Name = "Fly Mode OFF", Callback = stopFly})
moveTab:CreateButton({Name = "NoClip ON", Callback = enableNoclip})
moveTab:CreateButton({Name = "NoClip OFF", Callback = disableNoclip})
moveTab:CreateButton({Name = "Reset Movement", Callback = resetMovement})

-- Tab 4: Utilities
local utilTab = Window:CreateTab("🛠️ Utilities")
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

-- Notifikasi siap
notify("✅ TAS+ Utility with Rayfield loaded!", 3)
