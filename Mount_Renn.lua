--[[
    Renn HUB Universal - Motion Recorder Pro
    Refactored with Rayfield UI Library
    All original features preserved: Recording, Playback (with Path Recovery), Trail, Save/Load, Player Features
    Enhanced stability for Fly, Noclip, and respawn persistence.
]]

-- ========== LOAD RAYFIELD ==========
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== SERVICES ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

-- ========== LOCAL PLAYER & CHARACTER ==========
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ========== RECORDING GLOBALS ==========
local recordingActive = false
local recordingPaused = false
local recordedFrames = {}
local recordStartTime = 0
local recordPauseOffset = 0

-- ========== PLAYBACK GLOBALS ==========
local playbackActive = false
local playbackReverse = false
local playbackThread = nil
local playbackSpeed = 1.0
local playbackLoop = false
local playbackData = nil
local playbackStartTime = 0
local playbackTotalDuration = 0

-- ========== PATH RECOVERY GLOBALS ==========
local pathRecoveryActive = false
local pathRecoveryThread = nil
local pathRecoveryPendingUserInput = false
local pausedPlaybackState = false
local pausedPlaybackReverse = false
local pausedPlaybackSpeed = 1.0
local pausedPlaybackLoop = false

-- ========== TRAIL GLOBALS ==========
local trailParts = {}
local trailEnabled = true
local trailColor = Color3.fromRGB(255, 50, 50)
local lastTrailPosition = nil

-- ========== SAVE SYSTEM GLOBALS ==========
local SAVE_FOLDER_NAME = "RennMotionSaves"

-- ========== PLAYER FEATURES GLOBALS ==========
local flyEnabled = false
local flySpeed = 16
local flyBodyVelocity = nil
local flyConnection = nil

local noclipEnabled = false
local originalCollisionStates = {}

local jumpPowerDefault = humanoid.JumpPower
local jumpHighEnabled = false
local jumpHighPower = 50

local godModeEnabled = false

-- ========== UTILITY FUNCTIONS ==========
local function showNotification(message, notificationType)
    local title = (notificationType == "error" and "Error") or (notificationType == "success" and "Success") or "Info"
    Rayfield:Notify({
        Title = title,
        Content = message,
        Duration = 2.5
    })
    print("[RennHUB] " .. message)
end

local function cleanupTrail()
    for _, part in pairs(trailParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    trailParts = {}
    lastTrailPosition = nil
end

-- ========== TRAIL CORE ==========
local function addTrailSegment(position)
    if not trailEnabled then return end
    if lastTrailPosition then
        local distance = (position - lastTrailPosition).Magnitude
        if distance < 0.1 then return end
        local midpoint = (lastTrailPosition + position) / 2
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.2, 0.2, distance)
        part.CFrame = CFrame.new(midpoint, position) * CFrame.new(0, 0, -distance / 2)
        part.Anchored = true
        part.CanCollide = false
        part.BrickColor = BrickColor.new(trailColor)
        part.Material = Enum.Material.Neon
        part.Parent = workspace
        game:GetService("Debris"):AddItem(part, 3600)
        table.insert(trailParts, part)
    end
    lastTrailPosition = position
end

local function updateTrail()
    if trailEnabled and humanoidRootPart and humanoidRootPart.Parent then
        addTrailSegment(humanoidRootPart.Position)
    end
end

-- ========== RECORDING CORE ==========
local function startRecording()
    if recordingActive then
        showNotification("Recording is already active", "error")
        return
    end
    if playbackActive then
        showNotification("Please stop playback before recording", "error")
        return
    end
    recordedFrames = {}
    recordStartTime = os.clock()
    recordPauseOffset = 0
    recordingActive = true
    recordingPaused = false
    if humanoidRootPart and humanoidRootPart.Parent then
        table.insert(recordedFrames, {
            time = 0,
            cframe = humanoidRootPart.CFrame,
            position = humanoidRootPart.Position,
            velocity = humanoidRootPart.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
    showNotification("Recording started", "info")
end

local function pauseRecording()
    if not recordingActive or recordingPaused then return end
    recordingPaused = true
    recordPauseOffset = os.clock() - recordStartTime
    showNotification("Recording paused", "info")
end

local function resumeRecording()
    if not recordingActive or not recordingPaused then return end
    recordingPaused = false
    recordStartTime = os.clock() - recordPauseOffset
    showNotification("Recording resumed", "info")
end

local function stopRecording()
    if not recordingActive then
        showNotification("No active recording", "error")
        return
    end
    recordingActive = false
    recordingPaused = false
    showNotification("Recording stopped", "info")
end

-- ========== PATH RECOVERY ==========
local function findNearestFrame(targetPosition, frameData)
    local nearestIndex = 1
    local nearestDistance = (frameData[1].position - targetPosition).Magnitude
    for i = 2, #frameData do
        local distance = (frameData[i].position - targetPosition).Magnitude
        if distance < nearestDistance then
            nearestDistance = distance
            nearestIndex = i
        end
    end
    return nearestIndex, frameData[nearestIndex].time, nearestDistance
end

local function cancelPathRecovery()
    if pathRecoveryThread then
        task.cancel(pathRecoveryThread)
        pathRecoveryThread = nil
    end
    pathRecoveryActive = false
    pathRecoveryPendingUserInput = false
    humanoid.PlatformStand = false
    humanoid.AutoRotate = true
    if humanoidRootPart:FindFirstChild("BodyVelocity") then
        humanoidRootPart:FindFirstChild("BodyVelocity"):Destroy()
    end
end

local function initiatePathRecovery(forceTeleport)
    if pathRecoveryActive or not playbackData or not playbackActive then return end

    local currentPosition = humanoidRootPart.Position
    local nearestIndex, targetTime, distanceToPath = findNearestFrame(currentPosition, playbackData)
    local targetPosition = playbackData[nearestIndex].position

    if forceTeleport then
        humanoidRootPart.CFrame = playbackData[nearestIndex].cframe
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        playbackStartTime = os.clock() - (targetTime / playbackSpeed)
        showNotification("Teleported back to path", "info")
        cancelPathRecovery()
        return
    end

    if distanceToPath > 150 and not pathRecoveryPendingUserInput then
        pathRecoveryPendingUserInput = true
        pausedPlaybackState = playbackActive
        pausedPlaybackReverse = playbackReverse
        pausedPlaybackSpeed = playbackSpeed
        pausedPlaybackLoop = playbackLoop
        if playbackActive then
            playbackActive = false
            if playbackThread then
                task.cancel(playbackThread)
            end
        end

        Rayfield:Notify({
            Title = "Distance Warning",
            Content = string.format("Distance to path: %.1f studs. Select an action:", distanceToPath),
            Duration = 10,
            Actions = {
                Recover = {
                    Name = "Recover",
                    Callback = function()
                        pathRecoveryPendingUserInput = false
                        if pausedPlaybackState then
                            initiatePathRecovery(false)
                        else
                            cancelPathRecovery()
                        end
                    end
                },
                Cancel = {
                    Name = "Cancel",
                    Callback = function()
                        pathRecoveryPendingUserInput = false
                        stopPlayback()
                        cancelPathRecovery()
                    end
                },
                Teleport = {
                    Name = "Teleport",
                    Callback = function()
                        pathRecoveryPendingUserInput = false
                        if pausedPlaybackState then
                            initiatePathRecovery(true)
                        else
                            cancelPathRecovery()
                        end
                    end
                }
            }
        })
        return
    end

    pathRecoveryActive = true
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45
    })

    local success, errorMessage = pcall(function()
        path:ComputeAsync(currentPosition, targetPosition)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        showNotification("Pathfinding failed, teleporting to nearest point", "error")
        pathRecoveryActive = false
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        initiatePathRecovery(true)
        return
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        showNotification("No valid waypoints found", "error")
        pathRecoveryActive = false
        humanoid.PlatformStand = false
        return
    end

    showNotification("Recovering path...", "info")

    pathRecoveryThread = task.spawn(function()
        for _, waypoint in ipairs(waypoints) do
            if not pathRecoveryActive then break end
            local targetWaypoint = waypoint.Position
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            bodyVelocity.Velocity = (targetWaypoint - humanoidRootPart.Position).Unit * 16
            bodyVelocity.Parent = humanoidRootPart

            repeat
                RunService.RenderStepped:Wait()
                if not pathRecoveryActive then break end
                local direction = (targetWaypoint - humanoidRootPart.Position).Unit
                bodyVelocity.Velocity = direction * 16
                humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, targetWaypoint)
            until (humanoidRootPart.Position - targetWaypoint).Magnitude < 3 or not pathRecoveryActive

            bodyVelocity:Destroy()
        end

        if pathRecoveryActive then
            humanoidRootPart.CFrame = playbackData[nearestIndex].cframe
            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
            playbackStartTime = os.clock() - (targetTime / playbackSpeed)
            showNotification("Returned to path, resuming playback", "success")
            cancelPathRecovery()
            if playbackData then
                startPlayback(playbackData, pausedPlaybackReverse, pausedPlaybackSpeed, pausedPlaybackLoop)
            end
        end
    end)
end

-- ========== PLAYBACK CORE ==========
local function stopPlayback()
    if playbackActive then
        if playbackThread then
            task.cancel(playbackThread)
        end
        playbackActive = false
        if pathRecoveryActive then
            cancelPathRecovery()
        end
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        playbackData = nil
        showNotification("Playback stopped", "info")
    end
end

local function startPlayback(frameData, isReverse, speed, loop)
    if recordingActive then
        showNotification("Please stop recording before playback", "error")
        return
    end
    if playbackActive then
        stopPlayback()
    end
    if not frameData or #frameData < 2 then
        showNotification("No valid recorded data", "error")
        return
    end

    playbackActive = true
    playbackReverse = isReverse
    playbackData = frameData
    playbackSpeed = speed
    playbackLoop = loop
    local totalDuration = frameData[#frameData].time
    playbackTotalDuration = totalDuration
    playbackStartTime = os.clock()
    local lastJumpState = false
    humanoid.PlatformStand = true
    humanoid.AutoRotate = true

    playbackThread = task.spawn(function()
        while playbackActive and not pathRecoveryActive do
            local elapsed = (os.clock() - playbackStartTime) * playbackSpeed
            local progress
            if playbackReverse then
                progress = 1 - (elapsed / totalDuration)
                if progress < 0 then
                    if playbackLoop then
                        playbackStartTime = os.clock()
                        elapsed = 0
                        progress = 1
                    else
                        break
                    end
                end
            else
                progress = elapsed / totalDuration
                if progress > 1 then
                    if playbackLoop then
                        playbackStartTime = os.clock()
                        elapsed = 0
                        progress = 0
                    else
                        break
                    end
                end
            end
            progress = math.clamp(progress, 0, 1)
            local targetTime = progress * totalDuration

            local frameIndex1, frameIndex2
            for i = 1, #frameData - 1 do
                if frameData[i].time <= targetTime and frameData[i + 1].time >= targetTime then
                    frameIndex1 = i
                    frameIndex2 = i + 1
                    break
                end
            end
            if not frameIndex1 then
                if targetTime <= frameData[1].time then
                    frameIndex1, frameIndex2 = 1, 2
                else
                    frameIndex1, frameIndex2 = #frameData - 1, #frameData
                end
            end

            local frame1 = frameData[frameIndex1]
            local frame2 = frameData[frameIndex2]
            local alpha = (targetTime - frame1.time) / (frame2.time - frame1.time)
            alpha = math.clamp(alpha, 0, 1)

            local interpolatedCFrame = frame1.cframe:Lerp(frame2.cframe, alpha)
            local interpolatedVelocity = frame1.velocity:Lerp(frame2.velocity, alpha)
            local moveDirection = frame1.moveDirection:Lerp(frame2.moveDirection, alpha)

            humanoidRootPart.CFrame = interpolatedCFrame
            humanoidRootPart.AssemblyLinearVelocity = interpolatedVelocity

            if moveDirection.Magnitude > 0 then
                humanoid:MoveTo(humanoidRootPart.Position + moveDirection * 10)
            else
                humanoid:MoveTo(humanoidRootPart.Position)
            end

            local isJumping = alpha > 0.5 and frame2.isJumping or frame1.isJumping
            if isJumping and not lastJumpState and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end
            lastJumpState = isJumping

            -- Periodic deviation check
            if math.random(1, 30) == 1 then
                local currentPosition = humanoidRootPart.Position
                local expectedPosition = frame1.position:Lerp(frame2.position, alpha)
                local deviation = (currentPosition - expectedPosition).Magnitude
                if deviation > 15 and not pathRecoveryActive then
                    initiatePathRecovery(false)
                    break
                end
            end

            RunService.RenderStepped:Wait()
        end
        if playbackActive and not pathRecoveryActive then
            playbackActive = false
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            showNotification("Playback finished", "success")
        end
    end)
end

-- ========== SAVE/LOAD/DELETE ==========
local function getSavedRecordingsList()
    local saveFolder = player:FindFirstChild(SAVE_FOLDER_NAME)
    if not saveFolder then return {} end
    local recordingNames = {}
    for _, child in pairs(saveFolder:GetChildren()) do
        if child:IsA("StringValue") then
            table.insert(recordingNames, child.Name)
        end
    end
    table.sort(recordingNames)
    return recordingNames
end

local function loadRecording(recordingName)
    local saveFolder = player:FindFirstChild(SAVE_FOLDER_NAME)
    if not saveFolder then
        showNotification("No saved recordings found", "error")
        return
    end
    local recordingValue = saveFolder:FindFirstChild(recordingName)
    if not recordingValue then
        showNotification("Recording not found", "error")
        return
    end
    local success, decodedData = pcall(HttpService.JSONDecode, HttpService, recordingValue.Value)
    if not success then
        showNotification("Failed to load recording", "error")
        return
    end
    recordedFrames = decodedData.frames
    showNotification(string.format("Loaded '%s' (%d frames)", recordingName, #recordedFrames), "success")
end

local function saveCurrentRecording()
    if #recordedFrames == 0 then
        showNotification("No recording to save", "error")
        return
    end

    local dialog = Rayfield:Input({
        Title = "Save Recording",
        Description = "Enter a name for this recording",
        Placeholder = "Recording name"
    })
    dialog.OnSubmit = function(inputName)
        local name = inputName ~= "" and inputName or "rec_" .. os.time()
        local saveFolder = player:FindFirstChild(SAVE_FOLDER_NAME) or Instance.new("Folder", player)
        saveFolder.Name = SAVE_FOLDER_NAME
        local existingRecording = saveFolder:FindFirstChild(name)
        if existingRecording then
            existingRecording:Destroy()
        end
        local recordingValue = Instance.new("StringValue")
        recordingValue.Name = name
        recordingValue.Value = HttpService:JSONEncode({frames = recordedFrames, timestamp = os.time()})
        recordingValue.Parent = saveFolder
        showNotification("Saved as: " .. name, "success")
        if refreshRecordingListCallback then
            refreshRecordingListCallback()
        end
    end
end

local function deleteRecording(recordingName)
    if recordingName == "" then
        showNotification("Enter a recording name", "error")
        return
    end
    local saveFolder = player:FindFirstChild(SAVE_FOLDER_NAME)
    if saveFolder then
        local recordingValue = saveFolder:FindFirstChild(recordingName)
        if recordingValue then
            recordingValue:Destroy()
            showNotification("Deleted: " .. recordingName, "success")
            if refreshRecordingListCallback then
                refreshRecordingListCallback()
            end
        else
            showNotification("Recording not found", "error")
        end
    else
        showNotification("No saved recordings found", "error")
    end
end

-- ========== FLY SYSTEM ==========
local function enableFly()
    if flyEnabled then return end
    flyEnabled = true
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(9e5, 9e5, 9e5)
    flyBodyVelocity.Parent = humanoidRootPart
    humanoid.PlatformStand = true
    if flyConnection then flyConnection:Disconnect() end
    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled then return end
        local movement = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then movement = movement + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then movement = movement + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then movement = movement + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then movement = movement + Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then movement = movement + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then movement = movement + Vector3.new(0, -1, 0) end
        if movement.Magnitude > 0 then movement = movement.Unit end
        local camera = workspace.CurrentCamera
        local velocity = (camera.CFrame.LookVector * movement.Z + camera.CFrame.RightVector * movement.X + Vector3.new(0, movement.Y, 0)) * flySpeed
        flyBodyVelocity.Velocity = velocity
    end)
end

local function disableFly()
    if not flyEnabled then return end
    flyEnabled = false
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    humanoid.PlatformStand = false
end

-- ========== NOCLIP SYSTEM ==========
local function updateNoclip()
    if noclipEnabled then
        for _, descendant in pairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.CanCollide then
                originalCollisionStates[descendant] = descendant.CanCollide
                descendant.CanCollide = false
            end
        end
    else
        for part, originalState in pairs(originalCollisionStates) do
            if part and part.Parent then
                part.CanCollide = originalState
            end
        end
        originalCollisionStates = {}
    end
end

local function setNoclip(state)
    noclipEnabled = state
    updateNoclip()
end

-- ========== JUMP HIGH ==========
local function setJumpHigh(state)
    jumpHighEnabled = state
    humanoid.JumpPower = state and jumpHighPower or jumpPowerDefault
end

-- ========== GOD MODE ==========
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
    if godModeEnabled and humanoid.Health <= 0 then
        humanoid.Health = math.huge
    end
end)

-- ========== CHARACTER RESPAWN HANDLER ==========
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")

    jumpPowerDefault = humanoid.JumpPower

    if flyEnabled then
        disableFly()
        enableFly()
    end
    if noclipEnabled then
        originalCollisionStates = {}
        updateNoclip()
    end
    if jumpHighEnabled then
        setJumpHigh(true)
    end
    if godModeEnabled then
        setGodMode(true)
    end

    cleanupTrail()
end

player.CharacterAdded:Connect(onCharacterAdded)

-- ========== TRAIL COLOR ==========
local function setTrailColor(newColor)
    trailColor = newColor
    for _, part in pairs(trailParts) do
        if part and part.Parent then
            part.BrickColor = BrickColor.new(trailColor)
        end
    end
end

-- ========== RECORDING LOOP ==========
RunService.RenderStepped:Connect(function()
    if recordingActive and not recordingPaused and humanoidRootPart and humanoidRootPart.Parent then
        local currentTime = os.clock() - recordStartTime
        table.insert(recordedFrames, {
            time = currentTime,
            cframe = humanoidRootPart.CFrame,
            position = humanoidRootPart.Position,
            velocity = humanoidRootPart.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
    updateTrail()
end)

-- ========== RAYFIELD UI INITIALIZATION ==========
local mainWindow = Rayfield:CreateWindow({
    Name = "Renn HUB Universal - Motion Recorder Pro",
    LoadingTitle = "Renn HUB",
    LoadingSubtitle = "Motion Recorder Pro",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RennHUB",
        FileName = "MotionRecorder"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- Tab: Motion Recorder
local recordingTab = mainWindow:CreateTab("Motion Recorder", 4483362458)
local recordingSection = recordingTab:CreateSection("Recording Controls")
recordingTab:CreateButton({
    Name = "Start Record",
    Callback = startRecording
})
recordingTab:CreateButton({
    Name = "Pause Record",
    Callback = pauseRecording
})
recordingTab:CreateButton({
    Name = "Resume Record",
    Callback = resumeRecording
})
recordingTab:CreateButton({
    Name = "Stop Record",
    Callback = stopRecording
})

-- Tab: Playback
local playbackTab = mainWindow:CreateTab("Playback", 4483362458)
local playbackSection = playbackTab:CreateSection("Playback Controls")
playbackTab:CreateButton({
    Name = "Play Normal ▶",
    Callback = function()
        if #recordedFrames >= 2 then
            startPlayback(recordedFrames, false, playbackSpeed, playbackLoop)
        else
            showNotification("Please record something first", "error")
        end
    end
})
playbackTab:CreateButton({
    Name = "Play Reverse ◀",
    Callback = function()
        if #recordedFrames >= 2 then
            startPlayback(recordedFrames, true, playbackSpeed, playbackLoop)
        else
            showNotification("Please record something first", "error")
        end
    end
})
playbackTab:CreateButton({
    Name = "Stop Playback",
    Callback = stopPlayback
})
playbackTab:CreateSlider({
    Name = "Playback Speed",
    Range = {0.25, 3},
    Increment = 0.05,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "PlaybackSpeed",
    Callback = function(value)
        playbackSpeed = value
        if playbackActive and not pathRecoveryActive and playbackData then
            local wasActive = playbackActive
            local wasReverse = playbackReverse
            local wasLoop = playbackLoop
            local currentData = playbackData
            stopPlayback()
            startPlayback(currentData, wasReverse, value, wasLoop)
        end
    end
})
playbackTab:CreateToggle({
    Name = "Loop Mode",
    CurrentValue = false,
    Flag = "LoopMode",
    Callback = function(value)
        playbackLoop = value
    end
})

-- Tab: Saves
local savesTab = mainWindow:CreateTab("Saves", 4483362458)
local savesSection = savesTab:CreateSection("Save Management")
savesTab:CreateButton({
    Name = "Save Current Recording",
    Callback = saveCurrentRecording
})

local recordingDropdown = nil
local function refreshRecordingList()
    local recordings = getSavedRecordingsList()
    if #recordings == 0 then
        recordings = {"(empty)"}
    end
    if recordingDropdown then
        recordingDropdown:SetValues(recordings)
        recordingDropdown.CurrentOption = recordings[1]
    else
        recordingDropdown = savesTab:CreateDropdown({
            Name = "Load Recording",
            Options = recordings,
            CurrentOption = recordings[1],
            Flag = "LoadRecording",
            Callback = function(option)
                if option ~= "(empty)" then
                    loadRecording(option)
                end
            end
        })
    end
end
refreshRecordingList()

local deleteInput = savesTab:CreateInput({
    Name = "Delete Recording",
    PlaceholderText = "Recording name",
    RemoveTextAfterFocusLost = true,
    Callback = function(text)
        deleteRecording(text)
    end
})

savesTab:CreateButton({
    Name = "Refresh List",
    Callback = refreshRecordingList
})

local refreshRecordingListCallback = refreshRecordingList

-- Tab: Visual & Player
local visualPlayerTab = mainWindow:CreateTab("Visual & Player", 4483362458)
local trailSection = visualPlayerTab:CreateSection("Trail")
visualPlayerTab:CreateToggle({
    Name = "Enable Trail",
    CurrentValue = true,
    Flag = "TrailEnabled",
    Callback = function(value)
        trailEnabled = value
        if not value then
            cleanupTrail()
        end
    end
})
visualPlayerTab:CreateColorPicker({
    Name = "Trail Color",
    Color = Color3.fromRGB(255, 50, 50),
    Flag = "TrailColor",
    Callback = function(color)
        setTrailColor(color)
    end
})
visualPlayerTab:CreateButton({
    Name = "Clear Trail",
    Callback = cleanupTrail
})

local playerSection = visualPlayerTab:CreateSection("Player Features")
visualPlayerTab:CreateToggle({
    Name = "Fly Mode",
    CurrentValue = false,
    Flag = "FlyMode",
    Callback = function(value)
        if value then
            enableFly()
        else
            disableFly()
        end
    end
})
visualPlayerTab:CreateSlider({
    Name = "Fly Speed",
    Range = {1, 50},
    Increment = 1,
    Suffix = "studs/s",
    CurrentValue = 16,
    Flag = "FlySpeed",
    Callback = function(value)
        flySpeed = value
    end
})
visualPlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(value)
        setNoclip(value)
    end
})
visualPlayerTab:CreateToggle({
    Name = "Jump High",
    CurrentValue = false,
    Flag = "JumpHigh",
    Callback = function(value)
        setJumpHigh(value)
    end
})
visualPlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {20, 200},
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(value)
        jumpHighPower = value
        if jumpHighEnabled then
            humanoid.JumpPower = value
        end
    end
})
visualPlayerTab:CreateToggle({
    Name = "God Mode",
    CurrentValue = false,
    Flag = "GodMode",
    Callback = function(value)
        setGodMode(value)
    end
})

-- Tab: About
local aboutTab = mainWindow:CreateTab("About", 4483362458)
local aboutSection = aboutTab:CreateSection("About")
aboutTab:CreateParagraph({
    Title = "Renn HUB Universal - Motion Recorder Pro",
    Content = "Version 3.0 with Rayfield UI\n\nAll original features preserved:\n- Recording with jump detection\n- Normal/Reverse playback\n- Continuous neon trail\n- Save/Load/Delete recordings\n- Path Recovery System\n- Fly, Noclip, Jump High, God Mode"
})
local upcomingSection = aboutTab:CreateSection("Upcoming Features")
aboutTab:CreateParagraph({
    Title = "Planned Features",
    Content = "✨ Speed Run Mode\n✨ Ghost Mode\n✨ Auto Record on Death\n✨ Export/Import recordings"
})

showNotification("Renn HUB Universal - Motion Recorder Pro is ready!", "success")