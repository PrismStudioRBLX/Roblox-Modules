local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DamageService = {}
DamageService.__index = DamageService

local DOTs = {}
local DesiredDuration = 5

local ClientConfig = ReplicatedStorage:WaitForChild("Client")
local RemotesFolder = ClientConfig:WaitForChild("Remotes")
local ModulesFolder = ClientConfig:WaitForChild("Modules")
local DOT_Remote = RemotesFolder.DotFX

local JanitorModule = require(ModulesFolder.Janitor)
local Signal = require(ModulesFolder.Signal)
local PlayerLib = require(script.Parent.Parent.PlayerLib)
local CombatProcessor = require(script.Parent.CombatProcessor)
local RagdollService = require(script.Parent.RagdollService)

type DamageData = CombatProcessor.DamageData
type DamageTypes = CombatProcessor.DamageTypes
type DOT_Types = CombatProcessor.DOT_Types

type Signal<T...> = Signal.Signal<T...>

function DamageService:TakeDamage()
	local TargetCharacter = self.TargetCharacter
	
	if self.DamageData.InstantKill then
		self.TargetHumanoid:TakeDamage(self.IncrementedDamage)
		if self.TargetHumanoid.Health <= .1 then self.TargetHumanoid.RequiresNeck = true end
	else
		self.TargetHumanoid.Health = math.max(self.TargetHumanoid.Health - self.IncrementedDamage,.1)

		if self.TargetHumanoid.Health <= .12 then 
			TargetCharacter:SetAttribute("Knocked",true)
			self.RagdollContainer:EnableRagdoll(10, true, function() 
				self.RagdollContainer.Character:SetAttribute("Knocked",false) 
			end)
			
			self:Pause()
			self.Finished:Fire(self)
		end
	
	end
end

function DamageService.CreateDOT(DamageData : DamageData, VictimCharacter : Model, RagdollContainer)
	local self = setmetatable({}, DamageService)
	self.TargetCharacter = VictimCharacter
	self.TargetHumanoid = PlayerLib:IsCharacterAlive(VictimCharacter) :: Humanoid
	
	if not self.TargetHumanoid then return end
	
	local newJanitor = JanitorModule.new()
	self.Janitor = newJanitor
	self.DamageData = DamageData
	self.DOT_Type = DamageData.DOT
	self.TotalDamage = DamageData.Damage
	self.IncrementedDamage = self.TotalDamage * 0.25
	self.DamageDone = 0
	self.TickSpeed = DesiredDuration / (self.TotalDamage / self.IncrementedDamage)

	self.Finished = newJanitor:Add(Signal.new(),"Destroy") :: Signal<DOTObject>
	self.DamageTicked = newJanitor:Add(Signal.new(), "Destroy") :: Signal<DOTObject>
	self.RagdollContainer = RagdollContainer
	
	table.insert(DOTs, self)
	
	newJanitor:Add(self.TargetHumanoid.Died:Connect(function()
		self:Destroy()
	end), "Disconnect")

	return self
end

function DamageService:Run()
	local thread = self.Janitor:Get("DamageOverTime")
	if thread then
		coroutine.resume(thread)
	else
		self.Janitor:Add(task.spawn(function()
			while self.TotalDamage > 0 do
				self.TotalDamage -= self.IncrementedDamage
				self:TakeDamage()
				self.DamageDone += self.IncrementedDamage
				self.DamageTicked:Fire(self.IncrementedDamage)
				--DOT_Remote:FireAllClients(self.DamageData, self.TargetCharacter)
				task.wait(self.TickSpeed)
			end
			print("Finished")
			self.Finished:Fire(self)
		end),true,"DamageOverTime")
	end
end

function DamageService:Pause()
	local thread = self.Janitor:Get("DamageOverTime")
	if not thread then return end
	coroutine.yield(thread)
end

function DamageService:Destroy()
	self.Janitor:Destroy()
	setmetatable(self,nil)
	table.clear(self)
	table.freeze(self)
end

export type DOTObject = typeof(DamageService.CreateDOT(_G,_G))

return DamageService