-- Integrated Client Admin Tools — Freecam / Fly / Slide / ESP Boxes + Tracers + Settings + Studio-only Aim Helper
-- LocalScript: place in StarterPlayerScripts. For development and debugging in games you own.
-- IMPORTANT: Aimbot helper only works in Roblox Studio for learning/testing. Do NOT use this in live games.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- CONFIG (defaults)
local config = {
    freecamSpeed = 100,
    flySpeed = 50,
    slideSpeed = 60,
    mouseSensitivity = 0.2,
    smoothTime = 0.08,
    toggleFreecamKey = Enum.KeyCode.RightControl,
    toggleFlyKey = Enum.KeyCode.F,
    slideKey = Enum.KeyCode.LeftControl,
    espDistance = 5000, -- increased per request
    espShowTeamMates = false, -- show only non-teammates by default
    espUpdateMode = "High", -- High / Medium / Low
    espBoxColor = Color3.fromRGB(255,0,0),
    tracersEnabled = true,
    tracerOrigin = "Bottom" -- Bottom or Center
}

-- STATE
local freecamEnabled = false
local flyEnabled = false
local sliding = false
local pressed = {}
local camRot = Vector2.new(0,0)
local camVelocity = Vector3.new()
local espEnabled = true
local espMap = {} -- model -> data
local espUpdateInterval = 0 -- computed from mode
local tracers = {}
local settingsOpen = false
local aimHelperEnabled = false

local moveKeys = {
    [Enum.KeyCode.W] = Vector3.new(0,0,-1),
    [Enum.KeyCode.S] = Vector3.new(0,0,1),
    [Enum.KeyCode.A] = Vector3.new(-1,0,0),
    [Enum.KeyCode.D] = Vector3.new(1,0,0),
    [Enum.KeyCode.E] = Vector3.new(0,1,0),
    [Enum.KeyCode.Q] = Vector3.new(0,-1,0),
}

-- UTIL
local function smoothDamp(current, target, smoothTime, dt)
    local t = 1 - math.exp(-dt / math.max(0.0001, smoothTime))
    return current:Lerp(target, t)
end

local function isTeammate(a, b)
    if a and b and a.Team and b.Team then
        return a.Team == b.Team
    end
    return false
end

local function getEspUpdateInterval(mode)
    if mode == "High" then return 0 end
    if mode == "Medium" then return 0.12 end
    return 0.5 -- Low
end

espUpdateInterval = getEspUpdateInterval(config.espUpdateMode)

-- FREECAM
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

-- FLY
local function toggleFly()
    flyEnabled = not flyEnabled
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.PlatformStand = flyEnabled
    end
end

-- SLIDE
local function startSlide() sliding = true end
local function stopSlide() sliding = false end

-- INPUT
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
        if input.KeyCode == config.slideKey then stopSlide() end
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if freecamEnabled and input.UserInputType == Enum.UserInputType.MouseMovement then
        camRot = camRot + Vector2.new(-input.Delta.x * config.mouseSensitivity, -input.Delta.y * config.mouseSensitivity)
        camRot = Vector2.new(camRot.X, math.clamp(camRot.Y, -89, 89))
    end
end)

-- ESP / BOX / TRACERS
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AdminESPGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local espContainer = Instance.new("Frame")
espContainer.Size = UDim2.new(1,0,1,0)
espContainer.BackgroundTransparency = 1
espContainer.Parent = ScreenGui

local function makeBoxESP(model)
    if not model then return end
    local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not part then return end

    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_Box"
    gui.Adornee = part
    gui.AlwaysOnTop = true
    gui.Size = UDim2.new(0, 120, 0, 60)
    gui.StudsOffset = Vector3.new(0, 3, 0)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1
    frame.Parent = gui

    local borderThickness = 2
    local top = Instance.new("Frame", frame)
    top.Size = UDim2.new(1,0,0,borderThickness)
    top.Position = UDim2.new(0,0,0,0)
    top.BackgroundColor3 = config.espBoxColor
    top.BorderSizePixel = 0

    local bottom = Instance.new("Frame", frame)
    bottom.Size = UDim2.new(1,0,0,borderThickness)
    bottom.Position = UDim2.new(0,0,1,-borderThickness)
    bottom.BackgroundColor3 = config.espBoxColor
    bottom.BorderSizePixel = 0

    local left = Instance.new("Frame", frame)
    left.Size = UDim2.new(0,borderThickness,1,0)
    left.Position = UDim2.new(0,0,0,0)
    left.BackgroundColor3 = config.espBoxColor
    left.BorderSizePixel = 0

    local right = Instance.new("Frame", frame)
    right.Size = UDim2.new(0,borderThickness,1,0)
    right.Position = UDim2.new(1,-borderThickness,0,0)
    right.BackgroundColor3 = config.espBoxColor
    right.BorderSizePixel = 0

    local nameLabel = Instance.new("TextLabel", frame)
    nameLabel.Size = UDim2.new(1,-4,0,20)
    nameLabel.Position = UDim2.new(0,2,0,0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Text = model.Name
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.Font = Enum.Font.SourceSansBold

    local healthBg = Instance.new("Frame", frame)
    healthBg.Size = UDim2.new(0.6,0,0,6)
    healthBg.Position = UDim2.new(0.2,0,1,-26)
    healthBg.AnchorPoint = Vector2.new(0,1)
    healthBg.BackgroundTransparency = 0.5
    healthBg.BackgroundColor3 = Color3.new(0,0,0)
    healthBg.BorderSizePixel = 0

    local healthFill = Instance.new("Frame", healthBg)
    healthFill.Size = UDim2.new(1,0,1,0)
    healthFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
    healthFill.BorderSizePixel = 0

    gui.Parent = ScreenGui
    return {gui = gui, healthFill = healthFill}
end

local function makeTracerGui()
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Size = UDim2.new(0, 2, 0, 10)
    frame.BackgroundColor3 = config.espBoxColor
    frame.BorderSizePixel = 0
    frame.Parent = ScreenGui
    frame.Visible = false
    return frame
end

local function ensureESPForModel(model)
    if espMap[model] then return end
    local data = makeBoxESP(model)
    local tracer = makeTracerGui()
    espMap[model] = {model = model, guiData = data, tracer = tracer}
end
local function removeESPForModel(model)
    local data = espMap[model]
    if not data then return end
    if data.guiData and data.guiData.gui and data.guiData.gui.Parent then data.guiData.gui:Destroy() end
    if data.tracer and data.tracer.Parent then data.tracer:Destroy() end
    espMap[model] = nil
end

local function refreshESPList()
    -- add players (non-teammates only if configured)
    for _,p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            if not config.espShowTeamMates and isTeammate(p, player) then
                removeESPForModel(p.Character)
            else
                ensureESPForModel(p.Character)
            end
        end
    end
    -- add NPC models
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.PrimaryPart and not Players:GetPlayerFromCharacter(obj) then
            ensureESPForModel(obj)
        end
    end
end

-- ESP update coroutine (honors performance mode)
spawn(function()
    while true do
        if espEnabled then
            refreshESPList()
            -- update visuals
            for model, data in pairs(espMap) do
                if data.guiData and data.guiData.gui and data.guiData.gui.Adornee then
                    local adornee = data.guiData.gui.Adornee
                    local pos = adornee.Position
                    local dist = (camera.CFrame.Position - pos).Magnitude
                    data.guiData.gui.Enabled = dist <= config.espDistance

                    -- update name
                    local frame = data.guiData.gui:FindFirstChildWhichIsA("Frame")
                    if frame then
                        local nameLabel = frame:FindFirstChildWhichIsA("TextLabel")
                        if nameLabel then nameLabel.Text = model.Name end
                    end

                    -- health
                    local humanoid = model:FindFirstChildWhichIsA("Humanoid")
                    if humanoid and data.guiData.healthFill then
                        local pct = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
                        data.guiData.healthFill.Size = UDim2.new(pct, 0, 1, 0)
                        if pct > 0.6 then
                            data.guiData.healthFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
                        elseif pct > 0.3 then
                            data.guiData.healthFill.BackgroundColor3 = Color3.fromRGB(255,165,0)
                        else
                            data.guiData.healthFill.BackgroundColor3 = Color3.fromRGB(255,0,0)
                        end
                    end
                end
            end
        end
        if espUpdateInterval > 0 then
            wait(espUpdateInterval)
        else
            RunService.Heartbeat:Wait()
        end
    end
end)

-- Tracers & per-frame updates (RenderStepped for smooth lines)
RunService.RenderStepped:Connect(function()
    -- freecam/fly/slide movement handled elsewhere (omitted here for brevity)

    if espEnabled and config.tracersEnabled then
        -- compute origin point
        local originScreen
        if config.tracerOrigin == "Center" then
            originScreen = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
        else -- Bottom
            originScreen = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
        end

        for model, data in pairs(espMap) do
            local gui = data.guiData and data.guiData.gui
            local tracer = data.tracer
            if gui and gui.Adornee and tracer then
                local worldPos = gui.Adornee.Position
                local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
                if onScreen and (camera.CFrame.Position - worldPos).Magnitude <= config.espDistance then
                    -- show tracer
                    tracer.Visible = true
                    local to = Vector2.new(screenPos.X, screenPos.Y)
                    local dir = to - originScreen
                    local length = dir.Magnitude
                    tracer.Size = UDim2.new(0, math.max(2, length), 0, 2)
                    tracer.Position = UDim2.new(0, originScreen.X - tracer.Size.X.Offset/2, 0, originScreen.Y)
                    tracer.Rotation = math.deg(math.atan2(dir.Y, dir.X))
                    tracer.BackgroundColor3 = config.espBoxColor
                else
                    tracer.Visible = false
                end
            end
        end
    end
end)

-- Simple Studio-only aim helper: smoothly rotate camera toward nearest target head
local function getNearestTarget()
    local best, bestDist = nil, math.huge
    for model, data in pairs(espMap) do
        if model.Parent and model.PrimaryPart and data.guiData and data.guiData.gui and data.guiData.gui.Enabled then
            local humanoid = model:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                local head = model:FindFirstChild("Head") or model.PrimaryPart
                if head then
                    local dd = (camera.CFrame.Position - head.Position).Magnitude
                    if dd < bestDist then best = head; bestDist = dd end
                end
            end
        end
    end
    return best
end

local aimSmoothing = 8 -- larger = slower
spawn(function()
    while true do
        if aimHelperEnabled then
            -- only allow in Studio
            if not RunService:IsStudio() then
                aimHelperEnabled = false
                warn("Aim helper disabled: only works in Studio")
                break
            end
            local target = getNearestTarget()
            if target then
                local desired = CFrame.new(camera.CFrame.Position, target.Position)
                -- slerp rotation only
                local current = camera.CFrame
                local newCFrame = CFrame.new(current.Position) * CFrame.Angles(0, 0, 0)
                -- interpolate look vector
                local curLook = current.LookVector
                local wantLook = (target.Position - current.Position).Unit
                local lerpLook = curLook:Lerp(wantLook, math.clamp(1/aimSmoothing, 0, 1))
                local up = Vector3.new(0,1,0)
                local cf = CFrame.new(current.Position, current.Position + lerpLook)
                camera.CFrame = cf
            end
        end
        RunService.Heartbeat:Wait()
    end
end)

-- GUI (main panel + settings)
local gui = ScreenGui

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 360, 0, 260)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,34)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundTransparency = 1
title.Text = "Dev Tools"
title.TextScaled = true
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local btnY = 44
local function makeButton(text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 300, 0, 34)
    b.Position = UDim2.new(0, 30, 0, btnY)
    b.Text = text
    b.TextScaled = true
    b.BackgroundColor3 = Color3.fromRGB(45,45,45)
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = frame
    btnY = btnY + 42
    return b
end

local freecamBtn = makeButton("Toggle Freecam")
local flyBtn = makeButton("Toggle Fly")
local slideBtn = makeButton("Toggle Slide (hold / toggle)")
local espBtn = makeButton("Toggle ESP")
local tracerBtn = makeButton("Toggle Tracers")
local settingsBtn = makeButton("Settings")
local aimBtn = makeButton("Studio Aim Helper")

freecamBtn.MouseButton1Click:Connect(function()
    if freecamEnabled then disableFreecam() else enableFreecam() end
end)
flyBtn.MouseButton1Click:Connect(function() toggleFly() end)
local slideToggled = false
slideBtn.MouseButton1Click:Connect(function() slideToggled = not slideToggled if slideToggled then startSlide() else stopSlide() end end)
espBtn.MouseButton1Click:Connect(function() if espEnabled then disableESP() else espEnabled = true end end)
tracerBtn.MouseButton1Click:Connect(function() config.tracersEnabled = not config.tracersEnabled end)
settingsBtn.MouseButton1Click:Connect(function() settingsOpen = not settingsOpen settingsPanel.Visible = settingsOpen end)
aimBtn.MouseButton1Click:Connect(function() aimHelperEnabled = not aimHelperEnabled if aimHelperEnabled and not RunService:IsStudio() then aimHelperEnabled = false warn("Aim helper only available in Studio") end end)

-- Settings panel (hidden by default)
local settingsPanel = Instance.new("Frame")
settingsPanel.Size = UDim2.new(0, 320, 0, 220)
settingsPanel.Position = UDim2.new(0, 380, 0, 20)
settingsPanel.BackgroundColor3 = Color3.fromRGB(24,24,24)
settingsPanel.BorderSizePixel = 0
settingsPanel.Parent = gui
settingsPanel.Visible = false

local sTitle = Instance.new("TextLabel")
sTitle.Size = UDim2.new(1,0,0,30)
sTitle.Position = UDim2.new(0,0,0,0)
sTitle.BackgroundTransparency = 1
sTitle.Text = "Settings"
sTitle.TextScaled = true
sTitle.TextColor3 = Color3.new(1,1,1)
sTitle.Font = Enum.Font.SourceSansBold
sTitle.Parent = settingsPanel

-- Simple slider builder
local function makeSlider(parent, y, labelText, min, max, value, onChange)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0, 200, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText .. ": " .. tostring(value)
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextScaled = false
    lbl.Font = Enum.Font.SourceSans

    local bar = Instance.new("Frame", parent)
    bar.Size = UDim2.new(0, 220, 0, 14)
    bar.Position = UDim2.new(0, 10, 0, y + 22)
    bar.BackgroundColor3 = Color3.fromRGB(50,50,50)
    bar.BorderSizePixel = 0

    local knob = Instance.new("Frame", bar)
    knob.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    knob.BackgroundColor3 = Color3.fromRGB(170,170,170)
    knob.BorderSizePixel = 0

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging then
            local mouseX = UserInputService:GetMouseLocation().X
            local barPos = bar.AbsolutePosition.X
            local width = bar.AbsoluteSize.X
            local rel = math.clamp((mouseX - barPos) / width, 0, 1)
            knob.Size = UDim2.new(rel, 0, 1, 0)
            local newVal = min + rel * (max - min)
            lbl.Text = labelText .. ": " .. string.format("%.1f", newVal)
            if onChange then onChange(newVal) end
        end
    end)
end

-- add sliders: freecamSpeed, flySpeed, espDistance
makeSlider(settingsPanel, 36, "Freecam Speed", 10, 500, config.freecamSpeed, function(v) config.freecamSpeed = v end)
makeSlider(settingsPanel, 90, "Fly Speed", 10, 300, config.flySpeed, function(v) config.flySpeed = v end)
makeSlider(settingsPanel, 144, "ESP Distance", 100, 5000, config.espDistance, function(v) config.espDistance = v end)

-- box color presets
local colorLabel = Instance.new("TextLabel", settingsPanel)
colorLabel.Size = UDim2.new(0, 200, 0, 20)
colorLabel.Position = UDim2.new(0, 10, 0, 190)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "Box Color"
colorLabel.TextColor3 = Color3.new(1,1,1)
colorLabel.TextScaled = false

local presets = {
    Color3.fromRGB(255,0,0),
    Color3.fromRGB(0,255,0),
    Color3.fromRGB(0,170,255),
    Color3.fromRGB(255,200,0)
}
for i,clr in ipairs(presets) do
    local btn = Instance.new("TextButton", settingsPanel)
    btn.Size = UDim2.new(0, 36, 0, 20)
    btn.Position = UDim2.new(0, 220 + (i-1)*40, 0, 190)
    btn.Text = ""
    btn.BackgroundColor3 = clr
    btn.BorderSizePixel = 0
    btn.MouseButton1Click:Connect(function() config.espBoxColor = clr end)
end

-- draggable main frame
local dragging = false
local dragInput, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
RunService.RenderStepped:Connect(function()
    if dragging and dragInput and dragStart and startPos then
        local delta = UserInputService:GetMouseLocation() - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        newX = math.clamp(newX, 0, math.max(0, camera.ViewportSize.X - frame.Size.X.Offset))
        newY = math.clamp(newY, 0, math.max(0, camera.ViewportSize.Y - frame.Size.Y.Offset))
        frame.Position = UDim2.new(0, newX, 0, newY)
        -- move settings panel along with main window
        settingsPanel.Position = UDim2.new(0, frame.Position.X.Offset + frame.Size.X.Offset + 20, 0, frame.Position.Y.Offset)
    end
end)

-- finalize: set espUpdateInterval when mode changed
local function setEspMode(mode)
    config.espUpdateMode = mode
    espUpdateInterval = getEspUpdateInterval(mode)
end

-- init defaults
setEspMode(config.espUpdateMode)
refreshESPList()

print("Dev Tools loaded. Use the panel to toggle features. Aim helper works only in Studio.")
