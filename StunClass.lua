---// Main //
local StunService = {}
StunService.__index = StunService

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

---// Other Variable(s) //
export type StunEffect = {
	Duration: number,
	Stackable: boolean,
	SpeedModifier: number,
}

export type StunEffects = {
	['Parry'] : StunEffect,
	['Attack'] : StunEffect,
	['Concussion'] : StunEffect,
	['BlockBreak'] : StunEffect,
	['Grip'] : StunEffect,
}

type Signal<T...> = Signal.Signal<T...>

local Default_Stun_Effects : StunEffects = {
	Parry = {Duration = 0.7, Stackable = false, SpeedModifier = 0.5},
	Attack = {Duration = 0.5, Stackable = true, SpeedModifier = 0.7},
	Concussion = {Duration = 8, Stackable = true, SpeedModifier = 0.3},
	BlockBreak = {Duration = 2, Stackable = true, SpeedModifier = 0},
	Grip = {Duration = 1.66666667, Stackable = true, SpeedModifier = 0},
	Carry = {Duration = 999999, Stackable = true, SpeedModifier = .8},
}

---// Function(s) //
function StunService.CreateStunContainer()
	local self = setmetatable({}, StunService)
	local newJanitor = Janitor.new()
	self.Janitor = newJanitor
	self.CurrentStuns = {}

	return self
end

function StunService:AddStun(character : Model, stunType : string, duration : number, stackable : boolean, speedModifier : number)
	local humanoid = PlayerLib:IsCharacterAlive(character) :: Humanoid
	if not humanoid then return end

	local stunData = Default_Stun_Effects[stunType]
	if not stunData then
		warn("Invalid stun type:", stunType)
		return
	end
	
	duration = duration or stunData.Duration
	stackable = stackable ~= nil and stackable or stunData.Stackable
	speedModifier = speedModifier or stunData.SpeedModifier

	self.CurrentStuns[stunType] = self.CurrentStuns[stunType] or {}

	if not stackable and next(self.CurrentStuns[stunType]) then
		self:RemoveStun(character, stunType)
	end
	
	local stunId = tick()
	local originalSpeed = humanoid.WalkSpeed
	local adjustedSpeed = originalSpeed * (speedModifier or 1)

	self.CurrentStuns[stunType][stunId] = {
		Duration = duration,
		SpeedModifier = speedModifier,
		OriginalSpeed = originalSpeed,
	}

	humanoid.WalkSpeed = adjustedSpeed
	character:SetAttribute("Stunned", true)

	self.Janitor:Add(task.delay(duration, function()
		if self:RemoveSpecificStun(character, stunType, stunId) then
			if not next(self.CurrentStuns[stunType]) then
				character:SetAttribute("Stunned", false)
			end
		end
	end), true)

	return stunId
end


function StunService:RemoveSpecificStun(character, stunType, stunId)
	local humanoid = PlayerLib:IsCharacterAlive(character) :: Humanoid
	if not humanoid or not self.CurrentStuns[stunType] then return false end

	local stun = self.CurrentStuns[stunType][stunId]
	if stun then
		self.CurrentStuns[stunType][stunId] = nil
		
		local originalSpeed = humanoid:GetAttribute("BaseWalkSpeed") or 20
		local newSpeed = originalSpeed

		for activeType, activeStuns in pairs(self.CurrentStuns) do
			for _, activeStun in pairs(activeStuns) do
				if activeStun and Default_Stun_Effects[activeType] then
					newSpeed *= Default_Stun_Effects[activeType].SpeedModifier
				end
			end
		end

		humanoid.WalkSpeed = newSpeed
		return true
	end

	return false
end

function StunService:RemoveStun(character, stunType)
	if self.CurrentStuns[stunType] then
		local humanoid = PlayerLib:IsCharacterAlive(character) :: Humanoid
		if not humanoid then return end

		for stunId in pairs(self.CurrentStuns[stunType]) do
			self.CurrentStuns[stunType][stunId] = nil
		end
		
		self.CurrentStuns[stunType] = nil
		
		local originalSpeed = humanoid:GetAttribute("BaseWalkSpeed") or 20
		local newSpeed = originalSpeed

		for activeType, activeStuns in pairs(self.CurrentStuns) do
			for _, activeStun in pairs(activeStuns) do
				if activeStun and Default_Stun_Effects[activeType] then
					newSpeed *= Default_Stun_Effects[activeType].SpeedModifier
				end
			end
		end

		humanoid.WalkSpeed = newSpeed
	end
end

function StunService:GetActiveStuns()
	local activeStuns = {}
	for stunType, stuns in pairs(self.CurrentStuns) do
		activeStuns[stunType] = {}
		for stunId, stunData in pairs(stuns) do
			activeStuns[stunType][stunId] = stunData
		end
	end
	return activeStuns
end

function StunService:HasActiveStunType(stunType : string) : boolean
	local stuns = self.CurrentStuns[stunType]
	return stuns ~= nil and next(stuns) ~= nil
end

function StunService:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
	table.clear(self)
	table.freeze(self)
	print(`[StunService] : (Debug) | Destroyed Stun Container.`)
end

---// Connection(s) //
export type StunService = typeof(StunService.CreateStunContainer())

---[[ Return ]]---
return StunService
