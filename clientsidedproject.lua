-- Integrated Client-side Admin Tools: Freecam / Fly / Slide + Movable Menu + ESP
-- Place this LocalScript in StarterPlayerScripts. Intended for testing / development / games you own.
-- WARNING: Do not use to cheat in live games you don't own. Only use for debugging and development.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- CONFIG -----------------------------------------------------------------
local config = {
    freecamSpeed = 100,
    flySpeed = 50,
    slideSpeed = 60,
    mouseSensitivity = 0.2,
    smoothTime = 0.08,
    toggleFreecamKey = Enum.KeyCode.RightControl,
    toggleFlyKey = Enum.KeyCode.F,
    slideKey = Enum.KeyCode.LeftControl,
    espDistance = 200, -- max distance to show ESP
    espShowTeamMates = true, -- show ESP for teammates
}

-- STATE ------------------------------------------------------------------
local freecamEnabled = false
local flyEnabled = false
local sliding = false
local pressed = {}
local camRot = Vector2.new(0,0)
local camVelocity = Vector3.new()
local espEnabled = false
local espMap = {} -- map character -> billboardGui

local moveKeys = {
    [Enum.KeyCode.W] = Vector3.new(0,0,-1),
    [Enum.KeyCode.S] = Vector3.new(0,0,1),
    [Enum.KeyCode.A] = Vector3.new(-1,0,0),
    [Enum.KeyCode.D] = Vector3.new(1,0,0),
    [Enum.KeyCode.E] = Vector3.new(0,1,0),
    [Enum.KeyCode.Q] = Vector3.new(0,-1,0),
}

-- UTILS ------------------------------------------------------------------
local function smoothDamp(current, target, smoothTime, dt)
    local t = 1 - math.exp(-dt / math.max(0.0001, smoothTime))
    return current:Lerp(target, t)
end

local function isTeammate(a, b)
    -- safe check for team equality (if game uses Teams)
    if not a or not b then return false end
    if a.Team and b.Team then
        return a.Team == b.Team
    end
    return false
end

-- FREECAM ----------------------------------------------------------------
local function enableFreecam()
    if freecamEnabled then return end
    freecamEnabled = true
    camera.CameraType = Enum.CameraType.Scriptable
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

-- FLY --------------------------------------------------------------------
local function toggleFly()
    flyEnabled = not flyEnabled
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.PlatformStand = flyEnabled
    end
end

-- SLIDE ------------------------------------------------------------------
local function startSlide()
    sliding = true
end
local function stopSlide()
    sliding = false
end

-- INPUT HANDLING ---------------------------------------------------------
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

-- ESP --------------------------------------------------------------------
local function makeBillboardForCharacter(char, displayName)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.Adornee = hrp
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 120, 0, 28)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 0.35
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -4, 1, 0)
    nameLabel.Position = UDim2.new(0, 2, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Text = displayName or "NPC"
    nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = frame

    billboard.Parent = player:WaitForChild("PlayerGui")
    return billboard
end

local function addESPToCharacter(playerObj)
    if not playerObj or not playerObj.Character then return end
    local char = playerObj.Character
    if espMap[char] then return end
    local shouldShow = true
    if playerObj ~= player and not config.espShowTeamMates and isTeammate(playerObj, player) then
        shouldShow = true
    end
    if shouldShow then
        local b = makeBillboardForCharacter(char, playerObj.Name)
        espMap[char] = b
    end
end

local function removeESPFromCharacter(char)
    if espMap[char] then
        espMap[char]:Destroy()
        espMap[char] = nil
    end
end

local function enableESP()
    if espEnabled then return end
    espEnabled = true
    -- add to existing players
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            addESPToCharacter(p)
        end
    end
end

local function disableESP()
    if not espEnabled then return end
    espEnabled = false
    -- remove all
    for char, gui in pairs(espMap) do
        if gui and gui.Parent then gui:Destroy() end
    end
    espMap = {}
end

-- track players
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        if espEnabled and p ~= player then addESPToCharacter(p) end
        char.AncestryChanged:Connect(function(_, parent)
            if not parent then removeESPFromCharacter(char) end
        end)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if p.Character then removeESPFromCharacter(p.Character) end
end)

-- Also add ESP to NPCs / models with PrimaryPart
local function scanNPCsForESP()
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.PrimaryPart and obj ~= player.Character then
            -- simple heuristic: skip players' characters
            if not Players:GetPlayerFromCharacter(obj) then
                if espEnabled and not espMap[obj] then
                    local b = makeBillboardForCharacter(obj, obj.Name)
                    espMap[obj] = b
                end
            end
        end
    end
end

-- periodic scan for NPCs
spawn(function()
    while true do
        if espEnabled then scanNPCsForESP() end
        wait(2)
    end
end)

-- MOVEMENT UPDATES -------------------------------------------------------
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

    -- Update ESP name/distance visibility
    if espEnabled then
        for char, gui in pairs(espMap) do
            if gui and gui.Adornee and gui.Parent then
                local adornee = gui.Adornee
                local pos = adornee.Position
                local dist = (camera.CFrame.Position - pos).Magnitude
                local nameLabel = gui:FindFirstChildWhichIsA("Frame") and gui:FindFirstChildWhichIsA("Frame"):FindFirstChildWhichIsA("TextLabel")
                if nameLabel then
                    nameLabel.Text = (char:IsA("Model") and char.Name) or tostring(char)
                    nameLabel.TextTransparency = dist > config.espDistance and 1 or 0
                    gui.Enabled = dist <= config.espDistance
                end
            end
        end
    end
end)

-- GUI --------------------------------------------------------------------
local PlayerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "IntegratedAdminGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 320, 0, 200)
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
    b.Size = UDim2.new(0, 280, 0, 36)
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
local slideBtn = makeButton("Toggle Slide (toggle)", frame)
local espBtn = makeButton("Toggle ESP", frame)

-- Button handlers
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

espBtn.MouseButton1Click:Connect(function()
    if espEnabled then disableESP() else enableESP() end
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

RunService.RenderStepped:Connect(function()
    if dragging and dragStart and startPos then
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
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
help.Text = string.format("%s to toggle Freecam | %s to toggle Fly | Hold %s to Slide | Toggle ESP from menu",
    tostring(config.toggleFreecamKey), tostring(config.toggleFlyKey), tostring(config.slideKey))
help.Parent = frame

-- Parent GUI
gui.Parent = PlayerGui

print("Integrated client admin tools loaded. Use the GUI to toggle features or use keybinds.")
