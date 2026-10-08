--[[
	PortalShowcase — кинематографичная анимация энергетического портала для Roblox.

	Как поставить:
	  1. Explorer > StarterPlayer > StarterPlayerScripts > (+) LocalScript
	  2. Вставь туда весь этот код
	  3. Lighting > Technology = Future (для максимального качества)
	  4. Нажми Play

	Клавиша P — повторить пролёт камеры.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- ===================== НАСТРОЙКИ =====================
local SETTINGS = {
	MainColor = Color3.fromRGB(140, 70, 255), -- основной цвет (фиолетовый)
	AccentColor = Color3.fromRGB(0, 230, 255), -- второй цвет (бирюзовый)
	Title = "P O R T A L", -- надпись во время заставки

	Distance = 35, -- расстояние от игрока до портала
	Height = 9, -- высота портала над игроком
	RingRadius = 9, -- радиус большого кольца
	RingSegments = 64, -- больше = глаже кольца
	OrbCount = 28, -- светящиеся шарики вокруг портала
	ArcCount = 5, -- молнии из ядра
	ShockwaveInterval = 4, -- раз в сколько секунд проходит волна

	CinematicDuration = 9, -- длина пролёта камеры в секундах
	ReplayKey = Enum.KeyCode.P,
	ChangeLighting = true, -- false — не менять освещение карты
}
-- =====================================================

local TAU = math.pi * 2
local WHITE = Color3.new(1, 1, 1)
-- Цилиндр в Roblox вытянут по оси X, поворачиваем его по касательной к кольцу
local SEGMENT_ROTATION = CFrame.Angles(0, 0, math.pi / 2)
local rng = Random.new()

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local function lerp(a, b, alpha)
	return a + (b - a) * alpha
end

-- Плавный разгон и плавное торможение
local function smootherstep(x)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

local function tween(instance, duration, goal)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local animation = TweenService:Create(instance, info, goal)
	animation:Play()
	return animation
end

-- Портал ставим перед игроком и разворачиваем к нему лицом
local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
if look.Magnitude < 0.01 then
	look = Vector3.new(0, 0, -1)
end
look = look.Unit
local center = rootPart.Position + look * SETTINGS.Distance + Vector3.new(0, SETTINGS.Height, 0)
local portalCFrame = CFrame.lookAt(center, center - look)

local container = Instance.new("Folder")
container.Name = "PortalShowcase"
container.Parent = Workspace

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	part.Parent = container
	return part
end

-- ===================== ОСВЕЩЕНИЕ =====================
local function getEffect(className, name)
	local effect = Lighting:FindFirstChild(name)
	if not effect then
		effect = Instance.new(className)
		effect.Name = name
		effect.Parent = Lighting
	end
	return effect
end

local bloom = getEffect("BloomEffect", "PortalBloom")
bloom.Intensity = 0.9
bloom.Size = 36
bloom.Threshold = 0.9

local depthOfField = getEffect("DepthOfFieldEffect", "PortalDepthOfField")
depthOfField.FarIntensity = 0
depthOfField.NearIntensity = 0
depthOfField.InFocusRadius = 18
depthOfField.FocusDistance = SETTINGS.Distance

if SETTINGS.ChangeLighting then
	local grading = getEffect("ColorCorrectionEffect", "PortalColorGrading")
	grading.Brightness = 0.02
	grading.Contrast = 0.18
	grading.Saturation = 0.25
	grading.TintColor = Color3.fromRGB(240, 232, 255)

	local sunRays = getEffect("SunRaysEffect", "PortalSunRays")
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.8

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(190, 160, 255)
	atmosphere.Decay = Color3.fromRGB(70, 40, 120)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	-- Закат: длинные тени и лучи солнца
	Lighting.ClockTime = 18.4
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
end

-- ===================== ПОРТАЛ =====================
-- Светящийся круг на земле под порталом
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { container, character }
local floorHit = Workspace:Raycast(center, Vector3.new(0, -200, 0), rayParams)
local floorGlow
if floorHit then
	floorGlow = makePart({
		Name = "FloorGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, SETTINGS.RingRadius * 3.5, SETTINGS.RingRadius * 3.5),
		CFrame = CFrame.new(floorHit.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = SETTINGS.MainColor,
		Transparency = 0.8,
	})
end

-- Раскалённое ядро
local core = makePart({
	Name = "Core",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 3,
	Color = WHITE,
	CFrame = portalCFrame,
})

-- Энергетическая оболочка вокруг ядра
local shell = makePart({
	Name = "Shell",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 6,
	Material = Enum.Material.ForceField,
	Color = SETTINGS.AccentColor,
	CFrame = portalCFrame,
})

-- Вращающаяся "гладь" портала внутри кольца
local vortex = makePart({
	Name = "Vortex",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.2, SETTINGS.RingRadius * 1.9, SETTINGS.RingRadius * 1.9),
	Material = Enum.Material.ForceField,
	Color = SETTINGS.MainColor,
})

local light = Instance.new("PointLight")
light.Color = SETTINGS.MainColor
light.Range = 45
light.Brightness = 4
light.Shadows = true
light.Parent = core

local coreAttachment = Instance.new("Attachment")
coreAttachment.Parent = core

local sparks = Instance.new("ParticleEmitter")
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(SETTINGS.AccentColor, SETTINGS.MainColor)
sparks.LightEmission = 1
sparks.LightInfluence = 0
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
sparks.Lifetime = NumberRange.new(1, 2.2)
sparks.Rate = 60
sparks.Speed = NumberRange.new(4, 10)
sparks.SpreadAngle = Vector2.new(180, 180)
sparks.Drag = 2
sparks.Rotation = NumberRange.new(0, 360)
sparks.RotSpeed = NumberRange.new(-180, 180)
sparks.Parent = coreAttachment

-- Мягкое туманное свечение
local nebula = Instance.new("ParticleEmitter")
nebula.Texture = "rbxasset://textures/particles/smoke_main.dds"
nebula.Color = ColorSequence.new(SETTINGS.MainColor, SETTINGS.AccentColor)
nebula.LightEmission = 1
nebula.LightInfluence = 0
nebula.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 9) })
nebula.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.75),
	NumberSequenceKeypoint.new(1, 1),
})
nebula.Lifetime = NumberRange.new(2, 3)
nebula.Rate = 12
nebula.Speed = NumberRange.new(0.5, 1.5)
nebula.SpreadAngle = Vector2.new(180, 180)
nebula.Rotation = NumberRange.new(0, 360)
nebula.RotSpeed = NumberRange.new(-30, 30)
nebula.Parent = coreAttachment

-- Три кольца-гироскопа из цилиндров, по которым бежит волна света
local ringDefs = {
	{ radius = 1.0, thickness = 0.5, spin = 0.5, tiltAxis = Vector3.new(0, 1, 0), tiltSpeed = 0 },
	{ radius = 0.78, thickness = 0.38, spin = -0.9, tiltAxis = Vector3.new(0, 1, 0), tiltSpeed = 0.6 },
	{ radius = 0.58, thickness = 0.3, spin = 1.4, tiltAxis = Vector3.new(1, 0, 0), tiltSpeed = -0.8 },
}

local rings = {}
for index, def in ringDefs do
	local radius = SETTINGS.RingRadius * def.radius
	local segmentLength = TAU * radius / SETTINGS.RingSegments * 1.25
	local segments = {}
	for i = 1, SETTINGS.RingSegments do
		segments[i] = makePart({
			Name = "RingSegment",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segmentLength, def.thickness, def.thickness),
		})
	end
	rings[index] = { def = def, radius = radius, segments = segments }
end

-- Светящиеся шарики со шлейфами, которые кружат вокруг портала
local orbs = {}
for i = 1, SETTINGS.OrbCount do
	local color = SETTINGS.MainColor:Lerp(SETTINGS.AccentColor, (i - 1) / math.max(SETTINGS.OrbCount - 1, 1))
	local orb = makePart({
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.5,
		Color = color,
	})

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.25, 0)
	top.Parent = orb
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.25, 0)
	bottom.Parent = orb
	local middle = Instance.new("Attachment")
	middle.Parent = orb

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.45
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = orb

	orbs[i] = { part = orb, attachment = middle, phase = (i - 1) / SETTINGS.OrbCount * TAU }
end

-- Молнии из ядра к случайным шарикам
local arcs = {}
for i = 1, SETTINGS.ArcCount do
	local attachment = Instance.new("Attachment")
	attachment.Parent = core

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment
	beam.Attachment1 = orbs[(i - 1) % #orbs + 1].attachment
	beam.Color = ColorSequence.new(WHITE, SETTINGS.AccentColor)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 24
	beam.Width0 = 0.35
	beam.Width1 = 0.05
	beam.Parent = core

	arcs[i] = { beam = beam, attachment = attachment }
end

-- Части, которые двигаются каждый кадр, двигаем одним вызовом BulkMoveTo — так быстрее
local movingParts = {}
local movingCFrames = {}
for _, ring in rings do
	for _, segment in ring.segments do
		table.insert(movingParts, segment)
	end
end
for _, orb in orbs do
	table.insert(movingParts, orb.part)
end

-- ===================== ИНТЕРФЕЙС ЗАСТАВКИ =====================
local gui = Instance.new("ScreenGui")
gui.Name = "PortalCinematic"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

-- Чёрные полосы сверху и снизу, как в кино
local function makeBar(anchorY)
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, anchorY)
	bar.Position = UDim2.fromScale(0, anchorY)
	bar.Size = UDim2.fromScale(1, 0)
	bar.ZIndex = 2
	bar.Parent = gui
	return bar
end
local topBar = makeBar(0)
local bottomBar = makeBar(1)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.8)
title.Size = UDim2.fromScale(0.7, 0.08)
title.Font = Enum.Font.GothamBlack
title.Text = SETTINGS.Title
title.TextScaled = true
title.TextColor3 = WHITE
title.TextTransparency = 1
title.ZIndex = 3
title.Parent = gui

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new(SETTINGS.MainColor, SETTINGS.AccentColor)
titleGradient.Parent = title

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = SETTINGS.MainColor
titleStroke.Thickness = 2
titleStroke.Transparency = 1
titleStroke.Parent = title

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(1, 1)
hint.Position = UDim2.new(1, -16, 1, -16)
hint.Size = UDim2.fromOffset(260, 24)
hint.Font = Enum.Font.GothamMedium
hint.Text = SETTINGS.ReplayKey.Name .. " — повторить заставку"
hint.TextSize = 16
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.TextColor3 = WHITE
hint.TextTransparency = 0.4
hint.Parent = gui

-- Затемнение экрана при переходе обратно к игроку
local fade = Instance.new("Frame")
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Size = UDim2.fromScale(1, 1)
fade.ZIndex = 10
fade.Parent = gui

-- ===================== ЭФФЕКТЫ =====================
local flash = 0 -- 1 сразу после волны, затухает до 0

local function shockwave()
	flash = 1
	local wave = makePart({
		Name = "Shockwave",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 4,
		Material = Enum.Material.ForceField,
		Color = SETTINGS.AccentColor,
		CFrame = portalCFrame,
	})
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local grow = TweenService:Create(wave, info, {
		Size = Vector3.one * SETTINGS.RingRadius * 6,
		Transparency = 1,
	})
	grow.Completed:Once(function()
		wave:Destroy()
	end)
	grow:Play()
end

-- ===================== КИНО-КАМЕРА =====================
local cinematicActive = false
local cinematicEnding = false
local cinematicStart = 0
local originalFieldOfView = 70

local function playCinematic()
	if cinematicActive then
		return
	end
	cinematicActive = true
	cinematicStart = os.clock()

	local camera = Workspace.CurrentCamera
	originalFieldOfView = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	hint.Visible = false
	tween(topBar, 1, { Size = UDim2.fromScale(1, 0.11) })
	tween(bottomBar, 1, { Size = UDim2.fromScale(1, 0.11) })
	tween(depthOfField, 1.5, { FarIntensity = 0.45, NearIntensity = 0.3 })
	task.delay(1.5, function()
		if cinematicActive and not cinematicEnding then
			tween(title, 1.5, { TextTransparency = 0 })
			tween(titleStroke, 1.5, { Transparency = 0.3 })
		end
	end)
	shockwave()
end

local function stopCinematic()
	if cinematicEnding then
		return
	end
	cinematicEnding = true

	task.spawn(function()
		tween(fade, 0.4, { BackgroundTransparency = 0 }).Completed:Wait()

		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = originalFieldOfView
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		cinematicActive = false
		cinematicEnding = false

		title.TextTransparency = 1
		titleStroke.Transparency = 1
		topBar.Size = UDim2.fromScale(1, 0)
		bottomBar.Size = UDim2.fromScale(1, 0)
		depthOfField.FarIntensity = 0
		depthOfField.NearIntensity = 0
		hint.Visible = true

		tween(fade, 0.6, { BackgroundTransparency = 1 })
	end)
end

-- ===================== ГЛАВНЫЙ ЦИКЛ =====================
local startTime = os.clock()
local arcTimer = 0
local shockwaveTimer = 0

local function update(dt)
	local t = os.clock() - startTime
	flash = math.max(0, flash - dt * 1.5)

	local k = 0

	-- Кольца: каждое крутится по-своему, по ним бежит волна цвета с белым "горячим" гребнем
	local pulse = 1 + math.sin(t * 2.2) * 0.04
	for ringIndex, ring in rings do
		local def = ring.def
		local ringCFrame = portalCFrame
			* CFrame.fromAxisAngle(def.tiltAxis, t * def.tiltSpeed)
			* CFrame.Angles(0, 0, t * def.spin)
		local radius = ring.radius * pulse
		for i, segment in ring.segments do
			local angle = (i - 1) / SETTINGS.RingSegments * TAU
			k += 1
			movingCFrames[k] = ringCFrame * CFrame.Angles(0, 0, angle) * CFrame.new(radius, 0, 0) * SEGMENT_ROTATION

			local wave = (math.sin(angle * 2 - t * 3 + ringIndex * 2) + 1) * 0.5
			local hot = math.max(0, (wave - 0.85) / 0.15)
			segment.Color = SETTINGS.MainColor:Lerp(SETTINGS.AccentColor, wave):Lerp(WHITE, hot * 0.8)
		end
	end

	-- Шарики: закрученный вихрь вокруг портала
	for i, orb in orbs do
		local speed = 1.1 + (i % 3) * 0.3
		local angle = t * speed + orb.phase
		local radius = SETTINGS.RingRadius * (0.75 + math.sin(t * 0.8 + orb.phase * 2) * 0.35)
		local depth = math.sin(angle * 2 + orb.phase) * 2.5
		k += 1
		movingCFrames[k] = portalCFrame * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, depth)
	end

	Workspace:BulkMoveTo(movingParts, movingCFrames, Enum.BulkMoveMode.FireCFrameChanged)

	-- Ядро, оболочка, свет
	core.Size = Vector3.one * 3 * (1 + math.sin(t * 3) * 0.1 + flash * 0.4)
	shell.Size = Vector3.one * (6 + math.sin(t * 2) * 0.6 + flash * 3)
	vortex.CFrame = portalCFrame * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(t * 0.7, 0, 0)
	light.Brightness = 4 + math.sin(t * 5) * 0.8 + flash * 12
	light.Color = SETTINGS.MainColor:Lerp(SETTINGS.AccentColor, (math.sin(t * 0.9) + 1) * 0.5)
	bloom.Intensity = 0.9 + flash * 1.5
	if floorGlow then
		floorGlow.Transparency = 0.82 - math.sin(t * 2) * 0.05 - flash * 0.3
	end

	-- Молнии мерцают и перескакивают между шариками
	arcTimer -= dt
	if arcTimer <= 0 then
		arcTimer = 0.07
		for _, arc in arcs do
			local visible = rng:NextNumber() < 0.7
			arc.beam.Enabled = visible
			if visible then
				arc.beam.Attachment1 = orbs[rng:NextInteger(1, #orbs)].attachment
				arc.attachment.Orientation = Vector3.new(rng:NextNumber(0, 360), rng:NextNumber(0, 360), 0)
				arc.beam.CurveSize0 = rng:NextNumber(-6, 6)
				arc.beam.CurveSize1 = rng:NextNumber(-4, 4)
			end
		end
	end

	shockwaveTimer += dt
	if shockwaveTimer >= SETTINGS.ShockwaveInterval then
		shockwaveTimer = 0
		shockwave()
	end

	titleGradient.Offset = Vector2.new(math.sin(t * 1.5) * 0.3, 0)

	-- Пролёт камеры: облёт по дуге с наездом, лёгкий крен и тряска от волн
	if cinematicActive then
		local camera = Workspace.CurrentCamera
		local progress = math.clamp((os.clock() - cinematicStart) / SETTINGS.CinematicDuration, 0, 1)
		local eased = smootherstep(progress)

		local orbitAngle = math.rad(lerp(-70, 60, eased))
		local distance = lerp(48, 17, eased)
		local height = lerp(14, 1, eased) + math.sin(progress * math.pi) * 3
		local cameraPosition = (portalCFrame * CFrame.Angles(0, orbitAngle, 0) * CFrame.new(0, height, -distance)).Position

		local shake = flash * 0.6
		local shakeOffset = Vector3.new(math.noise(t * 9, 1) * shake, math.noise(t * 9, 2) * shake, 0)
		local roll = math.sin(progress * math.pi) * math.rad(5)

		camera.CFrame = CFrame.lookAt(cameraPosition, center) * CFrame.new(shakeOffset) * CFrame.Angles(0, 0, roll)
		camera.FieldOfView = lerp(55, 75, eased)
		depthOfField.FocusDistance = (cameraPosition - center).Magnitude

		if progress >= 1 then
			stopCinematic()
		end
	end
end

RunService:BindToRenderStep("PortalShowcase", Enum.RenderPriority.Camera.Value + 1, update)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == SETTINGS.ReplayKey then
		playCinematic()
	end
end)

task.wait(0.5)
playCinematic()
