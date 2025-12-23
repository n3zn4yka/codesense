--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
getgenv().Silent = {
    Setting = {
        IsTargetting = true,
        Prediction = 0.12,
        TargetPart = "HumanoidRootPart",
        WallCheck = true,
        MinHPForTargetting = 2,
        Keybind = Enum.KeyCode.C,
        HighlightColor = Color3.fromRGB(255, 0, 0),
        FOV = {
            Radius = 200,
            Visible = true,
            NumSides = 60,
            Filled = false,
            Thickness = 1,
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 0.7
        }
    }
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Variables
local CurrentTarget = nil
local FOVCircle = nil
local HighlightInstance = nil

-- Create FOV Circle
local function CreateFOV()
    if FOVCircle then
        FOVCircle:Destroy()
    end
    
    local Drawing = Drawing
    if not Drawing then
        return
    end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = Silent.Setting.FOV.Visible
    FOVCircle.Radius = Silent.Setting.FOV.Radius
    FOVCircle.Color = Silent.Setting.FOV.Color
    FOVCircle.Thickness = Silent.Setting.FOV.Thickness
    FOVCircle.Transparency = Silent.Setting.FOV.Transparency
    FOVCircle.Filled = Silent.Setting.FOV.Filled
    FOVCircle.NumSides = Silent.Setting.FOV.NumSides
end

-- Update FOV position
local function UpdateFOV()
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end

-- Create Highlight
local function CreateHighlight(character)
    if HighlightInstance then
        HighlightInstance:Destroy()
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "SilentAimHighlight"
    highlight.FillColor = Silent.Setting.HighlightColor
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Silent.Setting.HighlightColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character
    highlight.Adornee = character
    
    HighlightInstance = highlight
end

-- Get closest player to mouse
local function GetClosestPlayer()
    if not Silent.Setting.IsTargetting then return nil end
    
    local closest = nil
    local closestDistance = Silent.Setting.FOV.Radius
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local targetPart = player.Character:FindFirstChild(Silent.Setting.TargetPart)
            
            if humanoid and humanoid.Health > Silent.Setting.MinHPForTargetting and targetPart then
                -- Wall Check
                if Silent.Setting.WallCheck then
                    local origin = Camera.CFrame.Position
                    local target = targetPart.Position
                    local direction = (target - origin).Unit
                    local ray = Ray.new(origin, direction * 1000)
                    local part, position = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
                    
                    if part and part:IsDescendantOf(player.Character) then
                        -- No wall, continue
                    else
                        continue
                    end
                end
                
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closest = player
                    end
                end
            end
        end
    end
    
    return closest
end

-- Hook to mouse
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index

setreadonly(mt, false)

-- Namecall hook for silent aim
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "FindPartOnRayWithIgnoreList" and Silent.Setting.IsTargetting and CurrentTarget then
        if CurrentTarget.Character then
            local targetPart = CurrentTarget.Character:FindFirstChild(Silent.Setting.TargetPart)
            if targetPart then
                -- Calculate prediction
                local velocity = targetPart.Velocity
                local predictedPosition = targetPart.Position + (velocity * Silent.Setting.Prediction)
                
                -- Create new ray with prediction
                local origin = args[1].Origin
                local direction = (predictedPosition - origin).Unit
                local newRay = Ray.new(origin, direction * 1000)
                
                args[1] = newRay
                return oldNamecall(self, unpack(args))
            end
        end
    end
    
    return oldNamecall(self, ...)
end)

-- Index hook for mouse target
mt.__index = newcclosure(function(self, key)
    if key == "Target" and Silent.Setting.IsTargetting and CurrentTarget then
        if CurrentTarget.Character then
            local targetPart = CurrentTarget.Character:FindFirstChild(Silent.Setting.TargetPart)
            if targetPart then
                -- Calculate prediction
                local velocity = targetPart.Velocity
                local predictedPosition = targetPart.Position + (velocity * Silent.Setting.Prediction)
                
                return predictedPosition
            end
        end
    end
    
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- Main update loop
local connection = RunService.RenderStepped:Connect(function()
    -- Update FOV
    if FOVCircle then
        UpdateFOV()
        FOVCircle.Visible = Silent.Setting.FOV.Visible
        FOVCircle.Radius = Silent.Setting.FOV.Radius
    end
    
    -- Get new target
    local newTarget = GetClosestPlayer()
    
    -- Update highlight
    if newTarget ~= CurrentTarget then
        if HighlightInstance then
            HighlightInstance:Destroy()
            HighlightInstance = nil
        end
        
        if newTarget and newTarget.Character then
            CreateHighlight(newTarget.Character)
        end
        
        CurrentTarget = newTarget
    end
    
    -- Check if target is still valid
    if CurrentTarget and (not CurrentTarget.Character or not CurrentTarget.Character:FindFirstChild("Humanoid") or CurrentTarget.Character.Humanoid.Health <= Silent.Setting.MinHPForTargetting) then
        if HighlightInstance then
            HighlightInstance:Destroy()
            HighlightInstance = nil
        end
        CurrentTarget = nil
    end
end)

-- Keybind toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Silent.Setting.Keybind then
        Silent.Setting.IsTargetting = not Silent.Setting.IsTargetting
        
        if not Silent.Setting.IsTargetting then
            if HighlightInstance then
                HighlightInstance:Destroy()
                HighlightInstance = nil
            end
            CurrentTarget = nil
        end
    end
end)

-- Initialize
CreateFOV()

-- Cleanup
local function Cleanup()
    connection:Disconnect()
    if FOVCircle then
        FOVCircle:Remove()
    end
    if HighlightInstance then
        HighlightInstance:Destroy()
    end
end

-- Auto cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        Cleanup()
    elseif player == CurrentTarget then
        if HighlightInstance then
            HighlightInstance:Destroy()
            HighlightInstance = nil
        end
        CurrentTarget = nil
    end
end)

warn("Silent Aim Loaded!")
