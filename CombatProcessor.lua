local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ClientConfig = ReplicatedStorage:WaitForChild("Client")

local CombatProcessor = {}
CombatProcessor.__index = CombatProcessor

local JanitorModule = require(ClientConfig.Modules.Janitor)

export type DamageTypes  = "Basic" | "DOT" | "Elemental" | "Blunt" | "Pierce" | "Magic" | "Slash"
export type DOT_Types = "Poison" | "Fire" | "Bleed" | "Radiation" | "Basic"

export type DamageData = {
	Damage : number,
	DamageType : DamageTypes,
	DOT : DOT_Types?,
	InstantKill : boolean?
}

export type DamageDataTemplate = {
	Damage : number?,
	DamageType : DamageTypes?,
	DOT : DOT_Types?,
	InstantKill : boolean?
}

function CombatProcessor.new()
	local self = setmetatable({}, CombatProcessor)
	local newJanitor = JanitorModule.new()
	self.Janitor = newJanitor
	self.Processes = {}

	return self
end

function CombatProcessor:AddProcess(Process : (DamageData : DamageData) -> (), Index : any)
	local ProcessIndex = self.Processes[Index]
	if not ProcessIndex then
		local newProcessIndex = Process
		self.Processes[Index] = newProcessIndex
	elseif ProcessIndex then
		if typeof(ProcessIndex) == "function" then
			local newProcessIndex = {}
			table.insert(newProcessIndex, ProcessIndex)
			table.insert(newProcessIndex, Process)
			self.Processes[Index] = newProcessIndex
		elseif typeof(ProcessIndex) == "table" then
			table.insert(ProcessIndex, Process)
		end
	end
end

function CombatProcessor:RemoveProcess(Index : any)
	local ProcessIndex = self.Processes[Index]
	if typeof(ProcessIndex) == "function" then
		self.Processes[Index] = nil
	elseif typeof(ProcessIndex) == "table" then
		table.remove(ProcessIndex, #ProcessIndex)
		if #ProcessIndex == 0 then
			self.Processes[Index] = nil
		end
	end
end

function CombatProcessor:Process(DamageData : DamageData)
	for _, ProcessIndex in pairs(self.Processes) do
		if typeof(ProcessIndex) == "function" then
			ProcessIndex(DamageData)
		elseif typeof(ProcessIndex) == "table" then
			for _, Process in ipairs(ProcessIndex) do
				Process(DamageData)
			end
		end
	end
end

function CombatProcessor:GetProcesses()
	return self.Processes
end

function CombatProcessor:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
	table.clear(self)
	table.freeze(self)
	--print(`[CombatProcessors] : (Debug) | Destroyed Combat Processor.`)
end

export type Processor = typeof(CombatProcessor.new())

return CombatProcessor