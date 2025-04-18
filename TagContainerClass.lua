---// Main //
local TagService = {}
TagService.__index = TagService

local CreatedTags = {}

---// Service(s) //
local PlayerService = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

---// Folder Declar(s) //
local ClientConfig = ReplicatedStorage:WaitForChild("Client")
local ModulesFolder = ClientConfig.Modules
local AssetsFolder = ClientConfig.Assets
local RemotesFolder = ClientConfig.Remotes

---// Module Declar(s) //
local Janitor = require(ModulesFolder.Janitor)

---// Remote Variable(s) //
local ClientFX_Remote = RemotesFolder.FX_Call

---// Other Variable(s) //
local Threshold, DisasterThreshold = 60, 20
export type DamageTag = {Damage : number, LastHit : number, _thread : thread?}

---// Function(s) //
function TagService.CreateContainer()
	local self = setmetatable({}, TagService)
	local newJanitor = Janitor.new()
	self.Janitor = newJanitor
	self.CurrentTags = {}

	return self
end

function TagService:CheckForDisaster() : number
	return self.CurrentTags.LastHitByDisaster
end

function TagService:GetHighestDamage() : Model
	local HighestDamage = 0
	local Target
	for Attacker, Data in pairs(self.CurrentTags) do
		if Data.Damage > HighestDamage then
			HighestDamage = Data.Damage
			Target = Attacker
		end
	end
	return Target
end

function TagService:AddTag(Attacker : Model | "Disaster", Data : DamageTag)
	if Attacker == "Disaster" then
		self.CurrentTags.LastHitByDisaster = os.clock()
		self.Janitor:Add(task.delay(DisasterThreshold, TagService.RemoveTag, self, Attacker), true, Attacker)
		return
	end
	local ExistingTag = self.CurrentTags[Attacker]
	if ExistingTag then
		ExistingTag.Damage += Data.Damage
		ExistingTag.LastHit = os.clock()
		ExistingTag._thread = self.Janitor:Add(task.delay(Threshold, TagService.RemoveTag, self, Attacker),true, Attacker)
	else
		Data._thread = self.Janitor:Add(task.delay(Threshold, TagService.RemoveTag, self, Attacker),true, Attacker)
		self.CurrentTags[Attacker] = Data
	end
end

function TagService:RemoveTag(Attacker : Model | "Disaster")
	self.CurrentTags[Attacker] = nil
end

function TagService:GetTags()
	return self.CurrentTags
end

function TagService:GetAmountOfTags() : number
	local Amount = 0
	for _, _ in pairs(self.CurrentTags) do
		Amount += 1
	end
	return Amount
end

function TagService:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
	table.clear(self)
	print(`[TagService] : (Debug) | Destroyed Tag Container.`)
end

---// Connection(s) //

---[[ Return ]]---
return TagService