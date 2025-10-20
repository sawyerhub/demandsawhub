-- Integrated Client Admin Tools — Players-only ESP with Team Colors, Freecam / Fly / Slide / Tracers + Settings + Studio-only Aim Helper (sends "aimbot" system message when enabled)
-- LocalScript: place in StarterPlayerScripts. For development and debugging in games you own.
-- NOTE: Aimbot helper only works in Roblox Studio for learning/testing. Do NOT use this in live games.

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
    espDistance = 5000, -- studs
    espShowTeamMates = false, -- show only non-teammates by default
    espUpdateMode = "High", -- High / Medium / Low
    espBoxColor = Color3.fromRGB(255,0,0), -- fallback color
    tracersEnabled = true,
    tracerOrigin = "Center" -- Center or Bottom
}

-- STATE
local freecamEnabled = false
local flyEnabled = false
local sliding = false
local pressed = {}
local camRot = Vector2.new(0,0)
local camVelocity = Vector3.new()
local espEnabled = true
local espMap = {} -- player -> data {ui, tracer}
local espUpdateInterval = 0 -- computed from mode
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
    pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
end
local function disableFreecam()
    if not freecamEnabled then return end
    freecamEnabled = false
    camera.CameraType = Enum.CameraType.Custom
    pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)
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

-- GUI root for 2D overlays (boxes & tracers)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AdminESPGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

-- utility: create boxed UI for a player
local function createBoxUI()
    local container = Instance.new("Frame")
    container.AnchorPoint = Vector2.new(0,0)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(0,0,0,0)
    container.Position = UDim2.new(0,0,0,0)

    local borderThickness = 2
    local top = Instance.new("Frame", container)
    top.Name = "Top"
    top.BackgroundColor3 = config.espBoxColor
    top.BorderSizePixel = 0

    local bottom = Instance.new("Frame", container)
    bottom.Name = "Bottom"
    bottom.BackgroundColor3 = config.espBoxColor
    bottom.BorderSizePixel = 0

    local left = Instance.new("Frame", container)
    left.Name = "Left"
    left.BackgroundColor3 = config.espBoxColor
    left.BorderSizePixel = 0

    local right = Instance.new("Frame", container)
    right.Name = "Right"
    right.BackgroundColor3 = config.espBoxColor
    right.BorderSizePixel = 0

    local nameLabel = Instance.new("TextLabel", container)
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextScaled = true
    nameLabel.Text = ""

    local healthBg = Instance.new("Frame", container)
    healthBg.Name = "HealthBg"
    healthBg.BackgroundColor3 = Color3.new(0,0,0)
    healthBg.BackgroundTransparency = 0.5
    healthBg.BorderSizePixel = 0
    local healthFill = Instance.new("Frame", healthBg)
    healthFill.Name = "HealthFill"
    healthFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
    healthFill.BorderSizePixel = 0

    container.Parent = ScreenGui
    return {
        container = container,
        top = top, bottom = bottom, left = left, right = right,
        nameLabel = nameLabel, healthBg = healthBg, healthFill = healthFill
    }
end

local function createTracerUI()
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 2, 0, 2)
    line.AnchorPoint = Vector2.new(0,0)
    line.BackgroundColor3 = config.espBoxColor
    line.BorderSizePixel = 0
    line.Visible = false
    line.Parent = ScreenGui
    return line
end

-- compute 2D bounding box for a model using Model:GetBoundingBox()
local function getModelScreenRect(model)
    if not model then return nil end
    if not model.PrimaryPart then return nil end
    local ok, cframe, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or not cframe or not size then return nil end

    local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
    local corners = {
        Vector3.new( hx,  hy,  hz), Vector3.new( hx,  hy, -hz), Vector3.new( hx, -hy,  hz), Vector3.new( hx, -hy, -hz),
        Vector3.new(-hx,  hy,  hz), Vector3.new(-hx,  hy, -hz), Vector3.new(-hx, -hy,  hz), Vector3.new(-hx, -hy, -hz),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOnScreen = false
    for _,corner in ipairs(corners) do
        local worldPos = (cframe * CFrame.new(corner)).p
        local sx, sy, onScreen = camera:WorldToViewportPoint(worldPos)
        if onScreen then anyOnScreen = true end
        minX = math.min(minX, sx)
        minY = math.min(minY, sy)
        maxX = math.max(maxX, sx)
        maxY = math.max(maxY, sy)
    end
    if minX==math.huge then return nil end
    return {minX=minX, minY=minY, maxX=maxX, maxY=maxY, onScreen=anyOnScreen}
end

-- ensure UI exists for player
local function ensureESPForPlayer(p)
    if not p or not p.Character or not p.Character.PrimaryPart then return end
    if espMap[p] then return end
    local ui = createBoxUI()
    local tracer = createTracerUI()
    espMap[p] = {player = p, model = p.Character, ui = ui, tracer = tracer}
end

local function removeESPForPlayer(p)
    local data = espMap[p]
    if not data then return end
    if data.ui and data.ui.container and data.ui.container.Parent then data.ui.container:Destroy() end
    if data.tracer and data.tracer.Parent then data.tracer:Destroy() end
    espMap[p] = nil
end

local function refreshESPList()
    -- only players (no NPCs)
    for _,p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character.PrimaryPart then
            if not config.espShowTeamMates and isTeammate(p, player) then
                removeESPForPlayer(p)
            else
                ensureESPForPlayer(p)
            end
        else
            removeESPForPlayer(p)
        end
    end
    -- remove any entries for players who left
    for p,_ in pairs(espMap) do
        if not p.Parent then removeESPForPlayer(p) end
    end
end

-- update loop for ESP visuals (runs at configurable interval for performance)
spawn(function()
    while true do
        if espEnabled then
            refreshESPList()
            for p,data in pairs(espMap) do
                local model = data.model
                if model and data.ui and data.ui.container then
                    local rect = getModelScreenRect(model)
                    local ui = data.ui
                    if rect and rect.onScreen and (camera.CFrame.Position - model.PrimaryPart.Position).Magnitude <= config.espDistance then
                        local minX, minY, maxX, maxY = rect.minX, rect.minY, rect.maxX, rect.maxY
                        local w, h = math.max(4, maxX - minX), math.max(4, maxY - minY)
                        ui.container.Position = UDim2.new(0, minX, 0, minY)
                        ui.container.Size = UDim2.new(0, w, 0, h)

                        -- border thickness
                        local thickness = 2
                        ui.top.Size = UDim2.new(1,0,0,thickness); ui.top.Position = UDim2.new(0,0,0,0)
                        ui.bottom.Size = UDim2.new(1,0,0,thickness); ui.bottom.Position = UDim2.new(0,0,1,-thickness)
                        ui.left.Size = UDim2.new(0,thickness,1,0); ui.left.Position = UDim2.new(0,0,0,0)
                        ui.right.Size = UDim2.new(0,thickness,1,0); ui.right.Position = UDim2.new(1,-thickness,0,0)

                        -- team color: prefer Player.TeamColor when available
                        local color = config.espBoxColor
                        if p.TeamColor then color = p.TeamColor.Color end
                        if isTeammate(p, player) then color = Color3.fromRGB(0,255,0) end
                        ui.top.BackgroundColor3 = color
                        ui.bottom.BackgroundColor3 = color
                        ui.left.BackgroundColor3 = color
                        ui.right.BackgroundColor3 = color

                        -- name label
                        ui.nameLabel.Text = p.Name
                        ui.nameLabel.Position = UDim2.new(0,2,0,0)
                        ui.nameLabel.Size = UDim2.new(1,-4,0,18)

                        -- health
                        local humanoid = model:FindFirstChildWhichIsA("Humanoid")
                        if humanoid then
                            ui.healthBg.Position = UDim2.new(0.2,0,1,-20)
                            ui.healthBg.Size = UDim2.new(0.6,0,0,8)
                            ui.healthBg.AnchorPoint = Vector2.new(0,1)
                            ui.healthBg.Parent = ui.container
                            local pct = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
                            ui.healthFill.Size = UDim2.new(pct, 0, 1, 0)
                            if pct > 0.6 then ui.healthFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
                            elseif pct > 0.3 then ui.healthFill.BackgroundColor3 = Color3.fromRGB(255,165,0)
                            else ui.healthFill.BackgroundColor3 = Color3.fromRGB(255,0,0) end
                        else
                            ui.healthBg.Size = UDim2.new(0,0,0,0)
                        end

                        -- tracer
                        if config.tracersEnabled and data.tracer then
                            local origin
                            if config.tracerOrigin == "Center" then
                                origin = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                            else
                                origin = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                            end
                            local to = Vector2.new((minX+maxX)/2, (minY+maxY)/2)
                            local dir = to - origin
                            local angle = math.deg(math.atan2(dir.Y, dir.X))
                            local length = dir.Magnitude
                            local tracer = data.tracer
                            tracer.Visible = true
                            tracer.Size = UDim2.new(0, math.max(2, length), 0, 2)
                            tracer.Position = UDim2.new(0, origin.X - tracer.Size.X.Offset/2, 0, origin.Y - tracer.Size.Y.Offset/2)
                            tracer.Rotation = angle
                            tracer.BackgroundColor3 = color
                        elseif data.tracer then
                            data.tracer.Visible = false
                        end
                    else
                        -- not on screen or too far
                        if data.ui and data.ui.container then data.ui.container.Size = UDim2.new(0,0,0,0) end
                        if data.tracer then data.tracer.Visible = false end
                    end
                else
                    removeESPForPlayer(p)
                end
            end
        end
        if espUpdateInterval > 0 then wait(espUpdateInterval) else RunService.Heartbeat:Wait() end
    end
end)

-- Simple Studio-only aim helper: smoothly rotate camera toward nearest target head
local function getNearestTarget()
    local best, bestDist = nil, math.huge
    for p,data in pairs(espMap) do
        local model = data.model
        if model and model.PrimaryPart and data.ui and data.ui.container and data.ui.container.Size.X.Offset > 0 then
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
            if not RunService:IsStudio() then
                aimHelperEnabled = false
                warn("Aim helper disabled: only works in Studio")
                break
            end
            local target = getNearestTarget()
            if target then
                local current = camera.CFrame
                local wantLook = (target.Position - current.Position).Unit
                local lerpLook = current.LookVector:Lerp(wantLook, math.clamp(1/aimSmoothing, 0, 1))
                camera.CFrame = CFrame.new(current.Position, current.Position + lerpLook)
            end
        end
        RunService.Heartbeat:Wait()
    end
end)

-- When aim helper is toggled on, show a local system message "aimbot"
local function announceAimbot(on)
    local ok, err = pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = on and "aimbot" or "aimbot disabled"})
    end)
    if not ok then warn("Could not send system message:", err) end
end

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
espBtn.MouseButton1Click:Connect(function() if espEnabled then espEnabled = false; for k,_ in pairs(espMap) do removeESPForPlayer(k) end else espEnabled = true end end)
tracerBtn.MouseButton1Click:Connect(function() config.tracersEnabled = not config.tracersEnabled end)
settingsBtn.MouseButton1Click:Connect(function() settingsOpen = not settingsOpen settingsPanel.Visible = settingsOpen end)
aimBtn.MouseButton1Click:Connect(function() aimHelperEnabled = not aimHelperEnabled if aimHelperEnabled and not RunService:IsStudio() then aimHelperEnabled = false warn("Aim helper only available in Studio") else announceAimbot(aimHelperEnabled) end end)

-- Settings panel (hidden by default)
local settingsPanel = Instance.new("Frame")
settingsPanel.Size = UDim2.new(0, 320, 0, 260)
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
makeSlider(settingsPanel, 96, "Fly Speed", 10, 300, config.flySpeed, function(v) config.flySpeed = v end)
makeSlider(settingsPanel, 156, "ESP Distance", 100, 10000, config.espDistance, function(v) config.espDistance = v end)

-- teammate toggle
local teamToggle = Instance.new("TextButton", settingsPanel)
teamToggle.Size = UDim2.new(0, 140, 0, 28)
teamToggle.Position = UDim2.new(0, 10, 0, 200)
teamToggle.Text = (config.espShowTeamMates and "Show Teammates: ON") or "Show Teammates: OFF"
teamToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
teamToggle.TextColor3 = Color3.new(1,1,1)
teamToggle.MouseButton1Click:Connect(function()
    config.espShowTeamMates = not config.espShowTeamMates
    teamToggle.Text = (config.espShowTeamMates and "Show Teammates: ON") or "Show Teammates: OFF"
end)

-- box color presets
local presets = {
    Color3.fromRGB(255,0,0),
    Color3.fromRGB(0,255,0),
    Color3.fromRGB(0,170,255),
    Color3.fromRGB(255,200,0)
}
for i,clr in ipairs(presets) do
    local btn = Instance.new("TextButton", settingsPanel)
    btn.Size = UDim2.new(0, 36, 0, 20)
    btn.Position = UDim2.new(0, 220 + (i-1)*40, 0, 200)
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
