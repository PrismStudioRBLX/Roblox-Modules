---// Main //
local CriticalClass = {}
CriticalClass.__index = CriticalClass

---// Service(s) //
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

---// Folder Declar(s) //
local ServerConfig = ServerScriptService.Server
local ClientConfig = ReplicatedStorage:WaitForChild('Client')
local ClientModulesFolder = ClientConfig.Modules
local ServerModulesFolder = ServerConfig.Modules
local ServerServices = ServerConfig.Services
local ServicesFolder = ServerConfig.Services

---// Module Declar(s) //
local EffectsService = ServerServices.EffectsService
local Janitor = require(ClientModulesFolder.Janitor)
local EffectsService = require(ServicesFolder.EffectsService)
local BamzHitboxModule = require(ServerModulesFolder.BamzHitboxModule)
local VelocityModule = require(ClientModulesFolder.Velocity)
---// Type Variable(s) //
export type IndicatorType = "Rush" | "Projectile" | "AOE"

export type indicatorData = {
	Size: Vector3,
	IndicatorType: IndicatorType,
	Count: number,
	LifeTime: number,
	
	HyperArmor: boolean,
	HyperArmorDuration: number?,
	HyperArmorStartupTime: number?
}

export type WeaponCritData = {
	Logic: (any) -> (any),
}

export type velocityProperties = {
	Duration  : number;
	Velocity : Vector3,
	MaxForce : number? | Vector3?,
	Attachment : Attachment?,
	ForceLimitMode : "Magnitude"? | "PerAxis"?,
	RelativeTo : "Attachment0"? | "Attachment1"? | "World"?,
	Stackable : boolean?;
	IsClient : boolean
}

---// Function(s) //
function CriticalClass.new(Character: Model,WeaponCritData: WeaponCritData)
	local self = setmetatable({}, CriticalClass)
	local newJanitor = Janitor.new()
	
	self.Character = Character
	self.Janitor = newJanitor
	self.CritData = WeaponCritData
	self.Logic = WeaponCritData.Logic
	self.HyperArmor = nil
	
	return self
end

function CriticalClass:SendClientEffects(...)
	EffectsService:Fire("CombatFX",...)
end

function CriticalClass:RemoveHyperArmor()
	if self.HyperArmor then
		EffectsService:Fire("CombatFX",{Caster = self.Character,Effect = "Indicators/HyperArmor/StopIndicator"})
	end
	
	self.HyperArmor  = false
end

function CriticalClass:StartHyperArmor()
	if not self.HyperArmor then
		self.HyperArmor = true

		self:SendClientEffects({
			Caster = self.Character,
			Effect = "Indicators/HyperArmor/StartIndicator", 
		})
	end
end

function CriticalClass:CreateIndicator(callback)
	local indicatorData = self.IndicatorData :: indicatorData
	if not indicatorData then
		return
	end
	
	local count = indicatorData.Count
	local lifeTime = indicatorData.LifeTime
	
	self.Janitor:Add(task.spawn(function()
		if count > 1 then

			for i = 1, count do
				self:SpawnSingleIndicator()
				self.Janitor:Add(task.delay(lifeTime, callback,i == count))
				task.wait(lifeTime)
			end

		else
			self:SpawnSingleIndicator()
			self.Janitor:Add(task.delay(lifeTime, callback, true))
		end
	end))
	
	if self.IndicatorData.HyperArmor then
		self:RemoveHyperArmor()
		self.Janitor:Add(task.delay(self.IndicatorData.HyperArmorStartupTime or 0,function()
			self:StartHyperArmor()
			
			if self.IndicatorData.HyperArmorDuration then
				self.Janitor:Add(task.delay(self.IndicatorData.HyperArmorDuration,function()
					self:RemoveHyperArmor()
				end))
			end

			self.Janitor:Add(function()
				self:RemoveHyperArmor()
			end,nil,"StopHyper")
		end))
	
	elseif not self.IndicatorData.HyperArmor then
		self:RemoveHyperArmor()
	end
	
	self.Janitor:Add(self.Character:GetAttributeChangedSignal("Stunned"):Connect(function()
		if self.HyperArmor then return end
		if not self.Character:GetAttribute("Stunned") then return end
		
		self.Janitor:Destroy()
	end))

	self.Janitor:Add(function()
		self.Character:SetAttribute("Attacking", "")
	end)

end

function CriticalClass:CastHitBox(CallBack)
	if not CallBack then return end
		
	local Settings = {} :: BamzHitboxModule.Hitbox_Settings
	Settings.Visualize = false
	Settings.Count = 1
	Settings.LifeTime = .1
	Settings.MaxHits = 1
	Settings.Shape = "Block"
	
	if self.IndicatorData.IndicatorType == "Rush" then
		Settings.Size = self.IndicatorData.Size
		Settings.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-self.IndicatorData.Size.Z/2)
	end
	
	local Hitbox = BamzHitboxModule.new(self.Character, Settings)
	Hitbox.Janitor:Add(Hitbox.OnHit:Connect(function(tableOfModels : {Model})
		for _, model in tableOfModels do
			if model:GetAttribute("GettingActionDoneTo") then return end
			CallBack(model)
		end
	end))
	
	Hitbox:Start()
end

function CriticalClass:SpawnSingleIndicator()
	local indicatorData = self.IndicatorData :: indicatorData
	if not indicatorData then return end

	--[[ Testing ]]--
	local IndicatorString = `Indicators/{indicatorData.IndicatorType}/`

	if self.Janitor:Get("StopIndicator") then
		self.Janitor:Remove("StopIndicator")
	end

	self:SendClientEffects({
		Caster = self.Character,
		Effect = IndicatorString.."StartIndicator", 
		Variables = {
			Size = indicatorData.Size
		}
	})

	self.Janitor:Add(task.delay(indicatorData.LifeTime, function()
		self:SendClientEffects({
			Caster = self.Character,
			Effect = IndicatorString.."StopIndicator", 
		})
	end))

	self.Janitor:Add(function()
		self:SendClientEffects({
			Caster = self.Character,
			Effect = IndicatorString.."StopIndicator", 
		})
	end,nil,"StopIndicator")

end


function CriticalClass:ExecuteLogic(...)
	local args = { ... }

	if self.Logic then
		return self.Logic(self,table.unpack(args))
	else
		warn("No logic function defined for this critical attack.")
	end
end

function CriticalClass:CreateVelocity(Arguments : velocityProperties )
	if Arguments.IsClient then
		--TODO make client senders
	else
		local CreatedJanitor,Vel = VelocityModule.ApplyVelocity(self.Character.HumanoidRootPart, Arguments)
		
		if Arguments.Duration then
			self.Janitor:Add(task.delay(Arguments.Duration,function()
				CreatedJanitor:Destroy()
				Vel:Destroy()
				Vel = nil
				CreatedJanitor = nil
			end))

		end
		

		self.Janitor:Add(Vel,"Destroy")
		self.Janitor:Add(CreatedJanitor,"Destroy")
	end
end

--[[ -- how indicator works 😁
EffectsService:Fire("CombatFX",{
		Caster = Character,
		Effect = "Indicators/RushIndicator/StartIndicator", 
		Variables = {
			--Width = 5,
			--Range = 15
			
			Size = vector3.new(X,Y,Z)
		}
	})
	
	task.wait(5)
	
	EffectsService:Fire("CombatFX",{
		Caster = Character,
		Effect = "Indicators/RushIndicator/StopIndicator", 
	})


]]

function CriticalClass:Cancel()
	self.Janitor:Cleanup()
end

---[[ Return ]]---
return CriticalClass
