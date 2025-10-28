--[[
================================================================================
BACKPACKER ADDON - SHAMAN AUTOMATION SUITE
================================================================================

VERSION COMPATIBILITY:
- World of Warcraft: Vanilla 1.12.1
- Lua Version: 5.0
- API: Classic WoW 1.12 API

CORE FUNCTIONALITY:
1. SMART HEALING SYSTEM (QUICKHEAL INTEGRATION):
   - Uses QuickHeal addon for all healing decisions
   - Decides between single-target heal (/qh) or chain heal (/qh chainheal)
   - No rank selection - QuickHeal handles all healing optimization
   - Hybrid mode: Switches to DPS when healing not needed

2. ADVANCED TOTEM MANAGEMENT:
   - FULLY CUSTOMIZABLE TOTEMS for each element
   - Configurable delay between totem casts (TOTEM_CAST_DELAY - default 0.25s)
   - Continuous maintenance of all totems (auto-recast if destroyed/expired/out-of-range)
   - Fast totem dropping with local verification flags
   - Independent server buff verification with buffer periods
   - Parallel totem verification (no sequential dependencies)
   - Smart Totemic Recall with dual cooldown system
   - Separate Water Shield handling (self-buff, not affected by totem recall)
   - ZG/Stratholme combat mode: Spammable cleansing totems for mass dispels

[Rest of the header comments remain the same...]
]]

-- Backpacker.lua
-- Main script for Backpacker addon

-- SavedVariables table
BackpackerDB = BackpackerDB or {
    DEBUG_MODE = false,
    FOLLOW_ENABLED = false,
    CHAIN_HEAL_ENABLED = false,
    HEALTH_THRESHOLD = 90,
    STRATHOLME_MODE = false,
    ZG_MODE = false,
    HYBRID_MODE = false,
    FISHING_MODE = false,  -- Add this line (enabled by default)
    
    -- Customizable totem settings
    EARTH_TOTEM = "Strength of Earth Totem",
    FIRE_TOTEM = "Flametongue Totem", 
    AIR_TOTEM = "Windfury Totem",
    WATER_TOTEM = "Mana Spring Totem",

    FOLLOW_TARGET_NAME = nil,
    FOLLOW_TARGET_UNIT = "party1",
};

-- Local variables to store settings
local settings = {
    DEBUG_MODE = BackpackerDB.DEBUG_MODE,
    FOLLOW_ENABLED = BackpackerDB.FOLLOW_ENABLED,
    CHAIN_HEAL_ENABLED = BackpackerDB.CHAIN_HEAL_ENABLED,
    HEALTH_THRESHOLD = BackpackerDB.HEALTH_THRESHOLD,
    STRATHOLME_MODE = BackpackerDB.STRATHOLME_MODE,
    ZG_MODE = BackpackerDB.ZG_MODE,
    HYBRID_MODE = BackpackerDB.HYBRID_MODE,
    
    -- Customizable totem settings
    EARTH_TOTEM = BackpackerDB.EARTH_TOTEM,
    FIRE_TOTEM = BackpackerDB.FIRE_TOTEM,
    AIR_TOTEM = BackpackerDB.AIR_TOTEM,
    WATER_TOTEM = BackpackerDB.WATER_TOTEM,
    FISHING_MODE = BackpackerDB.FISHING_MODE,
    
    -- Follow target settings
    FOLLOW_TARGET_NAME = BackpackerDB.FOLLOW_TARGET_NAME,
    FOLLOW_TARGET_UNIT = BackpackerDB.FOLLOW_TARGET_UNIT or "party1",
};

-- Remove old spell configurations since we're using QuickHeal
-- LESSER_HEALING_WAVE_RANKS and CHAIN_HEAL_RANKS removed

-- Totem definitions with their corresponding buff names (unchanged)
local TOTEM_DEFINITIONS = {
    -- Earth Totems
    ["Strength of Earth Totem"] = { buff = "Strength of Earth", element = "earth" },
    ["Stoneskin Totem"] = { buff = "Stoneskin", element = "earth" },
    ["Tremor Totem"] = { buff = nil, element = "earth" },
    ["Stoneclaw Totem"] = { buff = nil, element = "earth" },
    ["Earthbind Totem"] = { buff = nil, element = "earth" },
    
    -- Fire Totems  
    ["Flametongue Totem"] = { buff = "Flametongue Totem", element = "fire" },
    ["Frost Resistance Totem"] = { buff = "Frost Resistance", element = "fire" },
    ["Fire Nova Totem"] = { buff = nil, element = "fire" },
    ["Searing Totem"] = { buff = nil, element = "fire" },
    ["Magma Totem"] = { buff = nil, element = "fire" },
    
    -- Air Totems
    ["Windfury Totem"] = { buff = "Windfury Totem", element = "air" },
    ["Grace of Air Totem"] = { buff = "Grace of Air", element = "air" },
    ["Nature Resistance Totem"] = { buff = "Nature Resistance", element = "air" },
    ["Grounding Totem"] = { buff = nil, element = "air" },
    ["Sentry Totem"] = { buff = nil, element = "air" },
    ["Windwall Totem"] = { buff = "Windwall Totem", element = "air" },
    
    -- Water Totems
    ["Mana Spring Totem"] = { buff = "Mana Spring", element = "water" },
    ["Healing Stream Totem"] = { buff = "Healing Stream", element = "water" },
    ["Fire Resistance Totem"] = { buff = "Fire Resistance", element = "water" },
    ["Poison Cleansing Totem"] = { buff = nil, element = "water" },
    ["Disease Cleansing Totem"] = { buff = nil, element = "water" },
};

-- Cooldown variables for totem logic (unchanged)
local lastTotemRecallTime = 0;
local lastAllTotemsActiveTime = 0;
local lastTotemCastTime = 0;
local pendingTotems = {};
local TOTEM_RECALL_COOLDOWN = 3;
local TOTEM_RECALL_ACTIVATION_COOLDOWN = 3;
local TOTEM_VERIFICATION_TIME = 3;
local TOTEM_CAST_DELAY = 0.35;

-- Initialize totem state with current settings (unchanged)
local function InitializeTotemState()
    return {
        { 
            element = "air",  -- ADD THIS LINE
            spell = settings.AIR_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.AIR_TOTEM] and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0 
        },
        { 
            element = "fire",  -- ADD THIS LINE
            spell = settings.FIRE_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.FIRE_TOTEM] and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0 
        },
        { 
            element = "earth",  -- ADD THIS LINE
            spell = settings.EARTH_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0 
        },
        { 
            element = "water",  -- ADD THIS LINE
            spell = settings.WATER_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0 
        },
    };
end

local totemState = InitializeTotemState();

-- Event handler (unchanged)
local function OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Backpacker" then
        for k, v in pairs(BackpackerDB) do
            settings[k] = v;
        end
        -- Reinitialize totem state with loaded settings
        totemState = InitializeTotemState();
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Addon loaded. QuickHeal integration enabled.");
    end
end

-- Utility functions
local function TableLength(table)
    local count = 0;
    for _ in pairs(table) do
        count = count + 1;
    end
    return count;
end

local function PrintMessage(message)
    if settings.DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. message);
    end
end

local function SortByHealth(a, b)
    return (UnitHealth(a) / UnitHealthMax(a)) < (UnitHealth(b) / UnitHealthMax(b));
end

-- Toggle setting function
local function ToggleSetting(settingName, displayName)
    settings[settingName] = not settings[settingName];
    BackpackerDB[settingName] = settings[settingName];
    
    if settings[settingName] then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. displayName .. " enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. displayName .. " disabled.");
    end
end

-- Function to reset totem state when totems change (unchanged)
local function ResetTotemState()
    for i, totem in ipairs(totemState) do
        totemState[i].locallyVerified = false;
        totemState[i].serverVerified = false;
        totemState[i].localVerifyTime = 0;
    end
    lastAllTotemsActiveTime = 0;
    PrintMessage("Totem state reset for new configuration.");
end

-- Function to set follow target
-- Function to set follow target
local function SetFollowTarget(targetName)
    if targetName then
        if targetName == "target" then
            if UnitExists("target") and UnitIsPlayer("target") then
                local unitName = UnitName("target");
                settings.FOLLOW_TARGET_NAME = unitName;
                BackpackerDB.FOLLOW_TARGET_NAME = unitName;
                DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow target set to " .. unitName .. ".");
            else
                DEFAULT_CHAT_FRAME:AddMessage("Backpacker: No valid player target selected.");
            end
        else
            settings.FOLLOW_TARGET_NAME = targetName;
            BackpackerDB.FOLLOW_TARGET_NAME = targetName;
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow target set to " .. targetName .. ".");
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid follow target.");
    end
end

-- Totem logic with customizable totems (UNCHANGED)
-- Totem logic with customizable totems - MODIFIED FOR CLEANSING TOTEMS
local function DropTotems()
    local currentTime = GetTime();
    
    -- Check if we're in the cooldown period after Totemic Recall
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        local remainingCooldown = TOTEM_RECALL_COOLDOWN - (currentTime - lastTotemRecallTime);
        PrintMessage("Totems on cooldown after recall. Please wait " .. string.format("%.1f", remainingCooldown) .. " seconds.");
        return;
    end

    -- Check if we're in the cast delay period
    if currentTime - lastTotemCastTime < TOTEM_CAST_DELAY then
        local remainingDelay = TOTEM_CAST_DELAY - (currentTime - lastTotemCastTime);
        PrintMessage("Totem cast delay. Please wait " .. string.format("%.1f", remainingDelay) .. " seconds.");
        return;
    end

    -- Update all totems with current customization using the new order: Air > Fire > Earth > Water
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].spell = settings.AIR_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.AIR_TOTEM] and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff;
        elseif totem.element == "fire" then
            totemState[i].spell = settings.FIRE_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.FIRE_TOTEM] and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff;
        elseif totem.element == "earth" then
            totemState[i].spell = settings.EARTH_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff;
        elseif totem.element == "water" then
            -- Handle water totem special modes
            local cleansingTotemSpell = nil;
            if settings.STRATHOLME_MODE then
                cleansingTotemSpell = "Disease Cleansing Totem";
                totemState[i].spell = cleansingTotemSpell;
                totemState[i].buff = nil;
            elseif settings.ZG_MODE then
                cleansingTotemSpell = "Poison Cleansing Totem";
                totemState[i].spell = cleansingTotemSpell;
                totemState[i].buff = nil;
            else
                -- Use customized water totem when not in special modes
                totemState[i].spell = settings.WATER_TOTEM;
                totemState[i].buff = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff;
            end
        end
    end

    -- WATER SHIELD: Only check server buff status, no local verification
    if not buffed("Water Shield", 'player') then
        CastSpellByName("Water Shield");
        PrintMessage("Casting Water Shield.");
        lastTotemCastTime = currentTime;
        return;
    end

    -- SPECIAL CASE: If in ZG/Strath mode and in combat, AND all other totems are active, allow recasting cleansing totem
    local cleansingTotemSpell = nil;
    if settings.STRATHOLME_MODE then
        cleansingTotemSpell = "Disease Cleansing Totem";
    elseif settings.ZG_MODE then
        cleansingTotemSpell = "Poison Cleansing Totem";
    end

    if cleansingTotemSpell and UnitAffectingCombat("player") then
        local otherTotemsActive = true;
        for i, totem in ipairs(totemState) do
            if totem.element ~= "water" and not totem.serverVerified then
                otherTotemsActive = false;
                break;
            end
        end
        
        if otherTotemsActive then
            for i, totem in ipairs(totemState) do
                if totem.element == "water" then
                    totemState[i].locallyVerified = false;
                    totemState[i].serverVerified = false;
                    totemState[i].localVerifyTime = 0;
                    PrintMessage("COMBAT: Preparing " .. cleansingTotemSpell .. " for mass dispel.");
                    break;
                end
            end
        end
    end

    -- PHASE 1: Check for expired/destroyed totems and reset their state
    local hadExpiredTotems = false;
    for i, totem in ipairs(totemState) do
        if totem.locallyVerified and totem.serverVerified then
            if totem.buff then
                if not buffed(totem.buff, 'player') then
                    PrintMessage(totem.buff .. " has expired/destroyed - resetting for recast.");
                    totemState[i].locallyVerified = false;
                    totemState[i].serverVerified = false;
                    totemState[i].localVerifyTime = 0;
                    hadExpiredTotems = true;
                end
            end
        end
    end

    -- RESET RECALL STATE IF WE HAVE EXPIRED TOTEMS
    if hadExpiredTotems and lastAllTotemsActiveTime > 0 then
        PrintMessage("Expired totems detected - resetting recall cooldown.");
        lastAllTotemsActiveTime = 0;
        DEFAULT_CHAT_FRAME:AddMessage("Totems: NEED REPLACEMENT", 1, 1, 0); -- yellow color
    end

    -- PHASE 2: Drop all totems that need to be dropped (in order: Air > Fire > Earth > Water)
    for i, totem in ipairs(totemState) do
        if not totem.locallyVerified then
            CastSpellByName(totem.spell);
            PrintMessage("Casting " .. totem.spell .. ".");
            totemState[i].locallyVerified = true;
            totemState[i].localVerifyTime = currentTime;
            lastTotemCastTime = currentTime;
            return;
        end
    end

    -- Check if all totems are now locally verified (but not necessarily server verified yet)
    local allLocallyVerified = true;
    for i, totem in ipairs(totemState) do
        if not totem.locallyVerified then
            allLocallyVerified = false;
            break;
        end
    end

    if allLocallyVerified and lastAllTotemsActiveTime == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Totems: Pending", 1, 0.5, 0); -- orange color
        PrintMessage("All totems locally verified. Waiting for server confirmation...");
    end

    -- PHASE 3: Verify locally verified totems that aren't yet server verified
    local allServerVerified = true;
    local needsFastDropRestart = false;
    
    for i, totem in ipairs(totemState) do
        if totem.locallyVerified and not totem.serverVerified then
            if totem.buff then
                -- Totems with buffs: verify via server buff status
                if buffed(totem.buff, 'player') then
                    PrintMessage(totem.buff .. " confirmed active by server.");
                    totemState[i].serverVerified = true;
                else
                    local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                    if timeSinceLocalVerify > TOTEM_VERIFICATION_TIME then
                        PrintMessage(totem.buff .. " missing after " .. string.format("%.1f", timeSinceLocalVerify) .. "s - resetting for recast.");
                        totemState[i].locallyVerified = false;
                        totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;
                        allServerVerified = false;
                        needsFastDropRestart = true;
                    else
                        PrintMessage(totem.buff .. " not yet confirmed (waiting " .. string.format("%.1f", TOTEM_VERIFICATION_TIME - timeSinceLocalVerify) .. "s)");
                        allServerVerified = false;
                    end
                end
            else
                -- Totems without buffs (Tremor, Poison Cleansing, Disease Cleansing): 
                -- Reset VERY frequently to force continuous recasting
                local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                
                -- Define reset intervals based on totem type
                local resetInterval = 1.0; -- Default for unknown buff-less totems
                
                -- Special handling for cleansing totems - reset very frequently
                if totem.spell == "Tremor Totem" or 
                   totem.spell == "Poison Cleansing Totem" or 
                   totem.spell == "Disease Cleansing Totem" then
                    resetInterval = 0.5; -- Reset every 0.5 seconds for cleansing totems
                    PrintMessage(totem.spell .. " - rapid reset enabled (0.5s interval)");
                end
                
                if timeSinceLocalVerify > resetInterval then
                    PrintMessage(totem.spell .. " assumed expired after " .. string.format("%.1f", timeSinceLocalVerify) .. "s - resetting for recast.");
                    totemState[i].locallyVerified = false;
                    totemState[i].serverVerified = false;
                    totemState[i].localVerifyTime = 0;
                    allServerVerified = false;
                    needsFastDropRestart = true;
                else
                    PrintMessage(totem.spell .. " waiting for assumed activation (" .. string.format("%.1f", resetInterval - timeSinceLocalVerify) .. "s)");
                    allServerVerified = false;
                end
            end
        end
        
        if not totem.serverVerified then
            allServerVerified = false;
        end
    end

    -- PHASE 4: All totems server verified - handle Totemic Recall
    if allServerVerified then
        PrintMessage("All totems and buffs are active.");
        
        if lastAllTotemsActiveTime == 0 then
            lastAllTotemsActiveTime = currentTime;
            DEFAULT_CHAT_FRAME:AddMessage("Totems: ACTIVE", 1, 0, 0);
            PrintMessage("Totems now active. Totemic Recall available in " .. TOTEM_RECALL_ACTIVATION_COOLDOWN .. " seconds.");
            return;
        end
        
        if currentTime - lastAllTotemsActiveTime < TOTEM_RECALL_ACTIVATION_COOLDOWN then
            local remainingActivationCooldown = TOTEM_RECALL_ACTIVATION_COOLDOWN - (currentTime - lastAllTotemsActiveTime);
            PrintMessage("Totemic Recall activation cooldown. Please wait " .. string.format("%.1f", remainingActivationCooldown) .. " seconds.");
            return;
        end
        
        if not UnitAffectingCombat("player") then
            CastSpellByName("Totemic Recall");
            lastTotemRecallTime = GetTime();
            lastAllTotemsActiveTime = 0;
            lastTotemCastTime = currentTime;
            DEFAULT_CHAT_FRAME:AddMessage("Totems: RECALLED", 0, 1, 0);
            ResetTotemState();
            PrintMessage("Casting Totemic Recall. Totems will be available in " .. TOTEM_RECALL_COOLDOWN .. " seconds.");
        else
            PrintMessage("Cannot cast Totemic Recall while in combat.");
        end
    else
        lastAllTotemsActiveTime = 0;
    end
end

-- Add this function with the other toggle functions
local function ToggleFishingMode()
    ToggleSetting("FISHING_MODE", "Ancestral Fishing mode");
end

-- Manual Totemic Recall function
local function ManualTotemicRecall()
    local currentTime = GetTime();
    
    -- DO NOT Check if we're in combat. manual recall needs to work while we are IN COMBAT!! the player has decided to invoke it for a reason!!
    --if UnitAffectingCombat("player") then
      --  DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Cannot cast Totemic Recall while in combat.", 1, 0, 0);
        --return;
    --end
    
    -- Check if we're in the cooldown period after previous recall
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        local remainingCooldown = TOTEM_RECALL_COOLDOWN - (currentTime - lastTotemRecallTime);
        -- DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Totemic Recall on cooldown. Please wait " .. string.format("%.1f", remainingCooldown) .. " seconds.", 1, 1, 0);
        return;
    end
    
    -- Cast Totemic Recall
    CastSpellByName("Totemic Recall");
    --lastTotemRecallTime = currentTime;
    lastAllTotemsActiveTime = 0;
    lastTotemCastTime = currentTime;
    DEFAULT_CHAT_FRAME:AddMessage("Totems: RECALLED", 0, 1, 0);
    ResetTotemState();
    -- DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Totemic Recall cast. Totems will be available in " .. TOTEM_RECALL_COOLDOWN .. " seconds.", 0, 1, 0);
end

-- QUICKHEAL INTEGRATION FUNCTIONS
local function ExecuteQuickHeal()
    -- Execute QuickHeal's main healing function
    if QuickHeal then
        QuickHeal();
    else
        -- Fallback: Use RunMacroText if QuickHeal function isn't directly accessible
        RunMacroText("/qh");
    end
end

local function ExecuteQuickChainHeal()
    -- Execute QuickHeal's chain heal function
    if QuickChainHeal then
        QuickChainHeal();
    else
        -- Fallback: Use RunMacroText if QuickChainHeal function isn't directly accessible
        RunMacroText("/qh chainheal");
    end
end

-- NEW SIMPLIFIED HEALING LOGIC USING QUICKHEAL
-- NEW SIMPLIFIED HEALING LOGIC USING QUICKHEAL
local function HealPartyMembers()
    local lowHealthMembers = {};

    local function CheckHealth(unit)
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
            local healthPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100;
            PrintMessage("Checking health of " .. UnitName(unit) .. ": " .. healthPercent .. "%");
            if healthPercent < settings.HEALTH_THRESHOLD then
                table.insert(lowHealthMembers, unit);
                PrintMessage(UnitName(unit) .. " added to low-health list.");
            end
        end
    end

    -- Check player health
    CheckHealth("player");

    -- Check if in a raid
    local numRaidMembers = GetNumRaidMembers();
    if numRaidMembers > 0 then
        -- Player is in a raid, check all raid members
        for i = 1, numRaidMembers do
            CheckHealth("raid" .. i);
        end
    else
        -- Player is not in a raid, check party members
        for i = 1, GetNumPartyMembers() do
            CheckHealth("party" .. i);
        end
    end

    -- Sort low-health members by health percentage (lowest first)
    table.sort(lowHealthMembers, SortByHealth);

    -- Debug: Print low-health members
    PrintMessage("Low-health members: " .. TableLength(lowHealthMembers));
    for i, unit in ipairs(lowHealthMembers) do
        PrintMessage(i .. ": " .. UnitName(unit) .. " (" .. ((UnitHealth(unit) / UnitHealthMax(unit)) * 100 .. "%)"));
    end

    local numLowHealthMembers = TableLength(lowHealthMembers);

    if numLowHealthMembers >= 2 and settings.CHAIN_HEAL_ENABLED then
        -- Use QuickHeal for chain heal
        PrintMessage("Multiple low-health members detected - using QuickHeal chain heal.");
        ExecuteQuickChainHeal();
    elseif numLowHealthMembers >= 1 then
        -- Use QuickHeal for single target heal
        PrintMessage("Single low-health member detected - using QuickHeal single target heal.");
        ExecuteQuickHeal();
    else
        PrintMessage("No party or raid members require healing.");
        
        -- Follow our follow target if follow is enabled
        if settings.FOLLOW_ENABLED then
            if settings.FOLLOW_TARGET_NAME then
                -- Follow by name if specific target is set
                FollowByName(settings.FOLLOW_TARGET_NAME, true);
                PrintMessage("Following " .. settings.FOLLOW_TARGET_NAME .. " by name.");
            elseif GetNumPartyMembers() > 0 then
                -- Fallback to party1 if no specific target is set
                FollowUnit("party1");
                PrintMessage("Following party1 by default.");
            else
                PrintMessage("Follow enabled but no valid follow target available.");
            end
        end
        
        -- ANCESTRAL FISHING MODE: Cast rank 1 Healing Wave on follow target (OUT OF COMBAT ONLY)
        -- Works independently of follow setting - uses follow target OR party1
        if settings.FISHING_MODE and not UnitAffectingCombat("player") then
            -- For fishing, we need to find a valid unit to target
            local fishingTarget = nil;
            
            -- First try to find our follow target in the raid/party
            if settings.FOLLOW_TARGET_NAME then
                local numRaidMembers = GetNumRaidMembers();
                if numRaidMembers > 0 then
                    for i = 1, numRaidMembers do
                        local raidUnit = "raid" .. i;
                        if UnitExists(raidUnit) and UnitName(raidUnit) == settings.FOLLOW_TARGET_NAME then
                            fishingTarget = raidUnit;
                            break;
                        end
                    end
                else
                    for i = 1, GetNumPartyMembers() do
                        local partyUnit = "party" .. i;
                        if UnitExists(partyUnit) and UnitName(partyUnit) == settings.FOLLOW_TARGET_NAME then
                            fishingTarget = partyUnit;
                            break;
                        end
                    end
                end
            end
            
            -- Fallback to party1 if follow target not found or not set
            if not fishingTarget and GetNumPartyMembers() > 0 then
                fishingTarget = "party1";
            end
            
            if fishingTarget and UnitExists(fishingTarget) and not UnitIsDeadOrGhost(fishingTarget) and UnitIsConnected(fishingTarget) then
                -- Target the fishing target and cast rank 1 Healing Wave
                TargetUnit(fishingTarget);
                CastSpellByName("Healing Wave(Rank 1)");
                PrintMessage("Ancestral Fishing: Casting Healing Wave (Rank 1) on " .. UnitName(fishingTarget));
                return; -- Exit after casting to avoid other actions
            else
                PrintMessage("Ancestral Fishing: No valid fishing target available.");
            end
        end
        
        if settings.HYBRID_MODE then
            -- In hybrid mode, assist follow target by casting Lightning Bolt at their target
            local followTarget = nil;
            
            -- Determine which unit to assist
            if settings.FOLLOW_TARGET_NAME then
                -- Try to find the named follow target in raid/party
                local numRaidMembers = GetNumRaidMembers();
                if numRaidMembers > 0 then
                    for i = 1, numRaidMembers do
                        local raidUnit = "raid" .. i;
                        if UnitExists(raidUnit) and UnitName(raidUnit) == settings.FOLLOW_TARGET_NAME then
                            followTarget = raidUnit;
                            break;
                        end
                    end
                else
                    for i = 1, GetNumPartyMembers() do
                        local partyUnit = "party" .. i;
                        if UnitExists(partyUnit) and UnitName(partyUnit) == settings.FOLLOW_TARGET_NAME then
                            followTarget = partyUnit;
                            break;
                        end
                    end
                end
            else
                -- Fallback to party1 if no specific follow target
                followTarget = "party1";
            end
            
            if followTarget and UnitExists(followTarget) and not UnitIsDeadOrGhost(followTarget) and UnitIsConnected(followTarget) then
                local target = UnitName(followTarget .. "target");
                if target then
                    AssistUnit(followTarget);
                    CastSpellByName("Chain Lightning");
                    CastSpellByName("Fire Nova Totem");
                    CastSpellByName("Lightning Bolt");
                    PrintMessage("Casting Lightning Bolt at " .. target .. ".");
                else
                    PrintMessage("No valid target for Lightning Bolt.");
                    FollowUnit(followTarget);
                end
            else
                PrintMessage("No valid follow target for assistance.");
            end
        end
    end
end

-- Totem customization functions - UPDATED FOR NEW ORDER
function SetEarthTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.EARTH_TOTEM = totemName;
        BackpackerDB.EARTH_TOTEM = totemName;
        
        -- Find and reset earth totem by element
        for i, totem in ipairs(totemState) do
            if totem.element == "earth" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                break;
            end
        end
        
        -- Reset the global totem active time to prevent immediate recall
        lastAllTotemsActiveTime = 0;
        
        PrintMessage("Earth totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Earth totem set to " .. displayName .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown earth totem: " .. totemName);
    end
end

function SetFireTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.FIRE_TOTEM = totemName;
        BackpackerDB.FIRE_TOTEM = totemName;
        
        -- Find and reset fire totem by element
        for i, totem in ipairs(totemState) do
            if totem.element == "fire" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                break;
            end
        end
        
        -- Reset the global totem active time to prevent immediate recall
        lastAllTotemsActiveTime = 0;
        
        PrintMessage("Fire totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Fire totem set to " .. displayName .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown fire totem: " .. totemName);
    end
end

function SetAirTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.AIR_TOTEM = totemName;
        BackpackerDB.AIR_TOTEM = totemName;
        
        -- Find and reset air totem by element
        for i, totem in ipairs(totemState) do
            if totem.element == "air" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                break;
            end
        end
        
        -- Reset the global totem active time to prevent immediate recall
        lastAllTotemsActiveTime = 0;
        
        PrintMessage("Air totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Air totem set to " .. displayName .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown air totem: " .. totemName);
    end
end

function SetWaterTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.WATER_TOTEM = totemName;
        BackpackerDB.WATER_TOTEM = totemName;
        
        -- Find and reset water totem by element
        for i, totem in ipairs(totemState) do
            if totem.element == "water" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                break;
            end
        end
        
        -- Reset the global totem active time to prevent immediate recall
        lastAllTotemsActiveTime = 0;
        
        PrintMessage("Water totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Water totem set to " .. displayName .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown water totem: " .. totemName);
    end
end

local function ToggleStratholmeMode()
    if settings.ZG_MODE then
        settings.ZG_MODE = false;
        BackpackerDB.ZG_MODE = false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode disabled.");
    end
    ToggleSetting("STRATHOLME_MODE", "Stratholme mode");
    ResetTotemState(); -- Reset totems when mode changes
end

local function ToggleZulGurubMode()
    if settings.STRATHOLME_MODE then
        settings.STRATHOLME_MODE = false;
        BackpackerDB.STRATHOLME_MODE = false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode disabled.");
    end
    ToggleSetting("ZG_MODE", "Zul'Gurub mode");
    ResetTotemState(); -- Reset totems when mode changes
end

local function ToggleHybridMode()
    ToggleSetting("HYBRID_MODE", "Hybrid mode");
    if settings.HYBRID_MODE then
        settings.HEALTH_THRESHOLD = 80;
        BackpackerDB.HEALTH_THRESHOLD = 80;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Healing threshold set to 80% for hybrid mode.");
    else
        settings.HEALTH_THRESHOLD = 90;
        BackpackerDB.HEALTH_THRESHOLD = 90;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Healing threshold reset to 90%.");
    end
end

local function SetTotemCastDelay(delay)
    delay = tonumber(delay);
    if delay and delay >= 0 then
        TOTEM_CAST_DELAY = delay;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Totem cast delay set to " .. delay .. " seconds.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid delay. Use a number >= 0 (e.g., 0.25 for 250ms).");
    end
end

local function PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Usage (QuickHeal Integration):");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal - Heal party and raid members using QuickHeal.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpbuff - Drop totems.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bprecall - Manually cast Totemic Recall.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdebug - Toggle debug messages.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpf - Toggle follow functionality.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpl - Set your follow target to current target");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpchainheal - Toggle Chain Heal functionality.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpstrath - Toggle Stratholme mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpzg - Toggle Zul'Gurub mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bphybrid - Toggle Hybrid mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdelay <seconds> - Set totem cast delay (default: 0.25)");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfishing - Toggle Ancestral Fishing mode (cast Healing Wave when no healing needed).");
    DEFAULT_CHAT_FRAME:AddMessage("  TOTEM CUSTOMIZATION:");
    DEFAULT_CHAT_FRAME:AddMessage("  EARTH: /bpsoe (Strength), /bpss (Stoneskin)");
    DEFAULT_CHAT_FRAME:AddMessage("  FIRE: /bpft (Flametongue), /bpfrr (Frost Resist)");
    DEFAULT_CHAT_FRAME:AddMessage("  AIR: /bpwf (Windfury), /bpgoa (Grace of Air), /bpnr (Nature Resist)");
    DEFAULT_CHAT_FRAME:AddMessage("  WATER: /bpms (Mana Spring), /bphs (Healing Stream), /bpfr (Fire Resist)");
    DEFAULT_CHAT_FRAME:AddMessage("  /bp or /backpacker - Show usage information.");
    DEFAULT_CHAT_FRAME:AddMessage("  NOTE: Requires QuickHeal addon for healing functionality.");
end

-- Register slash commands
SLASH_BPHEAL1 = "/bpheal"; SlashCmdList["BPHEAL"] = HealPartyMembers;
SLASH_BPBUFF1 = "/bpbuff"; SlashCmdList["BPBUFF"] = DropTotems;
SLASH_BPDEBUG1 = "/bpdebug"; SlashCmdList["BPDEBUG"] = function() ToggleSetting("DEBUG_MODE", "Debug mode"); end;
SLASH_BPF1 = "/bpf";
SlashCmdList["BPF"] = function() ToggleSetting("FOLLOW_ENABLED", "Follow functionality"); end;
SLASH_BPCHAINHEAL1 = "/bpchainheal"; SlashCmdList["BPCHAINHEAL"] = function() ToggleSetting("CHAIN_HEAL_ENABLED", "Chain Heal functionality"); end;
SLASH_BPSTRATH1 = "/bpstrath"; SlashCmdList["BPSTRATH"] = ToggleStratholmeMode;
SLASH_BPZG1 = "/bpzg"; SlashCmdList["BPZG"] = ToggleZulGurubMode;
SLASH_BPHYBRID1 = "/bphybrid"; SlashCmdList["BPHYBRID"] = ToggleHybridMode;
SLASH_BPDELAY1 = "/bpdelay"; SlashCmdList["BPDELAY"] = SetTotemCastDelay;
SLASH_BPRECALL1 = "/bprecall"; SlashCmdList["BPRECALL"] = ManualTotemicRecall;

-- Follow target slash command - ONLY /bpfollowtar
-- Follow target slash command - ONLY /bpfollowtar
SLASH_BPL1 = "/bpl";
SlashCmdList["BPL"] = function()
    if UnitExists("target") and UnitIsPlayer("target") then
        local unitName = UnitName("target");
        settings.FOLLOW_TARGET_NAME = unitName;
        BackpackerDB.FOLLOW_TARGET_NAME = unitName;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow target set to " .. unitName .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: No valid player target selected.");
    end
end;

-- Totem customization commands
SLASH_BPSOE1 = "/bpsoe"; SlashCmdList["BPSOE"] = function() SetEarthTotem("Strength of Earth Totem", "Strength of Earth"); end;
SLASH_BPSS1 = "/bpss"; SlashCmdList["BPSS"] = function() SetEarthTotem("Stoneskin Totem", "Stoneskin"); end;

SLASH_BPFT1 = "/bpft"; SlashCmdList["BPFT"] = function() SetFireTotem("Flametongue Totem", "Flametongue"); end;
SLASH_BPFRR1 = "/bpfrr"; SlashCmdList["BPFRR"] = function() SetFireTotem("Frost Resistance Totem", "Frost Resistance"); end;

SLASH_BPWF1 = "/bpwf"; SlashCmdList["BPWF"] = function() SetAirTotem("Windfury Totem", "Windfury"); end;
SLASH_BPGOA1 = "/bpgoa"; SlashCmdList["BPGOA"] = function() SetAirTotem("Grace of Air Totem", "Grace of Air"); end;
SLASH_BPNR1 = "/bpnr"; SlashCmdList["BPNR"] = function() SetAirTotem("Nature Resistance Totem", "Nature Resistance"); end;

SLASH_BPMS1 = "/bpms"; SlashCmdList["BPMS"] = function() SetWaterTotem("Mana Spring Totem", "Mana Spring"); end;
SLASH_BPHS1 = "/bphs"; SlashCmdList["BPHS"] = function() SetWaterTotem("Healing Stream Totem", "Healing Stream"); end;
SLASH_BPFR1 = "/bpfr"; SlashCmdList["BPFR"] = function() SetWaterTotem("Fire Resistance Totem", "Fire Resistance"); end;

-- Additional totem commands
SLASH_BPTREMOR1 = "/bptremor"; SlashCmdList["BPTREMOR"] = function() SetEarthTotem("Tremor Totem", "Tremor"); end;
SLASH_BPSTONECLAW1 = "/bpstoneclaw"; SlashCmdList["BPSTONECLAW"] = function() SetEarthTotem("Stoneclaw Totem", "Stoneclaw"); end;
SLASH_BPEARTHBIND1 = "/bpearthbind"; SlashCmdList["BPEARTHBIND"] = function() SetEarthTotem("Earthbind Totem", "Earthbind"); end;

SLASH_BPFIRENOVA1 = "/bpfirenova"; SlashCmdList["BPFIRENOVA"] = function() SetFireTotem("Fire Nova Totem", "Fire Nova"); end;
SLASH_BPSEARING1 = "/bpsearing"; SlashCmdList["BPSEARING"] = function() SetFireTotem("Searing Totem", "Searing"); end;
SLASH_BPMAGMA1 = "/bpmagma"; SlashCmdList["BPMAGMA"] = function() SetFireTotem("Magma Totem", "Magma"); end;

SLASH_BPGROUNDING1 = "/bpgrounding"; SlashCmdList["BPGROUNDING"] = function() SetAirTotem("Grounding Totem", "Grounding"); end;
SLASH_BPSENTRY1 = "/bpsentry"; SlashCmdList["BPSENTRY"] = function() SetAirTotem("Sentry Totem", "Sentry"); end;
SLASH_BPWINDWALL1 = "/bpwindwall"; SlashCmdList["BPWINDWALL"] = function() SetAirTotem("Windwall Totem", "Windwall"); end;

SLASH_BPPOISON1 = "/bppoison"; SlashCmdList["BPPOISON"] = function() SetWaterTotem("Poison Cleansing Totem", "Poison Cleansing"); end;
SLASH_BPDISEASE1 = "/bpdisease"; SlashCmdList["BPDISEASE"] = function() SetWaterTotem("Disease Cleansing Totem", "Disease Cleansing"); end;

SLASH_BPFISHING1 = "/bpfishing"; SlashCmdList["BPFISHING"] = ToggleFishingMode;
SLASH_BP1 = "/bp"; SLASH_BP2 = "/backpacker"; SlashCmdList["BP"] = PrintUsage;

-- Initialize
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", OnEvent);

PrintUsage();