---// Main //
local RagdollClass = {}
RagdollClass.__index = RagdollClass

---// Service(s) //
local PlayerService = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

---// Folder Declar(s) //
local ServerConfig = ServerScriptService:WaitForChild('Server')
local ServicesFolder = ServerConfig.Services
local ClientConfig = ReplicatedStorage:WaitForChild("Client")
local ModulesFolder = ClientConfig.Modules
local AssetsFolder = ClientConfig.Assets
local RemotesFolder = ClientConfig.Remotes

---// Module Declar(s) //
local Janitor = require(ModulesFolder.Janitor)
local Signal = require(ModulesFolder.Signal)
local PlayerLib = require(ServicesFolder.PlayerLib)

---// Function(s) //

local function LoadCharacterForDeadModel(Character : Model) : ()
	local Player = PlayerService:GetPlayerFromCharacter(Character)
	if not Player then return end
	task.delay(PlayerService.RespawnTime, function()
		Player:LoadCharacter()
	end)
end

function RagdollClass.new(Character : Model)
	local self = setmetatable({},RagdollClass)
	local humanoid = PlayerLib:IsCharacterAlive(Character)
	if not humanoid then return self end

	self.Humanoid = humanoid
	self.Character = Character
	
	local newJanitor = Janitor.new()
	
	self.Janitor = newJanitor
	self.Ragdolled = false
	self.Sockets = {}
	self.Colliders = {}
	
	self.Janitor:Add(self.Character:GetAttributeChangedSignal("Parent"):Connect(function()
		if self.Character.Parent then return end
		LoadCharacterForDeadModel(self.Character)
	end))
	
	return self
end

function RagdollClass:GetMotors(Character) : {Motor6D}
	return {
		--Character.Hum:FindFirstChild(anoidRootPart['RootJoint'],
		Character.Torso:FindFirstChild('Left Hip'),
		Character.Torso:FindFirstChild('Left Shoulder'),
		Character.Torso:FindFirstChild('Neck'),
		Character.Torso:FindFirstChild('Right Hip'),
		Character.Torso:FindFirstChild('Right Shoulder'),
	}
end

function RagdollClass:CreateBallSocket(Motor : Motor6D)
	local Attachment0 = self.Janitor:Add(Instance.new("Attachment",Motor.Part0), "Destroy")
	Attachment0.CFrame = Motor.C0
	Attachment0.Name = Motor.Part0.Name.."-Part0-Attachment"

	local Attachment1 = self.Janitor:Add(Instance.new("Attachment",Motor.Part1), "Destroy")
	Attachment1.CFrame = Motor.C1
	Attachment1.Name = Motor.Part1.Name.."-Part1-Attachment"

	local BallSocket = self.Janitor:Add(Instance.new("BallSocketConstraint"), "Destroy")
	BallSocket.Parent = Motor.Part1
	BallSocket.Name = Motor.Name.."Socket"
	BallSocket.Attachment0 = Attachment0
	BallSocket.Attachment1 = Attachment1
	BallSocket.Name = `Part0{Motor.Part0}-Part1{Motor.Part1}-Socket`

	return Attachment0,Attachment1,BallSocket
end

function RagdollClass:CrateUnragTimer(Duration : number)
	if Duration then
		self.Janitor:Remove("UnragTimer")
		if  Duration > 0 then
			self.Janitor:Add(task.delay(Duration,function()
				self:DisableRagdoll()
			end),true,"UnragTimer")
		end
	end
end


function RagdollClass:createCollider(v1)
	local collider = self.Janitor:Add(Instance.new("Part"))
	collider.Size = v1.Size/ Vector3.new(1.3,1.5,1.3)
	collider.CFrame = v1.CFrame
	collider.Transparency = 1
	collider.CanCollide = true

	local weld = self.Janitor:Add(Instance.new("Weld"))
	weld.Part0 = v1
	weld.Part1 = collider
	weld.C0 = CFrame.new()
	weld.C1 = collider.CFrame:ToObjectSpace(v1.CFrame)
	weld.Parent = collider

	collider.Name = v1.Name .. " Collider"
	collider.Parent = v1

--[[
	local noCollisionConstraint = self.Janitor:Add(Instance.new("NoCollisionConstraint"))
	noCollisionConstraint.Part0 = v1
	noCollisionConstraint.Part1 = collider
	noCollisionConstraint.Parent = collider
]]
	self.Colliders[v1] = collider
end


function RagdollClass:EnableRagdoll(Duration : number?, SetNetworkOwner : boolean?, OnRagdollStopped : (any) -> (any), IgnoreHead : boolean?)
	if self.Ragdolled then 
		self:CrateUnragTimer(Duration)
		return 
	end
	
	local RagdollJanitor = self.Janitor
	
	self.Ragdolled = true
	self.Sockets = {}
	
	self.Humanoid.PlatformStand = true
	--self.Humanoid.EvaluateStateMachine = false
	self.Humanoid.AutoRotate = false
	self.Humanoid.RequiresNeck = false
	self.OnRagdollStopped = OnRagdollStopped


	self.Character.HumanoidRootPart.Anchored = false

	for _, Motor : Motor6D in self:GetMotors(self.Character) do
		local Part1, Part0 = Motor.Part1, Motor.Part0
		
		if not Part1 or not Part0 then 
			warn("Part1 or Part0 is nil for Motor:", Motor:GetFullName())
			continue
		end
		
		if IgnoreHead then
			if Part1.Name == "Head" or Part0.Name == "Head" then
				continue
			end
		end
		
		local Attachment0,Attachment1,Socket = self:CreateBallSocket(Motor)
		
		Motor.Enabled = false

		RagdollJanitor:Add(Attachment0)
		RagdollJanitor:Add(Attachment1)
		RagdollJanitor:Add(Socket)

		Part1.CFrame = self.Character[Part1.Name].CFrame
	
		if Part1.Name == "Head" or Part0.Name == "Head" then
			Socket.LimitsEnabled = true
			Socket.TwistLimitsEnabled = true
		end
		
		Part1.Massless = true

		self.Janitor:Add(task.spawn(function()
			task.wait()
			--Part0.CanCollide = true
			Part1.CanCollide = false
		end))

		
		table.insert(self.Sockets,Attachment0)
		table.insert(self.Sockets,Attachment1)
		table.insert(self.Sockets,Socket)
		
		--if SetNetworkOwner == nil or SetNetworkOwner == true then
		--	Part0:SetNetworkOwner(nil)
		--	Part1:SetNetworkOwner(nil)
		--end
		

		self:createCollider(Part1)
	end

	if SetNetworkOwner ~= false then
		self.Character.HumanoidRootPart:SetNetworkOwner(nil)
	end

	self.Character:SetAttribute("Ragdolled", true)
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	self.Character.HumanoidRootPart:ApplyAngularImpulse(self.Character.HumanoidRootPart.CFrame.LookVector * -100)

	self:CrateUnragTimer(Duration)
		
end

function RagdollClass:DisableRagdoll(ServerPlayer : Player?)
	if not self.Ragdolled then return end
	
	local Player = ServerPlayer or PlayerService:GetPlayerFromCharacter(self.Character)
	for _, v in self.Sockets do
		v:Destroy()
	end
	
	for _, Motor in self:GetMotors(self.Character) do
		Motor.Enabled = true
		Motor.Part0:SetNetworkOwner(Player)
		Motor.Part1:SetNetworkOwner(Player)
	end
	
	
	for _,v in self.Colliders do
		v:Destroy()
	end
	
	if self.OnRagdollStopped then
		self.OnRagdollStopped()
	end

	self.Sockets = {}
	self.Colliders = {}
	self.Ragdolled = false
	self.OnRagdollStopped = nil

	self.Humanoid.PlatformStand = false
	--self.Humanoid.EvaluateStateMachine = true
	self.Humanoid.AutoRotate = true
	self.Humanoid.RequiresNeck = true

	self.Character:SetAttribute("Ragdolled", false)
	task.wait()
	self.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

end

function RagdollClass:Destroy()
	if typeof(self) == "table" and self ~= {} then
		self.Janitor:Destroy()
	end
	
	setmetatable(self, nil)
	table.clear(self)
	table.freeze(self)
	print(`[RagdollService] : (Debug) | Destroyed Ragdoll Container.`)
end

---// Connection(s) //

---[[ Return ]]---

local _a = nil
export type RagdollClass = typeof(RagdollClass.new(_a))

return RagdollClass