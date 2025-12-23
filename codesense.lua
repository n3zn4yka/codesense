local Luxtl = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Luxware-UI-Library/main/Source.lua"))()

local Luxt = Luxtl.CreateWindow("CodeSense", 6105620301)

local mainTab = Luxt:Tab("Auto-Farm", 6087485864)
local combatTab = Luxt:Tab("Combat")
local visualTab = Luxt:Tab("Visuals")
local settingsTab = Luxt:Tab("Settings")

-- Variables
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPEnabled = false
local AimBotEnabled = false
local HitBoxExpanderEnabled = false
local AimBotFOV = 100
local AimBotSmoothness = 10
local HitBoxSize = 0
local HitBoxPart = "Head"

local TargetPlayers = {}
local ESPInstances = {}
local Connections = {}

-- Utility Functions
local function AddPlayer(player)
    if player ~= LocalPlayer and not TargetPlayers[player] then
        TargetPlayers[player] = {
            Player = player,
            Character = nil,
            Humanoid = nil,
            Head = nil,
            Torso = nil
        }
        
        -- Monitor player character
        local function CharacterAdded(character)
            TargetPlayers[player].Character = character
            TargetPlayers[player].Humanoid = character:WaitForChild("Humanoid", 5)
            TargetPlayers[player].Head = character:WaitForChild("Head", 5)
            TargetPlayers[player].Torso = character:WaitForChild("Torso", 5) or character:WaitForChild("UpperTorso", 5)
        end
        
        if player.Character then
            CharacterAdded(player.Character)
        end
        
        local conn = player.CharacterAdded:Connect(CharacterAdded)
        table.insert(Connections, conn)
    end
end

local function RemovePlayer(player)
    if TargetPlayers[player] then
        -- Clean up ESP visuals
        if ESPInstances[player] then
            for _, obj in pairs(ESPInstances[player]) do
                if obj and obj.Parent then
                    obj:Destroy()
                end
            end
            ESPInstances[player] = nil
        end
        
        TargetPlayers[player] = nil
    end
end

local function UpdatePlayerList()
    for _, player in ipairs(Players:GetPlayers()) do
        AddPlayer(player)
    end
end

-- ESP Functions
local function CreateESP(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    
    local character = player.Character
    local head = character.Head
    
    -- Create ESP visuals
    local espFolder = Instance.new("Folder")
    espFolder.Name = player.Name .. "_ESP"
    espFolder.Parent = workspace
    
    -- 2D Box
    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 2
    box.BorderColor3 = Color3.fromRGB(255, 0, 0)
    box.Size = UDim2.new(0, 100, 0, 150)
    box.Position = UDim2.new(0, 0, 0, 0)
    box.Parent = espFolder
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 14
    nameLabel.Text = player.Name
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, -0.15, 0)
    nameLabel.Parent = box
    
    ESPInstances[player] = {box, espFolder}
    
    return espFolder
end

local function UpdateESP()
    if not ESPEnabled then return end
    
    for player, data in pairs(TargetPlayers) do
        if player and data.Character and data.Head and ESPInstances[player] then
            local headPos, onScreen = Camera:WorldToViewportPoint(data.Head.Position)
            
            if onScreen then
                local box = ESPInstances[player][1]
                local distance = (Camera.CFrame.Position - data.Head.Position).Magnitude
                local scale = 1000 / distance
                
                box.Size = UDim2.new(0, 50 * scale, 0, 75 * scale)
                box.Position = UDim2.new(0, headPos.X - box.Size.X.Offset/2, 0, headPos.Y - box.Size.Y.Offset/2)
                box.Visible = true
            else
                if ESPInstances[player] and ESPInstances[player][1] then
                    ESPInstances[player][1].Visible = false
                end
            end
        end
    end
end

-- AimBot Functions
local function GetClosestPlayerToMouse()
    local closestPlayer = nil
    local closestDistance = AimBotFOV
    
    local mousePos = game:GetService("UserInputService"):GetMouseLocation()
    
    for player, data in pairs(TargetPlayers) do
        if player and data.Character and data.Head then
            local headPos, onScreen = Camera:WorldToViewportPoint(data.Head.Position)
            
            if onScreen then
                local distance = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(headPos.X, headPos.Y)).Magnitude
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    
    return closestPlayer
end

local function AimAt(targetPosition)
    if not targetPosition then return end
    
    local currentCamera = workspace.CurrentCamera
    local smooth = math.max(1, AimBotSmoothness)
    
    local targetCFrame = CFrame.lookAt(
        currentCamera.CFrame.Position,
        targetPosition
    )
    
    currentCamera.CFrame = currentCamera.CFrame:Lerp(
        targetCFrame,
        1 / smooth
    )
end

-- HitBox Expander Functions
local function ExpandHitBoxes()
    if not HitBoxExpanderEnabled or HitBoxSize <= 0 then return end
    
    for player, data in pairs(TargetPlayers) do
        if player and data.Character then
            if HitBoxPart == "Head" and data.Head then
                local weld = data.Head:FindFirstChildWhichIsA("WeldConstraint") or data.Head:FindFirstChild("Neck")
                if weld then
                    weld.Enabled = false
                end
                
                data.Head.Size = Vector3.new(HitBoxSize, HitBoxSize, HitBoxSize)
                data.Head.Transparency = 0.5
                data.Head.Color = Color3.fromRGB(255, 0, 0)
                data.Head.CanCollide = false
            elseif HitBoxPart == "Torso" and data.Torso then
                data.Torso.Size = Vector3.new(HitBoxSize, HitBoxSize, HitBoxSize)
                data.Torso.Transparency = 0.5
                data.Torso.Color = Color3.fromRGB(255, 0, 0)
                data.Torso.CanCollide = false
            end
        end
    end
end

local function ResetHitBoxes()
    for player, data in pairs(TargetPlayers) do
        if player and data.Character then
            if data.Head then
                data.Head.Size = Vector3.new(1, 1, 1)
                data.Head.Transparency = 0
                data.Head.Color = Color3.fromRGB(255, 255, 255)
                data.Head.CanCollide = true
                
                local weld = data.Head:FindFirstChildWhichIsA("WeldConstraint") or data.Head:FindFirstChild("Neck")
                if weld then
                    weld.Enabled = true
                end
            end
            
            if data.Torso then
                data.Torso.Size = Vector3.new(2, 2, 1)
                data.Torso.Transparency = 0
                data.Torso.Color = Color3.fromRGB(255, 255, 255)
                data.Torso.CanCollide = true
            end
        end
    end
end

-- UI Setup
local espSection = visualTab:Section("ESP")
espSection:Toggle("Enable ESP", function(state)
    ESPEnabled = state
    if not state then
        for player, instances in pairs(ESPInstances) do
            for _, obj in pairs(instances) do
                if obj and obj.Parent then
                    obj:Destroy()
                end
            end
        end
        ESPInstances = {}
    else
        for player, _ in pairs(TargetPlayers) do
            CreateESP(player)
        end
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
    AimBotSmoothness = value
end)

local hitboxSection = combatTab:Section("HitBox Expander")
hitboxSection:Toggle("Enable HitBox Expander", function(state)
    HitBoxExpanderEnabled = state
    if not state then
        ResetHitBoxes()
    end
end)

hitboxSection:Slider("HitBox Size", 0, 10, function(value)
    HitBoxSize = value
    if HitBoxExpanderEnabled then
        ExpandHitBoxes()
    end
end)

hitboxSection:DropDown("HitBox Part", {"Head", "Torso"}, function(part)
    HitBoxPart = part
    if HitBoxExpanderEnabled then
        ExpandHitBoxes()
    end
end)

-- Initialize player tracking
UpdatePlayerList()

-- Player added/removed events
local playerAddedConn = Players.PlayerAdded:Connect(function(player)
    AddPlayer(player)
    if ESPEnabled then
        CreateESP(player)
    end
end)

local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
    RemovePlayer(player)
end)

-- Main game loop
local renderConn = RunService.RenderStepped:Connect(function()
    -- Update ESP
    if ESPEnabled then
        UpdateESP()
    end
    
    -- AimBot logic
    if AimBotEnabled then
        local closestPlayer = GetClosestPlayerToMouse()
        if closestPlayer and TargetPlayers[closestPlayer] then
            local targetPart = HitBoxPart == "Head" and TargetPlayers[closestPlayer].Head or TargetPlayers[closestPlayer].Torso
            if targetPart then
                AimAt(targetPart.Position)
            end
        end
    end
    
    -- Update HitBoxes
    if HitBoxExpanderEnabled then
        ExpandHitBoxes()
    end
end)

-- Cleanup function
local function Cleanup()
    renderConn:Disconnect()
    playerAddedConn:Disconnect()
    playerRemovingConn:Disconnect()
    
    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
    
    ResetHitBoxes()
    
    for player, instances in pairs(ESPInstances) do
        for _, obj in pairs(instances) do
            if obj and obj.Parent then
                obj:Destroy()
            end
        end
    end
    
    ESPInstances = {}
    TargetPlayers = {}
end

-- Game closing cleanup
game:GetService("UserInputService").WindowFocusReleased:Connect(Cleanup)
