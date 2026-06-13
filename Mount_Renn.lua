--[[
══════════════════════════════════════════════════════════════════════════
🏔️ MIZUKAGE OFFICIAL - ULTIMATE EXPEDITION SYSTEM (V13.5 FINALE)
Creator: Mizukage Official | Engine: Absolute TAS, Godspeed TP & Cloud Sync
══════════════════════════════════════════════════════════════════════════
]]

-- ==========================================
-- 1. CLEANUP & INITIALIZATION
-- ==========================================
if getgenv().MizukageSystem then
    pcall(function() getgenv().MizukageSystem.DisconnectAll() end)
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- ==========================================
-- 2. GLOBAL STATE & CONFIGURATION
-- ==========================================
local state = {
    -- TAS Engine
    IsRecording = false, IsPlaying = false, IsLoopingTAS = false, AutoRespawn = false, ReversePlayback = false,
    CurrentSpeed = 1.0, RecordedPaths = {}, PathOrder = {},
    RecordFPS = 60, MinDistance = 0.5,
    
    -- Teleport & Radar
    CPList = {}, AutoDetectCP = false, TweenSpeed = 0, -- 0 = Instant Blink (Godspeed)
    IsAutoTP = false, IsLoopingTP = false,
    
    -- Movement & Ability
    WalkSpeed = 16, JumpPower = 50, WalkSpeedBypass = true, InfiniteJump = false, FlyMode = false, NoClip = false,
    
    -- Security & Cloud
    AntiAFK = true, VisualTrail = true,
    WebhookURL = "https://discord.com/api/webhooks/1483643363873001703/A4vanwmvJqZKYirad5LBwQxV4oepsRQPJloiJNgfz8Xzy7c3xLm1uW0BAVl1P5WiVTsf",
    
    Connections = {}
}

getgenv().MizukageSystem = {
    DisconnectAll = function()
        for _, conn in pairs(state.Connections) do pcall(function() conn:Disconnect() end) end
        pcall(function() Workspace:FindFirstChild("Mizukage_VisualTrail"):Destroy() end)
        if state.GUI then state.GUI:Destroy() end
    end
}

local function Notify(title, text)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "👑 " .. title, Text = text, Duration = 3}) end)
end

local function GetCharacter()
    local char = player.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil, nil end
    return hrp, hum
end

-- ==========================================
-- 3. UNBROKEN VISUAL TRAIL ENGINE
-- ==========================================
local TrailFolder = Workspace:FindFirstChild("Mizukage_VisualTrail") or Instance.new("Folder", Workspace)
TrailFolder.Name = "Mizukage_VisualTrail"

local function DrawTrail(pos1, pos2)
    if not state.VisualTrail then return end
    local dist = (pos1 - pos2).Magnitude
    if dist < 0.1 then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.3, 0.3, dist)
    part.CFrame = CFrame.lookAt(pos1, pos2) * CFrame.new(0, 0, -dist/2)
    part.Anchored = true part.CanCollide = false part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(0, 255, 255) part.Transparency = 0.2 part.Parent = TrailFolder
end

local function ClearTrail() TrailFolder:ClearAllChildren() end

-- ==========================================
-- 4. TAS ENGINE: FLAWLESS RECORD & PLAY
-- ==========================================
local function StartRecording()
    if state.IsRecording then return end
    local hrp = GetCharacter() if not hrp then return end
    
    state.IsRecording = true
    local pathName = "Mizukage_TAS_" .. os.date("%H%M%S")
    local newPath = { Name = pathName, Frames = {}, StartTime = tick() }
    local lastPos, lastRecordTime = hrp.Position, 0
    
    state.Connections.Record = RunService.Heartbeat:Connect(function()
        if not state.IsRecording then return end
        local hrp, hum = GetCharacter() if not hrp or not hum then return end
        
        local now = tick()
        if (now - lastRecordTime) < (1 / state.RecordFPS) then return end
        
        if (hrp.Position - lastPos).Magnitude >= state.MinDistance then
            local isJumping = (hum:GetState() == Enum.HumanoidStateType.Jumping) or (hum:GetState() == Enum.HumanoidStateType.Freefall)
            
            table.insert(newPath.Frames, {
                Position = {hrp.Position.X, hrp.Position.Y, hrp.Position.Z},
                LookVector = {hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Y, hrp.CFrame.LookVector.Z},
                UpVector = {hrp.CFrame.UpVector.X, hrp.CFrame.UpVector.Y, hrp.CFrame.UpVector.Z},
                Velocity = {hrp.Velocity.X, hrp.Velocity.Y, hrp.Velocity.Z},
                MoveState = isJumping and "Jumping" or "Grounded",
                WalkSpeed = hum.WalkSpeed, Timestamp = now - newPath.StartTime
            })
            
            if #newPath.Frames > 1 then DrawTrail(lastPos, hrp.Position) end
            lastPos = hrp.Position
            lastRecordTime = now
        end
    end)
    state.RecordedPaths[pathName] = newPath
    table.insert(state.PathOrder, pathName)
    Notify("Recording", "Merekam rute TAS secara presisi...")
end

local function StopRecording()
    if not state.IsRecording then return end
    if state.Connections.Record then state.Connections.Record:Disconnect() state.Connections.Record = nil end
    state.IsRecording = false
    if getgenv().MizukageRefreshPaths then getgenv().MizukageRefreshPaths() end
    Notify("Saved", "Rute berhasil diamankan.")
end

local function ApplyFrame(frame, reverseVel)
    local hrp, hum = GetCharacter() if not hrp then return end
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    hrp.CFrame = CFrame.lookAt(pos, pos + look, up)
    
    local mult = reverseVel and -1 or 1
    hrp.AssemblyLinearVelocity = Vector3.new(frame.Velocity[1]*state.CurrentSpeed*mult, (frame.MoveState == "Jumping") and frame.Velocity[2] or 0, frame.Velocity[3]*state.CurrentSpeed*mult)
    hrp.AssemblyAngularVelocity = Vector3.zero
    hum.WalkSpeed = (frame.WalkSpeed or 16) * state.CurrentSpeed
    if frame.MoveState == "Jumping" then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end

local function PlayRecording(recordingName)
    local recording = state.RecordedPaths[recordingName]
    if not recording or #recording.Frames == 0 then return Notify("Error", "Rute kosong!") end
    if state.IsPlaying then if state.Connections.Playback then state.Connections.Playback:Disconnect() end state.IsPlaying = false task.wait(0.1) end
    
    state.IsPlaying = true
    local hrp, hum = GetCharacter() if hrp then hum.AutoRotate = false end
    
    local frames = recording.Frames
    local totalDuration = frames[#frames].Timestamp
    local startTime = tick()
    
    state.Connections.Playback = RunService.Heartbeat:Connect(function()
        if not state.IsPlaying then return end
        local hrp, hum = GetCharacter()
        if not hrp or hum.Health <= 0 then if state.AutoRespawn then hum.Health=0 else state.IsPlaying=false end return end
        
        local elapsedTime = (tick() - startTime) * state.CurrentSpeed
        if state.ReversePlayback then elapsedTime = totalDuration - elapsedTime end
        
        if (not state.ReversePlayback and elapsedTime >= totalDuration) or (state.ReversePlayback and elapsedTime <= 0) then
            if state.IsLoopingTAS then startTime = tick() else state.IsPlaying = false hum.AutoRotate = true hum:Move(Vector3.zero) Notify("Selesai", "Bot tiba di tujuan.") end return
        end
        
        local fIdx = 1 
        while fIdx < #frames and frames[fIdx + 1].Timestamp <= elapsedTime do fIdx = fIdx + 1 end
        
        local cF = frames[fIdx]
        local nF = frames[math.min(fIdx + 1, #frames)]
        
        if cF and nF and cF ~= nF then
            local alpha = math.clamp((elapsedTime - cF.Timestamp) / (nF.Timestamp - cF.Timestamp), 0, 1)
            local p1 = Vector3.new(cF.Position[1], cF.Position[2], cF.Position[3])
            local p2 = Vector3.new(nF.Position[1], nF.Position[2], nF.Position[3])
            local l1 = Vector3.new(cF.LookVector[1], cF.LookVector[2], cF.LookVector[3])
            local l2 = Vector3.new(nF.LookVector[1], nF.LookVector[2], nF.LookVector[3])
            hrp.CFrame = CFrame.lookAt(p1:Lerp(p2, alpha), p1:Lerp(p2, alpha) + l1:Lerp(l2, alpha).Unit)
            hrp.AssemblyLinearVelocity = Vector3.new(cF.Velocity[1]*state.CurrentSpeed*(state.ReversePlayback and -1 or 1), (cF.MoveState == "Jumping" and cF.Velocity[2] or 0), cF.Velocity[3]*state.CurrentSpeed*(state.ReversePlayback and -1 or 1))
        elseif cF then 
            ApplyFrame(cF, state.ReversePlayback) 
        end
    end)
    Notify("TAS Playing", "Menjalankan rute: " .. recordingName)
end

local function StopPlayback()
    if state.Connections.Playback then state.Connections.Playback:Disconnect() state.Connections.Playback = nil end
    state.IsPlaying = false
    local hrp, hum = GetCharacter() if hum then hum.AutoRotate = true hum:Move(Vector3.zero) end
    Notify("Stopped", "Bot TAS dihentikan.")
end

-- ==========================================
-- 5. GODSPEED TELEPORT & SMART RADAR
-- ==========================================
local function TeleportTo(cf)
    local hrp = GetCharacter() if not hrp then return end
    state.NoClip = true
    if state.TweenSpeed <= 0 then
        hrp.CFrame = cf + Vector3.new(0, 3, 0)
        state.NoClip = false
    else
        local tw = TweenService:Create(hrp, TweenInfo.new(state.TweenSpeed, Enum.EasingStyle.Quad), {CFrame = cf + Vector3.new(0,3,0)})
        tw:Play() tw.Completed:Wait() state.NoClip = false
    end
end

local function RunAutoTPList()
    if state.IsAutoTP then return end
    if #state.CPList == 0 then return Notify("Error", "Daftar lokasi kosong!") end
    state.IsAutoTP = true
    Notify("Godspeed TP", "Memulai auto teleport list...")
    
    task.spawn(function()
        while state.IsAutoTP do
            for _, cp in ipairs(state.CPList) do
                if not state.IsAutoTP then break end
                TeleportTo(cp.CFrame)
                task.wait(state.TweenSpeed <= 0 and 0.05 or 0.1) 
            end
            if not state.IsLoopingTP then state.IsAutoTP = false Notify("Selesai", "Seluruh list telah didatangi.") break end
            task.wait(0.5)
        end
    end)
end

local function StopAutoTPList()
    state.IsAutoTP = false
    Notify("Stopped", "Auto Teleport dihentikan.")
end

local function SaveLocation(name, cf)
    for _, cp in ipairs(state.CPList) do if (cp.CFrame.Position - cf.Position).Magnitude < 10 then return end end
    table.insert(state.CPList, {Name = name, CFrame = cf})
    Notify("Radar", "Tersimpan: " .. name)
    if getgenv().MizukageRefreshCP then getgenv().MizukageRefreshCP() end
end

local function SetupRadar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    state.Connections.TouchRadar = hrp.Touched:Connect(function(hit)
        if not state.AutoDetectCP then return end
        local n = hit.Name:lower()
        if n:find("checkpoint") or n:find("cp") or n:find("spawn") or n:find("stage") then 
            SaveLocation("CP: " .. hit.Name, hit.CFrame) 
        end
    end)
end
player.CharacterAdded:Connect(SetupRadar)
task.spawn(SetupRadar)

state.Connections.StatsRadar = task.spawn(function()
    local lastCP = ""
    while task.wait(1) do
        if not state.AutoDetectCP then continue end
        local stats = player:FindFirstChild("leaderstats")
        if stats then
            for _, s in ipairs(stats:GetChildren()) do
                if s.Name:lower():find("stage") or s.Name:lower():find("level") then
                    if tostring(s.Value) ~= lastCP then 
                        lastCP = tostring(s.Value) 
                        local hrp = GetCharacter() if hrp then SaveLocation("Stage " .. lastCP, hrp.CFrame) end 
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- 6. DISCORD WEBHOOK EXPORTER (DATABASE READY)
-- ==========================================
local function SendBackupData()
    if not httprequest then return Notify("Error", "Executor tidak support HTTP Request.") end
    Notify("Cloud Sync", "Mengekspor Database ke Discord...")
    
    local proxyUrl = state.WebhookURL:gsub("discord.com", "webhook.lewisakura.moe")
    local gameName = "Unknown Map"
    pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)

    -- [A] MEMBANGUN FORMAT LUA DATABASE 
    local lines = {}
    table.insert(lines, "--[[")
    table.insert(lines, "  👑 MIZUKAGE OFFICIAL - DATABASE EXPORT")
    table.insert(lines, "  Map Name : " .. gameName)
    table.insert(lines, "  Map ID   : " .. game.PlaceId)
    table.insert(lines, "  Operator : " .. player.Name)
    table.insert(lines, "  Date     : " .. os.date("%c"))
    table.insert(lines, "--]]\n")
    table.insert(lines, "local MizukageDatabase = {")
    table.insert(lines, "    Metadata = {")
    table.insert(lines, '        PlaceId = ' .. game.PlaceId .. ',')
    table.insert(lines, '        GameName = "' .. gameName .. '"')
    table.insert(lines, "    },\n")
    
    table.insert(lines, "    TeleportList = {")
    for i, cp in ipairs(state.CPList) do 
        local p = cp.CFrame.Position
        table.insert(lines, string.format('        [%d] = {Name = "%s", Pos = Vector3.new(%.3f, %.3f, %.3f)},', i, cp.Name, p.X, p.Y, p.Z))
    end
    table.insert(lines, "    },\n")
    
    table.insert(lines, "    TrackMap_Paths = {")
    local totalPaths = 0
    for pName, pData in pairs(state.RecordedPaths) do
        totalPaths = totalPaths + 1
        table.insert(lines, '        ["' .. pName .. '"] = {')
        for _, f in ipairs(pData.Frames) do
            table.insert(lines, string.format(
                "            {P={%.3f,%.3f,%.3f}, L={%.3f,%.3f,%.3f}, U={%.3f,%.3f,%.3f}, V={%.3f,%.3f,%.3f}, S='%s', W=%.1f, T=%.3f},",
                f.Position[1], f.Position[2], f.Position[3], f.LookVector[1], f.LookVector[2], f.LookVector[3], f.UpVector[1], f.UpVector[2], f.UpVector[3], f.Velocity[1], f.Velocity[2], f.Velocity[3], f.MoveState, f.WalkSpeed, f.Timestamp
            ))
        end
        table.insert(lines, "        },")
    end
    table.insert(lines, "    }")
    table.insert(lines, "}\n\nreturn MizukageDatabase")
    
    local fileData = table.concat(lines, "\n")
    local fileName = "MizukageDB_" .. game.PlaceId .. "_" .. os.time() .. ".txt"

    local avatar = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"
    pcall(function() 
        local res = HttpService:JSONDecode(game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..player.UserId.."&size=420x420&format=Png&isCircular=false")) 
        if res.data[1] then avatar = res.data[1].imageUrl end 
    end)
    
    local boundary = "----WebKitFormBoundaryMizukage" .. tostring(math.random(100000, 999999))
    
    -- FIXED ANSI ESCAPE CODE (Menggunakan \\u001b agar Delta Executor tidak Error)
    local embedJson = HttpService:JSONEncode({
        username = "Mizukage Cloud",
        embeds = {{
            title = "💠 MIZUKAGE DATABASE SECURED 💠",
            description = "```ansi\n\\u001b[1;36mBerhasil mengekstrak data Teleport dan Record Route!\\u001b[0m\n```\nFile `.txt` terlampir sudah berformat Database Lua murni. Siap digunakan untuk sistem **Auto-Load By Map ID** pada Hub.",
            color = 65535,
            fields = {
                {name = "👤 Operator", value = "```" .. player.Name .. "```", inline = true},
                {name = "🌍 Map ID", value = "```" .. tostring(game.PlaceId) .. "```", inline = true},
                {name = "📍 Total Teleports", value = "**" .. tostring(#state.CPList) .. "** Titik", inline = true},
                {name = "🎥 Total Records", value = "**" .. tostring(totalPaths) .. "** Rute", inline = true}
            },
            thumbnail = {url = avatar}
        }}
    })

    local body = "--" .. boundary .. "\r\n"
    body = body .. 'Content-Disposition: form-data; name="payload_json"\r\n\r\n'
    body = body .. embedJson .. "\r\n"
    body = body .. "--" .. boundary .. "\r\n"
    body = body .. 'Content-Disposition: form-data; name="file"; filename="'..fileName..'"\r\n'
    body = body .. 'Content-Type: text/plain\r\n\r\n'
    body = body .. fileData .. "\r\n"
    body = body .. "--" .. boundary .. "--"

    task.spawn(function()
        local s, r = pcall(function() 
            return httprequest({
                Url = state.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "multipart/form-data; boundary=" .. boundary},
                Body = body
            }) 
        end)
        if s and r.StatusCode >= 200 then 
            Notify("Database Terkirim", "File berhasil mendarat di Discord!") 
        else
            Notify("Gagal", "Error pengiriman. Hubungi Dev.")
        end
    end)
end

-- ==========================================
-- 7. MOVEMENT & ABILITY
-- ==========================================
state.Connections.Move = RunService.RenderStepped:Connect(function()
    local hrp, hum = GetCharacter() if not hum then return end
    if state.WalkSpeedBypass then hum.WalkSpeed = hum.WalkSpeed + ((state.WalkSpeed - hum.WalkSpeed) * 0.5) else hum.WalkSpeed = state.WalkSpeed end
    hum.JumpPower = state.JumpPower
    if state.NoClip then for _, p in pairs(player.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
end)

local flyVel, flyGyro
state.Connections.Fly = RunService.RenderStepped:Connect(function()
    if not state.FlyMode then return end
    local hrp, hum = GetCharacter() if not hrp then return end
    if not flyVel then flyVel = Instance.new("BodyVelocity", hrp) flyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9) flyGyro = Instance.new("BodyGyro", hrp) flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9) flyGyro.P = 10000 end
    local vel = hum.MoveDirection * state.WalkSpeed
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, state.WalkSpeed, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, state.WalkSpeed, 0) end
    flyVel.Velocity = vel flyGyro.CFrame = Camera.CFrame
end)

local function ToggleFly(v) state.FlyMode = v if not v and flyVel then flyVel:Destroy() flyGyro:Destroy() flyVel, flyGyro = nil, nil end end
player.Idled:Connect(function() if state.AntiAFK then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end end)

-- ==========================================
-- 8. COMPACT CUSTOM GUI BUILDER
-- ==========================================
local Theme = { BG = Color3.fromRGB(15, 17, 22), Top = Color3.fromRGB(20, 24, 30), Side = Color3.fromRGB(12, 14, 18), Card = Color3.fromRGB(22, 26, 33), Cyan = Color3.fromRGB(0, 220, 255), Text = Color3.fromRGB(240, 240, 240), Sub = Color3.fromRGB(130, 140, 150) }
local SG = Instance.new("ScreenGui") SG.Name = "MizukageUI" SG.ResetOnSpawn = false SG.Parent = gethui and gethui() or CoreGui
state.GUI = SG

local FloatBtn = Instance.new("TextButton", SG) FloatBtn.Size = UDim2.fromOffset(45, 45) FloatBtn.Position = UDim2.new(0, 15, 0.5, -22) FloatBtn.BackgroundColor3 = Theme.BG FloatBtn.Text = "👑" FloatBtn.TextSize = 22 Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0) Instance.new("UIStroke", FloatBtn).Color = Theme.Cyan
local MainFrame = Instance.new("Frame", SG) MainFrame.Size = UDim2.fromOffset(540, 340) MainFrame.Position = UDim2.new(0.5, -270, 0.5, -170) MainFrame.BackgroundColor3 = Theme.BG MainFrame.ClipsDescendants = true MainFrame.Visible = false Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8) Instance.new("UIStroke", MainFrame).Color = Theme.Cyan

local TopBar = Instance.new("Frame", MainFrame) TopBar.Size = UDim2.new(1, 0, 0, 35) TopBar.BackgroundColor3 = Theme.Top TopBar.BorderSizePixel = 0
local Title = Instance.new("TextLabel", TopBar) Title.Size = UDim2.new(1, -20, 1, 0) Title.Position = UDim2.new(0, 15, 0, 0) Title.BackgroundTransparency = 1 Title.Text = "MIZUKAGE OFFICIAL - V13.5 FINALE" Title.TextColor3 = Theme.Cyan Title.Font = Enum.Font.GothamBold Title.TextSize = 12 Title.TextXAlignment = Enum.TextXAlignment.Left
local CloseBtn = Instance.new("TextButton", TopBar) CloseBtn.Size = UDim2.fromOffset(35, 35) CloseBtn.Position = UDim2.new(1, -35, 0, 0) CloseBtn.BackgroundTransparency = 1 CloseBtn.Text = "✖" CloseBtn.TextColor3 = Theme.Sub CloseBtn.Font = Enum.Font.GothamBold CloseBtn.TextSize = 14
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false FloatBtn.Visible = true end) FloatBtn.MouseButton1Click:Connect(function() MainFrame.Visible = true FloatBtn.Visible = false end)

local drag, dInp, dStart, sPos
TopBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true dStart = i.Position sPos = MainFrame.Position i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end) end end)
TopBar.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then dInp = i end end)
UserInputService.InputChanged:Connect(function(i) if i == dInp and drag then MainFrame.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + (i.Position.X - dStart.X), sPos.Y.Scale, sPos.Y.Offset + (i.Position.Y - dStart.Y)) end end)

local Sidebar = Instance.new("ScrollingFrame", MainFrame) Sidebar.Size = UDim2.new(0, 130, 1, -35) Sidebar.Position = UDim2.new(0, 0, 0, 35) Sidebar.BackgroundColor3 = Theme.Side Sidebar.BorderSizePixel = 0 Sidebar.ScrollBarThickness = 0 Instance.new("UIListLayout", Sidebar)
local Content = Instance.new("Frame", MainFrame) Content.Size = UDim2.new(1, -130, 1, -35) Content.Position = UDim2.new(0, 130, 0, 35) Content.BackgroundTransparency = 1

local Tabs = {}
local function CreateTab(name)
    local TBtn = Instance.new("TextButton", Sidebar) TBtn.Size = UDim2.new(1, 0, 0, 38) TBtn.BackgroundColor3 = Theme.Side TBtn.Text = " " .. name TBtn.TextColor3 = Theme.Sub TBtn.Font = Enum.Font.GothamBold TBtn.TextSize = 11 TBtn.TextXAlignment = Enum.TextXAlignment.Left
    local Ind = Instance.new("Frame", TBtn) Ind.Size = UDim2.new(0, 3, 1, 0) Ind.BackgroundColor3 = Theme.Cyan Ind.Visible = false
    local Page = Instance.new("ScrollingFrame", Content) Page.Size = UDim2.new(1, 0, 1, 0) Page.BackgroundTransparency = 1 Page.ScrollBarThickness = 3 Page.ScrollBarImageColor3 = Theme.Cyan Page.Visible = false
    local Pad = Instance.new("UIPadding", Page) Pad.PaddingTop = UDim.new(0, 12) Pad.PaddingLeft = UDim.new(0, 12) Pad.PaddingRight = UDim.new(0, 12) Pad.PaddingBottom = UDim.new(0, 12)
    local Lay = Instance.new("UIListLayout", Page) Lay.Padding = UDim.new(0, 8)
    Lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Page.CanvasSize = UDim2.new(0, 0, 0, Lay.AbsoluteContentSize.Y + 20) end)

    TBtn.MouseButton1Click:Connect(function() for _, t in pairs(Tabs) do t.P.Visible = false t.B.TextColor3 = Theme.Sub t.I.Visible = false t.B.BackgroundColor3 = Theme.Side end Page.Visible = true TBtn.TextColor3 = Theme.Text Ind.Visible = true TBtn.BackgroundColor3 = Theme.Card end)
    table.insert(Tabs, {B = TBtn, P = Page, I = Ind}) if #Tabs == 1 then Page.Visible = true TBtn.TextColor3 = Theme.Text Ind.Visible = true TBtn.BackgroundColor3 = Theme.Card end

    local Elem = {}
    function Elem:Lbl(txt) local l = Instance.new("TextLabel", Page) l.Size = UDim2.new(1, 0, 0, 20) l.BackgroundTransparency = 1 l.Text = txt l.TextColor3 = Theme.Cyan l.Font = Enum.Font.GothamBold l.TextSize = 12 l.TextXAlignment = Enum.TextXAlignment.Left end
    function Elem:Btn(txt, clr, cb) local b = Instance.new("TextButton", Page) b.Size = UDim2.new(1, 0, 0, 35) b.BackgroundColor3 = clr or Theme.Card b.Text = txt b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamSemibold b.TextSize = 12 Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) if not clr then Instance.new("UIStroke", b).Color = Theme.Cyan end b.MouseButton1Click:Connect(cb) end
    function Elem:Tog(txt, def, cb)
        local f = Instance.new("TextButton", Page) f.Size = UDim2.new(1, 0, 0, 35) f.BackgroundColor3 = Theme.Card f.Text = "" Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
        local l = Instance.new("TextLabel", f) l.Size = UDim2.new(1, -50, 1, 0) l.Position = UDim2.new(0, 12, 0, 0) l.BackgroundTransparency = 1 l.Text = txt l.TextColor3 = Theme.Text l.Font = Enum.Font.GothamSemibold l.TextSize = 11 l.TextXAlignment = Enum.TextXAlignment.Left
        local bg = Instance.new("Frame", f) bg.Size = UDim2.fromOffset(32, 18) bg.Position = UDim2.new(1, -44, 0.5, -9) bg.BackgroundColor3 = def and Theme.Cyan or Color3.fromRGB(40,40,50) Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
        local d = Instance.new("Frame", bg) d.Size = UDim2.fromOffset(14, 14) d.Position = def and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) d.BackgroundColor3 = Color3.new(1,1,1) Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        local t = def f.MouseButton1Click:Connect(function() t = not t TweenService:Create(bg, TweenInfo.new(0.2), {BackgroundColor3 = t and Theme.Cyan or Color3.fromRGB(40,40,50)}):Play() TweenService:Create(d, TweenInfo.new(0.2), {Position = t and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play() cb(t) end)
    end
    function Elem:Sld(txt, min, max, def, cb)
        local f = Instance.new("Frame", Page) f.Size = UDim2.new(1, 0, 0, 45) f.BackgroundColor3 = Theme.Card Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
        local l = Instance.new("TextLabel", f) l.Size = UDim2.new(1, -20, 0, 20) l.Position = UDim2.new(0, 12, 0, 3) l.BackgroundTransparency = 1 l.Text = txt .. ": " .. def l.TextColor3 = Theme.Text l.Font = Enum.Font.GothamSemibold l.TextSize = 11 l.TextXAlignment = Enum.TextXAlignment.Left
        local b = Instance.new("TextButton", f) b.Size = UDim2.new(1, -24, 0, 6) b.Position = UDim2.new(0, 12, 0, 28) b.BackgroundColor3 = Color3.fromRGB(40,40,50) b.Text = "" Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local fl = Instance.new("Frame", b) fl.Size = UDim2.new((def-min)/(max-min), 0, 1, 0) fl.BackgroundColor3 = Theme.Cyan Instance.new("UICorner", fl).CornerRadius = UDim.new(1, 0)
        local drag = false local function mv(i) local p = math.clamp((i.Position.X - b.AbsolutePosition.X) / b.AbsoluteSize.X, 0, 1) local v = min + ((max - min) * p) v = math.floor(v * 10) / 10 fl.Size = UDim2.new(p, 0, 1, 0) l.Text = txt .. ": " .. v cb(v) end
        b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true mv(i) end end) UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end) UserInputService.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then mv(i) end end)
    end
    function Elem:Drop(txt, vals, cb)
        local idx = 1 local v = vals[1] or "None"
        local b = Instance.new("TextButton", Page) b.Size = UDim2.new(1, 0, 0, 35) b.BackgroundColor3 = Theme.Side b.Text = " 📜 " .. txt .. ": " .. v b.TextColor3 = Theme.Cyan b.Font = Enum.Font.GothamSemibold b.TextSize = 11 b.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) Instance.new("UIStroke", b).Color = Theme.Card
        b.MouseButton1Click:Connect(function() idx = idx >= #vals and 1 or idx + 1 v = vals[idx] b.Text = " 📜 " .. txt .. ": " .. v cb(v) end)
        return {Update = function(nVals) vals = nVals idx = 1 v = vals[1] or "None" b.Text = " 📜 " .. txt .. ": " .. v cb(v) end}
    end
    function Elem:List(cb)
        local f = Instance.new("ScrollingFrame", Page) f.Size = UDim2.new(1, 0, 0, 130) f.BackgroundColor3 = Theme.Card f.ScrollBarThickness = 3 Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6) local lay = Instance.new("UIListLayout", f) lay.Padding = UDim.new(0, 5)
        return function()
            for _, c in ipairs(f:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            for _, cp in ipairs(state.CPList) do
                local b = Instance.new("TextButton", f) b.Size = UDim2.new(1, -10, 0, 30) b.BackgroundColor3 = Theme.Side b.Text = " 📍 " .. cp.Name b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamSemibold b.TextSize = 11 b.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                b.MouseButton1Click:Connect(function() TeleportTo(cp.CFrame) end)
            end f.CanvasSize = UDim2.new(0, 0, 0, #state.CPList * 35)
        end
    end
    return Elem
end

-- ==========================================
-- 9. POPULATING UI TABS
-- ==========================================
local T1 = CreateTab("TAS Engine")
T1:Lbl("Recorder")
T1:Btn("▶ Start Record", Color3.fromRGB(0, 150, 100), StartRecording) T1:Btn("⏹ Stop Record", Color3.fromRGB(200, 50, 50), StopRecording)
T1:Tog("Visual Trail Unbroken", true, function(v) state.VisualTrail = v if not v then ClearTrail() end end)
T1:Btn("🧹 Clear Visual Trail", Theme.Card, ClearTrail)

T1:Lbl("Playback Control")
local selPath = "None"
local pathDD = T1:Drop("Selected", {"None"}, function(v) selPath = v end)
getgenv().MizukageRefreshPaths = function() local vals = {"None"} for _, v in ipairs(state.PathOrder) do table.insert(vals, v) end pathDD.Update(vals) end
T1:Sld("Speed", 1, 5, 1, function(v) state.CurrentSpeed = v end)
T1:Tog("Loop Mode", false, function(v) state.IsLoopingTAS = v end) T1:Tog("Reverse Path", false, function(v) state.ReversePlayback = v end) 
T1:Btn("⚡ Play TAS", Theme.Card, function() if selPath~="None" then PlayRecording(selPath) end end) T1:Btn("⏹ Stop TAS", Theme.Card, StopPlayback)

local T2 = CreateTab("Radar CP")
T2:Tog("Auto Detect Checkpoint", false, function(v) state.AutoDetectCP = v end)
T2:Sld("TP Speed (0 = Godspeed Blink)", 0, 5, 0, function(v) state.TweenSpeed = v end)
T2:Lbl("Auto Teleport Engine")
T2:Tog("Loop Auto TP", false, function(v) state.IsLoopingTP = v end)
T2:Btn("🚀 START AUTO TP LIST", Color3.fromRGB(0, 150, 100), RunAutoTPList)
T2:Btn("⏹ STOP AUTO TP", Color3.fromRGB(200, 50, 50), StopAutoTPList)
T2:Btn("➕ Save Current Location", Theme.Card, function() local hrp = GetCharacter() if hrp then SaveLocation("Manual " .. (#state.CPList+1), hrp.CFrame) end end)
T2:Lbl("Locations")
getgenv().MizukageRefreshCP = T2:List()
T2:Btn("🗑️ Clear Locations", Theme.Card, function() state.CPList = {} getgenv().MizukageRefreshCP() end)

local T3 = CreateTab("Cloud Data")
T3:Lbl("Webhook Synchronizer (Database Format)")
T3:Btn("📤 Export Script To Webhook", Color3.fromRGB(80, 100, 220), SendBackupData)
T3:Lbl("System Integrity")
T3:Btn("Discord Form Data Builder: READY", Theme.Card, function() end)

local T4 = CreateTab("Movement")
T4:Sld("WalkSpeed", 16, 200, 16, function(v) state.WalkSpeed = v end)
T4:Sld("JumpPower", 50, 200, 50, function(v) state.JumpPower = v end)
T4:Tog("Infinite Jump", false, function(v) state.InfiniteJump = v if v then state.Connections.Jump = UserInputService.JumpRequest:Connect(function() local _, hum = GetCharacter() if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end) else if state.Connections.Jump then state.Connections.Jump:Disconnect() state.Connections.Jump=nil end end end)
T4:Tog("Fly Mode", false, ToggleFly) T4:Tog("NoClip", false, function(v) state.NoClip = v end)

local T5 = CreateTab("Utilities")
T5:Tog("Anti AFK", true, function(v) state.AntiAFK = v end)
T5:Btn("Server Hop", Theme.Card, function() local p = TeleportService:GetPlayerCountPages(game.PlaceId) local s = {} for _, v in ipairs(p:GetCurrentPage()) do if v.id ~= game.JobId and v.playing < v.maxPlayers then table.insert(s, v.id) end end if #s>0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, s[math.random(1,#s)], player) end end)
T5:Btn("Rejoin", Theme.Card, function() TeleportService:Teleport(game.PlaceId) end)
T5:Btn("Infinite Yield", Theme.Card, function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)
T5:Btn("🧨 Shutdown Script", Color3.fromRGB(200, 50, 50), function() getgenv().MizukageSystem.DisconnectAll() local _, hum = GetCharacter() if hum then hum.WalkSpeed=16 hum.JumpPower=50 hum.AutoRotate=true end end)

Notify("Ready", "Mizukage Godspeed System Online.")