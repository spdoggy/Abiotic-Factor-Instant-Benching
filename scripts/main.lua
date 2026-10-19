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
local myPlayerCache = CreateInvalidObject() ---@type AAbiotic_PlayerCharacter_C
local TheWorld = CreateInvalidObject()  ---@cast WorldCache UWorld

print("Starting Instant Benching mod initialization")


local function handle_minigame(Context)
    local player = Context:get() ---@type AAbioticPlayerController
    --print(">> Instant Benching: Minigame Hook Caught << ")
    if ModEnabled then
        player.Request_BenchPressReward(1000)
    end
end

---Get and Cache World Instance
---@return UWorld
function GetWorld()
    if TheWorld ~= nil and TheWorld.IsValid ~= nil and TheWorld:IsValid() then
        return TheWorld
    else
        local gameState = FindFirstOf("Abiotic_Survival_GameState_C")
        if gameState:IsValid() then
            local world = gameState:GetWorld()
            if world and world:IsValid() then
                TheWorld = world
                return world
            end
        end
    end
    print("[GetWorld]: Invalid World")
    return TheWorld
end

---Get Client Player Controller (local player)
---@return AAbioticPlayerController
local function GetMyPlayerController()

    if GameInstanceCache == nil or GameInstanceCache.IsValid == nil or not GameInstanceCache:IsValid() then
        local world = GetWorld()
        GameInstanceCache = world.OwningGameInstance
    end

    if GameInstanceCache ~= nil and GameInstanceCache.IsValid ~= nil and GameInstanceCache:IsValid() then
        local local_players = GameInstanceCache.LocalPlayers
        if local_players and #GameInstanceCache.LocalPlayers > 0  then
            local localPlayer = local_players[1]
            myPlayerControllerCache = localPlayer.PlayerController
            return myPlayerControllerCache
        end
    end
    return CreateInvalidObject() ---@type ---@return AAbioticPlayerController

end

---Get Client Player Char (local player)
---@return AAbiotic_PlayerCharacter_C
local function GetMyPlayer()
    if myPlayerCache ~= nil and myPlayerCache.IsValid ~= nil and myPlayerCache:IsValid() then
        return myPlayerCache
    end

    local player_controller = GetMyPlayerController()
    if player_controller ~= nil and player_controller.IsValid ~= nil and player_controller:IsValid() then
        return player_controller.MyPlayerCharacter
    end

    return CreateInvalidObject() ---@type AAbiotic_PlayerCharacter_C
end


---Initializing Hooks
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


    print("Instant Benching Hooks initialized")
end)


--- Define Mod ToggleKey Function
if ToggleKey and ToggleKeyModifiers then
    local function SetModState(Enable)
        ModEnabled = not ModEnabled
        ExecuteInGameThread(function()
            -- test stuff here

            local warn_beep = false
            local green = 0
            local red = 3
            local msg_color = red
            local msg = "Instant Benching: Disabled"

            if ModEnabled then
                msg = "Instant Benching: Enabled"
                msg_color = green
            end

            local fText = FText(msg)
            local my_player = GetMyPlayer()

            if fText and my_player then
                pcall(function()
                    my_player:Client_DisplayWarningMessage(fText, msg_color, warn_beep)

                    --my_player:StartSneakingXPTimer()
                    --my_player:Timer_CheckForSneakingXP()
                end)
            end
        end)
    end

    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(ModEnabled)
    end)
end

print("Mod loaded successfully")
