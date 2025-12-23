local Luxtl = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Luxware-UI-Library/main/Source.lua"))()

-- Check if GUI already exists and destroy it
if _G.CodeSenseGUI then
    _G.CodeSenseGUI:Destroy()
    _G.CodeSenseGUI = nil
end

if _G.CodeSenseConnections then
    for _, conn in pairs(_G.CodeSenseConnections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    _G.CodeSenseConnections = nil
end

-- Clear existing instances
if _G.CodeSenseESP then
    for player, instances in pairs(_G.CodeSenseESP) do
        for _, obj in pairs(instances) do
            pcall(function() obj:Destroy() end)
        end
    end
    _G.CodeSenseESP = nil
end

-- Create new GUI
_G.CodeSenseGUI = Luxtl.CreateWindow("CodeSense", 6105620301)

local combatTab = _G.CodeSenseGUI:Tab("Combat", 6087485864)
local visualTab = _G.CodeSenseGUI:Tab("Visuals")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Global tables
_G.CodeSenseESP = {}
_G.CodeSenseConnections = {}
_G.CodeSenseTargets = {}

-- States
local ESPEnabled = false
local AimBotEnabled = false
local HitBoxEnabled = false
local AimBotFOV = 100
local AimBotSmoothness = 10
local HitBoxSize = 2
local HitBoxPart = "Head"

-- Utility functions
local function WorldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function GetClosestToMouse()
    if not AimBotEnabled then return nil end
    
    local mousePos = UserInputService:GetMouseLocation()
    local closest = nil
    local closestDist = AimBotFOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local head = player.Character:FindFirstChild("Head")
            
            if humanoid and humanoid.Health > 0 and head then
                local screenPos, onScreen = WorldToScreen(head.Position)
                if onScreen then
                    local dist = (mousePos - screenPos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = player
                    end
                end
            end
        end
    end
    
    return closest
end

-- ESP functions
local function CreateESP(player)
    if not player or player == LocalPlayer or not player.Character then return end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = player.Name .. "_ESP"
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui
    
    -- Box
    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 2
    box.BorderColor3 = Color3.fromRGB(255, 0, 0)
    box.Size = UDim2.new(0, 100, 0, 150)
    box.Parent = gui
    
    -- Name
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.BackgroundTransparency = 1
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextSize = 14
    name.Text = player.Name
    name.Size = UDim2.new(0, 100, 0, 20)
    name.Parent = gui
    
    -- Distance
    local distance = Instance.new("TextLabel")
    distance.Name = "Distance"
    distance.BackgroundTransparency = 1
    distance.TextColor3 = Color3.fromRGB(0, 255, 255)
    distance.TextSize = 12
    distance.Size = UDim2.new(0, 100, 0, 20)
    distance.Parent = gui
    
    _G.CodeSenseESP[player] = {gui = gui, box = box, name = name, distance = distance}
end

local function UpdateESP()
    if not ESPEnabled then return end
    
    for player, esp in pairs(_G.CodeSenseESP) do
        if player and player.Character and player.Character:FindFirstChild("Humanoid") then
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character.Humanoid
            
            if head and humanoid.Health > 0 then
                local screenPos, onScreen = WorldToScreen(head.Position + Vector3.new(0, 3, 0))
                
                if onScreen then
                    -- Update box
                    local distance = (Camera.CFrame.Position - head.Position).Magnitude
                    local scale = 2000 / distance
                    
                    esp.box.Size = UDim2.new(0, 50 * scale, 0, 80 * scale)
                    esp.box.Position = UDim2.new(0, screenPos.X - esp.box.Size.X.Offset / 2, 0, screenPos.Y - esp.box.Size.Y.Offset)
                    esp.box.Visible = true
                    
                    -- Update name
                    esp.name.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - esp.box.Size.Y.Offset - 20)
                    esp.name.Visible = true
                    
                    -- Update distance
                    esp.distance.Text = math.floor(distance) .. " studs"
                    esp.distance.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y + esp.box.Size.Y.Offset)
                    esp.distance.Visible = true
                else
                    esp.box.Visible = false
                    esp.name.Visible = false
                    esp.distance.Visible = false
                end
            else
                esp.box.Visible = false
                esp.name.Visible = false
                esp.distance.Visible = false
            end
        else
            esp.box.Visible = false
            esp.name.Visible = false
            esp.distance.Visible = false
        end
    end
end

local function RemoveESP(player)
    if _G.CodeSenseESP[player] then
        pcall(function()
            _G.CodeSenseESP[player].gui:Destroy()
        end)
        _G.CodeSenseESP[player] = nil
    end
end

-- AimBot functions
local function AimAt(target)
    if not target or not target.Character then return end
    
    local targetPart = HitBoxPart == "Head" and target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("UpperTorso") or target.Character:FindFirstChild("Torso")
    if not targetPart then return end
    
    local targetPos = targetPart.Position
    local currentCF = Camera.CFrame
    local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
    
    local smooth = math.max(1, AimBotSmoothness)
    Camera.CFrame = currentCF:Lerp(targetCF, 1 / smooth)
end

-- HitBox functions
local function ExpandHitBoxes()
    if not HitBoxEnabled or HitBoxSize <= 0 then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local target = HitBoxPart == "Head" and player.Character:FindFirstChild("Head") or 
                          player.Character:FindFirstChild("UpperTorso") or 
                          player.Character:FindFirstChild("Torso")
            
            if target then
                local originalSize = _G.CodeSenseTargets[player] or target.Size
                _G.CodeSenseTargets[player] = originalSize
                
                target.Size = Vector3.new(HitBoxSize, HitBoxSize, HitBoxSize)
                target.Transparency = 0.5
                target.Color = Color3.fromRGB(255, 0, 0)
                target.CanCollide = false
            end
        end
    end
end

local function ResetHitBoxes()
    for player, originalSize in pairs(_G.CodeSenseTargets) do
        if player and player.Character then
            local target = HitBoxPart == "Head" and player.Character:FindFirstChild("Head") or 
                          player.Character:FindFirstChild("UpperTorso") or 
                          player.Character:FindFirstChild("Torso")
            
            if target then
                target.Size = originalSize
                target.Transparency = 0
                target.Color = Color3.fromRGB(255, 255, 255)
                target.CanCollide = true
            end
        end
    end
    _G.CodeSenseTargets = {}
end

-- UI Setup
local espSection = visualTab:Section("ESP")
espSection:Toggle("Enable ESP", function(state)
    ESPEnabled = state
    
    if state then
        -- Create ESP for all players
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
        
        -- Player added event
        table.insert(_G.CodeSenseConnections, Players.PlayerAdded:Connect(function(player)
            CreateESP(player)
        end))
        
        -- Player removed event
        table.insert(_G.CodeSenseConnections, Players.PlayerRemoving:Connect(function(player)
            RemoveESP(player)
        end))
        
        -- Character added event
        for _, player in pairs(Players:GetPlayers()) do
            table.insert(_G.CodeSenseConnections, player.CharacterAdded:Connect(function()
                if ESPEnabled then
                    CreateESP(player)
                end
            end))
        end
    else
        -- Remove all ESP
        for player, _ in pairs(_G.CodeSenseESP) do
            RemoveESP(player)
        end
        _G.CodeSenseESP = {}
    end
end)

local aimbotSection = combatTab:Section("AimBot")
aimbotSection:Toggle("Enable AimBot", function(state)
    AimBotEnabled = state
end)

aimbotSection:Slider("FOV", 10, 500, function(value)
    AimBotFOV = value
end)

aimbotSection:Slider("Smoothness", 1, 50, function(value)
    AimBotSmoothness = math.max(1, value)
end)

aimbotSection:KeyBind("Aim Key", Enum.KeyCode.LeftAlt, function()
    -- Key bind for toggle aim
end)

local hitboxSection = combatTab:Section("HitBox Expander")
hitboxSection:Toggle("Enable HitBox", function(state)
    HitBoxEnabled = state
    if not state then
        ResetHitBoxes()
    end
end)

hitboxSection:Slider("Size", 1, 10, function(value)
    HitBoxSize = value
    if HitBoxEnabled then
        ExpandHitBoxes()
    end
end)

hitboxSection:DropDown("Part", {"Head", "Torso"}, function(selected)
    HitBoxPart = selected
    if HitBoxEnabled then
        ExpandHitBoxes()
    end
end)

-- Main loop
table.insert(_G.CodeSenseConnections, RunService.RenderStepped:Connect(function()
    -- ESP Update
    if ESPEnabled then
        UpdateESP()
    end
    
    -- AimBot
    if AimBotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosestToMouse()
        if target then
            AimAt(target)
        end
    end
    
    -- HitBox
    if HitBoxEnabled then
        ExpandHitBoxes()
    end
end))

-- Auto-cleanup when player leaves
table.insert(_G.CodeSenseConnections, Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        for _, conn in pairs(_G.CodeSenseConnections) do
            pcall(function() conn:Disconnect() end)
        end
        
        for player, esp in pairs(_G.CodeSenseESP) do
            pcall(function() esp.gui:Destroy() end)
        end
        
        ResetHitBoxes()
        
        _G.CodeSenseConnections = nil
        _G.CodeSenseESP = nil
        _G.CodeSenseTargets = nil
        _G.CodeSenseGUI = nil
    else
        RemoveESP(player)
        if _G.CodeSenseTargets[player] then
            _G.CodeSenseTargets[player] = nil
        end
    end
end))

-- Initial ESP creation
if ESPEnabled then
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end
end

warn("CodeSense GUI Loaded Successfully!")
