--debug.setmemorycategory("BASE_COMBAT")

---// Main //
local Base, Private = {}, {}

---// Service(s) //
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local ServerStorage = game:GetService('ServerStorage')
local PlayerService = game:GetService('Players')
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')

---// Folder Declar(s) //
local ServerConfig, ClientConfig = ServerScriptService:WaitForChild('Server'), ReplicatedStorage:WaitForChild('Client')

local ServicesFolder = ServerConfig.Services
local ModulesFolder = ServerConfig.Modules
local ClientModulesFolder = ClientConfig.Modules
local RemotesFolder = ClientConfig.Remotes
local Storage = ServerStorage.Storage
local Animations = ClientConfig.Animations

---// Remote Declar(s) //
local Combat_Remote = RemotesFolder.Combat
local Movement_Remote = RemotesFolder.Movement
local Equip_Remote = RemotesFolder.Equip
local Block_Remote = RemotesFolder.Block
local Dash_Remote = RemotesFolder.Dash
local Feint_Remote = RemotesFolder.Feint
local Grip_Remote = RemotesFolder.Grip
local Carry_Remote = RemotesFolder.Carry

---// Module Declar(s) //
local CombatService = require(script.Parent)
local CombatProcessor = require(script.Parent.CombatProcessor)
local CharacterService = require(ServicesFolder.CharacterService)
local WeaponAppearance = require(ServicesFolder.CharacterService.WeaponAppearance)
local Manager = require(ServerConfig.pFolder.Manager)
local BamzHitboxModule = require(ModulesFolder.BamzHitboxModule)
local EffectsService = require(ServicesFolder.EffectsService)
local CriticalClass = require(script.Parent.CriticalClass)

-- Util
local JanitorModule = require(ClientModulesFolder.Janitor)
local SignalModule = require(ClientModulesFolder.Signal)
local ZonePlus = require(ClientModulesFolder.Zone)
local AnimationLibrary = require(ClientModulesFolder.AnimationLibrary)
local PlayerLib = require(ServicesFolder.PlayerLib)

---// Type Variable(s) //
export type DamageData = CombatProcessor.DamageData
export type DamageTypes = CombatProcessor.DamageTypes
export type DOT_Types = CombatProcessor.DOT_Types
type CharacterData = CharacterService.CharacterData
export type HitboxSettings = BamzHitboxModule.Hitbox_Settings
export type Hitbox = BamzHitboxModule.Hitbox

---// Table Variable(s) //
local EquippedStates = {}
local CharacterStates = {}
local GripJanitors = {}
local CarryJanitors = {}
local Timings = {}
local EquipDebounce, M1_Debounce, HeavyDebounce, BlockingDebounce, DashingDebounce, CriticalDebounce, GripDebounce, CarryDebounce = {},{} ,{}, {}, {}, {}, {}, {}
local Null = "Fists"

---// Function(s) //
function Private:GetProcessorsForCharacter(Character : Model)
	local incomingDamageProcessor, outgoingDamageProcessor = CombatService.GetProcessors(Character)
	return incomingDamageProcessor, outgoingDamageProcessor
end

function Private:CheckIfTypeIsCorrect(Str,Table)
	return table.find(Table,Str) and true or false 
end

function Private:FindAnimationFolder(Name : string)
	local animationFolder = Animations.Combat[Name]
	if animationFolder then
		return animationFolder
	end
	return Animations.Combat[Null]
end

function Private:GetEquippedState(character : Model) : boolean
	return EquippedStates[character]
end

function Private:SetEquippedState(character: Model)
	if EquippedStates[character] then
		EquippedStates[character] = not EquippedStates[character]
		return
	end
	EquippedStates[character] = true
end

function Base:Equip(Character: Model, Data, Ignore: boolean)
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	local HumanoidRootPart = PlayerLib:GetRootPart(Character)

	if not Ignore then
		if not Humanoid then return end
		if EquipDebounce[Character] then return end
		if Character:GetAttribute("Attacking") ~= "" then return end
		if not Base:CanAttack(Character) then return end
	end
	
	local EquipJanitor = JanitorModule.new()
	
	--//Character
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	local IsEquipped = Private:GetEquippedState(Character)

	--// Weapon Data
	local PrimaryWeapon, SecondaryWeapon = WeaponAppearance.findWeapon(Character, "PrimaryWeapon"), WeaponAppearance.findWeapon(Character, "SecondaryWeapon") -- Models
	local PrimaryWeaponData,SecondaryWeaponData = WeaponAppearance.GetModuleFromName(Data.PrimaryWeapon),WeaponAppearance.GetModuleFromName(Data.SecondaryWeapon) -- Modules
	local PrimaryAnimationFolder,SecondaryAnimationFolder = Animations.Combat[PrimaryWeaponData.AnimationType]['Primary'],Animations.Combat[SecondaryWeaponData.AnimationType]['Secondary'] -- Animations

	local MarkerName = IsEquipped and "UnequipPoint" or "EquipPoint"
	
	--// Getting Animations
	local PrimaryEquip = AnimationLibrary:GetTrack(Animator,PrimaryAnimationFolder[IsEquipped and "Unequip" or "Equip"])
	local SecondaryEquip = AnimationLibrary:GetTrack(Animator,SecondaryAnimationFolder[IsEquipped and "Unequip" or "Equip"])
	local PrimaryIdle = AnimationLibrary:GetTrack(Animator,PrimaryAnimationFolder.Idle)
	local SecondaryIdle = AnimationLibrary:GetTrack(Animator,SecondaryAnimationFolder.Idle)
	
	--------------- Playing And Setting Cooldown
	Private:SetEquippedState(Character)
	PrimaryEquip:Play(.1)
	SecondaryEquip:Play(.1)
	
	EffectsService:Fire("CombatFX",{
		Caster = Character,
		Effect = "Combat/Trail/Enable", 
		Variables = {
			Sound = (not IsEquipped) and PrimaryWeaponData.AnimationType.."Equip"
		}
	})
	
	EquipDebounce[Character] = true
	
	if IsEquipped then
		EquipJanitor:Add(task.spawn(function() -- Do Unequip
			PrimaryIdle:Stop(.1)
			SecondaryIdle:Stop(.1)
		end),true)
	else
		EquipJanitor:Add(task.delay(0.2, function()
			PrimaryIdle:Play(.1)
			SecondaryIdle:Play(.1)
		end), true)
	end
	-------------------------- Setting Welds
	EquipJanitor:Add(PrimaryEquip:GetMarkerReachedSignal(MarkerName):Connect(function()
		WeaponAppearance.SetSingleWeaponEquipped(Character , "PrimaryWeapon",{Name = Data.PrimaryWeapon},not IsEquipped)
	end),"Disconnect")
	
	EquipJanitor:Add(SecondaryEquip:GetMarkerReachedSignal(MarkerName):Connect(function()
		WeaponAppearance.SetSingleWeaponEquipped(Character , "SecondaryWeapon",{Name = Data.SecondaryWeapon}, not IsEquipped)
	end),"Disconnect")
	
	----------------------- Waiting For Finish
	EquipJanitor:Add(function()
		EquipDebounce[Character] = false
	end)
	
	EquipJanitor:Add(task.spawn(function() --- Finishing All
		repeat task.wait() until (not SecondaryEquip.IsPlaying) and (not PrimaryEquip.IsPlaying)	
		
		EffectsService:Fire("CombatFX",{
			Caster = Character,
			Effect = "Combat/Trail/Disable", 
			Variables = {
				Enabled = false,
			}
		})
		
		EquipJanitor:Destroy()
	end), true)
end

function Base:ForceUnequip(Character : Model, Data)
	if EquippedStates[Character]  then
		Base:Equip(Character, Data, true)
	end
end

function Base:Crit(Character: Model, WeaponData)
	local WeaponModule = WeaponAppearance.GetModuleFromName(WeaponData.SecondaryWeapon)

	if not WeaponModule then return end
	if not WeaponModule.CriticalLogic then return end
	if CriticalDebounce[Character] then return end

	local CritJanitor = JanitorModule.new()

	Character:SetAttribute("Attacking","W")
	CriticalDebounce[Character] = true
	
	local CritCooldown = WeaponModule.CriticalCooldown or 5
	local self = CriticalClass.new(Character,{
		WeaponName = WeaponData.SecondaryWeapon,
		Logic = WeaponModule.CriticalLogic
	})

	self:ExecuteLogic()
	
	CritJanitor:Add(Character:GetAttributeChangedSignal("Attacking"):Connect(function() -- when it stops
		if Character:GetAttribute("Attacking") ~= "" then return end
		
		CritJanitor:Add(task.delay(CritCooldown,function()
			CriticalDebounce[Character] = nil 
			CritJanitor:Destroy()
		end))
		
	end),"Disconnect")

end

function Base:BlockBreak(Character : Model)
	if not Character then return end
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	local Duration = 2
	local Anim = AnimationLibrary:GetTrack(Humanoid.Animator,Animations.Combat.Misc.Guardbroken)
	Anim:Play(.1)
	
	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)
	CharacterStunContainer:AddStun(Character, "BlockBreak", Duration, true, 0)
	
	Character:SetAttribute("BlockBar",0)
	Base:Unblock(Character)
	
	task.delay(Duration,function()
		Anim:Stop(.1)
	end)
end

function Base:HitPersonBlock(Character, Victim, Direction)
	local Anim = AnimationLibrary:GetTrack(Victim.Humanoid.Animator,Animations.Combat.Misc['Block_'..Direction..'_Successful'])
	Anim:Play()
	Anim.Priority = Enum.AnimationPriority.Action4
	
	EffectsService:Fire("CombatFX",{
		Caster = Victim,
		Effect = "Combat/MainEffects/Block", 
		Variables = {Direction = Direction}
	})
end

function Base:SuccessfulParry(Character, Victim, Direction)
	local Anim = AnimationLibrary:GetTrack(Victim.Humanoid.Animator,Animations.Combat.Misc['Parry_'..Direction])
	Anim.Priority = Enum.AnimationPriority.Action4
	Anim:Play()
	
	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)
	local modelStunContainer = CombatService.GetStunContainerForCharacter(Victim)
	
	--TODO-Make-A-Stunning-Substitution
	local parryIdCharacter = CharacterStunContainer:AddStun(Character, "Attack", .7, true, 0.3) -- Stuns ME FROM ATTACKING MORE
	--local parryStunIdCharacter = modelStunContainer:AddStun(Character, 'Parry', 0.5, true, 0.25)

	local moreStunId = modelStunContainer:AddStun(Victim, "Attack", .4, true, 1) -- Stuns ME FROM ATTACKING MORE
	
	if DashingDebounce[Victim] then
		warn("Debounce Stop Parry")
		DashingDebounce[Victim] = nil
	end
	
	EffectsService:Fire("CombatFX",{
		Caster = Victim,
		Effect = "Combat/MainEffects/Parry", 
		Variables = {Direction = Direction}
	})
	
	Base:AddBlockBar(Character, 15)
	Base:AddBlockBar(Victim,-40)
end

function Base:CheckForState(Victim,ParryDir)
	if Victim:GetAttribute("Ragdolled") or Victim:GetAttribute("Knocked") then
		return "Hit"
	end
	if Victim:GetAttribute("Dashing") == ParryDir then
		return "Dashing"
	elseif Victim:GetAttribute("Blocking") == ParryDir then	
		return "Blocking"
	else	
		return "Hit"
	end
end

function Base:CanAttack(Character)
	if Character:GetAttribute("BlockBroken") then return end
	if Character:GetAttribute("Blocking") ~= "" then return end
	if Character:GetAttribute("Dashing") ~= "" then return end
	if Character:GetAttribute("Attacking") ~= "" then return end
	if Character:GetAttribute("Ragdolled") then return end
	if Character:GetAttribute("Knocked") then return end
	return true
end

function Base:CheckForFeint(Character,Track,Janitor)
	if Character:GetAttribute("Feint") then
		Track:Stop(.1)
		Janitor:Cleanup()
		M1_Debounce[Character] = true

		task.delay(.2,function()
			M1_Debounce[Character] = false
		end)
		
		EffectsService:Fire("CombatFX",{
			Caster = Character,
			Effect = "Combat/MainEffects/PlaySound", 
			Variables = {
				Sound = "Feint"
			}
		})


		return true
	end
	
	return false
end

function Base:StunAnimation(Character: Model)
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	local HumanoidRootPart = PlayerLib:GetRootPart(Character) :: BasePart

	if (not Humanoid) or (not HumanoidRootPart) then return end
	
	EffectsService:Fire("CombatFX",{
		Caster = Character,
		Effect = "Combat/MainEffects/StunAnimation", 
	})

end

function Base:AddBlockBar(Character: Model,Amount: number)
	local CurrentBlockBar = Character:GetAttribute("BlockBar") or 0
	
	Character:SetAttribute("BlockBar",math.clamp(CurrentBlockBar + Amount,0,100))
	
	if Character:GetAttribute("BlockBar") == 100 then
		Base:BlockBreak(Character)
	end

end

function Base:Attack(Character: Model, Direction: 'A' | "D" | "W", WeaponData)
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	local HumanoidRootPart = PlayerLib:GetRootPart(Character) :: BasePart
	
	if (not Humanoid) or (not HumanoidRootPart) then return end
	if M1_Debounce[Character] then return end
	if not EquippedStates[Character] then return end
	if not Private:CheckIfTypeIsCorrect(Direction,{"A","D","W"}) then return end
	if not Base:CanAttack(Character) then return end
	
	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)

	if CharacterStunContainer:HasActiveStunType("Attack") then return end
	if CharacterStunContainer:HasActiveStunType("BlockBreak") then return end
	
	local AttackType = (Direction == 'A' or Direction == "D") and "PrimaryWeapon" or "SecondaryWeapon"
	local PrimaryWeapon = WeaponAppearance.findWeapon(Character, "PrimaryWeapon")
	local PrimaryWeaponData = WeaponAppearance.GetModuleFromName(WeaponData.PrimaryWeapon)
	local PrimaryAnimationFolder = Animations.Combat[PrimaryWeaponData.AnimationType]['Primary']
	local PrimaryWeaponTrail = PrimaryWeapon:FindFirstChildWhichIsA("Trail", true)

	if AttackType == "SecondaryWeapon" then
		Base:Crit(Character, WeaponData)
		return
	end

	local AnimationObject = PrimaryAnimationFolder:FindFirstChild('Attack'..Direction)
	if not AnimationObject then
		warn("[Combat Base] : Animation Not Found for:",('Attack'..Direction))
		return
	end

	Character:SetAttribute("Attacking",Direction)

	local Track = Humanoid:LoadAnimation(AnimationObject) --AnimationLibrary:GetTrack(Humanoid.Animator,AnimationObject)
	local AttackJanitor = JanitorModule.new()
	local ParryDir = Direction == 'A' and "D" or 'A'
	local Hitbox

	Track:Play(.1)

	EffectsService:Fire("CombatFX",{
		Caster = Character,
		Effect = "Combat/Trail/Enable", 
		Variables = {
			Single = "Primary"
		}
	})

	AnimationLibrary:StopAnimation(Character,Animations.Combat.Misc.Parry_A)
	AnimationLibrary:StopAnimation(Character,Animations.Combat.Misc.Parry_D)

	Character:SetAttribute("Feint",false)
	
	AttackJanitor:Add(task.delay(.25,function()
		Character:SetAttribute("Feint",false)
	end))

	AttackJanitor:Add(function()
		EffectsService:Fire("CombatFX",{
			Caster = Character,
			Effect = "Combat/Trail/Disable", 
		})
		
		Character:SetAttribute("Attacking","")
	end)

	AttackJanitor:Add(Character:GetAttributeChangedSignal("Stunned"):Connect(function()
		if not Character:GetAttribute("Stunned") then return end
		if Hitbox and Hitbox.Stop then Hitbox:Stop() end
		
		Track:Stop(.1)
		AttackJanitor:Cleanup()
	end),"Disconnect", "StunnedSignal")
	
	AttackJanitor:Add(task.delay(.55,function() Base:CheckForFeint(Character,Track,AttackJanitor) end)) -- LateFeint
	AttackJanitor:Add(task.delay(.35,function() Base:CheckForFeint(Character,Track,AttackJanitor) end)) -- EarlyFeint
	
	AttackJanitor:Add(Track:GetMarkerReachedSignal("Hitbox"):Connect(function()
		local damageData = PrimaryWeaponData.DamageData
		local Settings = {} :: HitboxSettings
		Settings.Visualize = false
		Settings.Size = PrimaryWeaponData.HitboxData.SwingSize
		Settings.CFrame = HumanoidRootPart.CFrame * CFrame.new(0,0,-PrimaryWeaponData.HitboxData.SwingSize.Z/2)
		Settings.Count = 1
		Settings.LifeTime = .1
		Settings.MaxHits = 1
		Settings.Shape = "Block"

		Hitbox = BamzHitboxModule.new(Character, Settings)
		Hitbox.Janitor:Add(Hitbox.OnHit:Connect(function(tableOfModels : {Model})
			for _, model in tableOfModels do
				if model == Character then continue end
				if Character:GetAttribute("GettingActionDoneTo") then return end
				local modelStunContainer = CombatService.GetStunContainerForCharacter(model)
				
				--modelStunContainer.Changed:Connect(function(stunnedState : boolean)
				--	model:SetAttribute("Stunned", stunnedState)
				--end)
				
				local State = Base:CheckForState(model,ParryDir)

				if not modelStunContainer then return end

				if State == "Dashing" then -- Parry
					Base:SuccessfulParry(Character, model, Direction)
					EffectsService:Fire("CombatFX",{
						Caster = Character,
						Effect = "Combat/MainEffects/PlaySound", 
						Variables = {
							Sound = 'Clash'..Direction
						}
					})

					Track:Stop(.1)
					AttackJanitor:Cleanup()
				
				elseif State == "Blocking" then	
					local HisPrimaryWeaponData = WeaponAppearance.GetModuleFromName(model:GetAttribute("PrimaryWeapon"))
					local HisSecondaryWeaponData = WeaponAppearance.GetModuleFromName(model:GetAttribute("SecondaryWeapon"))
					local ChosenName = (Direction == "D" and HisPrimaryWeaponData.AnimationType or HisSecondaryWeaponData.AnimationType)
					
					Base:HitPersonBlock(Character,model,ParryDir)
					Base:AddBlockBar(model,30)
					
					EffectsService:Fire("CombatFX",{
						Caster = Character,
						Effect = "Combat/MainEffects/PlaySound", 
						Variables = {
							Sound = (ChosenName..'Block'..Direction)
						}
					})
				elseif State == "IFrames" then	
				else

					--- Attributes
					Base:StunAnimation(model)
					Base:AddBlockBar(model,-5)
					-- Stun
					model:SetAttribute("Stunned",false)
					model:SetAttribute("Stunned",true)
					modelStunContainer:AddStun(model, "Attack", .7, true, 0.3) -- Stuns For Attack
					
					--- Damage
					EffectsService:Fire("CombatFX",{
						Caster = Character,
						Effect = "Combat/MainEffects/PlaySound", 
						Variables = {
							Sound = (PrimaryWeaponData.AnimationType..Direction..'Hit')
						}
					})
					CombatService.Damage(Character, model, damageData)
					 -- Damaging
					
					--AttackJanitor:Add(task.delay(.15,function() -- DashCooldown
					--	warn("Janitor check:, Setting Dashing Debounce!!!!")
						--DashingDebounce[Character] = nil
					--end))
				end
			end
		end),"Disconnect")

		Hitbox:Start()

		EffectsService:Fire("CombatFX",{
			Caster = Character,
			Effect = "Combat/MainEffects/SwingSound", 
			Variables = {Sound =  (PrimaryWeaponData.AnimationType..'Swing'..Direction)}
		})

	end), "Disconnect")

	AttackJanitor:Add(task.delay(AnimationLibrary:GetAnimationLength(AnimationObject) - .02,function()
		AttackJanitor:Cleanup()
	end))

	AttackJanitor:Add(Track.Ended:Connect(function()
		AttackJanitor:Cleanup()
	end))

end

function Base:Block(Character: Model, Direction: 'A' | "D" )
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	
	if not Humanoid then return end	-- if alive
	if not Private:CheckIfTypeIsCorrect(Direction,{"A","D"}) then return end -- if direction is valid
	if BlockingDebounce[Character] then return end -- if not blocking cooldown
	if not Private:GetEquippedState(Character) then return end -- if weapon equiped
	if Character:GetAttribute("BlockBroken") then return end -- Attributes
	if Character:GetAttribute("Blocking") ~= "" then return end
	if Character:GetAttribute("Dashing") ~= "" then return end
	if Character:GetAttribute("Attacking") ~= "" then return end

	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)

	if CharacterStunContainer:HasActiveStunType(Character,"BlockBreak") then return end
	
	AnimationLibrary:PlayAnimation(Character,Animations.Combat.Misc['Block_'..Direction])
	Character:SetAttribute("Blocking",Direction)
end

function Base:Unblock(Character:Model)
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid

	if not Humanoid then return end	
	
	AnimationLibrary:StopAnimation(Character,Animations.Combat.Misc['Block_A'])
	AnimationLibrary:StopAnimation(Character,Animations.Combat.Misc['Block_D'])
	Character:SetAttribute("Blocking","")
end

function Base:Dash(Character: Model, Direction)
	local DashJanitor = JanitorModule.new()
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end
	if DashingDebounce[Character] then return end
	if not Private:CheckIfTypeIsCorrect(Direction,{"W","S","A","D"}) then return end
	
	---[[ Attributes ]]---
	if not Base:CanAttack(Character) then return end
	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)
	if CharacterStunContainer:HasActiveStunType(Character,"BlockBreak") then return end
	--if CharacterStunContainer:HasActiveStunType(Character, "Attack") then return end -- TODO_Check-This-Line-And-Experiment

	EffectsService:Fire("CombatFX",{
		Caster = Character,
		Effect = "Combat/MainEffects/Dash", 
		Variables = {Direction = Direction}
	})

	DashingDebounce[Character] = true
	Character:SetAttribute("Dashing", Direction)
	
	task.wait(.3) -- Dash Done
	Character:SetAttribute("Dashing", "")

	DashJanitor:Add(task.spawn(function()
		local Start = os.clock()

		while (os.clock() - Start) < 1.4 do
			task.wait()
			
			if not DashingDebounce[Character] then
				DashJanitor:Destroy()
				return
			end
		end
		
		DashingDebounce[Character] = nil

	end))
end

function Base:AttemptFeint(Character: Model)
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid

	if not Humanoid then return end
	if Character:GetAttribute("Attacking") == "" then return end
	
	Character:SetAttribute("Feint",true)
end

function Base:GetNearestGripTarget(Character : Model)
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end
	local CharacterRootPart = PlayerLib:GetRootPart(Character) :: BasePart
	if not CharacterRootPart then return end
	
	local Nearest = nil
	local Mag = CombatService.GripDistance
	
	for _, v in CombatService.RagdollContainers do
		if not v.Ragdolled then continue end
		if not v.Character:GetAttribute("Knocked") then continue end
		if v.Character:GetAttribute("Gripped") then continue end
		if v.Character:GetAttribute("GettingActionDoneTo") then continue end
		local RootPart = PlayerLib:GetRootPart(v.Character)
		if not RootPart then continue end
		
		local Distance = (CharacterRootPart.Position - RootPart.Position).Magnitude
		
		if Distance <= Mag then
			Mag = Distance
			Nearest = v.Character
		end
	end
	
	return Nearest
end

function Base:AttemptGrip(Character)
	if GripDebounce[Character]then return end
	if GripJanitors[Character] then
		GripJanitors[Character]:Destroy()
		GripJanitors[Character]= nil
		return
	end
	--- Getting Target
	local Target =  Base:GetNearestGripTarget(Character)
	
	if not Target then return end -- Stoppi
	if not Base:CanAttack(Character) then return end -- Stopping If Stunned

	local CharacterHumanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	local TargetHumanoid = PlayerLib:IsCharacterAlive(Target) :: Humanoid
	if not CharacterHumanoid then return end
	if not TargetHumanoid then return end
	local CharacterAnimator, TargetAnimator = CharacterHumanoid.Animator, TargetHumanoid.Animator
	
	local RagdollContainer = CombatService.GetRagdollContainerForCharacter(Target)
	if not RagdollContainer then return end

	local Folder = game.ReplicatedStorage.Client.Animations.Combat.Fists.Secondary -- TODO DO it of your secondary
	local GripJanitor = JanitorModule.new()
	local Finished = false
	
	local MyAnimation = GripJanitor:Add(CharacterAnimator:LoadAnimation(Folder.Gripping),"Stop") :: AnimationTrack
	local TargetAnimation = GripJanitor:Add(TargetAnimator:LoadAnimation(Folder.Gripped),"Stop") :: AnimationTrack
	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)
	local StunId = CharacterStunContainer:AddStun(Character, "Grip", AnimationLibrary:GetAnimationLength(MyAnimation.Animation) * MyAnimation.Speed, true, 0)
	
	MyAnimation:Play(.1)
	TargetAnimation:Play(.1)
	
	--MyAnimation:AdjustSpeed(.05)
	--TargetAnimation:AdjustSpeed(.05)
	
	RagdollContainer:DisableRagdoll(PlayerService:GetPlayerFromCharacter(Character)) -- Disables with network ownership
	Target:SetAttribute("Knocked",true) 
	Target:SetAttribute("GettingActionDoneTo",true)
	TargetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	
	--------- Setting Rotation
	Target.Animate.Enabled = false
	TargetHumanoid.AutoRotate = false
	CharacterHumanoid.AutoRotate = false
	GripJanitors[Character] = GripJanitor
	

	--warn(AnimationLibrary:GetAnimationLength(MyAnimation.Animation) * MyAnimation.Speed)
	-------- Tweening
	--Character.HumanoidRootPart.Anchored = true
	--Target.HumanoidRootPart.Anchored = true
	
	for i,v in Target:GetChildren() do
		if not v:IsA("BasePart") then continue end
		v:SetNetworkOwner(PlayerService:GetPlayerFromCharacter(Character))
	end


	local TargetAttach = GripJanitor:Add(Instance.new("Attachment",Target.HumanoidRootPart), "Destroy")
	local CharacterAttach = GripJanitor:Add(Instance.new("Attachment",Character.HumanoidRootPart), "Destroy")

	local TargetPositionAttach = GripJanitor:Add(Instance.new("Attachment", Character.HumanoidRootPart), "Destroy")
	TargetPositionAttach.CFrame = CFrame.new(0,0,-1) * CFrame.Angles(0,math.pi,0)

	GripJanitor:Add(task.spawn(function() --- Making Victim Stay in Place
		local TargetAlignOrientation = GripJanitor:Add(Instance.new("AlignOrientation"), "Destroy")
		TargetAlignOrientation.Parent = Character
		TargetAlignOrientation.MaxTorque = math.huge --Vector3.new(9e9,9e9,9e9)
		TargetAlignOrientation.Attachment1 = TargetPositionAttach
		TargetAlignOrientation.Attachment0 = TargetAttach
		TargetAlignOrientation.RigidityEnabled = true

		local TargetAlignPosition = GripJanitor:Add(Instance.new("AlignPosition"),"Destroy")
		TargetAlignPosition.Parent = Character
		TargetAlignPosition.MaxForce = math.huge --Vector3.new(9e9,9e9,9e9)
		TargetAlignPosition.Attachment1 = TargetPositionAttach
		TargetAlignPosition.Attachment0 = TargetAttach
		TargetAlignPosition.RigidityEnabled = true
	end))


	GripJanitor:Add(Character:GetAttributeChangedSignal("Parent"):Connect(function()
		if Character.Parent then return end
		GripJanitor:Destroy()
	end))
	
	GripJanitor:Add(Target:GetAttributeChangedSignal("Parent"):Connect(function()
		if Target.Parent then return end
		GripJanitor:Destroy()
	end))

	GripJanitor:Add(function()
		if CharacterStunContainer:HasActiveStunType("Grip") then
			CharacterStunContainer:RemoveStun(Character,"Grip")
		end
		MyAnimation:Stop()
		TargetAnimation:Stop()
		---- Setting Back
		
		if Character.Parent then
			Character.Head.CanCollide = true
			Character.Torso.CanCollide = true

			Character.HumanoidRootPart.Anchored = false
			CharacterHumanoid.AutoRotate = true
		end
	
		------
	
		----------------------
		GripDebounce[Character] = true
		GripJanitors[Character] = nil

		task.delay(1,function()
			GripDebounce[Character] = nil
		end)
	
		
		if (not Finished) and Target.Parent then
			Target:SetAttribute("GettingActionDoneTo",nil)
			Target.Animate.Enabled = true
			Target.HumanoidRootPart.Anchored = false
			TargetHumanoid.AutoRotate = true
			TargetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			Target.HumanoidRootPart:SetNetworkOwner(PlayerService:GetPlayerFromCharacter(Target))
			
			RagdollContainer:EnableRagdoll(25, false, function() 
				Target:SetAttribute("Knocked",false) 
			end,false)
		end
	
		Finished = nil
	end)
	
	GripJanitor:Add(MyAnimation.Ended:Connect(function()
		GripJanitor:Destroy()
	end))

	GripJanitor:Add(Character:GetAttributeChangedSignal("Stunned"):Connect(function()
		if not Character:GetAttribute("Stunned") then return end
		GripJanitor:Destroy()
	end))
	
	GripJanitor:Add(MyAnimation:GetMarkerReachedSignal("Death"):Connect(function()
		Finished = true
		
		if not (TargetHumanoid) or not (Target.Parent) then return end
		
		Target.HumanoidRootPart.Anchored = false
		TargetHumanoid.BreakJointsOnDeath = false
		Target:SetAttribute("Gripped", true)

		RagdollContainer:EnableRagdoll(25, true, function() 
			Target:SetAttribute("Knocked",false) 
		end,true)

		task.spawn(function()
			task.wait(5)
			TargetHumanoid.RequiresNeck = false
			TargetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			TargetHumanoid.Health = 0
			TargetHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end)

	end))
	
	GripJanitor:Add(MyAnimation:GetMarkerReachedSignal("HeadFling"):Connect(function()
		if Target:FindFirstChild("Head") then
			Target.Head.CanCollide = true
			if Target.Head:FindFirstChild('Part0Torso-Part1Head-SocketPart0Torso-Part1Head-Socket') then
				Target.Head['Part0Torso-Part1Head-Socket'].Enabled = false
			end

			if  Target:FindFirstChild("Torso") and Target.Torso:FindFirstChild('Neck') then
				Target.Torso['Neck'].Enabled = false
			end

			Target.Head.Velocity = Vector3.new(0,50,0)
		end
	end))

end

function Base:AttemptCarry(Character)
	if CarryDebounce[Character] then return end

	if CarryJanitors[Character] then
		CarryJanitors[Character]:Destroy()
		CarryJanitors[Character]= nil
		return
	end
	
	local Target =  Base:GetNearestGripTarget(Character)

	if not Target then return end -- Stoppi
	if not Base:CanAttack(Character) then return end -- Stopping If Stunned

	local CharacterHumanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	local TargetHumanoid = PlayerLib:IsCharacterAlive(Target) :: Humanoid
	if not CharacterHumanoid then return end
	if not TargetHumanoid then return end
	local CharacterAnimator, TargetAnimator = CharacterHumanoid.Animator, TargetHumanoid.Animator

	local RagdollContainer = CombatService.GetRagdollContainerForCharacter(Target)
	if not RagdollContainer then return end
	
	local CarryJanitor = JanitorModule.new()
	local CharacterStunContainer = CombatService.GetStunContainerForCharacter(Character)
	local StunId = CharacterStunContainer:AddStun(Character, "Carry", 9e9, true, .8)
	
	local TargetAnimation = CarryJanitor:Add(TargetAnimator:LoadAnimation(Animations.Combat.Misc.Carried),"Stop") :: AnimationTrack
	TargetAnimation:Play()
	
	RagdollContainer:DisableRagdoll(PlayerService:GetPlayerFromCharacter(Character)) -- Disables with network ownership
	Target:SetAttribute("Knocked",true) 
	Target:SetAttribute("GettingActionDoneTo",true)
	TargetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	TargetHumanoid.PlatformStand = true
	
	CarryJanitors[Character] = CarryJanitor
	
	local Weld = CarryJanitor:Add(Instance.new('Weld'), "Destroy")
	Weld.Parent = Character
	Weld.C0 = CFrame.new(0,.5,1)
	Weld.Part0 = Character.Torso
	Weld.Part1 = Target.Torso
	
	local Plr = PlayerService:GetPlayerFromCharacter(Character)
	local MasslessParts = {}
	
	if Plr then
		CarryJanitor:Add(PlayerService.PlayerRemoving:Connect(function(LeftPlayr)
			if LeftPlayr == Plr then
				if CarryJanitor.Destroy then CarryJanitor:Destroy() end
			end
		end))
	end
	
	for i,v : BasePart in Target:GetDescendants() do
		if not v:IsA("BasePart") then continue end
		if v.Massless then continue end
		
		v.Massless = true
		table.insert(MasslessParts,v)
	end

	CarryJanitor:Add(Character:GetAttributeChangedSignal("Stunned"):Connect(function()
		if not Character:GetAttribute("Stunned") then return end
		if CarryJanitor.Destroy then CarryJanitor:Destroy() end
	end), "Disconnect")

	--- If Character Is Destroyed
	CarryJanitor:Add(Character:GetAttributeChangedSignal("Parent"):Connect(function()
		if Character.Parent then return end
		if CarryJanitor.Destroy then CarryJanitor:Destroy() end
	end), "Disconnect")


	CarryJanitor:Add(Target:GetAttributeChangedSignal("Parent"):Connect(function()
		if Target.Parent then return end
		if CarryJanitor.Destroy then CarryJanitor:Destroy() end
	end), "Disconnect")

	--- if Either Die 
	CarryJanitor:Add(Character.Humanoid.Died:Connect(function()
		if CarryJanitor.Destroy then CarryJanitor:Destroy() end
	end), "Disconnect")
	
	CarryJanitor:Add(TargetHumanoid.Died:Connect(function()
		if CarryJanitor.Destroy then CarryJanitor:Destroy() end
	end), "Disconnect")
	
	CarryJanitor:Add(function()
		if not CharacterStunContainer then print("Character Stun Container nil") return end
		if CharacterStunContainer:HasActiveStunType("Carry") then
			CharacterStunContainer:RemoveStun(Character,"Carry")
		end
		
		for _,v in MasslessParts do
			if v.Parent then
				v.Massless = false
			end
		end
		
		if Weld.Parent then
			Weld:Destroy()
		end
		task.wait()
		MasslessParts = nil
		---- Setting Back

		if Character.Parent then
			Character.Head.CanCollide = true
			Character.Torso.CanCollide = true

			Character.HumanoidRootPart.Anchored = false
			CharacterHumanoid.AutoRotate = true
		end

		------

		----------------------
		CarryDebounce[Character] = true
		CarryJanitors[Character] = nil

		task.delay(1,function()
			CarryDebounce[Character] = nil
		end)


		if Target.Parent then
			Target:SetAttribute("GettingActionDoneTo",nil)
			Target.Animate.Enabled = true
			
			if Target.HumanoidRootPart then
				Target.HumanoidRootPart.Anchored = false
			else
				--Check for void
				
			end
			TargetHumanoid.AutoRotate = true
			TargetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			Target.HumanoidRootPart:SetNetworkOwner(PlayerService:GetPlayerFromCharacter(Target))

			RagdollContainer:EnableRagdoll(25, false, function() 
				Target:SetAttribute("Knocked",false) 
			end,false)
		
		end

		CarryJanitor = nil
	end)
end

---// Connection(s) //

Equip_Remote.OnServerEvent:Connect(function(Player)
	local PlayerProfile = Manager.Profiles[Player]
	if not PlayerProfile then return end
	local Data = PlayerProfile.Data
	Base:Equip(Player.Character, {PrimaryWeapon = Data.EquippedSlots.PrimaryWeapon.Name or Null,SecondaryWeapon = Data.EquippedSlots.SecondaryWeapon.Name or Null}, false)
end)

Block_Remote.OnServerEvent:Connect(function(Player : Player,Key: 'A' | "D" | "Unblock")
	local Character = Player.Character
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end
	local PlayerProfile = Manager.Profiles[Player]
	if not PlayerProfile then return end
	
	if Key == "Unblock" then
		Base:Unblock(Character)
	else
		Base:Block(Character, Key)
	end
end)

Dash_Remote.OnServerEvent:Connect(function(Player : Player,Key)
	local Character = Player.Character
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end
	local PlayerProfile = Manager.Profiles[Player]
	if not PlayerProfile then return end

	Base:Dash(Character,Key)
end)

Combat_Remote.OnServerEvent:Connect(function(Player : Player,Key)
	local Character = Player.Character
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end
	local PlayerProfile = Manager.Profiles[Player]
	if not PlayerProfile then return end
	local Data = PlayerProfile.Data
	
	Base:Attack(Character, Key,{PrimaryWeapon = Data.EquippedSlots.PrimaryWeapon.Name or Null,SecondaryWeapon = Data.EquippedSlots.SecondaryWeapon.Name or Null})
end)

Feint_Remote.OnServerEvent:Connect(function(Player : Player)
	local Character = Player.Character
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end
	local PlayerProfile = Manager.Profiles[Player]
	if not PlayerProfile then return end
	local Data = PlayerProfile.Data

	Base:AttemptFeint(Character)
end)

Grip_Remote.OnServerEvent:Connect(function(Player : Player)
	local Character = Player.Character
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end

	Base:AttemptGrip(Character)
end)

Carry_Remote.OnServerEvent:Connect(function(Player : Player)
	local Character = Player.Character
	local Humanoid = PlayerLib:IsCharacterAlive(Character) :: Humanoid
	if not Humanoid then return end

	Base:AttemptCarry(Character)
end)

---[[ Return ]]---
return Base