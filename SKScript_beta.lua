--[[ 
  Script de Assistência Inteligente - Refatorado do Zero
  Modos: Nada | Full Legit | Legit | Semi | Rage
  Funções: Aimbot (com wallcheck, headshot-only), AutoFire inteligente, ESP, No Recoil, FOV, Charms
--]]

--// Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

--// Variáveis locais
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// Configuração geral
local settings = {
    mode = "Nada",
    aimbot = {
        enabled = false,
        smoothness = 25,
        fov = 60,
        aimlock = false,
        wallcheck = false,
        headshotOnly = true
    },
    autoFire = {
        enabled = false,
        fov = 5,
        range = 100,
        delay = 0.15,
        headshotOnly = true,
        penetrateWalls = true
    },
    esp = {
        enabled = false,
        thickness = 2,
        allyColor = Color3.fromRGB(0, 255, 0),
        enemyColor = Color3.fromRGB(255, 0, 0)
    },
    charms = {
        enabled = false
    },
    visuals = {
        showFOV = false
    },
    noRecoil = false
}

--// Reset das funções a cada troca de modo
local function resetSettings()
    for group, config in pairs(settings) do
        if type(config) == "table" then
            for k in pairs(config) do
                settings[group][k] = false
            end
        end
    end
end

--// Aplicar modo
local function applyMode(mode)
    resetSettings()
    settings.mode = mode

    if mode == "Nada" then
        -- tudo desativado

    elseif mode == "Full Legit" then
        settings.aimbot.enabled = true
        settings.aimbot.smoothness = 60
        settings.aimbot.fov = 25

        settings.autoFire.enabled = true
        settings.autoFire.fov = 3
        settings.autoFire.range = 70
        settings.autoFire.delay = 0.3

    elseif mode == "Legit" then
        settings.aimbot.enabled = true
        settings.aimbot.smoothness = 40
        settings.aimbot.fov = 35

        settings.autoFire.enabled = true
        settings.autoFire.fov = 4
        settings.autoFire.range = 80

        settings.esp.enabled = true
        settings.charms.enabled = true

    elseif mode == "Semi" then
        settings.aimbot.enabled = true
        settings.aimbot.smoothness = 20
        settings.aimbot.fov = 45
        settings.aimbot.wallcheck = true

        settings.autoFire.enabled = true
        settings.autoFire.fov = 3
        settings.autoFire.range = 100

        settings.esp.enabled = true
        settings.charms.enabled = true
        settings.visuals.showFOV = true

    elseif mode == "Rage" then
        settings.aimbot.enabled = true
        settings.aimbot.smoothness = 0
        settings.aimbot.fov = 360
        settings.aimbot.aimlock = true
        settings.aimbot.wallcheck = true

        settings.autoFire.enabled = true
        settings.autoFire.fov = 999
        settings.autoFire.range = 999
        settings.autoFire.delay = 0.05

        settings.esp.enabled = true
        settings.charms.enabled = true
        settings.visuals.showFOV = true
    end

    print("[Modo aplicado]:", mode)
end

---------------------------------------------------------------- Pt 2

--// Último tiro
local lastShot = 0

--// Função: Verifica se pode ver a cabeça (wallcheck com raycast)
local function canSee(targetHead)
	if not settings.aimbot.wallcheck then return true end

	local origin = Camera.CFrame.Position
	local direction = (targetHead.Position - origin).Unit * 1000

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

	local result = Workspace:Raycast(origin, direction, rayParams)

	if not result then return true end
	return result.Instance:IsDescendantOf(targetHead.Parent)
end

--// Função: Seleciona o melhor inimigo baseado na FOV da tela
local function getBestTarget()
	local closest = nil
	local closestDist = math.huge
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team and player.Character then
			local head = player.Character:FindFirstChild("Head")
			local hum = player.Character:FindFirstChildOfClass("Humanoid")

			if head and hum and hum.Health > 0 then
				local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
				if onScreen and canSee(head) then
					local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
					if distFromCenter < settings.aimbot.fov and distFromCenter < closestDist then
						closestDist = distFromCenter
						closest = player
					end
				end
			end
		end
	end

	return closest
end

--// Função: Move o mouse suavemente até a cabeça do alvo
local function aimAt(headPos)
	local screenPos = Camera:WorldToViewportPoint(headPos)
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local delta = Vector2.new(screenPos.X, screenPos.Y) - screenCenter

	if settings.aimbot.smoothness <= 0 then
		mousemoverel(delta.X, delta.Y)
	else
		mousemoverel(delta.X / settings.aimbot.smoothness, delta.Y / settings.aimbot.smoothness)
	end
end

--// Função: AutoFire apenas se mira está bem precisa na cabeça
local function shouldShoot(head)
	local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
	if not onScreen then return false end

	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude

	if dist <= settings.autoFire.fov then
		if settings.autoFire.penetrateWalls or canSee(head) then
			return true
		end
	end

	return false
end

--// Loop principal de mira e tiro
RunService.RenderStepped:Connect(function()
	if not settings.aimbot.enabled then return end

	local target = getBestTarget()
	if target and target.Character and target.Character:FindFirstChild("Head") then
		local head = target.Character.Head
		aimAt(head.Position)

		-- AutoFire
		if settings.autoFire.enabled and tick() - lastShot >= settings.autoFire.delay then
			if shouldShoot(head) then
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
				task.wait(0.05)
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
				lastShot = tick()
			end
		end
	end
end)

------------------------------------------------------- Pt 3

--// Tabelas de desenho por jogador
local espObjects = {}

--// Cria elementos ESP pro jogador
local function createESP(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = settings.esp.thickness
    box.Filled = false

    local nameTag = Drawing.new("Text")
    nameTag.Visible = false
    nameTag.Size = 14
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Font = 2

    espObjects[player] = {
        box = box,
        name = nameTag
    }
end

--// Remove ESP ao sair
local function removeESP(player)
    if espObjects[player] then
        espObjects[player].box:Remove()
        espObjects[player].name:Remove()
        espObjects[player] = nil
    end
end

--// Conecta jogadores existentes e novos
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        createESP(p)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then createESP(p) end
end)

Players.PlayerRemoving:Connect(removeESP)

--// Render ESP na tela
RunService.RenderStepped:Connect(function()
    for player, drawings in pairs(espObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if settings.esp.enabled and hrp and hum and hum.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

            if onScreen then
                local height = 100
                local width = 50
                local boxPos = Vector2.new(pos.X - width / 2, pos.Y - height / 2)

                drawings.box.Size = Vector2.new(width, height)
                drawings.box.Position = boxPos
                drawings.box.Color = player.Team == LocalPlayer.Team and settings.esp.allyColor or settings.esp.enemyColor
                drawings.box.Visible = true

                if settings.charms.enabled then
                    drawings.name.Text = player.Name .. " [" .. math.floor(hum.Health) .. "]"
                    drawings.name.Position = Vector2.new(pos.X, boxPos.Y - 15)
                    drawings.name.Color = drawings.box.Color
                    drawings.name.Visible = true
                else
                    drawings.name.Visible = false
                end
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
            end
        else
            drawings.box.Visible = false
            drawings.name.Visible = false
        end
    end
end)

------------------------------------------ Pt 4

--// Círculo do FOV
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 0, 0)
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Visible = false

--// Atualização no loop
RunService.RenderStepped:Connect(function()
	if settings.showFOV and settings.aimbot.enabled then
		fovCircle.Radius = settings.aimbot.fov
		fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end
end)

--------------------------------------- Pt 5

--// GUI principal
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimAssistUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

--// Frame de fundo
local frame = Instance.new("Frame", ScreenGui)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Position = UDim2.new(0, 20, 0.4, 0)
frame.Size = UDim2.new(0, 160, 0, 250)
frame.Active = true
frame.Draggable = true
frame.BorderSizePixel = 0

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 6)

--// Layout dos botões
local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 6)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top

--// Função para criar botão de modo
local function createModeButton(name, mode)
	local button = Instance.new("TextButton", frame)
	button.Size = UDim2.new(1, -20, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Font = Enum.Font.SourceSansBold
	button.Text = name
	button.AutoButtonColor = true

	local bcorner = Instance.new("UICorner", button)
	bcorner.CornerRadius = UDim.new(0, 4)

	button.MouseButton1Click:Connect(function()
		_G.ApplyMode(mode)
	end)
end

--// Botões para os modos
createModeButton("Nada", "Nada")
createModeButton("Full Legit", "Full Legit")
createModeButton("Legit", "Legit")
createModeButton("Semi", "Semi")
createModeButton("Rage", "Rage")

--// Toggle da UI com RightShift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)

--------------------------------------------- Pt 6

-- Variável global para configurações
_G.Settings = {
    currentMode = "Nada",
    aimbot = {
        enabled = false,
        smooth = 0,
        fov = 0,
        aimlock = false,
        wallcheck = false,
    },
    autoFire = {
        enabled = false,
        fov = 0,
        range = 0,
        delay = 0,
    },
    esp = {
        enabled = false,
        allyColor = Color3.fromRGB(0, 255, 0),
        enemyColor = Color3.fromRGB(255, 0, 0),
        boxThickness = 2,
    },
    charms = {
        enabled = false,
    },
    showFOV = false,
    noRecoil = false,
    grenadeHelper = false,
}

-- Função para resetar configurações para "Nada"
local function resetSettings()
    local s = _G.Settings
    s.aimbot.enabled = false
    s.aimbot.smooth = 0
    s.aimbot.fov = 0
    s.aimbot.aimlock = false
    s.aimbot.wallcheck = false
    s.autoFire.enabled = false
    s.autoFire.fov = 0
    s.autoFire.range = 0
    s.autoFire.delay = 0
    s.esp.enabled = false
    s.charms.enabled = false
    s.showFOV = false
    s.noRecoil = false
    s.grenadeHelper = false
end

-- Função para aplicar modo
function _G.ApplyMode(mode)
    resetSettings()
    local s = _G.Settings
    s.currentMode = mode

    if mode == "Nada" then
        -- Tudo desligado (padrão)
        print("[Modo] Nada ativado: Tudo desligado.")

    elseif mode == "Full Legit" then
        s.aimbot.enabled = true
        s.aimbot.smooth = 80
        s.aimbot.fov = 30
        s.aimbot.aimlock = false
        s.aimbot.wallcheck = false

        s.autoFire.enabled = true
        s.autoFire.fov = 10
        s.autoFire.range = 70
        s.autoFire.delay = 0.3

        print("[Modo] Full Legit ativado.")

    elseif mode == "Legit" then
        s.aimbot.enabled = true
        s.aimbot.smooth = 50
        s.aimbot.fov = 30
        s.aimbot.aimlock = false
        s.aimbot.wallcheck = false

        s.autoFire.enabled = true
        s.autoFire.fov = 8
        s.autoFire.range = 70
        s.autoFire.delay = 0.25

        s.esp.enabled = true
        s.charms.enabled = true

        print("[Modo] Legit ativado.")

    elseif mode == "Semi" then
        s.aimbot.enabled = true
        s.aimbot.smooth = 15
        s.aimbot.fov = 60
        s.aimbot.aimlock = false
        s.aimbot.wallcheck = true

        s.autoFire.enabled = true
        s.autoFire.fov = 5
        s.autoFire.range = 80
        s.autoFire.delay = 0.15

        s.esp.enabled = true
        s.charms.enabled = true

        print("[Modo] Semi ativado.")

    elseif mode == "Rage" then
        s.aimbot.enabled = true
        s.aimbot.smooth = 0
        s.aimbot.fov = 360
        s.aimbot.aimlock = true
        s.aimbot.wallcheck = true

        s.autoFire.enabled = true
        s.autoFire.fov = 3
        s.autoFire.range = 100
        s.autoFire.delay = 0.1

        s.esp.enabled = true
        s.charms.enabled = true

        s.showFOV = true
        s.grenadeHelper = true

        print("[Modo] Rage ativado.")

    else
        warn("Modo desconhecido:", mode)
    end
end

--------------------------------------------------- Pt 7

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local lastFire = 0
local damagePerShot = 35 -- Supondo que um tiro na cabeça dá 35 de dano

-- Função para checar se o local está visível (wallcheck)
local function canSeeHead(head)
    if not _G.Settings.aimbot.wallcheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (head.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    return raycastResult and raycastResult.Instance and raycastResult.Instance:IsDescendantOf(head.Parent)
end

-- Função pra pegar melhor alvo pra aimbot / autofire
local function getBestTarget()
    local bestTarget = nil
    local bestDistance = math.huge
    local settings = _G.Settings

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team then
            local character = player.Character
            if character then
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChild("Humanoid")
                if head and humanoid and humanoid.Health > 0 then
                    local distance3D = (head.Position - Camera.CFrame.Position).Magnitude
                    if distance3D <= settings.autoFire.range then
                        if canSeeHead(head) then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                            if onScreen then
                                local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                                local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                                local distance2D = (mousePos - targetPos).Magnitude

                                if distance2D <= settings.aimbot.fov and distance3D < bestDistance then
                                    bestDistance = distance3D
                                    bestTarget = character
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

-- Loop principal
RunService.RenderStepped:Connect(function()
    local s = _G.Settings

    -- Desenhar FOV circle se ativado
    if s.showFOV then
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Color = Color3.new(1, 0, 0)
            fovCircle.Thickness = 1
            fovCircle.NumSides = 32
            fovCircle.Filled = false
        end
        fovCircle.Radius = s.aimbot.fov
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
        fovCircle.Visible = true
    else
        if fovCircle then
            fovCircle.Visible = false
        end
    end

    -- Verifica se aimbot ativado
    if s.aimbot.enabled and LocalPlayer.Character then
        local target = getBestTarget()
        if target then
            local head = target:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local dx = screenPos.X - center.X
                    local dy = screenPos.Y - center.Y

                    -- Move o mouse suavemente ou direto dependendo do smooth
                    if s.aimbot.smooth > 0 then
                        mousemoverel(dx / s.aimbot.smooth, dy / s.aimbot.smooth)
                    else
                        mousemoverel(dx, dy)
                    end

                    -- Auto Fire - só dispara se o alvo estiver dentro do fov de autofire, com linha de visão limpa e vida baixa o suficiente pra matar com 1 tiro na cabeça
                    if s.autoFire.enabled then
                        local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                        local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                        local distToTarget = (mousePos - targetPos).Magnitude

                        local humanoid = target:FindFirstChild("Humanoid")
                        if humanoid and distToTarget <= s.autoFire.fov and tick() - lastFire >= s.autoFire.delay then
                            if canSeeHead(head) and humanoid.Health <= damagePerShot then
                                -- Atira
                                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 1)
                                wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
                                lastFire = tick()
                            end
                        end
                    end
                end
            end
        end
    end
end)

------------------------------------------------ Pt 8

local Drawing = Drawing -- já definido no ambiente do Roblox Exploit

local espBoxes = {}
local espTexts = {}

-- Função para criar as peças de ESP para cada jogador
local function createESPForPlayer(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Filled = false
    box.Thickness = _G.Settings.esp.boxThickness
    box.Color = Color3.new(1, 0, 0) -- padrão vermelho (inimigo)

    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Size = 14
    text.Color = box.Color
    text.Text = player.Name

    espBoxes[player] = box
    espTexts[player] = text
end

-- Remove ESP ao sair do jogo
local function removeESPForPlayer(player)
    if espBoxes[player] then
        espBoxes[player]:Remove()
        espBoxes[player] = nil
    end
    if espTexts[player] then
        espTexts[player]:Remove()
        espTexts[player] = nil
    end
end

-- Cria ESP para todos jogadores atuais e escuta novos jogadores
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESPForPlayer(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createESPForPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(removeESPForPlayer)

-- Atualiza as posições e visibilidade da ESP todo frame
RunService.RenderStepped:Connect(function()
    if not _G.Settings.esp.enabled then
        for player, box in pairs(espBoxes) do
            box.Visible = false
        end
        for player, text in pairs(espTexts) do
            text.Visible = false
        end
        return
    end

    for player, box in pairs(espBoxes) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local text = espTexts[player]

        if humanoid and humanoid.Health > 0 and rootPart then
            local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local size = Vector2.new(50, 100) -- tamanho padrão da caixa
                local boxPos = Vector2.new(pos.X - size.X/2, pos.Y - size.Y/2)

                -- Cor baseado no time (aliado verde, inimigo vermelho)
                if player.Team == LocalPlayer.Team then
                    box.Color = _G.Settings.esp.allyColor
                    text.Color = _G.Settings.esp.allyColor
                else
                    box.Color = _G.Settings.esp.enemyColor
                    text.Color = _G.Settings.esp.enemyColor
                end

                box.Position = boxPos
                box.Size = size
                box.Visible = true

                text.Text = string.format("%s [%d]", player.Name, math.floor(humanoid.Health))
                text.Position = Vector2.new(boxPos.X + size.X/2, boxPos.Y - 15)
                text.Visible = true
            else
                box.Visible = false
                text.Visible = false
            end
        else
            box.Visible = false
            text.Visible = false
        end
    end
end)


------------------------------------ Pt 9

local charmsBars = {}

local function createCharmForPlayer(player)
    local barBackground = Drawing.new("Square")
    barBackground.Filled = true
    barBackground.Color = Color3.fromRGB(0, 0, 0)
    barBackground.Transparency = 0.5
    barBackground.Thickness = 1
    barBackground.Visible = false

    local barHealth = Drawing.new("Square")
    barHealth.Filled = true
    barHealth.Color = Color3.fromRGB(0, 255, 0) -- verde da vida
    barHealth.Visible = false

    charmsBars[player] = {
        background = barBackground,
        health = barHealth
    }
end

local function removeCharmForPlayer(player)
    if charmsBars[player] then
        charmsBars[player].background:Remove()
        charmsBars[player].health:Remove()
        charmsBars[player] = nil
    end
end

-- Criar charms para jogadores existentes
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createCharmForPlayer(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createCharmForPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(removeCharmForPlayer)

-- Atualizar charms todo frame
RunService.RenderStepped:Connect(function()
    if not _G.Settings.charms.enabled then
        for _, charm in pairs(charmsBars) do
            charm.background.Visible = false
            charm.health.Visible = false
        end
        return
    end

    for player, charm in pairs(charmsBars) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local head = character and character:FindFirstChild("Head")
        if humanoid and humanoid.Health > 0 and head then
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            if onScreen then
                local barWidth = 50
                local barHeight = 5

                local healthRatio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

                local pos2d = Vector2.new(pos.X - barWidth/2, pos.Y)

                charm.background.Position = pos2d
                charm.background.Size = Vector2.new(barWidth, barHeight)
                charm.background.Visible = true

                charm.health.Position = pos2d
                charm.health.Size = Vector2.new(barWidth * healthRatio, barHeight)
                charm.health.Visible = true

                -- Cor da barra pode mudar com a vida, ex: verde > amarelo > vermelho
                if healthRatio > 0.5 then
                    charm.health.Color = Color3.fromRGB(0, 255, 0)
                elseif healthRatio > 0.25 then
                    charm.health.Color = Color3.fromRGB(255, 255, 0)
                else
                    charm.health.Color = Color3.fromRGB(255, 0, 0)
                end
            else
                charm.background.Visible = false
                charm.health.Visible = false
            end
        else
            charm.background.Visible = false
            charm.health.Visible = false
        end
    end
end)

----------------------------------------------------------------- Pt 10

local charms = {}

-- Função para criar o charm (barra de vida) para um jogador
local function createCharmForPlayer(player)
    local charm = Drawing.new("Square")
    charm.Visible = false
    charm.Filled = true
    charm.Thickness = 1
    charm.Color = _G.Settings.esp.enemyColor
    charm.Transparency = 0.6

    local charmBg = Drawing.new("Square")
    charmBg.Visible = false
    charmBg.Filled = true
    charmBg.Thickness = 1
    charmBg.Color = Color3.new(0, 0, 0) -- fundo preto semitransparente
    charmBg.Transparency = 0.4

    charms[player] = {bar = charm, bg = charmBg}
end

local function removeCharmForPlayer(player)
    if charms[player] then
        charms[player].bar:Remove()
        charms[player].bg:Remove()
        charms[player] = nil
    end
end

-- Criar charms para todos os jogadores existentes (exceto local)
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createCharmForPlayer(player)
    end
end

-- Conectar os eventos de player entrando e saindo
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createCharmForPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeCharmForPlayer(player)
end)

-- Atualizar charms junto com ESP na RenderStepped
RunService.RenderStepped:Connect(function()
    if not _G.Settings.esp.enabled then
        -- esconder charms também
        for _, charmData in pairs(charms) do
            charmData.bar.Visible = false
            charmData.bg.Visible = false
        end
        return
    end

    for player, charmData in pairs(charms) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.Health > 0 and rootPart then
            local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0)) -- charm fica acima da cabeça
            if onScreen then
                local maxHealth = humanoid.MaxHealth
                local healthPercent = math.clamp(humanoid.Health / maxHealth, 0, 1)

                -- Tamanho da barra (ex: 50px largura, 5px altura)
                local barWidth = 50
                local barHeight = 5
                local barPos = Vector2.new(pos.X - barWidth / 2, pos.Y)

                -- Fundo da barra
                charmData.bg.Position = barPos
                charmData.bg.Size = Vector2.new(barWidth, barHeight)
                charmData.bg.Visible = true

                -- Barra de vida (largura proporcional à vida)
                charmData.bar.Position = barPos
                charmData.bar.Size = Vector2.new(barWidth * healthPercent, barHeight)
                
                -- Cor baseado no time
                if player.Team == LocalPlayer.Team then
                    charmData.bar.Color = _G.Settings.esp.allyColor
                else
                    charmData.bar.Color = _G.Settings.esp.enemyColor
                end
                charmData.bar.Visible = true
            else
                charmData.bar.Visible = false
                charmData.bg.Visible = false
            end
        else
            charmData.bar.Visible = false
            charmData.bg.Visible = false
        end
    end
end)


------------------------------------------------------- PT 11

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Criar ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPSettingsUI"
screenGui.Parent = PlayerGui
screenGui.ResetOnSpawn = false

-- Criar frame principal
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 200)
frame.Position = UDim2.new(0.5, -150, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Título
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Configurações ESP"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextColor3 = Color3.new(1,1,1)
title.Parent = frame

-- Checkbox helper function
local function createCheckbox(text, parent, position, initialValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 30)
    container.Position = position
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.8, 0, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 18
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 25, 0, 25)
    box.Position = UDim2.new(0.85, 0, 0.1, 0)
    box.BackgroundColor3 = initialValue and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    box.Text = ""
    box.Parent = container

    box.MouseButton1Click:Connect(function()
        local newValue = not (box.BackgroundColor3 == Color3.new(0, 1, 0))
        box.BackgroundColor3 = newValue and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
        callback(newValue)
    end)

    return container
end

-- Slider helper function
local function createSlider(text, parent, position, min, max, initialValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 50)
    container.Position = position
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(initialValue)
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, 0, 0, 10)
    sliderBar.Position = UDim2.new(0, 0, 0, 30)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sliderBar.Parent = container

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((initialValue - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    sliderFill.Parent = sliderBar

    local dragging = false

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)

    sliderBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    sliderBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relativeX = math.clamp(input.Position.X - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
            local percent = relativeX / sliderBar.AbsoluteSize.X
            local value = math.floor(min + (max - min) * percent)
            sliderFill.Size = UDim2.new(percent, 0, 1, 0)
            label.Text = text .. ": " .. tostring(value)
            callback(value)
        end
    end)

    return container
end

-- Checkbox ESP Enabled
local espEnabledCheckbox = createCheckbox("ESP Ativado", frame, UDim2.new(0, 10, 0, 40), _G.Settings.esp.enabled, function(value)
    _G.Settings.esp.enabled = value
end)

-- Slider Box Thickness
local boxThicknessSlider = createSlider("Espessura Caixa", frame, UDim2.new(0, 10, 0, 80), 1, 10, _G.Settings.esp.boxThickness, function(value)
    _G.Settings.esp.boxThickness = value
end)

-- Slider Life Bar Height
local lifeBarHeightSlider = createSlider("Altura Barra Vida", frame, UDim2.new(0, 10, 0, 130), 1, 20, 5, function(value)
    -- Você pode usar esse valor no charm (tem que modificar o código do charm pra pegar essa variável)
    _G.Settings.esp.lifeBarHeight = value
end)

-- Botão fechar
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 60, 0, 25)
closeButton.Position = UDim2.new(1, -70, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.new(1,1,1)
closeButton.Text = "Fechar"
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 18
closeButton.Parent = frame

closeButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
end)

------------------------------------------------------------------------------- Pt 12

local function createColorButton(color, parent, position, isSelected, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 25, 0, 25)
    button.Position = position
    button.BackgroundColor3 = color
    button.Text = ""
    button.BorderSizePixel = isSelected and 3 or 0
    button.Parent = parent

    button.MouseButton1Click:Connect(function()
        callback(color)
    end)

    return button
end

local colorsAlly = {
    Color3.fromRGB(0, 255, 0),   -- verde
    Color3.fromRGB(0, 128, 255), -- azul
    Color3.fromRGB(255, 255, 0), -- amarelo
}

local colorsEnemy = {
    Color3.fromRGB(255, 0, 0),   -- vermelho
    Color3.fromRGB(255, 128, 0), -- laranja
    Color3.fromRGB(128, 0, 128), -- roxo
}

-- Label aliado
local allyLabel = Instance.new("TextLabel")
allyLabel.Size = UDim2.new(0, 100, 0, 20)
allyLabel.Position = UDim2.new(0, 10, 0, 180)
allyLabel.BackgroundTransparency = 1
allyLabel.Text = "Cor Aliado:"
allyLabel.TextColor3 = Color3.new(1,1,1)
allyLabel.Font = Enum.Font.SourceSans
allyLabel.TextSize = 14
allyLabel.Parent = frame

-- Criar botões aliado
local allyButtons = {}
for i, color in ipairs(colorsAlly) do
    local isSelected = (color == _G.Settings.esp.allyColor)
    local btn = createColorButton(color, frame, UDim2.new(0, 110 + (i-1)*30, 0, 180), isSelected, function(selectedColor)
        _G.Settings.esp.allyColor = selectedColor
        -- Atualizar borda dos botões
        for _, b in ipairs(allyButtons) do
            b.BorderSizePixel = 0
        end
        btn.BorderSizePixel = 3
    end)
    table.insert(allyButtons, btn)
end

-- Label inimigo
local enemyLabel = Instance.new("TextLabel")
enemyLabel.Size = UDim2.new(0, 100, 0, 20)
enemyLabel.Position = UDim2.new(0, 10, 0, 210)
enemyLabel.BackgroundTransparency = 1
enemyLabel.Text = "Cor Inimigo:"
enemyLabel.TextColor3 = Color3.new(1,1,1)
enemyLabel.Font = Enum.Font.SourceSans
enemyLabel.TextSize = 14
enemyLabel.Parent = frame

-- Criar botões inimigo
local enemyButtons = {}
for i, color in ipairs(colorsEnemy) do
    local isSelected = (color == _G.Settings.esp.enemyColor)
    local btn = createColorButton(color, frame, UDim2.new(0, 110 + (i-1)*30, 0, 210), isSelected, function(selectedColor)
        _G.Settings.esp.enemyColor = selectedColor
        for _, b in ipairs(enemyButtons) do
            b.BorderSizePixel = 0
        end
        btn.BorderSizePixel = 3
    end)
    table.insert(enemyButtons, btn)
end

------------------------------------------------------------ PT 13

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Criar a janela principal da UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPSettingsGui"
screenGui.Parent = game:GetService("CoreGui") -- ou LocalPlayer:WaitForChild("PlayerGui") se preferir

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 250)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Text = "Configurações ESP"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = frame

-- Checkbox simples para ligar/desligar ESP
local function createCheckbox(text, defaultValue, position, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 30)
    container.Position = position
    container.BackgroundTransparency = 1
    container.Parent = frame

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 30, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local checkbox = Instance.new("TextButton")
    checkbox.Size = UDim2.new(0, 20, 0, 20)
    checkbox.Position = UDim2.new(0, 5, 0, 5)
    checkbox.BackgroundColor3 = defaultValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    checkbox.Text = ""
    checkbox.Parent = container

    checkbox.MouseButton1Click:Connect(function()
        local newValue = not defaultValue
        defaultValue = newValue
        checkbox.BackgroundColor3 = newValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        callback(newValue)
    end)

    return container, checkbox
end

-- _G.Settings table defaults
_G.Settings = _G.Settings or {}
_G.Settings.esp = _G.Settings.esp or {}
_G.Settings.esp.enabled = _G.Settings.esp.enabled == nil and true or _G.Settings.esp.enabled
_G.Settings.esp.allyColor = _G.Settings.esp.allyColor or Color3.fromRGB(0, 255, 0)
_G.Settings.esp.enemyColor = _G.Settings.esp.enemyColor or Color3.fromRGB(255, 0, 0)
_G.Settings.esp.lifeBarHeight = _G.Settings.esp.lifeBarHeight or 5

-- Checkbox ESP ligado/desligado
createCheckbox("ESP Ativado", _G.Settings.esp.enabled, UDim2.new(0, 10, 0, 50), function(value)
    _G.Settings.esp.enabled = value
end)

-- Função para criar botões de cor
local function createColorButton(color, parent, position, isSelected, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 25, 0, 25)
    button.Position = position
    button.BackgroundColor3 = color
    button.Text = ""
    button.BorderSizePixel = isSelected and 3 or 0
    button.BorderColor3 = Color3.new(1, 1, 1)
    button.Parent = parent

    button.MouseButton1Click:Connect(function()
        callback(color)
    end)

    return button
end

local colorsAlly = {
    Color3.fromRGB(0, 255, 0),   -- verde
    Color3.fromRGB(0, 128, 255), -- azul
    Color3.fromRGB(255, 255, 0), -- amarelo
}

local colorsEnemy = {
    Color3.fromRGB(255, 0, 0),   -- vermelho
    Color3.fromRGB(255, 128, 0), -- laranja
    Color3.fromRGB(128, 0, 128), -- roxo
}

-- Label aliado
local allyLabel = Instance.new("TextLabel")
allyLabel.Size = UDim2.new(0, 100, 0, 20)
allyLabel.Position = UDim2.new(0, 10, 0, 90)
allyLabel.BackgroundTransparency = 1
allyLabel.Text = "Cor Aliado:"
allyLabel.TextColor3 = Color3.new(1,1,1)
allyLabel.Font = Enum.Font.SourceSans
allyLabel.TextSize = 14
allyLabel.Parent = frame

-- Criar botões aliado
local allyButtons = {}
for i, color in ipairs(colorsAlly) do
    local isSelected = (color == _G.Settings.esp.allyColor)
    local btn = createColorButton(color, frame, UDim2.new(0, 110 + (i-1)*30, 0, 90), isSelected, function(selectedColor)
        _G.Settings.esp.allyColor = selectedColor
        for _, b in ipairs(allyButtons) do
            b.BorderSizePixel = 0
        end
        btn.BorderSizePixel = 3
    end)
    table.insert(allyButtons, btn)
end

-- Label inimigo
local enemyLabel = Instance.new("TextLabel")
enemyLabel.Size = UDim2.new(0, 100, 0, 20)
enemyLabel.Position = UDim2.new(0, 10, 0, 130)
enemyLabel.BackgroundTransparency = 1
enemyLabel.Text = "Cor Inimigo:"
enemyLabel.TextColor3 = Color3.new(1,1,1)
enemyLabel.Font = Enum.Font.SourceSans
enemyLabel.TextSize = 14
enemyLabel.Parent = frame

-- Criar botões inimigo
local enemyButtons = {}
for i, color in ipairs(colorsEnemy) do
    local isSelected = (color == _G.Settings.esp.enemyColor)
    local btn = createColorButton(color, frame, UDim2.new(0, 110 + (i-1)*30, 0, 130), isSelected, function(selectedColor)
        _G.Settings.esp.enemyColor = selectedColor
        for _, b in ipairs(enemyButtons) do
            b.BorderSizePixel = 0
        end
        btn.BorderSizePixel = 3
    end)
    table.insert(enemyButtons, btn)
end

-- Label vida barra (lifeBarHeight)
local lifeBarLabel = Instance.new("TextLabel")
lifeBarLabel.Size = UDim2.new(0, 150, 0, 20)
lifeBarLabel.Position = UDim2.new(0, 10, 0, 170)
lifeBarLabel.BackgroundTransparency = 1
lifeBarLabel.Text = "Altura Barra de Vida:"
lifeBarLabel.TextColor3 = Color3.new(1,1,1)
lifeBarLabel.Font = Enum.Font.SourceSans
lifeBarLabel.TextSize = 14
lifeBarLabel.Parent = frame

-- Slider simples para ajustar altura da barra de vida
local slider = Instance.new("Frame")
slider.Size = UDim2.new(0, 150, 0, 20)
slider.Position = UDim2.new(0, 140, 0, 170)
slider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
slider.Parent = frame

local sliderBar = Instance.new("Frame")
sliderBar.Size = UDim2.new((_G.Settings.esp.lifeBarHeight or 5)/20, 1, 1, 0) -- max 20
sliderBar.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
sliderBar.Parent = slider

local sliderHandle = Instance.new("TextButton")
sliderHandle.Size = UDim2.new(0, 10, 1, 0)
sliderHandle.Position = UDim2.new(sliderBar.Size.X.Scale, 0, 0, 0)
sliderHandle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
sliderHandle.Text = ""
sliderHandle.Parent = slider

local dragging = false

sliderHandle.MouseButton1Down:Connect(function()
    dragging = true
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mousePos = input.Position
        local relativePos = math.clamp(mousePos.X - slider.AbsolutePosition.X, 0, slider.AbsoluteSize.X)
        local scale = relativePos / slider.AbsoluteSize.X
        sliderBar.Size = UDim2.new(scale, 0, 1, 0)
        sliderHandle.Position = UDim2.new(scale, 0, 0, 0)
        local value = math.floor(scale * 20)
        if value < 1 then value = 1 end
        _G.Settings.esp.lifeBarHeight = value
    end
end)

print("UI Config ESP carregada!")

---------------------------------------------------------- PT 15

local Drawing = Drawing -- já disponível no ambiente Roblox Exploit
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local charms = {}

local function createCharmForPlayer(player)
    local barBack = Drawing.new("Square")
    barBack.Color = Color3.fromRGB(0, 0, 0)
    barBack.Filled = true
    barBack.Transparency = 0.5
    barBack.Thickness = 0

    local lifeBar = Drawing.new("Square")
    lifeBar.Color = Color3.fromRGB(0, 255, 0)
    lifeBar.Filled = true
    lifeBar.Thickness = 0

    charms[player] = {
        barBack = barBack,
        lifeBar = lifeBar,
    }
end

local function removeCharmForPlayer(player)
    if charms[player] then
        charms[player].barBack:Remove()
        charms[player].lifeBar:Remove()
        charms[player] = nil
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createCharmForPlayer(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createCharmForPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(removeCharmForPlayer)

RunService.RenderStepped:Connect(function()
    if not _G.Settings or not _G.Settings.esp or not _G.Settings.esp.enabled then
        for _, charm in pairs(charms) do
            charm.barBack.Visible = false
            charm.lifeBar.Visible = false
        end
        return
    end

    local lifeBarHeight = _G.Settings.esp.lifeBarHeight or 5

    for player, charm in pairs(charms) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.Health > 0 and rootPart then
            local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0)) -- um pouco acima da cabeça
            if onScreen then
                local sizeX = 50
                local sizeY = lifeBarHeight
                local posX = pos.X - sizeX/2
                local posY = pos.Y

                charm.barBack.Position = Vector2.new(posX, posY)
                charm.barBack.Size = Vector2.new(sizeX, sizeY)
                charm.barBack.Visible = true

                charm.lifeBar.Position = Vector2.new(posX, posY)
                charm.lifeBar.Size = Vector2.new(sizeX * (humanoid.Health / humanoid.MaxHealth), sizeY)
                charm.lifeBar.Color = player.Team == LocalPlayer.Team and _G.Settings.esp.allyColor or _G.Settings.esp.enemyColor
                charm.lifeBar.Visible = true
            else
                charm.barBack.Visible = false
                charm.lifeBar.Visible = false
            end
        else
            charm.barBack.Visible = false
            charm.lifeBar.Visible = false
        end
    end
end)

------------------------------------------------------------ Pt 16

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remove GUI anterior se tiver
local oldGui = PlayerGui:FindFirstChild("ESPSettingsGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPSettingsGui"
screenGui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 300)
frame.Position = UDim2.new(0, 20, 0, 50)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local function createLabel(text, posY)
    local label = Instance.new("TextLabel")
    label.Text = text
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, posY)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 18
    label.Parent = frame
    return label
end

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 100, 0, 30)
toggleButton.Position = UDim2.new(0, 10, 0, 30)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggleButton.TextColor3 = Color3.new(1,1,1)
toggleButton.Font = Enum.Font.SourceSans
toggleButton.TextSize = 20
toggleButton.Text = _G.Settings.esp.enabled and "ESP: ON" or "ESP: OFF"
toggleButton.Parent = frame

toggleButton.MouseButton1Click:Connect(function()
    _G.Settings.esp.enabled = not _G.Settings.esp.enabled
    toggleButton.Text = _G.Settings.esp.enabled and "ESP: ON" or "ESP: OFF"
end)

createLabel("Ally Color", 70)
local allyColorPicker = Instance.new("TextBox")
allyColorPicker.Size = UDim2.new(0, 80, 0, 25)
allyColorPicker.Position = UDim2.new(0, 10, 0, 95)
allyColorPicker.PlaceholderText = "R,G,B"
allyColorPicker.Text = string.format("%d,%d,%d", _G.Settings.esp.allyColor.R*255, _G.Settings.esp.allyColor.G*255, _G.Settings.esp.allyColor.B*255)
allyColorPicker.TextColor3 = Color3.new(1,1,1)
allyColorPicker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
allyColorPicker.Font = Enum.Font.SourceSans
allyColorPicker.TextSize = 18
allyColorPicker.Parent = frame

allyColorPicker.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local r,g,b = allyColorPicker.Text:match("(%d+),(%d+),(%d+)")
        r, g, b = tonumber(r), tonumber(g), tonumber(b), tonumber(b)
        if r and g and b and r <= 255 and g <= 255 and b <= 255 then
            _G.Settings.esp.allyColor = Color3.fromRGB(r,g,b)
        else
            allyColorPicker.Text = string.format("%d,%d,%d", _G.Settings.esp.allyColor.R*255, _G.Settings.esp.allyColor.G*255, _G.Settings.esp.allyColor.B*255)
        end
    end
end)

createLabel("Enemy Color", 130)
local enemyColorPicker = allyColorPicker:Clone()
enemyColorPicker.Position = UDim2.new(0, 10, 0, 155)
enemyColorPicker.Text = string.format("%d,%d,%d", _G.Settings.esp.enemyColor.R*255, _G.Settings.esp.enemyColor.G*255, _G.Settings.esp.enemyColor.B*255)
enemyColorPicker.Parent = frame

enemyColorPicker.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local r,g,b = enemyColorPicker.Text:match("(%d+),(%d+),(%d+)")
        r, g, b, b = tonumber(r), tonumber(g), tonumber(b), tonumber(b)
        if r and g and b and r <= 255 and g <= 255 and b <= 255 then
            _G.Settings.esp.enemyColor = Color3.fromRGB(r,g,b)
        else
            enemyColorPicker.Text = string.format("%d,%d,%d", _G.Settings.esp.enemyColor.R*255, _G.Settings.esp.enemyColor.G*255, _G.Settings.esp.enemyColor.B*255)
        end
    end
end)

createLabel("Life Bar Height", 190)
local lifeBarSlider = Instance.new("TextBox")
lifeBarSlider.Size = UDim2.new(0, 80, 0, 25)
lifeBarSlider.Position = UDim2.new(0, 10, 0, 215)
lifeBarSlider.Text = tostring(_G.Settings.esp.lifeBarHeight)
lifeBarSlider.TextColor3 = Color3.new(1,1,1)
lifeBarSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
lifeBarSlider.Font = Enum.Font.SourceSans
lifeBarSlider.TextSize = 18
lifeBarSlider.ClearTextOnFocus = false
lifeBarSlider.Parent = frame

lifeBarSlider.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local val = tonumber(lifeBarSlider.Text)
        if val and val > 0 and val <= 50 then
            _G.Settings.esp.lifeBarHeight = val
        else
            lifeBarSlider.Text = tostring(_G.Settings.esp.lifeBarHeight)
        end
    end
end)

--------------------------------------------- Pt 18

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remove GUI anterior se tiver
local oldGui = PlayerGui:FindFirstChild("MainSettingsGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainSettingsGui"
screenGui.Parent = PlayerGui

-- Container principal
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 400)
mainFrame.Position = UDim2.new(0, 20, 0, 50)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Título da janela
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
title.Text = "Configurações do Script"
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = mainFrame

-- Container das abas (botões lateral)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 100, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
sidebar.Parent = mainFrame

-- Container do conteúdo
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -100, 1, -40)
contentFrame.Position = UDim2.new(0, 100, 0, 40)
contentFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
contentFrame.Parent = mainFrame

-- Função utilitária para criar botão de aba
local function createTabButton(name, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 18
    btn.Parent = sidebar
    return btn
end

-- Função utilitária pra criar label
local function createLabel(parent, text, posY)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, posY)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 18
    label.Text = text
    label.Parent = parent
    return label
end

-- Função utilitária para criar toggle (check box)
local function createToggle(parent, text, posY, initialValue, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, -20, 0, 30)
    toggleFrame.Position = UDim2.new(0, 10, 0, posY)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 18
    label.TextColor3 = Color3.new(1,1,1)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.8, 0, 1, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame

    local checkbox = Instance.new("TextButton")
    checkbox.Size = UDim2.new(0, 25, 0, 25)
    checkbox.Position = UDim2.new(0.85, 0, 0.1, 0)
    checkbox.BackgroundColor3 = initialValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(70, 70, 70)
    checkbox.Text = ""
    checkbox.Parent = toggleFrame

    local checked = initialValue

    checkbox.MouseButton1Click:Connect(function()
        checked = not checked
        checkbox.BackgroundColor3 = checked and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(70, 70, 70)
        callback(checked)
    end)

    return toggleFrame
end

-- Função utilitária para criar slider
local function createSlider(parent, text, posY, min, max, initialValue, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, -20, 0, 50)
    sliderFrame.Position = UDim2.new(0, 10, 0, posY)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Text = text .. " ("..tostring(initialValue)..")"
    label.Font = Enum.Font.Gotham
    label.TextSize = 18
    label.TextColor3 = Color3.new(1,1,1)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Parent = sliderFrame

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -20, 0, 10)
    sliderBar.Position = UDim2.new(0, 10, 0, 30)
    sliderBar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    sliderBar.Parent = sliderFrame

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((initialValue - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    sliderFill.Parent = sliderBar

    local dragging = false

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)

    sliderBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    sliderBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relativePos = math.clamp(input.Position.X - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
            local value = min + (relativePos / sliderBar.AbsoluteSize.X) * (max - min)
            sliderFill.Size = UDim2.new(relativePos / sliderBar.AbsoluteSize.X, 0, 1, 0)
            label.Text = string.format("%s (%.1f)", text, value)
            callback(value)
        end
    end)

    return sliderFrame
end

-- Função utilitária para criar um color picker simples (3 sliders R, G, B)
local function createColorPicker(parent, text, posY, initialColor, callback)
    local pickerFrame = Instance.new("Frame")
    pickerFrame.Size = UDim2.new(1, -20, 0, 110)
    pickerFrame.Position = UDim2.new(0, 10, 0, posY)
    pickerFrame.BackgroundTransparency = 1
    pickerFrame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 18
    label.TextColor3 = Color3.new(1,1,1)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Parent = pickerFrame

    local currentColor = {R = initialColor.R*255, G = initialColor.G*255, B = initialColor.B*255}

    local function updateColor()
        local color = Color3.fromRGB(currentColor.R, currentColor.G, currentColor.B)
        callback(color)
    end

    local yOffset = 30
    local channels = {"R", "G", "B"}
    local colors = {Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255)}

    for i, channel in ipairs(channels) do
        local slider = createSlider(pickerFrame, channel, yOffset + (i-1)*25, 0, 255, currentColor[channel], function(value)
            currentColor[channel] = math.floor(value)
            updateColor()
        end)
        slider.Size = UDim2.new(1, -20, 0, 20)
    end
end

-- ==== Criar abas ====

local tabs = {}
local activeTab = nil

-- Função pra limpar contentFrame
local function clearContent()
    for _, child in ipairs(contentFrame:GetChildren()) do
        if not (child:IsA("UIListLayout") or child:IsA("UISizeConstraint")) then
            child:Destroy()
        end
    end
end

-- Aba ESP
local function createESPTab()
    clearContent()

    createToggle(contentFrame, "ESP Enabled", 10, _G.Settings.esp.enabled, function(val)
        _G.Settings.esp.enabled = val
    end)

    createColorPicker(contentFrame, "Ally Color", 60, _G.Settings.esp.allyColor, function(color)
        _G.Settings.esp.allyColor = color
    end)

    createColorPicker(contentFrame, "Enemy Color", 180, _G.Settings.esp.enemyColor, function(color)
        _G.Settings.esp.enemyColor = color
    end)

    createSlider(contentFrame, "Life Bar Height", 300, 0, 50, _G.Settings.esp.lifeBarHeight, function(val)
        _G.Settings.esp.lifeBarHeight = val
    end)
end

-- Aqui pode criar a função para aba Charms depois, para expandir

-- Criar botões da sidebar e associar evento

local espBtn = createTabButton("ESP", 10)
local charmsBtn = createTabButton("Charms", 60)
-- adicionar outros botões aqui

local function setActiveTab(tabName)
    if activeTab == tabName then return end
    activeTab = tabName

    if tabName == "ESP" then
        createESPTab()
    elseif tabName == "Charms" then
        clearContent()
        -- aqui cria UI de Charms depois
        local label = createLabel(contentFrame, "Charms UI em construção...", 20)
    else
        clearContent()
        local label = createLabel(contentFrame, "Aba não implementada.", 20)
    end
end

espBtn.MouseButton1Click:Connect(function() setActiveTab("ESP") end)
charmsBtn.MouseButton1Click:Connect(function() setActiveTab("Charms") end)

-- Inicializa com aba ESP aberta
setActiveTab("ESP")

-------------------- pt 19 --> in the future!
