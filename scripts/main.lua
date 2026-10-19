--[[
    Author: SpDoggy
    Date: 2026-08-19
    Mod Name: Instant Benching
]]

---------- Configurations ----------
-- Enable mod from the start
ModEnabled = true

-------------- Hotkeys -------------
-- Possible keys: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/key.md
-- See ModifierKey: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/modifierkey.md
-- ModifierKeys can be combined. e.g.: {ModifierKey.CONTROL, ModifierKey.ALT} = CTRL + ALT + Q
-- Set to `nil` to disable hotkey.
ToggleKey = Key.F5
ToggleKeyModifiers = {ModifierKey.CONTROL}
------------------------------------

------------------------------
-- Don't change code below --
------------------------------
ModName = "InstantBenching"
ModVersion = "1.0.0"
DebugMode = false

LogInfo("Starting Instant Benching mod initialization")


Debuffs = {
    Netted = "Debuff_Netted",
    NettedCannon = "Debuff_NettedCannon",
    Bleeding = "Debuff_Bleeding",
    SevereBleeding = "Debuff_SevereBleeding",
    ShockTrap = "Debuff_ShockTrap",
    Zapped = "Debuff_Zapped",
    ZappedPurple = "Debuff_ZappedPurple",
    Ignited = "Debuff_Ignited",
    IgnitedHoly = "Debuff_Ignited_Holy",
    Rooted = "Debuff_Rooted",
    Fear = "Debuff_Fear",
    Concussed = "Debuff_Concussed",
    Debuff_Tired_Legs = "Debuff_Tired_Legs",
    Debuff_LacticAcid_Legs = "Debuff_LacticAcid_Legs",
    Debuff_LacticAcid_Arms = "Debuff_LacticAcid_Arms",
}

Buffs = {
    HazSuit = "Buff_HazmatSuit",
    AirSeal = "Buff_AirtightSeal",
    LeadVest = "Buff_LeadVest",
    RadPills = "Buff_Radpills",
    HealShot = "Buff_SyringeHeal",
    Buff_Leyak360 = "Buff_Leyak360",
    Buff_LeyakSafetyZone = "Buff_LeyakSafetyZone",
    Buff_Workout_Legs = "Buff_Workout_Legs",
    Buff_Workout_Arms = "Buff_Workout_Arms",
    Buff_FogLantern  = "buff_foglantern",
    Buff_NeutrinoDampener = "Buff_NeutrinoDampener",
}



---@param actor class AActor*
function IsActorValid(actor)
    if IsNotValid(actor) then return false end

    local ok, npcData = pcall(function() return actor.NPCData end)
    if not ok then return false end

    -- Discard non-level loaded actors
    if IsValid(npcData) then
        local ok, levelLoaded = pcall(function()
            return actor:IsLevelLoaded(false)
        end)
        if not ok or not levelLoaded then return false end
    end

    return true
end

function ResolveByPath(path)
    if not path then return nil end
    local obj
    pcall(function() obj = StaticFindObject(path) end)
    if obj and obj:IsValid() then return obj end
    return nil
end


function ObjectPath(obj)
    if IsNotValid(obj) then return nil end
    local full
    pcall(function() full = obj:GetFullName() end)
    if not full then return nil end
    return full:match("^%S+ (.+)$") or full   -- strip the "ClassName " prefix
end

function IsActorInvalid(actor)
    return not IsActorValid(actor)
end


local function handle_minigame(Context)
    local player = Context:get() ---@type AAbioticPlayerController
    -- print(">> Instant Benching: Minigame Hook Caught << ")
    if ModEnabled then
        player.Request_BenchPressReward(1000)
    end
end

local function handle_throw(Context)
    -- local player_cont = Context:get() ---@type AAbioticPlayerController
    -- local owner = player_cont:GetOwner()
    -- print("player_cont: " .. player_cont:GetFullName())
    -- print("player_cont: " .. player_cont:GetClass():GetFullName())
    -- print("owner: " .. owner:GetFullName())
    -- print("owner: " .. owner:GetClass():GetFullName())




    -- print(">> Instant Benching: Throw Hook Caught << ")
    -- prog = player_cont.CharacterProgressionComponent
    -- print("CharacterProgressionComponent: " .. prog:GetFullName())
    -- print("CharacterProgressionComponentClassName: " .. prog:GetClass():GetFullName())

    
    -- sprint_check = prog.SprintingXPCheckInterval
    -- prog.SprintingXPCheckInterval = 0.01
    -- --print("sprint_check: " .. sprint_check:GetFullName())
    -- --print("sprint_check: " .. sprint_check:GetClass():GetFullName())

    
    -- print("SprintingXPCheckInterval")
    -- print(sprint_check)
end



-- Shared buff plumbing: path-capture the actor's BuffDebuffComponent (+ optional linked actor), then
-- run `apply(comp, link)` OFF-HOOK (ExecuteInGameThread, all roles), both re-resolved BY PATH inside
-- the callback.
--   * Off-hook because a buff's first apply can blocking-load and hang the game thread.
--   * GC-SAFE because a wrapper captured across the hop can be freed = native AV (see Utils.ObjectPath).
local function applyBuffOffHook(actor, linkedActor, apply, label)
    -- BOTH bails used to be SILENT, which is the worst shape for this function: a buff that never
    -- applies looks identical to a buff that applied and did nothing, and the two have completely
    -- different fixes. They are one-line logs now (DEBUG_NPC_ACTIONS).
    --   * IsActorValid opens with an actor.NPCData read - fine on NPCs, and a PLAYER has no such
    --     field, so this is exactly the sort of place a player-only failure hides.
    if IsActorInvalid(actor) then
        return
    end
    local compPath = ObjectPath(actor.BuffDebuffComponent)
    if not compPath then
        -- LogDebug("buff " .. (label or "apply") .. " - SKIPPED: no BuffDebuffComponent path on "
        --     .. tostring(Utils.GetActorName(actor)), require("Settings").DEBUG_NPC_ACTIONS)
        return
    end
    local linkPath = linkedActor and Utils.ObjectPath(linkedActor) or nil

    ExecuteInGameThread(function()
        -- Freeze breadcrumb (DEBUG_FREEZE_TRACE watchdog): a buff apply cold-loads its buff
        -- object by ROW NAME (the debuff-preload trap, CLAUDE.md 6) - if the process hangs in
        -- here the watchdog names the component. `label` distinguishes apply from remove.

        local comp = ResolveByPath(compPath)
        if comp then
            local link = linkPath and ResolveByPath(linkPath) or nil
            apply(comp, link)
        end

    end)
end


-- [AUTHORITY] Apply a buff via the DIRECT Server_ApplyBuff path.
--   * Server_TryApplyBuff (AddBuff) routes on Is_Locally_Controlled and NO-OPS when a server applies
--     to a player - NPC->player debuffs (BeeSwarm) never land through AddBuff; use this instead.
local buffHandleLib
function ApplyBuffLinked(actor, buff, duration, linkedActor, limb)
    applyBuffOffHook(actor, linkedActor, function(comp, link)
        if IsNotValid(buffHandleLib) then
            buffHandleLib = StaticFindObject("/Script/AbioticFactor.Default__BuffDebuffHandleFunctionLibrary")
        end
        if IsNotValid(buffHandleLib) then
            Utils.LogBad("ApplyBuffLinked - BuffDebuffHandleFunctionLibrary not found")
            return
        end
        pcall(function()
            local handle = buffHandleLib:MakeBuffDebuffRowHandle(FName(buff))
            -- (handle, OverrideDefaultDuration, NewDuration, Limb, LinkedActor, bool)
            comp:Server_ApplyBuff(handle, true, duration or 10, limb or 0, link, false)
        end)
    end)
end



function doesPlayerHaveBuff(player, buff_name)

    buff_map = player.BuffDebuffComponent.CurrentBuffs -- @TArray<FBuffDebuffEntry> CurrentBuffs;     
    has_the_buff = false
    buff_map:ForEach(function(index, value)


        --FBuffDebuffRowHandle BuffRow;                                                     // 0x0000 (size: 0x20)
        --EBodyLimbs ParentLimb;                                                            // 0x0020 (size: 0x1)
        --float BuffExpireTime;      
        --print(value:get())
        -- Remember, need to :ToString() for an FName
        buff_debuff_name = value:get().BuffRow.RowName:ToString()
        --print(buff_debuff_name)
        if buff_debuff_name == buff_name then
            has_the_buff = true
        end

    
    end)
    return has_the_buff
end



local function Handle_Server_ApplyBuff(Context, BuffRow, bOverrideDefaultDuration, NewDuration, Limb, LinkedActor, bSkipDialog)

    -- Log.Debug(">>> Handle_Server_ApplyBuff <<<")

    local overrideDefaultDuration = bOverrideDefaultDuration:get() ---@type boolean
    local newDuration = NewDuration:get() ---@type float
    local limb = Limb:get() ---@type EBodyLimbs
    local linkedActor = LinkedActor:get() ---@type AActor
    local skipDialog = bSkipDialog:get() ---@type boolean

    buff_row = BuffRow:get()
    -- Log.Debug("BuffRow: " .. buff_row:GetFullName())
    -- Log.Debug("BuffRowClassName: " .. buff_row:GetClass():GetFullName())
    

    local actor = Context:get() -- AActor
    -- Log.Debug("Actor: " .. actor:GetFullName())
    -- Log.Debug("ActorClassName: " .. actor:GetClass():GetFullName())

    local actor_owner = actor:GetOwner()

    local gameState = FindFirstOf("GameStateBase")

    if gameState and gameState.PlayerArray then
        for i = 1, #gameState.PlayerArray, 1 do
            local playerState = gameState.PlayerArray[i]
            if playerState:IsValid() and playerState.PawnPrivate:IsValid() and actor_owner ~= nil then
                local playerName = playerState.PlayerNamePrivate:ToString()
                -- Log.Debug("Buff/Debug Player Name:")
                --Log.Debug(playerName)

                -- Log.Debug(actor:GetAddress())
                -- Log.Debug(actor_owner:GetAddress())
                -- Log.Debug(playerState:GetAddress())
                

                if actor_owner:GetAddress() == playerState.PawnPrivate:GetAddress() then

                    local buffRow = BuffRow:get() ---@type FBuffDebuffRowHandle
                    local rowName = buffRow.RowName
                    local buffRowName = rowName:ToString()
                    player_controller = playerState:GetPlayerController()
                    --Log.Debug("rowName: " )
                    --Log.Debug(rowName)
                    --Log.Debug(buffRowName)

                    if #buffRowName > 5 and buffRowName == Buffs.RadPills then
                        
                        NewDuration:set(500)
                        bOverrideDefaultDuration:set(true)
                        bSkipDialog:set(true)

                        -- TODO: Improve RadPill and Pentetic Acid Syringe
                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.HazSuit, 500)
                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.AirSeal, 500)
                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.LeadVest, 500)
                    end

                    if buffRowName == Buffs.Buff_FogLantern then
                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.HazSuit, 500)
                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.AirSeal, 500)
                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.LeadVest, 500)

                    end

                    if buffRowName == Debuffs.Debuff_LacticAcid_Legs then
                        NewDuration:set(0.001)
                        bOverrideDefaultDuration:set(true)
                        bSkipDialog:set(true)

                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.Buff_Workout_Legs, 200)
                    end

                    
                    if buffRowName == Debuffs.Debuff_LacticAcid_Arms then
                        NewDuration:set(0.001)
                        bOverrideDefaultDuration:set(true)
                        bSkipDialog:set(true)

                        ApplyBuffLinked(playerState.PawnPrivate, Buffs.Buff_Workout_Arms, 200)
                    end



                    

                    if buffRowName == Buffs.HealShot then
                        

                        --NewDuration:set(45)
                        --bOverrideDefaultDuration:set(true)
                        --bSkipDialog:set(true)

                        -- TODO: Improve Healing Syringe
                        -- Check First Aid of all party members
                        -- Apply extra healing based on the sum of all First Aid

                        -- TODO: Base this on First Aid Skills
                        -- Base Syringe is +3 health every 0.5 seconds
                        -- An extra 1-2 per tick should be reasonable, not replacing chem, just supplement

                        -- Powerful if stacked, might have to prevent that

                        -- Bonus wHydration
                        playerState.PawnPrivate.CurrentThirst = playerState.PawnPrivate.CurrentThirst + 20
                        

                        
                        local hp_regen_tick = 3
                        local ticks_per_sec = 2 -- Must be equal to 1000/LoopAsyncRate used below
                        local duration = 45
                        local hp_regen_tick_cnt = 0
                        LoopAsync(500, function()
                            playerState.PawnPrivate:Server_HealRandomLimb(hp_regen_tick, {})
                            playerState.PawnPrivate:OnRep_CurrentHealth()
                            hp_regen_tick_cnt = hp_regen_tick_cnt + 1

                            -- print("Heal Extra Tick")
                            -- print(hp_regen_tick_cnt)

                            if hp_regen_tick_cnt > (duration*ticks_per_sec) then

                                return true
                            else
                                return false
                            end
                        end)
                    end
                end
            end
        end
    end
end



ExecuteInGameThread(function()
    LogInfo("Initializing Instant Benching hooks")

    --void Request_SendTextChatMessage(FString MessageToSend);
    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Meta/Abiotic_PlayerController.Abiotic_PlayerController_C:InpActEvt_ContinenceMinigame_K2Node_InputActionEvent_1",
        handle_minigame
    )
        if not okHook then
            print("Instant Benching Hook registration failed: %s", tostring(errHook))
        else
            print("Instant Benching Hook registration success: InpActEvt_ContinenceMinigame_K2Node_InputActionEvent_1")
        end
    end)

    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Script/AbioticFactor.CharacterBuffComponent:Server_ApplyBuff",
        Handle_Server_ApplyBuff
    )
        if not okHook then
            print("Hook registration failed: %s", tostring(errHook))
        else
            print("Hook registration success: Handle_Server_ApplyBuff")
        end
    end)

    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C:Local_ThrowWeapon",
        handle_throw
    )
        if not okHook then
            print("Instant Benching Hook registration failed: %s", tostring(errHook))
        else
            print("Instant Benching Hook registration success: Local_ThrowWeapon")
        end
    end)

    LogInfo("Instant Benching Hooks initialized")
end)

if ToggleKey and ToggleKeyModifiers then
    local function SetModState(Enable)
        ExecuteInGameThread(function()
            -- test stuff here
        end)
    end
    
    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

LogInfo("Mod loaded successfully")
