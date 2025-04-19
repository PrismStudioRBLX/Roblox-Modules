debug.setmemorycategory('CombatService')

---// Service(s) //
local PlayerService = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerStorage = game:GetService('ServerStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local Debris = game:GetService('Debris')

---// Folder Declar(s) //
local MainConfig = workspace:WaitForChild('Main')
local ClientConfig, ServerConfig = ReplicatedStorage:WaitForChild("Client"), ServerScriptService:WaitForChild("Server")
local ServerServicesFolder, ClientServices = ServerConfig.Services, ClientConfig.Services
local RemotesFolder = ClientConfig:WaitForChild("Remotes")
local StatusEffectTemplatesFolder = ServerConfig:WaitForChild("StatusEffectTemplates")

---// Module Declar(s) //
local CombatService = {}
local CombatProcessor = require(script.CombatProcessor)
local DamageService = require(script.DamageService)
local TagService = require(script.TagService)
local StunService = require(script.StunService)
local RagdollService = require(script.RagdollService)
local PlayerLib = require(ServerServicesFolder.PlayerLib)
local EffectsService = require(ServerServicesFolder.EffectsService)

---// Combat Variable(s) //
CombatService.DamageIncomingProcessors = {}
CombatService.DamageOutgoingProcessors = {}
CombatService.CombatTagContainers = {}
CombatService.StunContainers = {}
CombatService.RagdollContainers = {}
CombatService.MinimumDistanceBetweenPlayers = 100
CombatService.DefaultDamage, CombatService.DefaultDamageType = 10, "Basic"
CombatService.GripDistance = 7.5

---// Table Variable(s) //
export type Processor = CombatProcessor.Processor
export type DamageTypes = CombatProcessor.DamageTypes
export type DOT_Types = CombatProcessor.DOT_Types
export type DamageData = CombatProcessor.DamageData
export type DamageDataTemplate = CombatProcessor.DamageDataTemplate

---// Remote Variable(s) //
--local Damage_FX_Remote = RemotesFolder.DamageFX

---// Other Variable(s) //

---// Function(s) //

--================== [[ Processors Section ]] ==================--

function CombatService.CreateProcessors(Character : Model)
	local incomingDamageProcessor = CombatProcessor.new()
	local outgoingDamageProcessor = CombatProcessor.new()
	CombatService.DamageIncomingProcessors[Character] = incomingDamageProcessor
	CombatService.DamageOutgoingProcessors[Character] = outgoingDamageProcessor
	return incomingDamageProcessor, outgoingDamageProcessor
end

function CombatService.GetProcessors(Character)
	local incomingProcessor = CombatService.DamageIncomingProcessors[Character]
	local outgoingProcessor = CombatService.DamageOutgoingProcessors[Character]
	return incomingProcessor, outgoingProcessor
end

function CombatService.DestroyProcessors(Character : Model)
	local incomingProcessor, outgoingProcessor = CombatService.GetProcessors(Character)
	incomingProcessor:Destroy(); outgoingProcessor:Destroy()
	CombatService.DamageIncomingProcessors[Character] = nil
	CombatService.DamageOutgoingProcessors[Character] = nil
	print(`[CombatService] : (Debug) | Destroyed Combat Processors.`)
end

function CombatService.ClearAllProcessors()
	for Character : Model, Processor : Processor in pairs(CombatService.DamageIncomingProcessors) do
		Processor:Destroy()
	end
	
	for Character : Model, Processor : Processor in pairs(CombatService.DamageOutgoingProcessors) do
		Processor:Destroy()
	end
	
	table.clear(CombatService.DamageIncomingProcessors)
	table.clear(CombatService.DamageOutgoingProcessors)
	print(`[CombatService] : Cleared All Combat Processors`)
end

--================== [[ Tags Section ]] ==================--

function CombatService.CreateTagContainer(Character : Model)
	local ExistingContainer = CombatService.CombatTagContainers[Character]
	if ExistingContainer then return ExistingContainer end
	local newTagContainer = TagService.CreateContainer()
	CombatService.CombatTagContainers[Character] = newTagContainer
end

function CombatService.GetTagContainerForCharacter(Character : Model)
	local CharacterCombatTagContainer = CombatService.CombatTagContainers[Character]
	if not CharacterCombatTagContainer then return end
	return CharacterCombatTagContainer
end

function CombatService.DestroyTagContainer(Character : Model)
	local TagContainer = CombatService.GetTagContainerForCharacter(Character)
	TagContainer:Destroy()
	CombatService.CombatTagContainers[Character] = nil
end

function CombatService.ClearAllTagContainers()
	print(`[Combat Service] : TagContainers`, CombatService.CombatTagContainers)
	for Character : Model, TagContainer in pairs(CombatService.CombatTagContainers) do
		TagContainer:Destroy()
	end
	table.clear(CombatService.CombatTagContainers)
end

--================== [[ Stun Section ]] ==================--

function CombatService.CreateStunContainer(Character : Model)
	local ExistingContainer = CombatService.StunContainers[Character]
	if ExistingContainer then return ExistingContainer end
	local newStunContainer = StunService.CreateStunContainer()
	CombatService.StunContainers[Character] = newStunContainer
end

function CombatService.GetStunContainerForCharacter(Character : Model)
	local CharacterStunContainer = CombatService.StunContainers[Character]
	if not CharacterStunContainer then return end
	return CharacterStunContainer
end

function CombatService.DestroyStunContainer(Character : Model)
	local StunContainer = CombatService.GetStunContainerForCharacter(Character)
	StunContainer:Destroy()
	CombatService.StunContainers[Character] = nil
end

function CombatService.ClearAllStunContainers()
	print(`[Combat Service] : StunContainers`, CombatService.StunContainers)
	for Character : Model, StunContainer in pairs(CombatService.StunContainers) do
		StunContainer:Destroy()
	end
	table.clear(CombatService.StunContainers)
end

--================== [[ Ragdoll Section ]] ==================--

function CombatService.CreateRagdollContainer(Character : Model)
	local ExistingContainer = CombatService.RagdollContainers[Character]
	if ExistingContainer then return ExistingContainer end
	local newRagdollContainer = RagdollService.new(Character)
	CombatService.RagdollContainers[Character] = newRagdollContainer
end

function CombatService.GetRagdollContainerForCharacter(Character : Model)
	local CharacterRagdollContainer = CombatService.RagdollContainers[Character]
	if not CharacterRagdollContainer then return end
	return CharacterRagdollContainer
end

function CombatService.DestroyRagdollContainer(Character : Model)
	local RagdollContainer = CombatService.GetRagdollContainerForCharacter(Character)
	RagdollContainer:Destroy()
	CombatService.RagdollContainers[Character] = nil
end

function CombatService.ClearAllRagdollContainers()
	print(`[Combat Service] : RagdollContainers`, CombatService.RagdollContainers)
	for Character : Model, RagdollContainer in pairs(CombatService.RagdollContainers) do
		RagdollContainer:Destroy()
	end
	table.clear(CombatService.RagdollContainers)
end

--================== [[ Damage Section ]] ==================--

function CombatService.CreateDamageData(_Template : DamageDataTemplate?) : DamageData
	local Template = _Template or {}
	local newDamageData = {}
	newDamageData.Damage = Template.Damage or CombatService.DefaultDamage
	newDamageData.DamageType = Template.DamageType or CombatService.DefaultDamageType
	newDamageData.InstantKill = Template.InstantKill or false
	if newDamageData.DamageType == "DOT" then
		newDamageData.DOT = Template.DOT or CombatService.DefaultDamageType
	end
	return newDamageData
end

function CombatService.ProcessDamage(Processor : Processor, DamageData : DamageData)
	if not Processor then return end
	
	Processor:Process(DamageData)
end

function CombatService.Damage(Attacker : Model, Victim : Model, DamageData : DamageData)
	local attackerRootPart = PlayerLib:GetRootPart(Attacker)
	local victimRootPart = PlayerLib:GetRootPart(Victim)
	if not attackerRootPart or not victimRootPart then return end
	local distance = (attackerRootPart.Position - victimRootPart.Position).Magnitude
	if distance > CombatService.MinimumDistanceBetweenPlayers then return end
	
	local _, outboundAttacker = CombatService.GetProcessors(Attacker)
	local inboundVictim, _ = CombatService.GetProcessors(Victim)
	
	CombatService.ProcessDamage(outboundAttacker, DamageData)
	CombatService.ProcessDamage(inboundVictim, DamageData)
	
	if DamageData.Damage <= 0 then
		return
	end
	
	local victimHumanoid = PlayerLib:IsCharacterAlive(Victim) :: Humanoid
	if not victimHumanoid then return end
	
	local Container = CombatService.GetRagdollContainerForCharacter(Victim) 
	if not Container then return end
	
	if DamageData.DamageType == "DOT" then
		local DOT_Object = DamageService.CreateDOT(DamageData, Victim, Container)
		local Running = coroutine.running()
		
		DOT_Object.Janitor:Add(DOT_Object.Finished:Connect(function()
			coroutine.resume(Running)
		end),"Disconnect")
		
		DOT_Object.Janitor:Add(DOT_Object.DamageTicked:Connect(function(incrimentedDamage)
			print(incrimentedDamage)
			local VictimTagContainer = CombatService.GetTagContainerForCharacter(Victim)
			VictimTagContainer:AddTag(Attacker, {Damage = incrimentedDamage, LastHit = os.clock()})
			print(`[CombatService] : Victim Tag Container for {Victim.Name} |`,VictimTagContainer)
		end),"Disconnect")
		
		DOT_Object.Janitor:Add(function()
			coroutine.resume(Running)
		end)
		
		DOT_Object:Run()
		coroutine.yield(Running)
		if not DOT_Object.Destroy or DOT_Object.Janitor.CurrentlyCleaning then return end
		DOT_Object:Destroy()
	else
		EffectsService:Fire("DamageFX",{
			Caster = Victim;
			Effect = "Combat/HitEffect/Impulse"
		})
		
		if DamageData.InstantKill then
			victimHumanoid:TakeDamage(DamageData.Damage)
			
			if victimHumanoid.Health <= .1 then victimHumanoid.RequiresNeck = true end
		else
			victimHumanoid.Health = math.max(victimHumanoid.Health - DamageData.Damage,.1)

			if victimHumanoid.Health <= .12 then
				Victim:SetAttribute("Knocked",true)
				Container:EnableRagdoll(15, false, function() Victim:SetAttribute("Knocked",false) end)
			end
		end
		
		--
	
		local VictimTagContainer = CombatService.GetTagContainerForCharacter(Victim)
		VictimTagContainer:AddTag(Attacker, {Damage = DamageData.Damage, LastHit = os.clock()})
		--print(`[CombatService] : Victim Tag Container for {Victim.Name} |`,VictimTagContainer)
	end
end

--================== [[ Misc Section ]] ==================--

function CombatService.GetTemplateFromStatusEffectName(StatusEffect : string)
	local foundStatusEffect = StatusEffectTemplatesFolder:FindFirstChild(StatusEffect)
	if not foundStatusEffect then return end
	return require(foundStatusEffect)
end


---// Connection(s) //
local incoming, outgoing = CombatService.CreateProcessors(MainConfig.Living.Rig)
local tagContainer = CombatService.CreateTagContainer(MainConfig.Living.Rig)
local stunContainer = CombatService.CreateStunContainer(MainConfig.Living.Rig)
local RigStunContainer = CombatService.GetStunContainerForCharacter(MainConfig.Living.Rig)
local ragdollContainer = CombatService.CreateRagdollContainer(MainConfig.Living.Rig)

incoming:AddProcess(function(DamageData : DamageData)
	if DamageData.DamageType == 'DOT' then
		if DamageData.DOT == 'Fire' then
			local random = math.random(1,5)
			if random == 3 then
				DamageData.DOT = nil
				DamageData.DamageType = 'Basic'
			end
		end
	end
end, 'IceArmor')


incoming:AddProcess(function(DamageData : DamageData)
	DamageData.Damage -= 10
	if DamageData.InstantKill then
		DamageData.InstantKill = false
	end
end, 'DamageReductionAndMythicStability')

incoming:AddProcess(function(DamageData : DamageData)
	DamageData.Damage -= 10
	if DamageData.InstantKill then
		DamageData.InstantKill = false
	end
end, 'DamageReductionAndMythicStability')

incoming:RemoveProcess('DamageReductionAndMythicStability')


local incomingA, outgoingA = CombatService.CreateProcessors(MainConfig.Living.PeryA)
local tagContainerA = CombatService.CreateTagContainer(MainConfig.Living.PeryA)
local stunContainerA = CombatService.CreateStunContainer(MainConfig.Living.PeryA)
local ragdollContainerA = CombatService.CreateRagdollContainer(MainConfig.Living.PeryA)

MainConfig.Living.PeryA:GetAttributeChangedSignal("Dashing"):Connect(function()
	MainConfig.Living.PeryA:SetAttribute("Dashing", "A")
end)

local incomingD, outgoingD = CombatService.CreateProcessors(MainConfig.Living.PeryD)
local tagContainerD = CombatService.CreateTagContainer(MainConfig.Living.PeryD)
local stunContainerD = CombatService.CreateStunContainer(MainConfig.Living.PeryD)
local ragdollContainerD = CombatService.CreateRagdollContainer(MainConfig.Living.PeryD)

MainConfig.Living.PeryD:GetAttributeChangedSignal("Dashing"):Connect(function()
	MainConfig.Living.PeryD:SetAttribute("Dashing", "D")
end)

local incomingB, outgoingB = CombatService.CreateProcessors(MainConfig.Living.Rigb)
local tagContainerB = CombatService.CreateTagContainer(MainConfig.Living.Rigb)
local stunContainerB = CombatService.CreateStunContainer(MainConfig.Living.Rigb)
local ragdollContainerB = CombatService.CreateRagdollContainer(MainConfig.Living.Rigb)


for _, model in pairs(MainConfig.Living:GetChildren()) do
	if model:IsA('Model') and model:FindFirstChildOfClass("Humanoid") then
		CombatService.CreateProcessors(model)
		CombatService.CreateStunContainer(model)
		CombatService.CreateTagContainer(model)
	end
end


warn(CombatService.DamageIncomingProcessors)
warn(CombatService.DamageOutgoingProcessors)

---[[ Return ]]---
return CombatService 
