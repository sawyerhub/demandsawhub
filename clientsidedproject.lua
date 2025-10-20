local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local config = {
    freecamSpeed = 100,
    flySpeed = 50,
    slideSpeed = 60,
    mouseSensitivity = 0.2,
    smoothTime = 0.08,
    toggleFreecamKey = Enum.KeyCode.RightControl,
    toggleFlyKey = Enum.KeyCode.F,
    slideKey = Enum.KeyCode.LeftControl,
}

local freecamEnabled = false
local flyEnabled = false
local sliding = false
local pressed = {}
local camRot = Vector2.new(0,0)
local camVelocity = Vector3.new()

local moveKeys = {
    [Enum.KeyCode.W] = Vector3.new(0,0,-1),
    [Enum.KeyCode.S] = Vector3.new(0,0,1),
    [Enum.KeyCode.A] = Vector3.new(-1,0,0),
    [Enum.KeyCode.D] = Vector3.new(1,0,0),
    [Enum.KeyCode.E] = Vector3.new(0,1,0),
    [Enum.KeyCode.Q] = Vector3.new(0,-1,0),
}

local function smoothDamp(current, target, smoothTime, dt)
    local t = 1 - math.exp(-dt / math.max(0.0001, smoothTime))
    return current:Lerp(target, t)
end

local function enableFreecam()
    if freecamEnabled then return end
    freecamEnabled = true
    camera.CameraType = Enum.CameraType.Scriptable
    -- capture camera rotation
    local _, yaw, pitch = camera.CFrame:ToOrientation()
    camRot = Vector2.new(math.deg(yaw), math.deg(pitch))
    StarterGui:SetCore("TopbarEnabled", false)
end

local function disableFreecam()
    if not freecamEnabled then return end
    freecamEnabled = false
    camera.CameraType = Enum.CameraType.Custom
    StarterGui:SetCore("TopbarEnabled", true)
end

local function toggleFly()
    flyEnabled = not flyEnabled
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.PlatformStand = flyEnabled
    end
end

local function startSlide()
    sliding = true
end
local function stopSlide()
    sliding = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local kc = input.KeyCode
        if kc == config.toggleFreecamKey then
            if freecamEnabled then disableFreecam() else enableFreecam() end
        elseif kc == config.toggleFlyKey then
            toggleFly()
        elseif kc == config.slideKey then
            startSlide()
        else
            pressed[kc] = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        pressed[input.KeyCode] = nil
        if input.KeyCode == config.slideKey then
            stopSlide()
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if freecamEnabled and input.UserInputType == Enum.UserInputType.MouseMovement then
        camRot = camRot + Vector2.new(-input.Delta.x * config.mouseSensitivity, -input.Delta.y * config.mouseSensitivity)
        camRot = Vector2.new(camRot.X, math.clamp(camRot.Y, -89, 89))
    end
end)

local lastTick = tick()
RunService.RenderStepped:Connect(function()
    local now = tick()
    local dt = math.clamp(now - lastTick, 0, 0.05)
    lastTick = now

    if freecamEnabled then
        local yaw = math.rad(camRot.X)
        local pitch = math.rad(camRot.Y)
        local camCF = CFrame.new(camera.CFrame.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
        local forward = camCF.LookVector
        local right = camCF.RightVector
        local up = Vector3.new(0,1,0)

        local moveDir = Vector3.new()
        for key, vec in pairs(moveKeys) do
            if pressed[key] then
                if vec.Y ~= 0 then
                    moveDir = moveDir + up * vec.Y
                else
                    moveDir = moveDir + (forward * vec.Z + right * vec.X)
                end
            end
        end

        local sprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        local targetSpeed = config.freecamSpeed * (sprint and 2 or 1)
        local targetVel = (moveDir.Magnitude > 0) and moveDir.Unit * targetSpeed or Vector3.new()

        camVelocity = smoothDamp(camVelocity, targetVel, config.smoothTime, dt)

        local newPos = camera.CFrame.Position + camVelocity * dt
        camera.CFrame = CFrame.new(newPos, newPos + camCF.LookVector)
    end

    if flyEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        local cf = camera.CFrame
        local dir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0,1,0) end

        if dir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + dir.Unit * config.flySpeed * dt
        end
    end

    -- Slide movement (client-side, simple ground check)
    if sliding and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and hrp and humanoid.FloorMaterial ~= Enum.Material.Air then
            local look = camera.CFrame.LookVector
            hrp.CFrame = hrp.CFrame + look * config.slideSpeed * dt
        end
    end
end)

local PlayerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "IntegratedAdminGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 280, 0, 160)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,32)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundTransparency = 1
title.Text = "Admin Tools"
title.TextScaled = true
title.TextColor3 = Color3.new(1,1,1)
title.Parent = frame

local btnY = 40
local function makeButton(textStr, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 240, 0, 36)
    b.Position = UDim2.new(0, 20, 0, btnY)
    b.Text = textStr
    b.TextScaled = true
    b.BackgroundColor3 = Color3.fromRGB(40,40,40)
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = parent
    btnY = btnY + 44
    return b
end

local freecamBtn = makeButton("Toggle Freecam", frame)
local flyBtn = makeButton("Toggle Fly", frame)
local slideBtn = makeButton("Hold Slide (Key) / Toggle", frame)

freecamBtn.MouseButton1Click:Connect(function()
    if freecamEnabled then disableFreecam() else enableFreecam() end
end)

flyBtn.MouseButton1Click:Connect(function()
    toggleFly()
end)

local slideToggled = false
slideBtn.MouseButton1Click:Connect(function()
    slideToggled = not slideToggled
    if slideToggled then startSlide() else stopSlide() end
end)

-- Draggable frame implementation
local dragging = false
local dragStart = nil
local startPos = nil

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        -- handled in RenderStepped
    end
end)

RunService.RenderStepped:Connect(function()
    if dragging and dragStart and startPos then
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        -- clamp to screen bounds (simple)
        newX = math.clamp(newX, 0, math.max(0, workspace.CurrentCamera.ViewportSize.X - frame.Size.X.Offset))
        newY = math.clamp(newY, 0, math.max(0, workspace.CurrentCamera.ViewportSize.Y - frame.Size.Y.Offset))
        frame.Position = UDim2.new(0, newX, 0, newY)
    end
end)

-- Small footer/help text
local help = Instance.new("TextLabel")
help.Size = UDim2.new(1,0,0,26)
help.Position = UDim2.new(0,0,1,-26)
help.BackgroundTransparency = 0.6
help.BackgroundColor3 = Color3.fromRGB(0,0,0)
help.TextColor3 = Color3.new(1,1,1)
help.TextScaled = true
help.Text = string.format("%s to toggle Freecam | %s to toggle Fly | Hold %s to Slide",
    tostring(config.toggleFreecamKey), tostring(config.toggleFlyKey), tostring(config.slideKey))
help.Parent = frame

-- Parent GUI
gui.Parent = PlayerGui

print("Integrated client admin tools loaded. Use the GUI to toggle features or use keybinds.")
