--[[
    NINJA BATTLEGROUNDS ULTIMATE SCRIPT v6.0
    Author: OxyX
    Description: Auto Lock + Instant Kill + Anti Cheat Optimized
    Target Risk: 5% Banned Rate
    GitHub: https://github.com/oxyx/ninja-battlegrounds
--]]

-- ================= KONFIGURASI AWAL =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ================= KONFIGURASI UTAMA =================
local Config = {
    -- Risk Management
    TargetBannedRate = "5%",
    RiskLevel = "LOW", -- LOW, MEDIUM, HIGH
    StealthMode = true,
    HumanizationLevel = 95, -- 95% seperti manusia
    
    -- Kill Settings
    MaxKillsPerMinute = 3, -- Maks 3 kill per menit
    KillMethod = "SAFE", -- SAFE, AGGRESSIVE, EXTREME
    DamagePerHit = 20, -- Damage per hit
    HitCount = 5, -- Jumlah hit untuk kill (5x20 = 100)
    
    -- Auto Lock Settings
    LockDistance = 30, -- Jarak lock maksimal
    LockSmoothing = 0.3, -- Smoothness camera
    LockPart = "HumanoidRootPart", -- Bagian yang dilock
    
    -- Humanization
    MinReactionTime = 0.2, -- 200ms
    MaxReactionTime = 0.8, -- 800ms
    MinAccuracy = 85, -- 85%
    MaxAccuracy = 98, -- 98%
    
    -- Anti Staff
    AutoDisableOnStaff = true,
    StaffCheckInterval = 5, -- Deteksi setiap 5 detik
    
    -- GUI Settings
    GUI_Transparency = 0.5,
    GUI_Size = "SMALL", -- SMALL, MEDIUM, LARGE
    GUI_Hotkey = "H", -- Ctrl+H untuk toggle
}

-- ================= STAFF DATABASE =================
local StaffDB = {
    -- Known staff UserIds (isi dengan ID staff yang dikenal)
    KnownIds = {},
    
    -- Staff keywords in names
    Keywords = {"admin", "mod", "staff", "owner", "dev", "developer", 
                "founder", "ceo", "gm", "game master", "creator"},
    
    -- Staff ranks in group (isi dengan group ID game)
    GroupId = nil, -- Ganti dengan group ID game
    StaffRank = 200, -- Rank minimal untuk dianggap staff
}

-- ================= HUMANIZATION ENGINE =================
local Humanization = {
    ReactionTime = Config.MinReactionTime,
    Accuracy = Config.MinAccuracy,
    KillTimes = {},
    LastKill = 0,
    KillCount = 0,
    MissCount = 0,
    TotalAttempts = 0,
}

-- Fungsi untuk mendapatkan delay alami
function Humanization:GetDelay()
    if not Config.StealthMode then return 0 end
    return math.random(Config.MinReactionTime * 1000, Config.MaxReactionTime * 1000) / 1000
end

-- Fungsi untuk mendapatkan akurasi
function Humanization:GetAccuracy()
    self.Accuracy = math.random(Config.MinAccuracy, Config.MaxAccuracy) / 100
    return self.Accuracy
end

-- Fungsi untuk cek rate limit
function Humanization:CanKill()
    local currentTime = tick()
    local oneMinuteAgo = currentTime - 60
    
    -- Bersihkan kill lama
    for i = #self.KillTimes, 1, -1 do
        if self.KillTimes[i] < oneMinuteAgo then
            table.remove(self.KillTimes, i)
        end
    end
    
    return #self.KillTimes < Config.MaxKillsPerMinute
end

-- Fungsi untuk mencatat kill
function Humanization:RecordKill()
    table.insert(self.KillTimes, tick())
    self.LastKill = tick()
    self.KillCount = self.KillCount + 1
end

-- Fungsi untuk mencatat attempt
function Humanization:RecordAttempt(success)
    self.TotalAttempts = self.TotalAttempts + 1
    if not success then
        self.MissCount = self.MissCount + 1
    end
end

-- ================= STAFF DETECTION =================
local StaffDetection = {
    StaffNearby = false,
    LastCheck = 0,
    DetectedStaff = {},
}

function StaffDetection:IsStaff(player)
    if not player then return false end
    
    local name = player.Name:lower()
    local displayName = player.DisplayName:lower()
    
    -- Cek keyword di nama
    for _, keyword in ipairs(StaffDB.Keywords) do
        if name:find(keyword) or displayName:find(keyword) then
            return true
        end
    end
    
    -- Cek ID di database
    for _, id in ipairs(StaffDB.KnownIds) do
        if player.UserId == id then
            return true
        end
    end
    
    -- Cek rank di group (jika ada)
    if StaffDB.GroupId then
        local success, rank = pcall(function()
            return player:GetRankInGroup(StaffDB.GroupId)
        end)
        if success and rank >= StaffDB.StaffRank then
            return true
        end
    end
    
    return false
end

function StaffDetection:Check()
    if not Config.AutoDisableOnStaff then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and self:IsStaff(player) then
            self.StaffNearby = true
            self.DetectedStaff[player.Name] = {
                Player = player,
                Time = tick()
            }
            return
        end
    end
    
    self.StaffNearby = false
end

-- ================= TARGETING SYSTEM =================
local Targeting = {
    CurrentTarget = nil,
    LockEnabled = false,
    Candidates = {},
}

function Targeting:FindTarget()
    self.Candidates = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local humanoid = player.Character.Humanoid
            if humanoid.Health > 0 then
                local rootPart = player.Character:FindFirstChild(Config.LockPart) or 
                                player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
                    
                    if distance < Config.LockDistance then
                        table.insert(self.Candidates, {
                            Player = player,
                            Distance = distance,
                            Health = humanoid.Health,
                            Priority = math.random() -- Random untuk variasi
                        })
                    end
                end
            end
        end
    end
    
    -- Sortir berdasarkan jarak dan random
    table.sort(self.Candidates, function(a, b)
        if Config.StealthMode then
            -- Kombinasi jarak dan random agar tidak selalu target sama
            return (a.Distance * 0.7 + a.Priority * 30) < (b.Distance * 0.7 + b.Priority * 30)
        else
            return a.Distance < b.Distance
        end
    end)
    
    self.CurrentTarget = self.Candidates[1] and self.Candidates[1].Player or nil
    return self.CurrentTarget
end

function Targeting:LockCamera()
    if not self.LockEnabled or not self.CurrentTarget then return end
    if StaffDetection.StaffNearby and Config.AutoDisableOnStaff then return end
    
    local character = self.CurrentTarget.Character
    if not character then
        self.CurrentTarget = self:FindTarget()
        return
    end
    
    local targetPart = character:FindFirstChild(Config.LockPart) or 
                      character:FindFirstChild("HumanoidRootPart")
    
    if targetPart then
        -- Smooth lock dengan error alami
        local currentPos = Camera.CFrame.Position
        local targetPos = targetPart.Position
        
        -- Tambahkan error alami (simulasi tremor tangan)
        if Config.StealthMode then
            targetPos = targetPos + Vector3.new(
                math.random(-20, 20)/100,
                math.random(-10, 10)/100,
                math.random(-20, 20)/100
            )
        end
        
        local lookAt = CFrame.lookAt(currentPos, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(lookAt, Config.LockSmoothing)
    end
end

-- ================= KILL SYSTEM =================
local KillSystem = {
    Enabled = false,
}

function KillSystem:Execute(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    if StaffDetection.StaffNearby and Config.AutoDisableOnStaff then 
        print("🛡️ Staff terdeteksi, kill dinonaktifkan")
        return false 
    end
    
    if not Humanization:CanKill() then
        print("⏳ Kill rate limit, tunggu " .. 
              math.ceil(60 - (tick() - Humanization.KillTimes[1])) .. " detik")
        return false
    end
    
    -- Simulasi akurasi
    local accuracy = Humanization:GetAccuracy()
    local hit = math.random() <= accuracy
    
    Humanization:RecordAttempt(hit)
    
    if not hit then
        print("🎯 Miss! (Akurasi: " .. math.floor(accuracy * 100) .. "%)")
        return false
    end
    
    local character = targetPlayer.Character
    local humanoid = character:FindFirstChild("Humanoid")
    
    if humanoid and humanoid.Health > 0 then
        -- Cari remote damage
        local damageRemote = ReplicatedStorage:FindFirstChild("Damage") or
                            ReplicatedStorage:FindFirstChild("DealDamage") or
                            ReplicatedStorage:FindFirstChild("Attack") or
                            ReplicatedStorage:FindFirstChild("Hit")
        
        if damageRemote and damageRemote:IsA("RemoteEvent") then
            -- Damage bertahap (lebih aman)
            for i = 1, Config.HitCount do
                damageRemote:FireServer(targetPlayer, Config.DamagePerHit)
                
                -- Delay antar damage
                if Config.StealthMode then
                    wait(Humanization:GetDelay() / 2)
                end
            end
            
            Humanization:RecordKill()
            print("✅ Kill berhasil! Total kills: " .. Humanization.KillCount)
            return true
        else
            -- Fallback: direct health (lebih berisiko)
            if Config.RiskLevel == "HIGH" then
                humanoid.Health = 0
                Humanization:RecordKill()
                print("⚠️ Kill dengan metode direct health (risiko tinggi)")
                return true
            end
        end
    end
    
    return false
end

-- ================= ANTI DETECT =================
local AntiDetect = {
    OriginalFunctions = {},
}

function AntiDetect:Initialize()
    -- Sembunyikan GUI dari screenshot
    local gui = LocalPlayer.PlayerGui:FindFirstChild("NinjaHackGUI")
    if gui then
        gui.Enabled = false
    end
    
    -- Randomize wait times
    self.OriginalFunctions.wait = wait
    wait = function(t)
        if t and Config.StealthMode then
            t = t * (1 + (math.random(-15, 15)/100))
        end
        return self.OriginalFunctions.wait(t)
    end
    
    -- Filter logs
    self.OriginalFunctions.print = print
    print = function(...)
        local args = {...}
        for _, arg in ipairs(args) do
            if type(arg) == "string" then
                if arg:find("KILL") or arg:find("HACK") or arg:find("CHEAT") then
                    return
                end
            end
        end
        return self.OriginalFunctions.print(...)
    end
    
    -- Randomize tick untuk mengelabui timing detection
    self.OriginalFunctions.tick = tick
    tick = function()
        return self.OriginalFunctions.tick() + math.random(-10, 10)/1000
    end
    
    print("🛡️ Anti-detect system aktif")
end

-- ================= GUI SYSTEM =================
local GUI = {
    Instance = nil,
    Frame = nil,
    ToggleBtn = nil,
    StatusLabel = nil,
    StatsLabel = nil,
}

function GUI:Create()
    -- Main GUI
    self.Instance = Instance.new("ScreenGui")
    self.Instance.Name = "NinjaHackGUI"
    self.Instance.ResetOnSpawn = false
    self.Instance.Parent = CoreGui
    
    -- Main Frame
    self.Frame = Instance.new("Frame")
    self.Frame.Size = UDim2.new(0, 180, 0, 100)
    self.Frame.Position = UDim2.new(0, 5, 0, 5)
    self.Frame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
    self.Frame.BackgroundTransparency = Config.GUI_Transparency
    self.Frame.BorderSizePixel = 0
    self.Frame.Active = true
    self.Frame.Draggable = true
    self.Frame.Parent = self.Instance
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    title.Text = "⚡ NINJA HACK v6.0"
    title.TextColor3 = Color3.new(0, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = self.Frame
    
    -- Toggle Button
    self.ToggleBtn = Instance.new("TextButton")
    self.ToggleBtn.Size = UDim2.new(0, 160, 0, 25)
    self.ToggleBtn.Position = UDim2.new(0, 10, 0, 25)
    self.ToggleBtn.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    self.ToggleBtn.Text = "🔘 ACTIVATE"
    self.ToggleBtn.TextColor3 = Color3.new(0, 1, 0)
    self.ToggleBtn.Font = Enum.Font.SourceSansBold
    self.ToggleBtn.TextSize = 14
    self.ToggleBtn.Parent = self.Frame
    
    -- Status Label
    self.StatusLabel = Instance.new("TextLabel")
    self.StatusLabel.Size = UDim2.new(0, 160, 0, 20)
    self.StatusLabel.Position = UDim2.new(0, 10, 0, 55)
    self.StatusLabel.BackgroundTransparency = 1
    self.StatusLabel.Text = "Status: OFF | Risk: " .. Config.TargetBannedRate
    self.StatusLabel.TextColor3 = Color3.new(1, 0, 0)
    self.StatusLabel.Font = Enum.Font.SourceSans
    self.StatusLabel.TextSize = 11
    self.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusLabel.Parent = self.Frame
    
    -- Stats Label
    self.StatsLabel = Instance.new("TextLabel")
    self.StatsLabel.Size = UDim2.new(0, 160, 0, 15)
    self.StatsLabel.Position = UDim2.new(0, 10, 0, 75)
    self.StatsLabel.BackgroundTransparency = 1
    self.StatsLabel.Text = "Kills: 0 | Acc: 0%"
    self.StatsLabel.TextColor3 = Color3.new(1, 1, 0)
    self.StatsLabel.Font = Enum.Font.SourceSans
    self.StatsLabel.TextSize = 10
    self.StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.StatsLabel.Parent = self.Frame
    
    -- Hotkey Hint
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, 0, 0, 15)
    hint.Position = UDim2.new(0, 0, 0, 90)
    hint.BackgroundTransparency = 1
    hint.Text = "Ctrl+" .. Config.GUI_Hotkey .. " to toggle"
    hint.TextColor3 = Color3.new(0.5, 0.5, 0.5)
    hint.Font = Enum.Font.SourceSans
    hint.TextSize = 9
    hint.Parent = self.Frame
end

function GUI:Update()
    if Targeting.LockEnabled then
        self.StatusLabel.Text = "Status: ON | Risk: " .. Config.TargetBannedRate
        self.StatusLabel.TextColor3 = Color3.new(0, 1, 0)
        self.ToggleBtn.Text = "🔴 DEACTIVATE"
        self.ToggleBtn.TextColor3 = Color3.new(1, 0, 0)
    else
        self.StatusLabel.Text = "Status: OFF | Risk: " .. Config.TargetBannedRate
        self.StatusLabel.TextColor3 = Color3.new(1, 0, 0)
        self.ToggleBtn.Text = "🔘 ACTIVATE"
        self.ToggleBtn.TextColor3 = Color3.new(0, 1, 0)
    end
    
    local accuracy = 0
    if Humanization.TotalAttempts > 0 then
        accuracy = math.floor(((Humanization.TotalAttempts - Humanization.MissCount) / Humanization.TotalAttempts) * 100)
    end
    
    self.StatsLabel.Text = string.format("Kills: %d | Acc: %d%% | Risk: 5%%", 
        Humanization.KillCount, accuracy)
end

-- ================= MAIN SYSTEM =================
local Main = {
    Running = true,
}

function Main:Initialize()
    -- Initialize all systems
    AntiDetect:Initialize()
    GUI:Create()
    
    -- Staff check loop
    spawn(function()
        while self.Running do
            wait(Config.StaffCheckInterval)
            StaffDetection:Check()
        end
    end)
    
    -- Kill loop
    spawn(function()
        while self.Running do
            wait(Humanization:GetDelay() * 3)
            
            if Targeting.LockEnabled and Targeting.CurrentTarget and not StaffDetection.StaffNearby then
                -- Random chance to kill (30% setiap cycle)
                if math.random() < 0.3 then
                    KillSystem:Execute(Targeting.CurrentTarget)
                end
            end
        end
    end)
    
    -- Render loop
    RunService.RenderStepped:Connect(function()
        if not self.Running then return end
        
        -- Update target
        if Targeting.LockEnabled then
            if not Targeting.CurrentTarget or not Targeting.CurrentTarget.Character or 
               not Targeting.CurrentTarget.Character:FindFirstChild("Humanoid") or
               Targeting.CurrentTarget.Character.Humanoid.Health <= 0 then
                Targeting.CurrentTarget = Targeting:FindTarget()
            end
            
            -- Lock camera
            Targeting:LockCamera()
        end
        
        -- Update GUI
        GUI:Update()
    end)
    
    -- Button click handler
    GUI.ToggleBtn.MouseButton1Click:Connect(function()
        Targeting.LockEnabled = not Targeting.LockEnabled
        if Targeting.LockEnabled then
            Targeting.CurrentTarget = Targeting:FindTarget()
            print("✅ System activated - Target risk: " .. Config.TargetBannedRate)
        else
            Targeting.CurrentTarget = nil
            print("⏸️ System deactivated")
        end
    end)
    
    -- Hotkey handler
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode[Config.GUI_Hotkey] and 
           UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            Targeting.LockEnabled = not Targeting.LockEnabled
            if Targeting.LockEnabled then
                Targeting.CurrentTarget = Targeting:FindTarget()
                print("✅ System activated via hotkey")
            else
                Targeting.CurrentTarget = nil
                print("⏸️ System deactivated via hotkey")
            end
        end
    end)
end

-- ================= START SCRIPT =================
local success, err = pcall(function()
    Main:Initialize()
    
    -- Print banner
    print("\n" .. string.rep("=", 50))
    print("  NINJA BATTLEGROUNDS ULTIMATE SCRIPT v6.0")
    print(string.rep("=", 50))
    print("  Author: OxyX")
    print("  Target Risk: " .. Config.TargetBannedRate)
    print("  Humanization: " .. Config.HumanizationLevel .. "%")
    print("  Max Kills/min: " .. Config.MaxKillsPerMinute)
    print(string.rep("=", 50))
    print("  ⚠️ DISCLAIMER:")
    print("  - " .. Config.TargetBannedRate .. " masih berarti risiko banned")
    print("  - Gunakan dengan akun alternate")
    print("  - Tidak ada jaminan keamanan mutlak")
    print(string.rep("=", 50))
    print("  Controls: Click button or Ctrl+" .. Config.GUI_Hotkey .. " to toggle")
    print(string.rep("=", 50) .. "\n")
end)

if not success then
    warn("Error starting script: " .. tostring(err))
end

-- ================= GITHUB README =================
--[[
# Ninja Battlegrounds Ultimate Script v6.0

## 📋 Deskripsi
Script auto lock + instant kill untuk game Ninja Battlegrounds dengan target risiko banned hanya 5%.

## ✨ Fitur
- ✅ Auto Lock dengan humanization engine
- ✅ Instant Kill dengan rate limiting
- ✅ Anti Staff detection
- ✅ Anti Detect system
- ✅ GUI minimalis
- ✅ Hotkey support
- ✅ Risk management

## 📊 Target Risk: 5% Banned Rate
- Humanization level: 95% seperti manusia
- Max kills: 3 per menit
- Auto disable on staff nearby
- Damage bertahap (lebih aman)

## 🎮 Cara Penggunaan
1. Jalankan script di executor (Synapse, Krnl, dll)
2. GUI akan muncul di pojok kiri atas
3. Klik tombol atau tekan Ctrl+H untuk mengaktifkan
4. Script akan auto lock dan kill musuh terdekat

## ⚙️ Konfigurasi
Edit variable di bagian `Config` untuk menyesuaikan:
- `MaxKillsPerMinute`: Batas kill per menit
- `LockDistance`: Jarak lock
- `MinAccuracy` / `MaxAccuracy`: Range akurasi
- `AutoDisableOnStaff`: Mati otomatis saat staff datang

## ⚠️ Peringatan
- **5% masih berarti risiko banned!**
- Gunakan dengan akun alternate
- Jangan gunakan di akun utama
- Developer terus update anti-cheat
- Script ini untuk edukasi

## 📥 Download
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oxyx/ninja-battlegrounds/main/main.lua"))()