--[[
	RickPrimeAbilities — способности Рика Прайма из «Рика и Морти».
	Только визуальные эффекты: урона нет, эффекты видишь ты.

	Как поставить:
	  1. Explorer > StarterPlayer > StarterPlayerScripts > (+) LocalScript
	  2. Вставь ВЕСЬ этот код (последняя строка — print("[Rick Prime] ..."))
	  3. Нажми Play

	Клавиши:
	  Z — Чёрный портал: ныряешь в портал из чёрной жижи Прайма и выходишь там, куда смотрит мышка
	  X — Стоп-пули: пули замирают в воздухе, затягиваются в пистолет и летят обратно
	  C — Куато Рик: из живота вылезает мини-Рик Прайм и дважды стреляет из дробовика (7 сезон, 5 серия)
	  V — Бомба из портала: над курсором открывается портал и падает мигающая бомба
	  G — Омега-устройство (ульта): стирает ближайшего персонажа «из всех вселенных»
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- ===================== НАСТРОЙКИ =====================
local SETTINGS = {
	GooColor = Color3.fromRGB(8, 8, 12), -- чёрная портальная жижа Прайма
	GooShine = Color3.fromRGB(90, 80, 140), -- отблеск на жиже
	PortalGlow = Color3.fromRGB(140, 90, 255), -- светящийся край чёрного портала
	Accent = Color3.fromRGB(255, 70, 70), -- красный акцент (интерфейс, прицел)
	PanelColor = Color3.fromRGB(22, 20, 40), -- тёмно-синий, как куртка Прайма

	MaxAimDistance = 120, -- как далеко можно телепортироваться и кидать бомбу
	ShowSubtitles = true, -- фразы Рика внизу экрана
	CameraShake = true,

	Keys = {
		BlackPortal = Enum.KeyCode.Z,
		BulletStop = Enum.KeyCode.X,
		KuatoRick = Enum.KeyCode.C,
		PortalBomb = Enum.KeyCode.V,
		OmegaDevice = Enum.KeyCode.G,
	},
}

local ABILITIES = {
	BlackPortal = { name = "Чёрный портал", icon = "🌀", cooldown = 4, castTime = 1.1 },
	BulletStop = { name = "Стоп-пули", icon = "✋", cooldown = 8, castTime = 2.8 },
	KuatoRick = { name = "Куато Рик", icon = "🔫", cooldown = 7, castTime = 3.5 },
	PortalBomb = { name = "Бомба из портала", icon = "💣", cooldown = 10, castTime = 1 },
	OmegaDevice = { name = "Омега-устройство", icon = "Ω", cooldown = 25, castTime = 6.5 },
}
local ABILITY_ORDER = { "BlackPortal", "BulletStop", "KuatoRick", "PortalBomb", "OmegaDevice" }

local LINES = {
	BlackPortal = { "Двери — для слабаков.", "Моя жижа. Чёрная. Как моя душа.", "Ты правда думал, что я пойду пешком?" },
	BulletStop = { "Пули? Серьёзно? Мне?", "Спасибо за патроны.", "Возвращаю. Без сдачи." },
	KuatoRick = { "Знакомься: Куато Рик. Его мысли не прочитать.", "Сюрприз. Внутри меня есть ещё я.", "Он не думает. Он стреляет." },
	PortalBomb = { "Посылка через портал. Распишись.", "Бип... бип... бип...", "Я всегда захожу первым." },
	OmegaDevice = { "Омега-устройство. Тебя больше нет. Нигде.", "Стираю. Во всех вселенных сразу." },
}
-- =====================================================

local TAU = math.pi * 2
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CYLINDER_FORWARD = CFrame.Angles(0, math.pi / 2, 0) -- ось цилиндра (X) смотрит вперёд (-Z)
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"

local rng = Random.new()
local player = Players.LocalPlayer

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "RickPrimeEffects"
effectsFolder.Parent = Workspace

-- ===================== УТИЛИТЫ =====================
local function lerp(a, b, alpha)
	return a + (b - a) * alpha
end

local function easeOutBack(x)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function easeInBack(x)
	local c1 = 1.70158
	return (c1 + 1) * x ^ 3 - c1 * x ^ 2
end

local function easeOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function tween(instance, duration, goal, style, direction)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local animation = TweenService:Create(instance, info, goal)
	animation:Play()
	return animation
end

local function makePart(props, lifetime)
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
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = props.Parent or effectsFolder
	if lifetime then
		Debris:AddItem(part, lifetime)
	end
	return part
end

local function makeEmitter(parent, props)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightInfluence = 0
	for key, value in props do
		emitter[key] = value
	end
	emitter.Parent = parent
	return emitter
end

-- Выпустить частицы в точке мира (создаёт невидимого «держателя» и удаляет его потом)
local function emitAt(position, props, count)
	local holder = makePart({ Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(position) }, 6)
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	makeEmitter(attachment, props):Emit(count)
end

-- Всё, что должно обновляться каждый кадр, регистрируется здесь.
-- Функция возвращает true, пока ей нужно продолжать работать.
local updaters = {}
local function addUpdater(fn)
	table.insert(updaters, fn)
end

-- Плавно прогнать alpha от 0 до 1 за duration секунд
local function animate(duration, step)
	local start = os.clock()
	addUpdater(function(now)
		local alpha = math.clamp((now - start) / duration, 0, 1)
		step(alpha)
		return alpha < 1
	end)
end

local function getCharacterParts()
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

local function makeRayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { effectsFolder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

-- Точка в мире, куда смотрит мышка (не дальше maxDistance от персонажа)
local function getAimPoint(maxDistance)
	local camera = Workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, makeRayParams())
	local point = if result then result.Position else ray.Origin + ray.Direction * 1000
	local _, _, root = getCharacterParts()
	if root then
		local offset = point - root.Position
		if offset.Magnitude > maxDistance then
			point = root.Position + offset.Unit * maxDistance
		end
	end
	return point
end

local function findGround(position)
	local result = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), makeRayParams())
	return result and result.Position
end

-- Горизонтальное направление от персонажа к точке
local function flatDirection(from, to, fallback)
	local offset = (to - from) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.1 then
		return fallback
	end
	return offset.Unit
end

local function faceTowards(root, point)
	local direction = flatDirection(root.Position, point, nil)
	if direction then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
end

-- Высота HumanoidRootPart над землёй (разная у R6 и R15)
local function getGroundOffset(root, humanoid)
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), makeRayParams())
	if result then
		return root.Position.Y - result.Position.Y
	end
	return humanoid.HipHeight + root.Size.Y * 0.5
end

-- ===================== КАМЕРА И ЭКРАН =====================
local shakes = {}
local shakeActive = false

local function shake(intensity, duration)
	if SETTINGS.CameraShake then
		table.insert(shakes, { intensity = intensity, duration = duration, start = os.clock() })
	end
end

local function updateShake(now)
	local total = 0
	for i = #shakes, 1, -1 do
		local item = shakes[i]
		local progress = (now - item.start) / item.duration
		if progress >= 1 then
			table.remove(shakes, i)
		else
			total += item.intensity * (1 - progress) ^ 2
		end
	end
	local _, humanoid = getCharacterParts()
	if not humanoid then
		return
	end
	if total > 0 then
		humanoid.CameraOffset = Vector3.new(math.noise(now * 25, 0.3), math.noise(now * 25, 7.1), math.noise(now * 25, 13.7))
			* total
			* 2
		shakeActive = true
	elseif shakeActive then
		humanoid.CameraOffset = Vector3.zero
		shakeActive = false
	end
end

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "RickPrimeGrade"
grade.Parent = Workspace.CurrentCamera

local function screenFlash(color, brightness, fadeTime)
	grade.TintColor = color
	grade.Brightness = brightness
	tween(grade, fadeTime, { TintColor = WHITE, Brightness = 0 })
end

local defaultFieldOfView = Workspace.CurrentCamera.FieldOfView
local fovOffset = Instance.new("NumberValue")
local fovWasChanged = false

local function punchFov(amount, inTime, outTime)
	tween(fovOffset, inTime, { Value = amount }).Completed:Once(function()
		tween(fovOffset, outTime, { Value = 0 }, Enum.EasingStyle.Sine)
	end)
end

local cinematicCamera = nil -- функция, которая ставит камеру во время ульты

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if cinematicCamera then
		cinematicCamera(camera)
	end
	if fovOffset.Value ~= 0 then
		camera.FieldOfView = defaultFieldOfView + fovOffset.Value
		fovWasChanged = true
	elseif fovWasChanged then
		camera.FieldOfView = defaultFieldOfView
		fovWasChanged = false
	end
end

-- ===================== ИНТЕРФЕЙС =====================
local gui = Instance.new("ScreenGui")
gui.Name = "RickPrimeHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local hotbar = Instance.new("Frame")
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -20)
hotbar.Size = UDim2.fromOffset(5 * 78 + 4 * 8, 78)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.Padding = UDim.new(0, 8)
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

local slots = {}
for order, id in ABILITY_ORDER do
	local ability = ABILITIES[id]

	local slot = Instance.new("Frame")
	slot.Size = UDim2.fromOffset(78, 78)
	slot.BackgroundColor3 = SETTINGS.PanelColor
	slot.BackgroundTransparency = 0.1
	slot.LayoutOrder = order
	slot.Parent = hotbar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = SETTINGS.PortalGlow
	stroke.Thickness = 2
	stroke.Parent = slot

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromScale(0, 0.12)
	icon.Size = UDim2.fromScale(1, 0.5)
	icon.Font = Enum.Font.GothamBlack
	icon.Text = ability.icon
	icon.TextScaled = true
	icon.TextColor3 = WHITE
	icon.Parent = slot

	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.Position = UDim2.fromOffset(6, 3)
	keyLabel.Size = UDim2.fromOffset(20, 18)
	keyLabel.Font = Enum.Font.GothamBlack
	keyLabel.Text = SETTINGS.Keys[id].Name
	keyLabel.TextSize = 16
	keyLabel.TextColor3 = SETTINGS.Accent
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.ZIndex = 3
	keyLabel.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 1)
	nameLabel.Position = UDim2.new(0.5, 0, 1, -4)
	nameLabel.Size = UDim2.new(1, -6, 0, 24)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = ability.name
	nameLabel.TextSize = 10
	nameLabel.TextWrapped = true
	nameLabel.TextColor3 = WHITE
	nameLabel.ZIndex = 3
	nameLabel.Parent = slot

	local overlay = Instance.new("Frame")
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.BackgroundColor3 = BLACK
	overlay.BackgroundTransparency = 0.35
	overlay.ZIndex = 2
	overlay.Parent = slot
	local overlayCorner = corner:Clone()
	overlayCorner.Parent = overlay

	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Size = UDim2.fromScale(1, 0.7)
	timer.Font = Enum.Font.GothamBlack
	timer.Text = ""
	timer.TextSize = 24
	timer.TextColor3 = WHITE
	timer.TextStrokeTransparency = 0.5
	timer.ZIndex = 4
	timer.Parent = slot

	slots[id] = { stroke = stroke, overlay = overlay, timer = timer }
end

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.AnchorPoint = Vector2.new(0.5, 1)
subtitle.Position = UDim2.new(0.5, 0, 1, -112)
subtitle.Size = UDim2.new(0.8, 0, 0, 34)
subtitle.Font = Enum.Font.GothamBold
subtitle.RichText = true
subtitle.Text = ""
subtitle.TextSize = 24
subtitle.TextColor3 = WHITE
subtitle.TextStrokeTransparency = 0.3
subtitle.TextTransparency = 1
subtitle.Parent = gui

local subtitleToken = 0
local function say(text)
	if not SETTINGS.ShowSubtitles then
		return
	end
	subtitleToken += 1
	local token = subtitleToken
	subtitle.Text = '<font color="#FF5050">Рик Прайм:</font> ' .. text
	subtitle.TextTransparency = 0
	subtitle.TextStrokeTransparency = 0.3
	subtitle.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = (utf8.len(text) or #text) + 11
		for count = 1, total do
			if token ~= subtitleToken then
				return
			end
			subtitle.MaxVisibleGraphemes = count
			task.wait(0.025)
		end
		subtitle.MaxVisibleGraphemes = -1
		task.wait(2.2)
		if token == subtitleToken then
			tween(subtitle, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- Чёрные полосы для катсцены ульты
local function makeBar(anchorY)
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = BLACK
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, anchorY)
	bar.Position = UDim2.fromScale(0, anchorY)
	bar.Size = UDim2.fromScale(1, 0)
	bar.ZIndex = 8
	bar.Parent = gui
	return bar
end
local topBar = makeBar(0)
local bottomBar = makeBar(1)

local function setLetterbox(enabled)
	local height = if enabled then 0.11 else 0
	tween(topBar, 0.5, { Size = UDim2.fromScale(1, height) })
	tween(bottomBar, 0.5, { Size = UDim2.fromScale(1, height) })
	hotbar.Visible = not enabled
end

-- Большая «глючная» надпись по центру экрана
local function glitchTitle(text, duration)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromScale(0.8, 0.09)
	holder.ZIndex = 9
	holder.Parent = gui

	local layers = {}
	for index, color in { Color3.fromRGB(255, 40, 80), Color3.fromRGB(40, 220, 255), WHITE } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.TextTransparency = if index == 3 then 0 else 0.3
		label.ZIndex = 9 + index
		label.Parent = holder
		layers[index] = label
	end

	animate(duration, function(alpha)
		local strength = if alpha < 0.15 or alpha > 0.85 then 10 else 3
		layers[1].Position = UDim2.fromOffset(rng:NextNumber(-strength, strength), rng:NextNumber(-2, 2))
		layers[2].Position = UDim2.fromOffset(rng:NextNumber(-strength, strength), rng:NextNumber(-2, 2))
		local fade = if alpha > 0.8 then (alpha - 0.8) / 0.2 else 0
		for _, label in layers do
			label.TextTransparency = math.max(label.TextTransparency, fade)
		end
		if alpha >= 1 then
			holder:Destroy()
		end
	end)
end

-- Рамка «сканера» над объектом (как повязка-сканер Злого Морти)
local function scanTag(adornee, title, status, duration)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(3.4, 3.4)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = adornee
	billboard.Parent = adornee

	local brackets = {}
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		for _, horizontal in { true, false } do
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = SETTINGS.Accent
			line.AnchorPoint = corner
			line.Position = UDim2.fromScale(corner.X, corner.Y)
			line.Size = if horizontal then UDim2.fromScale(0.25, 0.025) else UDim2.fromScale(0.025, 0.25)
			line.Parent = billboard
			table.insert(brackets, line)
		end
	end

	local function makeText(text, y, height)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.fromScale(0.95, height)
		label.Font = Enum.Font.Code
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = SETTINGS.Accent
		label.TextStrokeTransparency = 0.4
		label.MaxVisibleGraphemes = 0
		label.Parent = billboard
		return label
	end
	local titleLabel = makeText(title, 0.84, 0.13)
	local statusLabel = makeText(status, 0.04, 0.09)

	animate(duration, function(alpha)
		local shown = math.floor(alpha * 60)
		titleLabel.MaxVisibleGraphemes = shown
		statusLabel.MaxVisibleGraphemes = shown
		local blink = if math.floor(alpha * duration * 8) % 2 == 0 then 0 else 0.5
		for _, line in brackets do
			line.BackgroundTransparency = blink
		end
		if alpha >= 1 then
			billboard:Destroy()
		end
	end)
end

-- ===================== ПЕРСОНАЖ =====================
local movementLocks = 0
local savedWalkSpeed = 16

local function lockMovement(duration)
	local _, humanoid = getCharacterParts()
	if not humanoid then
		return
	end
	if movementLocks == 0 then
		savedWalkSpeed = humanoid.WalkSpeed
	end
	movementLocks += 1
	humanoid.WalkSpeed = 0
	task.delay(duration, function()
		movementLocks -= 1
		if movementLocks == 0 and humanoid.Parent then
			humanoid.WalkSpeed = savedWalkSpeed
		end
	end)
end

-- Поднять руку вперёд (работает и для R6, и для R15)
local originalC0 = setmetatable({}, { __mode = "k" })
local poseTokens = setmetatable({}, { __mode = "k" })

local function poseArmForward(side, duration)
	local character = player.Character
	if not character then
		return
	end
	local motor, rotation
	local upperArm = character:FindFirstChild(side .. "UpperArm")
	if upperArm then
		motor = upperArm:FindFirstChild(side .. "Shoulder")
		rotation = CFrame.Angles(math.rad(90), 0, 0)
	else
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild(side .. " Shoulder")
		rotation = CFrame.Angles(0, 0, math.rad(if side == "Right" then 90 else -90))
	end
	if not motor or not motor:IsA("Motor6D") then
		return
	end
	local original = originalC0[motor] or motor.C0
	originalC0[motor] = original
	poseTokens[motor] = (poseTokens[motor] or 0) + 1
	local token = poseTokens[motor]
	tween(motor, 0.12, { C0 = original * rotation })
	task.delay(duration, function()
		if poseTokens[motor] == token and motor.Parent then
			tween(motor, 0.25, { C0 = original })
		end
	end)
end

local function getHand(character, side)
	local hand = character:FindFirstChild(side .. "Hand")
	if hand then
		return hand, hand.CFrame
	end
	local arm = character:FindFirstChild(side .. " Arm")
	if arm then
		return arm, arm.CFrame * CFrame.new(0, -arm.Size.Y * 0.5, 0)
	end
	return nil
end

local function getBellyCFrame(character)
	local torso = character:FindFirstChild("UpperTorso")
	if torso then
		return torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.3, -torso.Size.Z * 0.5)
	end
	torso = character:FindFirstChild("Torso")
	if torso then
		return torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.25, -torso.Size.Z * 0.5)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame * CFrame.new(0, -0.3, -0.6)
end

local function setModelHidden(model, hidden)
	local value = if hidden then 1 else 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = value
		end
	end
end

-- Подсветить персонажа, в которого попали (только визуально)
local function hitFlash(instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not model or model == player.Character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = SETTINGS.Accent
	highlight.FillTransparency = 0.2
	highlight.OutlineColor = WHITE
	highlight.Adornee = model
	highlight.Parent = effectsFolder
	tween(highlight, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, 0.4)
end

-- ===================== БАЗОВЫЕ ЭФФЕКТЫ =====================
-- Брызги жижи: маленькие капли с физикой, разлетаются и тают
local function splashGoo(position, direction, count, color)
	for _ = 1, count do
		local size = rng:NextNumber(0.2, 0.55)
		local drop = makePart({
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.SmoothPlastic,
			Color = color or SETTINGS.GooColor,
			Reflectance = 0.3,
			Size = Vector3.one * size,
			CFrame = CFrame.new(position + rng:NextUnitVector() * 0.5),
			Anchored = false,
			CanCollide = true,
			Massless = true,
		}, 2.6)
		local spread = (direction + rng:NextUnitVector() * 0.9).Unit
		drop.AssemblyLinearVelocity = spread * rng:NextNumber(12, 26) + Vector3.new(0, 8, 0)
		task.delay(1.6, function()
			if drop.Parent then
				tween(drop, 0.8, { Size = Vector3.one * 0.05 })
			end
		end)
	end
end

-- Расходящееся кольцо (плоское). Ось кольца — LookVector у cframe.
local function ripple(cframe, maxRadius, duration, color, thickness)
	local holder = makePart({ Transparency = 1, Size = Vector3.one * 0.1, CFrame = cframe }, duration + 0.2)
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = holder
	ring.Height = 0.08
	ring.Radius = 0.2
	ring.InnerRadius = 0.1
	ring.Color3 = color
	ring.Transparency = 0.1
	ring.Parent = holder
	animate(duration, function(alpha)
		local radius = math.max(0.2, maxRadius * easeOutCubic(alpha))
		ring.Radius = radius
		ring.InnerRadius = radius * (1 - (thickness or 0.12))
		ring.Transparency = 0.1 + 0.9 * alpha
	end)
end

local function groundRippleCFrame(position)
	return CFrame.lookAt(position + Vector3.new(0, 0.15, 0), position + Vector3.new(0, 10, 0), Vector3.zAxis)
end

-- Трассер пули
local function tracer(from, to, color, width)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local beam = makePart({
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = color,
	}, 0.2)
	tween(beam, 0.15, { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, length) })
end

local function impact(result, color)
	emitAt(result.Position, {
		Texture = TEX_SPARK,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new(0.35, 0),
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -40, 0),
		EmissionDirection = Enum.NormalId.Top,
	}, 8)
	-- след от пули
	local hole = makePart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(20, 18, 18),
		Size = Vector3.new(0.03, 0.28, 0.28),
		CFrame = CFrame.lookAt(result.Position, result.Position + result.Normal) * CYLINDER_FORWARD,
	}, 6)
	task.delay(4, function()
		if hole.Parent then
			tween(hole, 1.5, { Transparency = 1 })
		end
	end)
	hitFlash(result.Instance)
end

local function muzzleFlash(cframe, size)
	local flash = makePart({
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(255, 220, 120),
		Size = Vector3.one * size,
		CFrame = cframe,
	}, 0.2)
	local cone = makePart({
		Color = Color3.fromRGB(255, 170, 60),
		Size = Vector3.new(size * 0.5, size * 0.5, size * 1.8),
		CFrame = cframe * CFrame.new(0, 0, -size * 0.9),
		Transparency = 0.2,
	}, 0.2)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Brightness = 8
	light.Range = 14
	light.Parent = flash
	tween(flash, 0.08, { Size = Vector3.one * 0.05, Transparency = 1 })
	tween(cone, 0.08, { Size = Vector3.new(0.05, 0.05, size * 2.5), Transparency = 1 })
	tween(light, 0.1, { Brightness = 0 })
end

-- ===================== ЧЁРНЫЙ ПОРТАЛ ПРАЙМА =====================
-- У Рика Прайма портальная жижа чёрная (7 сезон, 5 серия)
local function openPortal(cframe, radius)
	local portal = { cframe = cframe, radius = radius, born = os.clock(), closing = false, closeStart = 0 }

	portal.glow = makePart({ Name = "PortalGlow", Shape = Enum.PartType.Cylinder, Color = SETTINGS.PortalGlow })
	portal.void = makePart({ Name = "PortalVoid", Shape = Enum.PartType.Cylinder, Color = SETTINGS.GooColor })
	portal.swirl = makePart({
		Name = "PortalSwirl",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.ForceField,
		Color = SETTINGS.GooShine,
	})
	portal.blobs = {}
	for i = 1, 16 do
		portal.blobs[i] = makePart({
			Name = "PortalGoo",
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.SmoothPlastic,
			Color = SETTINGS.GooColor,
			Reflectance = 0.25,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = SETTINGS.PortalGlow
	light.Range = radius * 4
	light.Brightness = 2
	light.Parent = portal.glow

	local allParts = { portal.glow, portal.void, portal.swirl }
	for _, blob in portal.blobs do
		table.insert(allParts, blob)
	end

	splashGoo(cframe.Position, cframe.LookVector, 10)

	addUpdater(function(now)
		local scale
		if portal.closing then
			local alpha = math.clamp((now - portal.closeStart) / 0.3, 0, 1)
			scale = 1 - easeInBack(alpha)
			if alpha >= 1 then
				for _, part in allParts do
					part:Destroy()
				end
				return false
			end
		else
			scale = easeOutBack(math.clamp((now - portal.born) / 0.45, 0, 1))
		end

		local t = now - portal.born
		local r = portal.radius * math.max(scale, 0.02)
		local diameter = 2 * r * (1 + math.sin(t * 6) * 0.03)
		local base = portal.cframe * CYLINDER_FORWARD

		portal.void.Size = Vector3.new(0.2, diameter, diameter)
		portal.void.CFrame = base
		portal.glow.Size = Vector3.new(0.1, diameter * 1.08, diameter * 1.08)
		portal.glow.CFrame = base
		portal.glow.Transparency = 0.3 + math.sin(t * 4) * 0.1
		portal.swirl.Size = Vector3.new(0.24, diameter * 0.92, diameter * 0.92)
		portal.swirl.CFrame = base * CFrame.Angles(-t * 2.5, 0, 0)

		-- Вязкий край из капель жижи
		for i, blob in portal.blobs do
			local angle = (i - 1) / #portal.blobs * TAU + t * 0.6
			local noise = math.noise(i * 1.7, t * 1.3)
			local blobRadius = r * (1 + noise * 0.08)
			blob.Size = Vector3.one * math.max(0.05, r * (0.32 + noise * 0.15))
			blob.CFrame = portal.cframe * CFrame.new(math.cos(angle) * blobRadius, math.sin(angle) * blobRadius, 0)
		end
		return true
	end)

	return portal
end

local function closePortal(portal)
	if not portal.closing then
		portal.closing = true
		portal.closeStart = os.clock()
		splashGoo(portal.cframe.Position, portal.cframe.LookVector, 6)
	end
end

-- ===================== Z: ЧЁРНЫЙ ПОРТАЛ =====================
local function blackPortal()
	local character, humanoid, root = getCharacterParts()
	if not character then
		return
	end
	local target = getAimPoint(SETTINGS.MaxAimDistance)
	local travel = flatDirection(root.Position, target, root.CFrame.LookVector * Vector3.new(1, 0, 1))
	local groundOffset = getGroundOffset(root, humanoid)
	local ground = findGround(target - travel * 1.5) or (target - travel * 1.5)
	local exitRoot = ground + Vector3.new(0, groundOffset, 0)

	faceTowards(root, root.Position + travel)
	lockMovement(1.1)
	poseArmForward("Right", 0.5)
	say(pick(LINES.BlackPortal))

	local entryCenter = root.Position + travel * 3.5 + Vector3.new(0, 0.4, 0)
	local entry = openPortal(CFrame.lookAt(entryCenter, entryCenter - travel), 3)
	local exitCenter = exitRoot + Vector3.new(0, 0.4, 0)
	local exit = openPortal(CFrame.lookAt(exitCenter, exitCenter + travel), 3)
	shake(0.15, 0.3)
	task.wait(0.35)

	-- Ныряем во входной портал
	local start = root.Position
	local entryRoot = entryCenter - Vector3.new(0, 0.4, 0) + travel * 0.5
	punchFov(14, 0.15, 0.5)
	animate(0.16, function(alpha)
		if root.Parent then
			root.CFrame = CFrame.lookAt(start:Lerp(entryRoot, alpha), start:Lerp(entryRoot, alpha) + travel)
		end
	end)
	task.wait(0.17)
	setModelHidden(character, true)
	splashGoo(entryCenter, travel, 8)
	ripple(entry.cframe, 4.5, 0.4, SETTINGS.PortalGlow)

	-- Выходим из второго портала
	local exitStart = exitRoot - travel * 1.2
	local exitEnd = exitRoot + travel * 2.5
	root.CFrame = CFrame.lookAt(exitStart, exitStart + travel)
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.05)
	setModelHidden(character, false)
	splashGoo(exitCenter, travel, 10)
	ripple(exit.cframe, 4.5, 0.4, SETTINGS.PortalGlow)
	shake(0.25, 0.35)
	animate(0.2, function(alpha)
		if root.Parent then
			local position = exitStart:Lerp(exitEnd, easeOutCubic(alpha))
			root.CFrame = CFrame.lookAt(position, position + travel)
		end
	end)
	task.wait(0.22)
	root.AssemblyLinearVelocity = Vector3.zero

	task.wait(0.2)
	closePortal(entry)
	closePortal(exit)
end

-- ===================== X: СТОП-ПУЛИ =====================
local function buildPistol(hand, gripCFrame)
	-- Ствол смотрит вдоль руки (рука поднята вперёд)
	local gunCFrame = gripCFrame * CFrame.Angles(-math.pi / 2, 0, 0)
	local metal = Color3.fromRGB(45, 45, 55)
	local pieces = {
		{ CFrame.new(0, 0.12, -0.32), Vector3.new(0.22, 0.26, 0.95), metal, Enum.Material.Metal },
		{ CFrame.new(0, 0.27, -0.32), Vector3.new(0.06, 0.05, 0.85), SETTINGS.PortalGlow, Enum.Material.Neon },
		{ CFrame.new(0, -0.16, 0.02) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(0.18, 0.48, 0.24), Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic },
	}
	local parts = {}
	for _, piece in pieces do
		local part = makePart({
			Size = Vector3.one * 0.05,
			CFrame = gunCFrame * piece[1],
			Color = piece[3],
			Material = piece[4],
			Anchored = false,
			Massless = true,
		}, 4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		tween(part, 0.15, { Size = piece[2] }, Enum.EasingStyle.Back)
		table.insert(parts, part)
	end
	return parts, parts[1]
end

local function bulletStop()
	local character, _, root = getCharacterParts()
	if not character then
		return
	end
	local aim = getAimPoint(400)
	local forward = flatDirection(root.Position, aim, root.CFrame.LookVector)
	local right = forward:Cross(Vector3.yAxis).Unit
	faceTowards(root, root.Position + forward)
	lockMovement(2.8)
	poseArmForward("Left", 1.5)
	say(pick(LINES.BulletStop))

	-- «Остановка времени» перед Праймом
	local chest = root.Position + Vector3.new(0, 1, 0)
	local fieldCFrame = CFrame.lookAt(chest + forward * 3.6, chest + forward * 10)
	for i = 0, 2 do
		task.delay(i * 0.12, function()
			ripple(fieldCFrame, 5 + i, 0.7, Color3.fromRGB(170, 210, 255), 0.06)
		end)
	end
	grade.TintColor = Color3.fromRGB(200, 220, 255)
	tween(grade, 0.3, { Saturation = -0.5, Contrast = 0.15 })

	-- Пули летят в Прайма и замирают
	local bullets = {}
	for i = 1, 6 do
		local stop = chest
			+ forward * rng:NextNumber(3.2, 4.2)
			+ right * rng:NextNumber(-1.8, 1.8)
			+ Vector3.new(0, rng:NextNumber(-0.8, 1.1), 0)
		local from = stop + forward * rng:NextNumber(45, 60) + right * rng:NextNumber(-6, 6) + Vector3.new(0, rng:NextNumber(0, 3), 0)
		local direction = (stop - from).Unit
		local bullet = makePart({
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(230, 180, 90),
			Reflectance = 0.3,
			Size = Vector3.new(0.5, 0.16, 0.16),
			CFrame = CFrame.lookAt(from, stop) * CYLINDER_FORWARD,
		}, 5)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.07, 0)
		a0.Parent = bullet
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.07, 0)
		a1.Parent = bullet
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.15
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = bullet

		local state = { phase = "flying", stop = stop, direction = direction, spin = rng:NextNumber(-3, 3) }
		bullets[i] = { part = bullet, trail = trail, state = state }
		task.delay(0.2 + i * 0.08, function()
			local flightStart = os.clock()
			addUpdater(function(now)
				if not bullet.Parent or state.phase ~= "flying" then
					return false
				end
				local alpha = math.min(1, (now - flightStart) / 0.16)
				bullet.CFrame = CFrame.lookAt(from:Lerp(stop, alpha), stop + direction) * CYLINDER_FORWARD
				if alpha >= 1 then
					state.phase = "frozen"
					state.frozenAt = now
					ripple(CFrame.lookAt(stop, stop - direction), 1.2, 0.5, Color3.fromRGB(200, 230, 255), 0.15)
					return false
				end
				return true
			end)
		end)
	end

	-- Замершие пули медленно крутятся и покачиваются
	local freezeStart = os.clock()
	addUpdater(function(now)
		local any = false
		for _, bullet in bullets do
			local state = bullet.state
			if state.phase == "frozen" and bullet.part.Parent then
				any = true
				local t = now - state.frozenAt
				local bob = Vector3.new(0, math.sin(t * 3 + state.spin) * 0.05, 0)
				bullet.part.CFrame = CFrame.lookAt(state.stop + bob, state.stop + bob + state.direction)
					* CYLINDER_FORWARD
					* CFrame.Angles(t * state.spin, 0, 0)
			end
		end
		return any or now - freezeStart < 1.5
	end)

	task.wait(1.2)

	-- Достаём пистолет и затягиваем пули в него
	poseArmForward("Right", 1.4)
	task.wait(0.14)
	local hand, grip = getHand(character, "Right")
	if not hand then
		return
	end
	local _, slide = buildPistol(hand, grip)
	task.wait(0.15)

	for _, bullet in bullets do
		bullet.state.phase = "absorbing"
		local part = bullet.part
		local startCFrame = part.CFrame
		bullet.trail.Enabled = false
		animate(0.18, function(alpha)
			if not part.Parent then
				return
			end
			local muzzle = slide.CFrame * CFrame.new(0, 0, -0.5)
			local position = startCFrame.Position:Lerp(muzzle.Position, alpha * alpha)
			part.CFrame = CFrame.lookAt(position, muzzle.Position + (muzzle.Position - startCFrame.Position)) * CYLINDER_FORWARD
			part.Size = Vector3.new(0.5, 0.16, 0.16) * (1 - alpha * 0.8)
			if alpha >= 1 then
				part:Destroy()
			end
		end)
		task.wait(0.06)
	end
	task.wait(0.2)
	tween(grade, 0.25, { Saturation = 0, Contrast = 0, TintColor = WHITE })

	-- Огонь в ответ
	local params = makeRayParams()
	for _ = 1, 6 do
		local muzzle = slide.CFrame * CFrame.new(0, 0, -0.5)
		local target = getAimPoint(400)
		local direction = (target - muzzle.Position).Unit
		direction = (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(rng:NextNumber(-0.02, 0.02), rng:NextNumber(-0.02, 0.02), 0)).LookVector
		local result = Workspace:Raycast(muzzle.Position, direction * 400, params)
		local hit = if result then result.Position else muzzle.Position + direction * 400
		muzzleFlash(CFrame.lookAt(muzzle.Position, muzzle.Position + direction), 0.7)
		tracer(muzzle.Position, hit, Color3.fromRGB(255, 230, 160), 0.1)
		if result then
			impact(result, Color3.fromRGB(255, 200, 100))
		end
		shake(0.12, 0.12)
		task.wait(0.07)
	end
end

-- ===================== C: КУАТО РИК =====================
-- Мини-мутант Рик Прайм вылезает из живота и стреляет из дробовика
local KUATO_SKIN = Color3.fromRGB(200, 190, 186) -- сероватая кожа, как у Прайма
local KUATO_FLESH = Color3.fromRGB(190, 115, 120)
local KUATO_HAIR = Color3.fromRGB(150, 172, 198)
local KUATO_MUZZLE = Vector3.new(0, 0.3, -2.85)

local function buildKuato()
	local pieces = {}
	local byName = {}
	local function add(name, localCFrame, size, props)
		props.Name = "Kuato" .. name
		props.Size = Vector3.one * 0.05
		props.Material = props.Material or Enum.Material.SmoothPlastic
		local part = makePart(props, 8)
		local piece = { part = part, cframe = localCFrame, size = size, extra = Vector3.zero }
		table.insert(pieces, piece)
		byName[name] = piece
		return piece
	end
	local function limb(name, from, to, thickness, color)
		local length = (to - from).Magnitude
		add(name, CFrame.lookAt((from + to) / 2, to) * CYLINDER_FORWARD, Vector3.new(length, thickness, thickness), {
			Shape = Enum.PartType.Cylinder,
			Color = color,
		})
	end

	-- «Дыра» в животе и стебель, которым Куато растёт из Прайма
	add("Hole", CYLINDER_FORWARD, Vector3.new(0.06, 1.15, 1.15), {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(90, 25, 35),
	})
	limb("Stalk", Vector3.new(0, 0, 0), Vector3.new(0, 0.1, -0.65), 0.55, KUATO_FLESH)
	add("Body", CFrame.new(0, 0.15, -0.78), Vector3.new(0.75, 0.72, 0.55), { Color = KUATO_SKIN })

	local headCenter = Vector3.new(0, 0.82, -0.88)
	add("Head", CFrame.new(headCenter), Vector3.one * 0.9, { Shape = Enum.PartType.Ball, Color = KUATO_SKIN })

	-- Колючие волосы Рика: два ряда шипов
	for row, backward in { 0.25, 0.95 } do
		local count = if row == 1 then 9 else 7
		for i = 1, count do
			local angle = (i - 1) / (count - 1) * math.pi - math.pi / 2
			local direction = Vector3.new(math.sin(angle), math.cos(angle) * 0.9 + 0.1, backward).Unit
			local position = headCenter + direction * 0.55
			add("Hair" .. row .. "_" .. i, CFrame.lookAt(position, position + direction), Vector3.new(0.17, 0.17, 0.5), {
				Color = KUATO_HAIR,
			})
		end
	end

	-- Глаза, моноброви и рот
	for _, side in { -1, 1 } do
		add("Eye" .. side, CFrame.new(side * 0.18, 0.88, -1.2), Vector3.one * 0.3, {
			Shape = Enum.PartType.Ball,
			Color = WHITE,
		})
		add("Pupil" .. side, CFrame.new(side * 0.16, 0.87, -1.36), Vector3.one * 0.09, {
			Shape = Enum.PartType.Ball,
			Color = BLACK,
		})
		add("Brow" .. side, CFrame.new(side * 0.13, 1.06, -1.27) * CFrame.Angles(0, 0, side * 0.28), Vector3.new(0.28, 0.07, 0.08), {
			Color = Color3.fromRGB(95, 110, 130),
		})
	end
	add("Mouth", CFrame.new(0, 0.62, -1.28) * CFrame.Angles(0, 0, 0.08), Vector3.new(0.32, 0.05, 0.05), {
		Color = Color3.fromRGB(70, 40, 45),
	})

	-- Ручки, которые держат дробовик
	limb("ArmR", Vector3.new(0.38, 0.32, -0.78), Vector3.new(0.12, 0.16, -2.05), 0.17, KUATO_SKIN)
	limb("ArmL", Vector3.new(-0.38, 0.32, -0.78), Vector3.new(-0.12, 0.2, -1.42), 0.17, KUATO_SKIN)

	-- Помповый дробовик
	local metal = Color3.fromRGB(42, 42, 48)
	local wood = Color3.fromRGB(120, 78, 48)
	add("Barrel", CFrame.new(0, 0.3, -2.05) * CYLINDER_FORWARD, Vector3.new(1.6, 0.15, 0.15), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
		Color = metal,
	})
	add("Tube", CFrame.new(0, 0.16, -1.9) * CYLINDER_FORWARD, Vector3.new(1.2, 0.12, 0.12), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
		Color = metal,
	})
	add("Pump", CFrame.new(0, 0.16, -2.1) * CYLINDER_FORWARD, Vector3.new(0.42, 0.21, 0.21), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
		Color = wood,
	})
	add("Receiver", CFrame.new(0, 0.24, -1.3), Vector3.new(0.22, 0.3, 0.5), {
		Material = Enum.Material.Metal,
		Color = metal,
	})
	add("Stock", CFrame.new(0, 0.12, -0.92) * CFrame.Angles(math.rad(-12), 0, 0), Vector3.new(0.17, 0.26, 0.6), {
		Material = Enum.Material.Wood,
		Color = wood,
	})

	return pieces, byName
end

local function placeKuato(pieces, origin, scale)
	local parts, cframes = {}, {}
	local k = math.max(scale, 0.02)
	for i, piece in pieces do
		local localPosition = (piece.cframe.Position + piece.extra) * k
		parts[i] = piece.part
		cframes[i] = origin * CFrame.new(localPosition) * piece.cframe.Rotation
		piece.part.Size = piece.size * k
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function fireShotgun(muzzle, aim)
	local direction = (aim - muzzle.Position).Unit
	local aimFrame = CFrame.lookAt(Vector3.zero, direction)
	local params = makeRayParams()
	muzzleFlash(CFrame.lookAt(muzzle.Position, muzzle.Position + direction), 1.3)
	emitAt(muzzle.Position, {
		Texture = TEX_SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(150, 150, 150)),
		Size = NumberSequence.new(0.8, 2.5),
		Transparency = NumberSequence.new(0.5, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 2, 0),
		EmissionDirection = Enum.NormalId.Front,
		Rotation = NumberRange.new(0, 360),
	}, 6)
	for _ = 1, 10 do
		local spread = (aimFrame * CFrame.Angles(rng:NextNumber(-0.09, 0.09), rng:NextNumber(-0.09, 0.09), 0)).LookVector
		local result = Workspace:Raycast(muzzle.Position, spread * 90, params)
		local hit = if result then result.Position else muzzle.Position + spread * 90
		tracer(muzzle.Position, hit, Color3.fromRGB(255, 225, 150), 0.07)
		if result then
			impact(result, Color3.fromRGB(255, 190, 90))
		end
	end
	shake(0.45, 0.35)
	punchFov(6, 0.05, 0.3)
end

local function ejectShell(cframe)
	local shell = makePart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(190, 30, 30),
		Size = Vector3.new(0.28, 0.13, 0.13),
		CFrame = cframe,
		Anchored = false,
		CanCollide = true,
		Massless = true,
	}, 2.5)
	shell.AssemblyLinearVelocity = cframe.RightVector * 9 + Vector3.new(0, 11, 0)
	shell.AssemblyAngularVelocity = rng:NextUnitVector() * 25
end

local function kuatoRick()
	local character, humanoid, root = getCharacterParts()
	if not character then
		return
	end
	local previousAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	task.delay(4, function()
		humanoid.AutoRotate = previousAutoRotate
	end)
	lockMovement(3.5)
	say(pick(LINES.KuatoRick))

	local pieces, byName = buildKuato()
	local state = { scale = 0, recoil = 0, alive = true, muzzle = CFrame.identity, aim = Vector3.zero }

	addUpdater(function(_, dt)
		if not state.alive or not character.Parent or not root.Parent then
			return false
		end
		local aim = getAimPoint(250)
		-- Прайм поворачивается к курсору
		local direction = flatDirection(root.Position, aim, nil)
		if direction then
			root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + direction), math.min(1, dt * 12))
		end
		state.recoil = math.max(0, state.recoil - dt * 6)

		local belly = getBellyCFrame(character)
		if not belly then
			return true
		end
		local aimDirection = aim - belly.Position
		aimDirection = if aimDirection.Magnitude > 1 then aimDirection.Unit else belly.LookVector
		if aimDirection:Dot(belly.LookVector) < 0.35 then
			aimDirection = belly.LookVector
		end
		local origin = CFrame.lookAt(belly.Position, belly.Position + aimDirection)
			* CFrame.new(0, 0, 0.3 * state.recoil)
			* CFrame.Angles(0.4 * state.recoil, 0, 0)
		placeKuato(pieces, origin, state.scale)
		state.muzzle = origin * CFrame.new(KUATO_MUZZLE * state.scale)
		state.aim = aim
		return true
	end)

	-- Вылезает из живота
	animate(0.45, function(alpha)
		state.scale = easeOutBack(alpha)
	end)
	local belly = getBellyCFrame(character)
	if belly then
		splashGoo(belly.Position, belly.LookVector, 10, KUATO_FLESH)
	end
	shake(0.2, 0.3)
	punchFov(8, 0.1, 0.4)
	task.wait(0.5)
	scanTag(byName.Head.part, "KUATO RICK", "МЫСЛИ НЕ ЧИТАЮТСЯ", 2.6)
	task.wait(0.3)

	local function pump()
		animate(0.3, function(alpha)
			byName.Pump.extra = Vector3.new(0, 0, 0.35 * math.sin(alpha * math.pi))
		end)
		task.delay(0.15, function()
			if state.alive then
				ejectShell(state.muzzle * CFrame.new(0, 0, 1.5))
			end
		end)
	end

	for shot = 1, 2 do
		state.recoil = 1
		fireShotgun(state.muzzle, state.aim)
		task.wait(0.4)
		pump()
		task.wait(if shot == 1 then 0.45 else 0.4)
	end

	-- Прячется обратно
	animate(0.3, function(alpha)
		state.scale = 1 - easeInBack(alpha)
	end)
	task.wait(0.32)
	state.alive = false
	for _, piece in pieces do
		piece.part:Destroy()
	end
	belly = getBellyCFrame(character)
	if belly then
		splashGoo(belly.Position, belly.LookVector, 6, KUATO_FLESH)
	end
	humanoid.AutoRotate = previousAutoRotate
end

-- ===================== V: БОМБА ИЗ ПОРТАЛА =====================
-- Так Прайм убил Диану: открыл портал и сбросил мигающую бомбу
local function explode(position, radius)
	screenFlash(Color3.fromRGB(255, 220, 180), 0.6, 0.6)
	local _, _, root = getCharacterParts()
	local distance = if root then (root.Position - position).Magnitude else 0
	shake(math.clamp(2.2 - distance / 40, 0.3, 2.2), 1.1)
	punchFov(10, 0.06, 0.6)

	local core = makePart({
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(255, 250, 230),
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position),
	}, 0.5)
	tween(core, 0.25, { Size = Vector3.one * radius * 0.9, Transparency = 1 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Brightness = 12
	light.Range = 60
	light.Parent = core
	tween(light, 0.45, { Brightness = 0 })

	-- Огненные шары, которые темнеют и превращаются в дым
	for _ = 1, 8 do
		local offset = rng:NextUnitVector() * rng:NextNumber(0, radius * 0.25)
		offset = Vector3.new(offset.X, math.abs(offset.Y), offset.Z)
		local final = radius * rng:NextNumber(0.5, 0.85)
		local ball = makePart({
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(255, 210, 90),
			Size = Vector3.one,
			CFrame = CFrame.new(position + offset),
		}, 2)
		tween(ball, 0.25, { Size = Vector3.one * final, Color = Color3.fromRGB(255, 90, 20) }, Enum.EasingStyle.Quart)
		task.delay(0.25, function()
			if ball.Parent then
				ball.Material = Enum.Material.SmoothPlastic
				tween(ball, 1.3, {
					Color = Color3.fromRGB(45, 40, 38),
					Transparency = 1,
					Size = Vector3.one * final * 1.35,
					CFrame = ball.CFrame + Vector3.new(0, radius * 0.4, 0),
				})
			end
		end)
	end

	-- Ударные волны
	local shock = makePart({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(255, 180, 100),
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position),
	}, 0.8)
	tween(shock, 0.6, { Size = Vector3.one * radius * 3, Transparency = 1 }, Enum.EasingStyle.Quint)
	ripple(groundRippleCFrame(position - Vector3.new(0, 0.9, 0)), radius * 2.2, 0.8, Color3.fromRGB(255, 200, 140), 0.08)

	emitAt(position, {
		Texture = TEX_FIRE,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)),
		LightEmission = 1,
		Size = NumberSequence.new(5, 1),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(15, 30),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
	}, 50)
	emitAt(position, {
		Texture = TEX_SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(60, 55, 52)),
		Size = NumberSequence.new(6, 14),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(2.5, 4),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
	}, 30)
	emitAt(position, {
		Texture = TEX_SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 140)),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(30, 60),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -35, 0),
		Drag = 3,
	}, 80)

	-- Обломки
	for _ = 1, 12 do
		local rock = makePart({
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(70, 66, 62),
			Size = Vector3.new(rng:NextNumber(0.4, 1.2), rng:NextNumber(0.4, 1), rng:NextNumber(0.4, 1.2)),
			CFrame = CFrame.new(position + rng:NextUnitVector() * 1.5) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0),
			Anchored = false,
			CanCollide = true,
		}, 4)
		local direction = rng:NextUnitVector()
		rock.AssemblyLinearVelocity = Vector3.new(direction.X, math.abs(direction.Y) + 0.6, direction.Z) * rng:NextNumber(30, 55)
		rock.AssemblyAngularVelocity = rng:NextUnitVector() * 15
		task.delay(3, function()
			if rock.Parent then
				tween(rock, 1, { Transparency = 1 })
			end
		end)
	end

	-- Подпалина на земле
	local ground = findGround(position)
	if ground then
		local scorch = makePart({
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(15, 12, 12),
			Transparency = 0.2,
			Size = Vector3.new(0.05, radius * 1.6, radius * 1.6),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		}, 9)
		task.delay(6, function()
			if scorch.Parent then
				tween(scorch, 2.5, { Transparency = 1 })
			end
		end)
	end
end

local function buildBomb()
	local model = Instance.new("Model")
	model.Name = "PrimeBomb"
	local body = makePart({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(55, 55, 62),
		Reflectance = 0.15,
		Size = Vector3.one * 1.8,
		Parent = model,
	})
	makePart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(30, 30, 34),
		Size = Vector3.new(0.35, 1.9, 1.9),
		CFrame = CFrame.Angles(0, 0, math.pi / 2),
		Parent = model,
	})
	local lamp = makePart({
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(80, 0, 0),
		Size = Vector3.one * 0.45,
		CFrame = CFrame.new(0, 0.85, 0),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Range = 12
	light.Brightness = 0
	light.Parent = lamp
	model.PrimaryPart = body
	model.Parent = effectsFolder
	Debris:AddItem(model, 10)
	return model, lamp, light
end

local function portalBomb()
	local character, _, root = getCharacterParts()
	if not character then
		return
	end
	local target = getAimPoint(SETTINGS.MaxAimDistance)
	local ground = findGround(target) or target
	faceTowards(root, ground)
	poseArmForward("Right", 0.6)
	say(pick(LINES.PortalBomb))

	local portalCenter = ground + Vector3.new(0, 18, 0)
	local portal = openPortal(CFrame.lookAt(portalCenter, portalCenter - Vector3.yAxis, Vector3.zAxis), 3.2)

	-- Предупреждающее кольцо на земле
	local warning = makePart({ Transparency = 1, Size = Vector3.one * 0.1, CFrame = groundRippleCFrame(ground) }, 6)
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = warning
	ring.Radius = 11
	ring.InnerRadius = 10.4
	ring.Height = 0.1
	ring.Color3 = SETTINGS.Accent
	ring.Transparency = 0.4
	ring.Parent = warning

	task.wait(0.45)
	local bomb, lamp, light = buildBomb()
	local landed = ground + Vector3.new(0, 0.9, 0)
	local fallHeight = portalCenter.Y - landed.Y
	local fallTime = math.sqrt(2 * math.max(fallHeight, 1) / 140)
	local spin = rng:NextUnitVector()
	animate(fallTime, function(alpha)
		local position = portalCenter:Lerp(landed, alpha * alpha)
		bomb:PivotTo(CFrame.new(position) * CFrame.fromAxisAngle(spin, alpha * 6))
	end)
	task.wait(fallTime)
	closePortal(portal)
	shake(0.25, 0.25)
	ripple(groundRippleCFrame(ground), 3, 0.4, Color3.fromRGB(200, 200, 200), 0.2)
	local landedCFrame = bomb:GetPivot()
	animate(0.3, function(alpha)
		bomb:PivotTo(landedCFrame + Vector3.new(0, math.sin(alpha * math.pi) * 1.2, 0))
	end)
	task.wait(0.3)
	bomb:PivotTo(CFrame.new(landed))

	-- Бип-бип-бип, всё быстрее
	for _, interval in { 0.35, 0.3, 0.25, 0.2, 0.15, 0.12, 0.09, 0.07, 0.05 } do
		lamp.Color = Color3.fromRGB(255, 40, 40)
		light.Brightness = 6
		ring.Transparency = 0.1
		task.wait(0.05)
		lamp.Color = Color3.fromRGB(80, 0, 0)
		light.Brightness = 0
		ring.Transparency = 0.5
		task.wait(interval)
	end

	bomb:Destroy()
	warning:Destroy()
	explode(landed, 14)
end

-- ===================== G: ОМЕГА-УСТРОЙСТВО =====================
-- Стирает человека из всех вселенных сразу. Жертва падает в устройство.
local function buildRing(radius, segments, thickness, color, material)
	local ring = { radius = radius, parts = {}, offsets = {}, thickness = thickness, length = TAU * radius / segments * 1.2 }
	for i = 1, segments do
		local angle = (i - 1) / segments * TAU
		ring.parts[i] = makePart({
			Name = "OmegaRing",
			Shape = Enum.PartType.Cylinder,
			Color = color,
			Material = material or Enum.Material.Neon,
			Reflectance = if material == Enum.Material.Metal then 0.3 else 0,
		}, 12)
		ring.offsets[i] = angle
	end
	return ring
end

local function placeRing(ring, cframe, scale, parts, cframes)
	local k = math.max(scale, 0.02)
	local radius = ring.radius * k
	local size = Vector3.new(ring.length * k, ring.thickness * k, ring.thickness * k)
	for i, part in ring.parts do
		part.Size = size
		table.insert(parts, part)
		table.insert(cframes, cframe * CFrame.Angles(0, 0, ring.offsets[i]) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
end

local function makeVisualClone(model)
	local wasArchivable = model.Archivable
	model.Archivable = true
	local ok, clone = pcall(function()
		return model:Clone()
	end)
	model.Archivable = wasArchivable
	if not ok or not clone then
		return nil
	end
	for _, item in clone:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("ForceField") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.LocalTransparencyModifier = 0
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.EvaluateStateMachine = false
	end
	clone.Parent = effectsFolder
	Debris:AddItem(clone, 12)
	return clone
end

local function findVictim(root)
	local best, bestDistance = nil, 90
	for _, item in Workspace:GetDescendants() do
		if item:IsA("Humanoid") and item.Health > 0 then
			local model = item.Parent
			if model and model:IsA("Model") and model ~= player.Character and not model:IsDescendantOf(effectsFolder) then
				local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
				if part and part:IsA("BasePart") then
					local distance = (part.Position - root.Position).Magnitude
					if distance < bestDistance then
						best, bestDistance = model, distance
					end
				end
			end
		end
	end
	return best
end

local function omegaDevice()
	local character, _, root = getCharacterParts()
	if not character then
		return
	end
	local aim = getAimPoint(400)
	local forward = flatDirection(root.Position, aim, root.CFrame.LookVector * Vector3.new(1, 0, 1))
	faceTowards(root, root.Position + forward)
	lockMovement(6.5)
	poseArmForward("Right", 1)
	say(pick(LINES.OmegaDevice))

	-- Жертва: ближайший персонаж. Если никого нет — приманка-клон самого Прайма.
	local target = findVictim(root)
	local victim
	if target then
		victim = makeVisualClone(target)
		setModelHidden(target, true)
	else
		victim = makeVisualClone(character)
		if victim then
			local spot = root.Position + forward * 16
			victim:PivotTo(CFrame.lookAt(spot, spot - forward))
		end
	end

	local deviceCenter = root.Position + forward * 11 + Vector3.new(0, 4.5, 0)
	local deviceCFrame = CFrame.lookAt(deviceCenter, deviceCenter - forward)
	splashGoo(deviceCenter, Vector3.yAxis, 18)

	local outer = buildRing(6, 36, 0.9, Color3.fromRGB(60, 60, 72), Enum.Material.Metal)
	local trim = buildRing(6.7, 36, 0.18, SETTINGS.PortalGlow)
	local inner = {
		buildRing(4.6, 32, 0.3, Color3.fromRGB(235, 230, 255)),
		buildRing(3.6, 28, 0.25, Color3.fromRGB(235, 230, 255)),
		buildRing(2.6, 24, 0.2, Color3.fromRGB(235, 230, 255)),
	}
	local coreBall = makePart({ Name = "OmegaCore", Shape = Enum.PartType.Ball, Color = WHITE, Size = Vector3.one * 0.1, CFrame = deviceCFrame }, 12)
	local coreShell = makePart({
		Name = "OmegaShell",
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Color = SETTINGS.PortalGlow,
		Size = Vector3.one * 0.1,
		CFrame = deviceCFrame,
	}, 12)
	local coreLight = Instance.new("PointLight")
	coreLight.Color = WHITE
	coreLight.Range = 35
	coreLight.Brightness = 3
	coreLight.Parent = coreBall

	local device = { scale = 0, charge = 0, alive = true, born = os.clock() }
	addUpdater(function(now)
		if not device.alive then
			return false
		end
		local t = now - device.born
		local parts, cframes = {}, {}
		placeRing(outer, deviceCFrame * CFrame.Angles(0, 0, t * 0.2), device.scale, parts, cframes)
		placeRing(trim, deviceCFrame * CFrame.Angles(0, 0, -t * 0.4), device.scale, parts, cframes)
		local speed = 1 + device.charge * 4
		placeRing(inner[1], deviceCFrame * CFrame.Angles(t * speed, 0, 0), device.scale, parts, cframes)
		placeRing(inner[2], deviceCFrame * CFrame.Angles(0, t * speed * 1.3, 0), device.scale, parts, cframes)
		placeRing(inner[3], deviceCFrame * CFrame.Angles(t * speed * 0.8, t * speed, 0), device.scale, parts, cframes)
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		local pulse = 1 + math.sin(t * 10) * 0.08 * device.charge
		coreBall.Size = Vector3.one * math.max(0.05, 1.6 * device.scale * pulse * (1 + device.charge * 0.5))
		coreShell.Size = Vector3.one * math.max(0.05, 3.4 * device.scale * pulse)
		coreLight.Brightness = 3 + device.charge * 8
		return true
	end)

	-- Кинокамера
	local orbitStart = os.clock()
	cinematicCamera = function(camera)
		camera.CameraType = Enum.CameraType.Scriptable
		local alpha = math.clamp((os.clock() - orbitStart) / 6, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		local angle = math.rad(lerp(-40, 55, eased))
		local distance = lerp(22, 15, eased)
		local position = (deviceCFrame * CFrame.Angles(0, angle, 0) * CFrame.new(0, lerp(5, 2, eased), -distance)).Position
		camera.CFrame = CFrame.lookAt(position, deviceCenter)
	end
	setLetterbox(true)
	tween(grade, 0.6, { Saturation = -0.6, Contrast = 0.25, TintColor = Color3.fromRGB(225, 220, 255) })

	-- Сборка устройства
	animate(0.9, function(alpha)
		device.scale = easeOutBack(alpha)
	end)
	shake(0.4, 0.8)
	task.wait(1)

	-- Жертву поднимает и затягивает в ядро
	local victimStart = if victim then victim:GetPivot() else nil
	local ghosts = {}
	if victim and victimStart then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = WHITE
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = SETTINGS.PortalGlow
		highlight.Adornee = victim
		highlight.Parent = victim

		-- «Все версии этого персонажа во всех вселенных»
		for i = 1, 8 do
			local ghost = victim:Clone()
			for _, item in ghost:GetDescendants() do
				if item:IsA("BasePart") then
					item.Material = Enum.Material.ForceField
					item.Color = Color3.fromHSV((i - 1) / 8, 0.6, 1)
				elseif item:IsA("Decal") or item:IsA("Highlight") then
					item:Destroy()
				end
			end
			local angle = (i - 1) / 8 * TAU
			local spot = deviceCenter + deviceCFrame.RightVector * math.cos(angle) * 13 + Vector3.new(0, math.sin(angle) * 6, 0)
			ghost:PivotTo(CFrame.lookAt(spot, deviceCenter))
			ghost.Parent = effectsFolder
			Debris:AddItem(ghost, 8)
			ghosts[i] = { model = ghost, start = ghost:GetPivot() }
		end

		animate(2.2, function(alpha)
			if not victim.Parent then
				return
			end
			local eased = alpha * alpha
			local lift = victimStart.Position + Vector3.new(0, 3 * math.min(alpha * 4, 1), 0)
			local position = lift:Lerp(deviceCenter, eased)
			local jitter = rng:NextUnitVector() * 0.15 * alpha
			victim:PivotTo(CFrame.lookAt(position + jitter, deviceCenter) * CFrame.Angles(0, 0, alpha * 4))
			for _, ghost in ghosts do
				if ghost.model.Parent then
					local ghostPosition = ghost.start.Position:Lerp(deviceCenter, eased)
					ghost.model:PivotTo(CFrame.lookAt(ghostPosition, deviceCenter) * CFrame.Angles(0, 0, -alpha * 6))
				end
			end
			device.charge = alpha
		end)
		task.delay(1.2, function()
			for step = 1, 6 do
				if victim.Parent then
					victim:ScaleTo(math.max(0.1, 1 - step * 0.15))
				end
				for _, ghost in ghosts do
					if ghost.model.Parent then
						ghost.model:ScaleTo(math.max(0.1, 1 - step * 0.15))
					end
				end
				task.wait(0.16)
			end
		end)
	end
	task.wait(2.25)

	-- СТИРАНИЕ
	if victim then
		victim:Destroy()
	end
	for _, ghost in ghosts do
		if ghost.model.Parent then
			ghost.model:Destroy()
		end
	end
	screenFlash(WHITE, 1, 0.9)
	shake(1.6, 1)
	punchFov(-12, 0.05, 0.8)
	glitchTitle("СТЁРТ ИЗ ВСЕХ ВСЕЛЕННЫХ", 2.4)
	for i = 0, 3 do
		task.delay(i * 0.1, function()
			ripple(deviceCFrame, 10 + i * 6, 0.9, WHITE, 0.05)
		end)
	end
	emitAt(deviceCenter, {
		Texture = TEX_SPARK,
		Color = ColorSequence.new(WHITE, SETTINGS.PortalGlow),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(20, 45),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
	}, 120)
	local pillar = makePart({
		Shape = Enum.PartType.Cylinder,
		Color = WHITE,
		Size = Vector3.new(400, 3, 3),
		CFrame = CFrame.new(deviceCenter + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	}, 1.5)
	tween(pillar, 1.2, { Size = Vector3.new(400, 0.2, 0.2), Transparency = 1 })
	device.charge = 0

	task.wait(1.6)
	-- Устройство схлопывается в чёрную жижу
	animate(0.5, function(alpha)
		device.scale = 1 - easeInBack(alpha)
	end)
	task.wait(0.5)
	splashGoo(deviceCenter, Vector3.yAxis, 16)
	device.alive = false
	for _, ring in { outer, trim, inner[1], inner[2], inner[3] } do
		for _, part in ring.parts do
			part:Destroy()
		end
	end
	coreBall:Destroy()
	coreShell:Destroy()

	cinematicCamera = nil
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	setLetterbox(false)
	tween(grade, 0.6, { Saturation = 0, Contrast = 0, TintColor = WHITE })

	-- Эффекты не наносят урона, поэтому через пару секунд «стёртый» возвращается
	if target then
		task.delay(2.5, function()
			for _ = 1, 5 do
				if not target.Parent then
					return
				end
				setModelHidden(target, false)
				task.wait(0.06)
				setModelHidden(target, true)
				task.wait(0.06)
			end
			setModelHidden(target, false)
		end)
	end
end

-- ===================== ЗАПУСК =====================
ABILITIES.BlackPortal.run = blackPortal
ABILITIES.BulletStop.run = bulletStop
ABILITIES.KuatoRick.run = kuatoRick
ABILITIES.PortalBomb.run = portalBomb
ABILITIES.OmegaDevice.run = omegaDevice

local cooldownEnds = {}
local busyUntil = 0

local function tryCast(id)
	local ability = ABILITIES[id]
	local now = os.clock()
	if now < busyUntil or not getCharacterParts() then
		return
	end
	if now < (cooldownEnds[id] or 0) then
		local stroke = slots[id].stroke
		stroke.Color = SETTINGS.Accent
		tween(stroke, 0.3, { Color = SETTINGS.PortalGlow })
		return
	end
	cooldownEnds[id] = now + ability.cooldown
	busyUntil = now + ability.castTime
	task.spawn(function()
		local ok, err = pcall(ability.run)
		if not ok then
			warn("[Rick Prime] Ошибка в способности " .. id .. ": " .. tostring(err))
			if cinematicCamera then
				cinematicCamera = nil
				Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				setLetterbox(false)
			end
		end
	end)
end

local keyToAbility = {}
for id, key in SETTINGS.Keys do
	keyToAbility[key] = id
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local id = keyToAbility[input.KeyCode]
	if id then
		tryCast(id)
	end
end)

local function updateHotbar(now)
	for id, slot in slots do
		local ability = ABILITIES[id]
		local remaining = math.max(0, (cooldownEnds[id] or 0) - now)
		slot.overlay.Size = UDim2.fromScale(1, remaining / ability.cooldown)
		slot.timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
		slot.stroke.Transparency = if remaining > 0 then 0.6 else 0.1 + math.sin(now * 3) * 0.1
	end
end

RunService:BindToRenderStep("RickPrimeAbilities", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	for i = #updaters, 1, -1 do
		local ok, keep = pcall(updaters[i], now, dt)
		if not ok then
			warn("[Rick Prime] " .. tostring(keep))
			table.remove(updaters, i)
		elseif not keep then
			table.remove(updaters, i)
		end
	end
	updateShake(now)
	updateCamera()
	updateHotbar(now)
end)

print("[Rick Prime] Способности загружены: Z — портал, X — стоп-пули, C — Куато Рик, V — бомба, G — Омега-устройство")
