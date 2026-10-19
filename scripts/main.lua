--[[
    Author: SpDoggy
    Date: 2026-08-19
    Mod Name: Instant Benching
]]

---------- Configurations ----------
-- Enable mod from the start
ModEnabled = false

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
local GameInstanceCache = CreateInvalidObject() ---@type UGameInstance
local myPlayerControllerCache = CreateInvalidObject() ---@type AAbioticPlayerController

print("Starting Instant Benching mod initialization")


local function handle_minigame(Context)
    local player = Context:get() ---@type AAbioticPlayerController
    --print(">> Instant Benching: Minigame Hook Caught << ")
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

ExecuteInGameThread(function()
    print("Initializing Instant Benching hooks")

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
        "/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C:Local_ThrowWeapon",
        handle_throw
    )
        if not okHook then
            print("Instant Benching Hook registration failed: %s", tostring(errHook))
        else
            print("Instant Benching Hook registration success: Local_ThrowWeapon")
        end
    end)

    print("Instant Benching Hooks initialized")
end)

if ToggleKey and ToggleKeyModifiers then
    local function SetModState(Enable)
        ModEnabled = not ModEnabled
        ExecuteInGameThread(function()
            -- test stuff here

        end)
    end

    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(ModEnabled)
    end)
end

print("Mod loaded successfully")
