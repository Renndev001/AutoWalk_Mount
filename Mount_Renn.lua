--[[
    Advanced Motion Recorder (Complete Edition) - Rayfield UI
    - Rekam CFrame, Velocity, MoveDirection, lompatan
    - Playback normal/reverse + speed slider + loop mode
    - Save/Load rekaman ke file (DataStore simulasi dengan HttpService)
    - Export/Import JSON via clipboard
    - Visual trail neon (garis jejak)
    - Indikator status di layar
--]]

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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

-- Trail visual
local trailParts = {} -- table of parts (balls or beams)
local trailActive = false
local trailColor = Color3.fromRGB(0, 255, 255) -- neon cyan
local trailInterval = 0.3 -- detik antar titik jejak
local trailTimer = 0

-- Indikator UI (teks di layar)
local statusLabel = nil

-- Nama file untuk menyimpan rekaman (simulasi DataStore)
local SAVE_FOLDER = "MotionRecorderSaves"
local currentSaveName = "default"

-- ========== FUNGSI NOTIFIKASI ==========
local function notif(msg, msgType)
    msgType = msgType or "default"
    Rayfield:Notify({
        Title = "Motion Recorder",
        Content = msg,
        Duration = 1.5,
        Type = msgType,
    })
    print("[MotionRec] " .. msg)
end

-- ========== INDIKATOR STATUS DI LAYAR ==========
local function createStatusIndicator()
    if statusLabel then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MotionRecorderStatus"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 200, 0, 40)
    textLabel.Position = UDim2.new(0.5, -100, 0.02, 0)
    textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.BackgroundTransparency = 0.3
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 18
    textLabel.Text = ""
    textLabel.BorderSizePixel = 0
    textLabel.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = textLabel
    
    statusLabel = textLabel
end

local function updateStatus(text, color)
    if statusLabel then
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        statusLabel.Visible = (text ~= "")
    end
end

-- ========== TRAIL VISUAL (GARIS JEJAK NEON) ==========
local function clearTrail()
    for _, part in pairs(trailParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    trailParts = {}
end

local function addTrailPoint(position)
    if not trailActive then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.3, 0.3, 0.3)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new(trailColor)
    part.Material = Enum.Material.Neon
    part.Parent = workspace
    
    -- Efek fade out setelah beberapa detik (opsional)
    game:GetService("Debris"):AddItem(part, 10)
    
    table.insert(trailParts, part)
    
    -- Batasi jumlah titik trail (agar tidak terlalu berat)
    if #trailParts > 200 then
        local oldest = table.remove(trailParts, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end
end

local function startTrail()
    trailActive = true
    trailTimer = 0
    clearTrail()
end

local function stopTrail()
    trailActive = false
    -- Jangan hapus trail agar rute tetap terlihat
    -- notif("Trail dihentikan, jejak tetap ada", "info")
end

-- Update trail setiap frame
runService.RenderStepped:Connect(function(deltaTime)
    if trailActive and hrp and hrp.Parent then
        trailTimer = trailTimer + deltaTime
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
    startTrail() -- mulai jejak neon
    updateStatus("🔴 RECORDING", Color3.fromRGB(255, 50, 50))
    
    if hrp and hrp.Parent then
        table.insert(recordedFrames, {
            time = 0,
            cframe = hrp.CFrame,
            velocity = hrp.AssemblyLinearVelocity,
            isJumping = (humanoid.FloorMaterial == Enum.Material.Air),
            moveDirection = humanoid.MoveDirection
        })
    end
    notif("🔴 Merekam gerakan + lompatan...", "info")
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
    notif(string.format("⏹️ Berhenti. %d frame, %.2f detik", #recordedFrames, duration), "success")
end

-- Rekam loop (RenderStepped)
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

-- ========== PLAYBACK DENGAN SPEED, LOOP, REVERSE ==========
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

    updateStatus(reverse and "🔁 PLAYING REVERSE" or "▶️ PLAYING", Color3.fromRGB(0, 255, 0))

    workspace.Gravity = 0
    humanoid.PlatformStand = true

    task.spawn(function()
        local totalTime = playbackData[#playbackData].time
        local effectiveTotal = totalTime / playbackSpeed
        
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
                    -- Loop: reset waktu
                    playbackStartTime = os.clock()
                    continue
                else
                    break
                end
            end
            
            -- Cari frame berdasarkan waktu
            local idx = 1
            local targetTime = progress * totalTime
            if reverse then
                for i = #playbackData, 1, -1 do
                    if playbackData[i].time <= targetTime then
                        idx = i
                        break
                    end
                end
            else
                for i = 1, #playbackData do
                    if playbackData[i].time >= targetTime then
                        idx = i
                        break
                    end
                end
            end
            
            local frame = playbackData[idx]
            if frame then
                hrp.CFrame = frame.cframe
                hrp.AssemblyLinearVelocity = frame.velocity
                
                if frame.moveDirection.Magnitude > 0 then
                    local targetPos = hrp.Position + (frame.moveDirection * 10)
                    humanoid:MoveTo(targetPos)
                else
                    humanoid:MoveTo(hrp.Position)
                end
                
                if frame.isJumping and not lastJumpFrame then
                    if humanoid.FloorMaterial ~= Enum.Material.Air then
                        humanoid.Jump = true
                    end
                end
                lastJumpFrame = frame.isJumping
            end
            
            task.wait(0.016) -- ~60 FPS
        end
        
        workspace.Gravity = 196.2
        humanoid.PlatformStand = false
        playing = false
        updateStatus("", Color3.new(1,1,1))
        notif("Playback selesai", "success")
    end)
end

-- ========== SAVE & LOAD (MENGGUNAKAN HTTP SERVICE / SIMULASI FILE) ==========
-- Simpan ke file (menggunakan DataStore style via HttpService JSON)
local function saveRecording(name)
    if #recordedFrames == 0 then notif("Tidak ada rekaman untuk disimpan", "error") return end
    
    local saveData = {
        name = name,
        frames = recordedFrames,
        timestamp = os.time()
    }
    local json = httpService:JSONEncode(saveData)
    -- Simpan di penanda (menggunakan StringValue di player)
    local folder = Instance.new("Folder")
    folder.Name = SAVE_FOLDER
    folder.Parent = player
    local value = Instance.new("StringValue")
    value.Name = name
    value.Value = json
    value.Parent = folder
    
    notif("Rekaman '" .. name .. "' disimpan!", "success")
end

local function loadRecording(name)
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if not folder then notif("Belum ada rekaman tersimpan", "error") return false end
    local value = folder:FindFirstChild(name)
    if not value then notif("Rekaman '" .. name .. "' tidak ditemukan", "error") return false end
    
    local success, data = pcall(httpService.JSONDecode, httpService, value.Value)
    if not success then notif("Gagal memuat rekaman", "error") return false end
    
    recordedFrames = data.frames
    notif("Memuat rekaman '" .. name .. "' (" .. #recordedFrames .. " frame)", "success")
    return true
end

local function getSaveList()
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if not folder then return {} end
    local list = {}
    for _, v in pairs(folder:GetChildren()) do
        if v:IsA("StringValue") then
            table.insert(list, v.Name)
        end
    end
    return list
end

local function deleteSave(name)
    local folder = player:FindFirstChild(SAVE_FOLDER)
    if folder then
        local value = folder:FindFirstChild(name)
        if value then value:Destroy() end
        notif("Rekaman '" .. name .. "' dihapus", "info")
    end
end

-- Reset rekaman saat ini
local function resetRecording()
    recordedFrames = {}
    clearTrail()
    notif("Rekaman saat ini direset", "info")
end

-- ========== EXPORT / IMPORT JSON ==========
local function exportToClipboard()
    if #recordedFrames == 0 then notif("Tidak ada rekaman", "error") return end
    local data = {
        frames = recordedFrames
    }
    local json = httpService:JSONEncode(data)
    -- Set ke clipboard (menggunakan setclipboard jika tersedia)
    if setclipboard then
        setclipboard(json)
        notif("Data rekaman disalin ke clipboard (" .. #json .. " karakter)", "success")
    else
        notif("Clipboard tidak didukung di environment ini", "error")
    end
end

local function importFromClipboard()
    if not setclipboard then notif("Import tidak didukung", "error") return end
    -- Biasanya kita perlu paste, tapi tidak ada getclipboard. Minta user input? 
    -- Alternatif: buat TextBox untuk paste JSON
    notif("Fungsi import memerlukan input manual. Gunakan tombol 'Paste JSON'", "info")
end

-- Buat GUI Input untuk paste JSON
local function showImportDialog()
    local dialog = Instance.new("ScreenGui")
    dialog.Name = "ImportDialog"
    dialog.Parent = player:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 300)
    frame.Position = UDim2.new(0.5, -200, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = dialog
    
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0.9, 0, 0.7, 0)
    textBox.Position = UDim2.new(0.05, 0, 0.05, 0)
    textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    textBox.TextColor3 = Color3.new(1,1,1)
    textBox.Text = "Paste JSON di sini..."
    textBox.TextWrapped = true
    textBox.MultiLine = true
    textBox.ClearTextOnFocus = false
    textBox.Parent = frame
    
    local importBtn = Instance.new("TextButton")
    importBtn.Size = UDim2.new(0.4, 0, 0.15, 0)
    importBtn.Position = UDim2.new(0.05, 0, 0.8, 0)
    importBtn.Text = "Import"
    importBtn.BackgroundColor3 = Color3.fromRGB(70, 150, 70)
    importBtn.Parent = frame
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
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 70, 70)
    cancelBtn.Parent = frame
    cancelBtn.MouseButton1Click:Connect(function()
        dialog:Destroy()
    end)
end

-- ========== UI RAYFIELD (LENGKAP) ==========
local Window = Rayfield:CreateWindow({
    Name = "Motion Recorder Pro",
    Icon = "rbxassetid://6031097358",
    LoadingTitle = "Motion Recorder",
    LoadingSubtitle = "Complete Edition",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MotionRecorderPro",
        FileName = "Settings"
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("🎥 Kontrol", nil)
local TrailTab = Window:CreateTab("✨ Jejak Neon", nil)
local SaveTab = Window:CreateTab("💾 Save/Load", nil)

-- ===== MAIN TAB =====
MainTab:CreateSection("Rekaman")
MainTab:CreateButton({ Name = "🔴 Mulai Rekam", Callback = startRecording })
MainTab:CreateButton({ Name = "⏹️ Stop Rekam", Callback = stopRecording })
MainTab:CreateButton({ Name = "🗑️ Reset Rekaman", Callback = resetRecording })

MainTab:CreateSection("Playback")
MainTab:CreateButton({ Name = "▶️ Play Normal", Callback = function()
    if #recordedFrames >= 2 then
        startPlayback(recordedFrames, false, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end})
MainTab:CreateButton({ Name = "🔁 Play Reverse", Callback = function()
    if #recordedFrames >= 2 then
        startPlayback(recordedFrames, true, playbackSpeed, loopMode)
    else notif("Rekam dulu", "error") end
end})
MainTab:CreateButton({ Name = "⏹️ Stop Playback", Callback = stopPlayback })

-- Slider kecepatan
MainTab:CreateSlider({
    Name = "⏩ Kecepatan Playback",
    Range = {0.25, 3},
    Increment = 0.05,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "PlaybackSpeed",
    Callback = function(v)
        playbackSpeed = v
        notif("Kecepatan: " .. v .. "x", "default")
    end
})

-- Toggle Loop
MainTab:CreateToggle({
    Name = "🔄 Loop Mode",
    CurrentValue = false,
    Flag = "LoopMode",
    Callback = function(v)
        loopMode = v
        notif(loopMode and "Loop mode ON" or "Loop mode OFF", "info")
    end
})

-- ===== TRAIL TAB =====
TrailTab:CreateSection("Visual Trail (Jejak Neon)")
TrailTab:CreateToggle({
    Name = "Aktifkan Jejak Saat Rekam",
    CurrentValue = true,
    Callback = function(v)
        -- Trail otomatis aktif saat rekam; ini hanya pre-set
        trailActive = v
        if not v then clearTrail() end
        notif(v and "Jejak aktif" or "Jejak nonaktif", "info")
    end
})
TrailTab:CreateColorPicker({
    Name = "Warna Jejak",
    Color = Color3.fromRGB(0, 255, 255),
    Flag = "TrailColor",
    Callback = function(c)
        trailColor = c
        -- Update warna semua part yang sudah ada?
        for _, part in pairs(trailParts) do
            if part and part.Parent then
                part.BrickColor = BrickColor.new(c)
            end
        end
        notif("Warna jejak diubah", "default")
    end
})
TrailTab:CreateSlider({
    Name = "Interval Titik (detik)",
    Range = {0.1, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.3,
    Flag = "TrailInterval",
    Callback = function(v)
        trailInterval = v
    end
})
TrailTab:CreateButton({ Name = "Hapus Semua Jejak", Callback = function()
    clearTrail()
    notif("Jejak dihapus", "info")
end})

-- ===== SAVE/LOAD TAB =====
SaveTab:CreateSection("Simpan & Muat Rekaman")
SaveTab:CreateInput({
    Name = "Nama Rekaman",
    PlaceholderText = "nama_rekaman",
    RemoveTextAfterFocus = false,
    Flag = "SaveName",
    Callback = function(text)
        currentSaveName = text
    end
})
SaveTab:CreateButton({ Name = "💾 Simpan Rekaman", Callback = function()
    if currentSaveName and currentSaveName ~= "" then
        saveRecording(currentSaveName)
    else
        notif("Masukkan nama rekaman", "error")
    end
end})
SaveTab:CreateButton({ Name = "📂 Muat Rekaman", Callback = function()
    local saves = getSaveList()
    if #saves == 0 then notif("Tidak ada rekaman tersimpan", "error") return end
    -- Pilih dari dropdown? Untuk sederhana, gunakan input nama lagi.
    notif("Ketik nama rekaman di kolom, lalu tekan Load", "info")
end})
SaveTab:CreateButton({ Name = "🔁 Load (gunakan nama di atas)", Callback = function()
    if currentSaveName and currentSaveName ~= "" then
        loadRecording(currentSaveName)
    else
        notif("Masukkan nama rekaman", "error")
    end
end})
SaveTab:CreateButton({ Name = "🗑️ Hapus Rekaman", Callback = function()
    if currentSaveName and currentSaveName ~= "" then
        deleteSave(currentSaveName)
    else
        notif("Masukkan nama rekaman", "error")
    end
end})

SaveTab:CreateSection("Export / Import JSON")
SaveTab:CreateButton({ Name = "📋 Export ke Clipboard", Callback = exportToClipboard })
SaveTab:CreateButton({ Name = "📥 Import JSON (Paste)", Callback = showImportDialog })

-- ========== INISIALISASI ==========
createStatusIndicator()
notif("✅ Motion Recorder Pro siap! (dengan trail neon, save/load, speed, loop, import/export)", "success")
