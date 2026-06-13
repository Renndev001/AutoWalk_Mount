--[[
    Advanced Motion Recorder (Jump + Walk/Run Animation)
    - Merekam CFrame, Velocity, MoveDirection, dan status lompat setiap frame
    - Playback dengan interpolasi dan simulasi lompat
    - Animasi berjalan/lari aktif karena menggunakan Humanoid:MoveTo()
    - GUI kecil dan ramah mobile
--]]

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local runService = game:GetService("RunService")

-- Variabel rekaman
local recording = false
local recordedFrames = {}   -- setiap frame: {time, cframe, velocity, isJumping, moveDirection}
local startTime = 0

-- Variabel playback
local playing = false
local reverse = false
local playbackData = nil
local playbackStartTime = 0
local lastJumpFrame = false

-- Notifikasi
local function notif(msg)
    print("[MotionRec] " .. msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Motion Recorder",
            Text = msg,
            Duration = 1.5
        })
    end)
end

-- ========== REKAM ==========
local function startRecording()
    if recording then notif("Sudah merekam") return end
    if playing then notif("Hentikan playback dulu") return end
    recordedFrames = {}
    startTime = os.clock()
    recording = true
    -- Rekam frame pertama
    if hrp and hrp.Parent then
        table.insert(recordedFrames, {
            time = 0,
            cframe = hrp.CFrame,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air), -- di udara berarti lompat
            moveDirection = humanoid.MoveDirection
        })
    end
    notif("🔴 Merekam gerakan + lompatan...")
end

local function stopRecording()
    if not recording then notif("Tidak ada rekaman") return end
    recording = false
    if #recordedFrames < 2 then
        notif("Rekaman terlalu pendek")
        recordedFrames = {}
        return
    end
    local duration = recordedFrames[#recordedFrames].time
    notif(string.format("⏹️ Berhenti. %d frame, %.2f detik", #recordedFrames, duration))
end

-- Loop rekaman (60 FPS)
runService.RenderStepped:Connect(function()
    if recording and hrp and hrp.Parent then
        local now = os.clock() - startTime
        table.insert(recordedFrames, {
            time = now,
            cframe = hrp.CFrame,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air), -- deteksi melompat
            moveDirection = humanoid.MoveDirection
        })
    end
end)

-- ========== PLAYBACK DENGAN ANIMASI ==========
local function stopPlayback()
    playing = false
    reverse = false
    playbackData = nil
    -- Kembalikan gravitasi
    workspace.Gravity = 196.2
    humanoid.PlatformStand = false
    notif("Playback dihentikan")
end

local function startPlayback(data, isReverse)
    if recording then notif("Hentikan rekaman dulu") return end
    if playing then stopPlayback() end
    if not data or #data < 2 then notif("Tidak ada data rekaman") return end

    playing = true
    reverse = isReverse
    playbackData = data
    playbackStartTime = os.clock()
    lastJumpFrame = false

    -- Siapkan lingkungan playback
    local originalGravity = workspace.Gravity
    workspace.Gravity = 0  -- biar karakter tidak jatuh bebas
    humanoid.PlatformStand = true

    notif(isReverse and "🔁 Memutar REVERSE (dengan animasi)" or "▶️ Memutar NORMAL (dengan animasi)")

    task.spawn(function()
        local totalTime = playbackData[#playbackData].time
        while playing do
            local now = os.clock() - playbackStartTime
            local progress = isReverse and (1 - now / totalTime) or (now / totalTime)
            if progress <= 0 or progress >= 1 then
                notif("Playback selesai")
                break
            end

            -- Cari frame berdasarkan waktu
            local idx = 1
            if isReverse then
                for i = #playbackData, 1, -1 do
                    if playbackData[i].time <= progress * totalTime then
                        idx = i
                        break
                    end
                end
            else
                for i = 1, #playbackData do
                    if playbackData[i].time >= progress * totalTime then
                        idx = i
                        break
                    end
                end
            end

            local frame = playbackData[idx]

            -- Terapkan posisi dan kecepatan
            hrp.CFrame = frame.cframe
            hrp.AssemblyLinearVelocity = frame.velocity

            -- Aktifkan animasi berjalan/lari dengan MoveTo
            if frame.moveDirection.Magnitude > 0 then
                local targetPos = hrp.Position + (frame.moveDirection * 10)
                humanoid:MoveTo(targetPos)
            else
                humanoid:MoveTo(hrp.Position)
            end

            -- Simulasi lompat jika frame menunjukkan lompat dan sebelumnya tidak lompat
            if frame.isJumping and not lastJumpFrame then
                -- Pastikan karakter di tanah agar lompatan valid
                if humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid.Jump = true
                end
            end
            lastJumpFrame = frame.isJumping

            task.wait(0.016) -- ~60 FPS
        end

        -- Kembalikan pengaturan
        workspace.Gravity = originalGravity
        humanoid.PlatformStand = false
        playing = false
    end)
end

-- ========== GUI SEDERHANA (UKURAN KECIL) ==========
local function createGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MotionRecorderGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 210, 0, 175)
    frame.Position = UDim2.new(0.02, 0, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    title.Text = "🎥 Motion Recorder"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = frame

    local recBtn = Instance.new("TextButton")
    recBtn.Size = UDim2.new(0.9, 0, 0, 32)
    recBtn.Position = UDim2.new(0.05, 0, 0.23, 0)
    recBtn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    recBtn.Text = "🔴 REKAM"
    recBtn.TextColor3 = Color3.new(1, 1, 1)
    recBtn.Font = Enum.Font.GothamBold
    recBtn.TextSize = 14
    recBtn.Parent = frame
    recBtn.MouseButton1Click:Connect(startRecording)

    local stopRecBtn = Instance.new("TextButton")
    stopRecBtn.Size = UDim2.new(0.9, 0, 0, 32)
    stopRecBtn.Position = UDim2.new(0.05, 0, 0.42, 0)
    stopRecBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    stopRecBtn.Text = "⏹️ STOP REKAM"
    stopRecBtn.TextColor3 = Color3.new(1, 1, 1)
    stopRecBtn.Font = Enum.Font.Gotham
    stopRecBtn.TextSize = 13
    stopRecBtn.Parent = frame
    stopRecBtn.MouseButton1Click:Connect(stopRecording)

    local normalBtn = Instance.new("TextButton")
    normalBtn.Size = UDim2.new(0.43, 0, 0, 32)
    normalBtn.Position = UDim2.new(0.05, 0, 0.61, 0)
    normalBtn.BackgroundColor3 = Color3.fromRGB(70, 150, 70)
    normalBtn.Text = "▶️ Normal"
    normalBtn.TextColor3 = Color3.new(1, 1, 1)
    normalBtn.Font = Enum.Font.Gotham
    normalBtn.TextSize = 12
    normalBtn.Parent = frame
    normalBtn.MouseButton1Click:Connect(function()
        if #recordedFrames >= 2 then startPlayback(recordedFrames, false) else notif("Rekam dulu") end
    end)

    local reverseBtn = Instance.new("TextButton")
    reverseBtn.Size = UDim2.new(0.43, 0, 0, 32)
    reverseBtn.Position = UDim2.new(0.52, 0, 0.61, 0)
    reverseBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
    reverseBtn.Text = "🔁 Reverse"
    reverseBtn.TextColor3 = Color3.new(1, 1, 1)
    reverseBtn.Font = Enum.Font.Gotham
    reverseBtn.TextSize = 12
    reverseBtn.Parent = frame
    reverseBtn.MouseButton1Click:Connect(function()
        if #recordedFrames >= 2 then startPlayback(recordedFrames, true) else notif("Rekam dulu") end
    end)

    local stopPlayBtn = Instance.new("TextButton")
    stopPlayBtn.Size = UDim2.new(0.9, 0, 0, 28)
    stopPlayBtn.Position = UDim2.new(0.05, 0, 0.85, 0)
    stopPlayBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
    stopPlayBtn.Text = "⏹️ STOP PLAYBACK"
    stopPlayBtn.TextColor3 = Color3.new(1, 1, 1)
    stopPlayBtn.Font = Enum.Font.Gotham
    stopPlayBtn.TextSize = 11
    stopPlayBtn.Parent = frame
    stopPlayBtn.MouseButton1Click:Connect(stopPlayback)
end

-- Inisialisasi
createGUI()
notif("✅ Motion Recorder siap! Rekam gerakan, lompatan, dan putar ulang dengan animasi.")
