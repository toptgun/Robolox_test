-- StarterPack/Pickaxe/LocalScript
-- ProximityPrompt 감지 → 서버에 채굴 요청

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local MiningEvent = remotes:WaitForChild("MiningEvent")

-- Workspace의 모든 노드에 ProximityPrompt 핸들러 연결
local NodesFolder = Workspace:WaitForChild("Nodes")

local function setupNodePrompt(node: BasePart)
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end

	-- 이미 연결된 경우 스킵
	if prompt:GetAttribute("MiningHandlerSetup") then
		return
	end

	prompt.Triggered:Connect(function(player)
		if player == game.Players.LocalPlayer then
			MiningEvent:FireServer(node)
		end
	end)

	prompt:SetAttribute("MiningHandlerSetup", true)
end

-- 기존 노드 설정
for _, node in pairs(NodesFolder:GetChildren()) do
	if node:IsA("BasePart") then
		setupNodePrompt(node)
	end
end

-- 새로운 노드 추가 시 자동 연결
NodesFolder.ChildAdded:Connect(function(node)
	if node:IsA("BasePart") then
		setupNodePrompt(node)
	end
end)
