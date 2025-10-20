-- Client-sided Project Loader + Freecam/Fly/Slide
-- Safe for Roblox Studio / single-player testing / your own games only.
-- Simple GUI with buttons to load local modules like Freecam/Fly.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- PROJECT REGISTRY ------------------------------------------------------
-- Each project here can be toggled via button.
-- Add new ones easily: {Name="Your Project", Load=function() ... end}
--------------------------------------------------------------------------
local projects = {}

-- FREECAM/FLY MODULE ----------------------------------------------------
projects[1] = {
    Name = "Freecam / Fly / Slide",
    Description = "Client-sided movement tools for testing.",
    Load = function()
        if PlayerGui:FindFirstChild("ClientAdminHints") then return end

        local scriptClone = Instance.new("LocalScript")
        scriptClone.Name = "Client_FreecamFlySlide"
        scriptClone.Source = [[
        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local RunService = game:GetService("RunService")
        local StarterGui = game:GetService("StarterGui")
        local player = Players.LocalPlayer
        local camera = workspace.CurrentCamera

        local config = {
            toggleFreecamKey = Enum.KeyCode.RightControl,
            toggleFlyKey = Enum.KeyCode.F,
            slideKey = Enum.KeyCode.LeftControl,
            freecamSpeed = 100,
            flySpeed = 50,
            slideSpeed = 60,
            mouseSensitivity = 0.2,
            smoothTime = 0.08,
        }

        local freecamActive, flyActive, sliding = false, false, false
        local camVelocity = Vector3.new()
        local camRot = Vector2.new(0,0)
        local pressed = {}

        local moveKeys = {
            [Enum.KeyCode.W] = Vector3.new(0,0,-1),
            [Enum.KeyCode.S] = Vector3.new(0,0,1),
            [Enum.KeyCode.A] = Vector3.new(-1,0,0),
            [Enum.KeyCode.D] = Vector3.new(1,0,0),
            [Enum.KeyCode.E] = Vector3.new(0,1,0),
            [Enum.KeyCode.Q] = Vector3.new(0,-1,0),
        }

        local function enableFreecam()
            if freecamActive then return end
            freecamActive = true
            camera.CameraType = Enum.CameraType.Scriptable
            StarterGui:SetCore("TopbarEnabled", false)
        end

        local function disableFreecam()
            if not freecamActive then return end
            freecamActive = false
            camera.CameraType = Enum.CameraType.Custom
            StarterGui:SetCore("TopbarEnabled", true)
        end

        local function toggleFly()
            flyActive = not flyActive
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.PlatformStand = flyActive
            end
        end

        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == config.toggleFreecamKey then
                if freecamActive then disableFreecam() else enableFreecam() end
            elseif input.KeyCode == config.toggleFlyKey then
                toggleFly()
            elseif input.KeyCode == config.slideKey then
                sliding = true
            else
                pressed[input.KeyCode] = true
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            pressed[input.KeyCode] = nil
            if input.KeyCode == config.slideKey then sliding = false end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if freecamActive and input.UserInputType == Enum.UserInputType.MouseMovement then
                camRot = camRot + Vector2.new(-input.Delta.x * config.mouseSensitivity, -input.Delta.y * config.mouseSensitivity)
                camRot = Vector2.new(camRot.X, math.clamp(camRot.Y, -89, 89))
            end
        end)

        local function smoothDamp(current, target, smoothTime, dt)
            local t = 1 - math.exp(-dt / math.max(0.0001, smoothTime))
            return current:Lerp(target, t)
        end

        local function performSlide(dt)
            if not sliding or not player.Character then return end
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if not hrp or not humanoid or humanoid.FloorMaterial == Enum.Material.Air then return end
            local look = camera.CFrame.LookVector
            hrp.CFrame = hrp.CFrame + look * config.slideSpeed * dt
        end

        local last = tick()
        RunService.RenderStepped:Connect(function()
            local now = tick()
            local dt = math.clamp(now - last, 0, 0.05)
            last = now

            if freecamActive then
                local yaw, pitch = math.rad(camRot.X), math.rad(camRot.Y)
                local cf = CFrame.new(camera.CFrame.Position) * CFrame.Angles(0,yaw,0) * CFrame.Angles(pitch,0,0)
                local f, r, u = cf.LookVector, cf.RightVector, Vector3.new(0,1,0)
                local move = Vector3.new()
                for k,v in pairs(moveKeys) do if pressed[k] then
                    if v.Y~=0 then move+=u*v.Y else move+=(f*v.Z+r*v.X) end end end
                local sprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                local targetVel = (move.Magnitude>0 and move.Unit or Vector3.new())*(config.freecamSpeed*(sprint and 2 or 1))
                camVelocity = smoothDamp(camVelocity,targetVel,config.smoothTime,dt)
                local newPos = camera.CFrame.Position + camVelocity*dt
                camera.CFrame = CFrame.new(newPos, newPos+cf.LookVector)
            end

            if flyActive and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                local cf = camera.CFrame
                local dir = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir+=Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir-=Vector3.new(0,1,0) end
                if dir.Magnitude>0 then hrp.CFrame = hrp.CFrame + dir.Unit*config.flySpeed*dt end
            end
            performSlide(dt)
        end)

        local gui = Instance.new("ScreenGui")
        gui.Name = "ClientAdminHints"
        gui.ResetOnSpawn = false
        local t = Instance.new("TextLabel", gui)
        t.Size = UDim2.new(0,520,0,60)
        t.Position = UDim2.new(0,10,1,-80)
        t.BackgroundTransparency=0.6
        t.BackgroundColor3=Color3.fromRGB(0,0,0)
        t.TextColor3=Color3.new(1,1,1)
        t.TextScaled=true
        t.Text="RightCtrl=Freecam | F=Fly | Hold LeftCtrl=Slide | Shift=Sprint"
        gui.Parent = player:WaitForChild("PlayerGui")
        print("Freecam/Fly/Slide loaded Client-side.")
        ]]
        scriptClone.Parent = PlayerGui
        print("Freecam/Fly/Slide module loaded.")
    end
}

--------------------------------------------------------------------------
-- GUI Loader Menu
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ProjectLoaderGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 200)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Text = "Client Project Loader"
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Parent = frame

local list = Instance.new("Frame")
list.Position = UDim2.new(0,0,0,40)
list.Size = UDim2.new(1,0,1,-40)
list.BackgroundTransparency = 1
list.Parent = frame

local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0,6)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top

for _,proj in ipairs(projects) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,260,0,40)
    btn.Text = "Load "..proj.Name
    btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = list
    btn.MouseButton1Click:Connect(function()
        pcall(proj.Load)
    end)
end

print("Client Project Loader loaded. Click buttons to load local modules.")