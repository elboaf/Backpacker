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
    PET_HEALING_ENABLED = false,  -- Add pet healing mode
    AUTO_SHIELD_MODE = false,    -- RENAMED: Auto-refresh shield mode (was WATER_SHIELD_MODE)
    SHIELD_TYPE = "Water Shield", -- Which shield to use (Water Shield or Lightning Shield)
    FARMING_MODE = false,  -- NEW: Farming mode
    
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
    PET_HEALING_ENABLED = BackpackerDB.PET_HEALING_ENABLED,  -- Add pet healing mode
    AUTO_SHIELD_MODE = BackpackerDB.AUTO_SHIELD_MODE,      -- RENAMED: Auto-refresh shield mode
    SHIELD_TYPE = BackpackerDB.SHIELD_TYPE or "Water Shield", -- Which shield to use
    FARMING_MODE = BackpackerDB.FARMING_MODE or false,  -- NEW: Farming mode
    
    -- Customizable totem settings
    EARTH_TOTEM = BackpackerDB.EARTH_TOTEM,
    FIRE_TOTEM = BackpackerDB.FIRE_TOTEM,
    AIR_TOTEM = BackpackerDB.AIR_TOTEM,
    WATER_TOTEM = BackpackerDB.WATER_TOTEM,
    
    -- Follow target settings
    FOLLOW_TARGET_NAME = BackpackerDB.FOLLOW_TARGET_NAME,
    FOLLOW_TARGET_UNIT = BackpackerDB.FOLLOW_TARGET_UNIT or "party1",
};

-- ===== NEW: Spell ID lookup table =====
local SPELL_ID_LOOKUP = {
    -- Shields
    ["Water Shield"] = 51536,
    ["Lightning Shield"] = 10432,
    ["Earth Shield"] = 45525,
    
    -- Earth Totem buffs
    ["Strength of Earth"] = 10441,
    ["Stoneskin"] = 10405,
    
    -- Fire Totem buffs  
    ["Flametongue Totem"] = 16388,
    ["Frost Resistance"] = 10476,
    ["Fire Resistance"] = 10535, -- From Fire Resistance Totem (fire element)
    
    -- Air Totem buffs
    ["Windfury Totem"] = 51367,
    ["Grace of Air"] = 10626,
    ["Nature Resistance"] = 10599,
    ["Windwall Totem"] = 15108,
    
    -- Water Totem buffs
    ["Mana Spring"] = 10494,
    ["Healing Stream"] = 10461,
    ["Fire Resistance"] = 10535, -- Same as Fire Resistance Totem (shared buff name)
};

-- Also create a reverse lookup for debugging/tooltips
local SPELL_NAME_BY_ID = {};
for name, id in pairs(SPELL_ID_LOOKUP) do
    SPELL_NAME_BY_ID[id] = name;
end;

-- ===== NEW: Function to check if a buff is active using UnitBuff() =====
local function HasBuff(buffName, unit)
    if not buffName or not unit then
        return false;
    end
    
    -- Get the spell ID for this buff name
    local spellId = SPELL_ID_LOOKUP[buffName];
    if not spellId or spellId == 0 then
        -- If we don't have a spell ID for this buff, return false
        -- This handles totems without buffs (like Tremor Totem)
        return false;
    end
    
    -- Scan through buffs using UnitBuff() with superwow.dll
    for i = 1, 32 do
        local texture, index, buffSpellId = UnitBuff(unit, i);
        if not texture then
            break; -- No more buffs
        end
        
        -- Check if this buff's spell ID matches what we're looking for
        if buffSpellId and buffSpellId == spellId then
            return true;
        end
    end
    
    return false;
end;

-- ===== NEW: Function to get buff spell ID (for debugging) =====
local function GetBuffSpellId(buffName)
    return SPELL_ID_LOOKUP[buffName] or 0;
end;

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

local SHIELD_DEFINITIONS = {
    ["Water Shield"] = {
        spell = "Water Shield",
        texture = "watershield",
        baseCharges = 3,
        spellId = 51536 -- UPDATED with spell ID
    },
    ["Lightning Shield"] = {
        spell = "Lightning Shield", 
        texture = "lightningshield",
        baseCharges = 3,
        spellId = 10432 -- UPDATED with spell ID
    },
    ["Earth Shield"] = {  -- NEW: Earth Shield definition
        spell = "Earth Shield",
        texture = "skinofearth",
        baseCharges = 3,  -- Earth Shield has 3 charges by default
        spellId = 45525 -- UPDATED with spell ID
    }
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

-- NEW: Shield charge tracking variables
local lastShieldCheckTime = 0;
local SHIELD_CHECK_INTERVAL = 1.0; -- Check every second

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
            element = "earth",  -- ADD THIS LINE
            spell = settings.EARTH_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff,
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
            element = "water",  -- ADD THIS LINE
            spell = settings.WATER_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0 
        },
    };
end

-- Register the slash command (add this with the other slash command registrations, around line 700-710)
SLASH_BPREPORT1 = "/bpreport";
SLASH_BPREPORT2 = "/bptotems";  -- Alternative command
SlashCmdList["BPREPORT"] = ReportTotemsToParty;

-- Also add the command to the usage information (update PrintUsage function, around line 610)
local function PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Usage (QuickHeal Integration):");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal - Heal party and raid members using QuickHeal.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpbuff - Drop totems.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bprecall - Manually cast Totemic Recall.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpreport - Report current totems to party chat.");  -- NEW LINE
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdebug - Toggle debug messages.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpf - Toggle follow functionality.");
    -- ... rest of the usage message ...
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

-- NEW: Function to check if Stable Shields talent is learned and get rank
function GetStableShieldsRank()
    for tabIndex = 1, GetNumTalentTabs() do
        for talentIndex = 1, GetNumTalents(tabIndex) do
            local name, _, _, _, rank, maxRank = GetTalentInfo(tabIndex, talentIndex)
            if name == "Stable Shields" then
                return rank
            end
        end
    end
    return 0
end

-- NEW: Function to get maximum shield charges
function GetMaxShieldCharges(shieldType)
    local shieldDef = SHIELD_DEFINITIONS[shieldType]
    if not shieldDef then
        return 3 -- Default fallback
    end
    
    local baseCharges = shieldDef.baseCharges
    
    -- Only apply Stable Shields talent to Water Shield and Lightning Shield
    local bonusCharges = 0
    if shieldType == "Water Shield" or shieldType == "Lightning Shield" then
        local talentRank = GetStableShieldsRank()
        bonusCharges = talentRank * 2  -- Each rank of Stable Shields gives +2 charges
    end
    
    return baseCharges + bonusCharges
end

-- NEW: Function to get current shield charges
function GetCurrentShieldCharges(shieldType)
    local shieldDef = SHIELD_DEFINITIONS[shieldType]
    if not shieldDef then
        return 0
    end
    
    local texturePattern = shieldDef.texture
    
    -- Check using GetPlayerBuff method which we know works
    for i = 0, 15 do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex >= 0 then
            local texture = GetPlayerBuffTexture(buffIndex)
            local applications = GetPlayerBuffApplications(buffIndex)
            
            if texture and string.find(string.lower(texture), texturePattern) then
                return applications or 1
            end
        end
    end
    return 0
end

-- Add a helper function to check if any shield is active
local function GetCurrentSharges(shieldType)
    -- Typo in function name but keeping for backward compatibility
    return GetCurrentShieldCharges(shieldType)
end

-- ===== MODIFIED: IsShieldActive function =====
local function IsShieldActive(shieldName)
    -- Use our new HasBuff function instead of buffed()
    return HasBuff(shieldName, "player");
end

-- RENAMED: Function to toggle auto shield refresh mode
local function ToggleAutoShieldMode()
    ToggleSetting("AUTO_SHIELD_MODE", "Shield auto-refresh mode");
    if settings.AUTO_SHIELD_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: /bpbuff will now automatically refresh " .. settings.SHIELD_TYPE .. " when charges are low.");
    end
end

local function SetWaterShield()
    if settings.FARMING_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Cannot change shield type while farming mode is active. Disable farming mode first with /bpfarm");
        return
    end
    
    settings.SHIELD_TYPE = "Water Shield"
    BackpackerDB.SHIELD_TYPE = "Water Shield"
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Shield type set to Water Shield.");
    
    -- Update mode message if auto-refresh mode is enabled
    if settings.AUTO_SHIELD_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh is now set to Water Shield.");
    end
end

local function SetLightningShield()
    if settings.FARMING_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Cannot change shield type while farming mode is active. Disable farming mode first with /bpfarm");
        return
    end
    
    settings.SHIELD_TYPE = "Lightning Shield"
    BackpackerDB.SHIELD_TYPE = "Lightning Shield"
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Shield type set to Lightning Shield.");
    
    -- Update mode message if auto-refresh mode is enabled
    if settings.AUTO_SHIELD_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh is now set to Lightning Shield.");
    end
end

local function SetEarthShield()
    if settings.FARMING_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Cannot change shield type while farming mode is active. Disable farming mode first with /bpfarm");
        return
    end
    
    settings.SHIELD_TYPE = "Earth Shield"
    BackpackerDB.SHIELD_TYPE = "Earth Shield"
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Shield type set to Earth Shield.");
    
    -- Update mode message if auto-refresh mode is enabled
    if settings.AUTO_SHIELD_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh is now set to Earth Shield.");
    end
end

local function GetFarmingModeShield()
    local healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
    local manaPercent = (UnitMana("player") / UnitManaMax("player")) * 100
    
    PrintMessage(string.format("Farming Mode Check - Health: %.1f%%, Mana: %.1f%%", healthPercent, manaPercent))
    
    -- CRITICAL: Check if Earth Shield is already active FIRST
    -- If Earth Shield is active, keep it regardless of current health/mana
    if IsShieldActive("Earth Shield") then
        PrintMessage("Earth Shield is active - KEEPING IT")
        return "Earth Shield"  -- Keep Earth Shield until it expires
    end
    
    -- Only check conditions if Earth Shield is NOT active
    -- Earth Shield only if BOTH conditions are true:
    -- 1. Mana > Health (plenty of mana)
    -- 2. Health < 80% (low health)
    if manaPercent > healthPercent and healthPercent < 70 then
        PrintMessage("Mana > Health AND Health < 80% - Casting Earth Shield")
        return "Earth Shield"
    else
        -- Otherwise use free Water Shield
        PrintMessage("Using Water Shield (default)")
        return "Water Shield"
    end
end

-- RENAMED: Function to check and refresh shield if needed
local function CheckAndRefreshShield()
    if not settings.FARMING_MODE then
        if not settings.AUTO_SHIELD_MODE then
            return false; -- Auto-refresh mode not enabled
        end
    end
    local currentTime = GetTime();
    
    -- Throttle checks to avoid spamming
    if currentTime - lastShieldCheckTime < SHIELD_CHECK_INTERVAL then
        return false;
    end
    
    lastShieldCheckTime = currentTime;
    
    -- Determine which shield to use
    local shieldSpell
    if settings.FARMING_MODE then
        shieldSpell = GetFarmingModeShield()
    else
        shieldSpell = settings.SHIELD_TYPE
    end
    
    -- SIMPLIFIED FIX: Check what shield (if any) is currently active
    local currentShield = nil
    local currentCharges = 0
    
    -- Use IsShieldActive to check which shield is present
    if IsShieldActive("Earth Shield") then
        currentShield = "Earth Shield"
        currentCharges = GetCurrentShieldCharges("Earth Shield")
    elseif IsShieldActive("Water Shield") then
        currentShield = "Water Shield"
        currentCharges = GetCurrentShieldCharges("Water Shield")
    elseif IsShieldActive("Lightning Shield") then
        currentShield = "Lightning Shield"
        currentCharges = GetCurrentShieldCharges("Lightning Shield")
    end
    
    PrintMessage("Current: " .. (currentShield or "none") .. " (" .. currentCharges .. " charges), Desired: " .. shieldSpell)
    
    -- FARMING MODE: Only cast if we need to switch shields (regardless of charges)
    -- NORMAL MODE: Cast if we need to switch OR if charges are low
    if settings.FARMING_MODE then
        -- Farming mode: Only cast if we have the wrong shield (or no shield)
        if currentShield ~= shieldSpell then
            CastSpellByName(shieldSpell);
            PrintMessage("Farming mode: Switching to " .. shieldSpell);
            lastTotemCastTime = currentTime;
            return true;
        end
    else
        -- Normal auto-refresh mode: Cast if wrong shield OR charges are low
        local maxCharges = GetMaxShieldCharges(shieldSpell);
        
        if currentShield ~= shieldSpell or currentCharges < 1 or currentCharges < maxCharges then
            CastSpellByName(shieldSpell);
            PrintMessage(shieldSpell .. " needs refreshing (" .. currentCharges .. "/" .. maxCharges .. " charges)");
            lastTotemCastTime = currentTime;
            return true;
        end
    end
    
    return false;
end

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

-- Totem logic with customizable totems - MODIFIED FOR AUTO SHIELD MODE AND UPDATED BUFF CHECKS
local function DropTotems()
    local currentTime = GetTime();
    
    -- RENAMED: First check if we need to refresh shield
    if CheckAndRefreshShield() then
        return; -- Exit if we just cast a shield
    end
    
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

    -- Update all totems with current customization
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].spell = settings.AIR_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.AIR_TOTEM] and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff;
        elseif totem.element == "fire" then
            if settings.FARMING_MODE then
                totemState[i].spell = nil;  -- Will be handled below
                totemState[i].buff = nil;
            else
                totemState[i].spell = settings.FIRE_TOTEM;
                totemState[i].buff = TOTEM_DEFINITIONS[settings.FIRE_TOTEM] and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff;
            end
        elseif totem.element == "earth" then
            totemState[i].spell = settings.EARTH_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff;
        elseif totem.element == "water" then
            -- Handle water totem special modes
            if settings.FARMING_MODE then
                totemState[i].spell = nil;  -- Will be handled below
                totemState[i].buff = nil;
            elseif settings.STRATHOLME_MODE then
                totemState[i].spell = "Disease Cleansing Totem";
                totemState[i].buff = nil;
            elseif settings.ZG_MODE then
                totemState[i].spell = "Poison Cleansing Totem";
                totemState[i].buff = nil;
            else
                -- Use customized water totem when not in special modes
                totemState[i].spell = settings.WATER_TOTEM;
                totemState[i].buff = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff;
            end
        end
    end

    -- Skip shield check in farming mode since we handle shields in CheckAndRefreshShield
    if not settings.FARMING_MODE then
        -- ===== MODIFIED: Use HasBuff instead of buffed() =====
        if not HasBuff(settings.SHIELD_TYPE, 'player') then
            CastSpellByName(settings.SHIELD_TYPE);
            PrintMessage("Casting " .. settings.SHIELD_TYPE .. ".");
            lastTotemCastTime = currentTime;
            return;
        end
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
            -- Skip disabled totems in farming mode
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                -- Skip fire and water totem check in farming mode
            elseif totem.element ~= "water" and not totem.serverVerified then
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
        -- Skip disabled totems in farming mode
        if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            -- Mark as verified to skip processing
            totemState[i].locallyVerified = true;
            totemState[i].serverVerified = true;
        elseif totem.locallyVerified and totem.serverVerified then
            if totem.buff then
                -- ===== MODIFIED: Use HasBuff instead of buffed() =====
                if not HasBuff(totem.buff, 'player') then
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
        -- Skip disabled totems in farming mode
        if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            -- Mark as verified to skip casting
            if not totem.locallyVerified then
                totemState[i].locallyVerified = true;
                totemState[i].serverVerified = true;
            end
        elseif not totem.locallyVerified then
            -- Check if we have a valid spell to cast
            if not totem.spell or totem.spell == "" then
                -- Mark as verified to skip
                totemState[i].locallyVerified = true;
                totemState[i].serverVerified = true;
                PrintMessage("Skipping " .. totem.element .. " totem (disabled in farming mode)");
            else
                CastSpellByName(totem.spell);
                PrintMessage("Casting " .. totem.spell .. ".");
                totemState[i].locallyVerified = true;
                totemState[i].localVerifyTime = currentTime;
                lastTotemCastTime = currentTime;
                return;
            end
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
        -- Skip disabled totems in farming mode
        if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            -- Skip verification for disabled totems
        elseif totem.locallyVerified and not totem.serverVerified then
            if totem.buff then
                -- Totems with buffs: verify via server buff status
                -- ===== MODIFIED: Use HasBuff instead of buffed() =====
                if HasBuff(totem.buff, 'player') then
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
                -- Totems without buffs...
                -- (Keep existing logic here - no changes needed)
                local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                local resetInterval = 1.0;
                
                if totem.spell == "Tremor Totem" or 
                   totem.spell == "Poison Cleansing Totem" or 
                   totem.spell == "Disease Cleansing Totem" then
                    resetInterval = 0.5;
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

-- Add pet healing toggle function
local function TogglePetHealing()
    ToggleSetting("PET_HEALING_ENABLED", "Pet healing mode");
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

-- NEW SIMPLIFIED HEALING LOGIC USING QUICKHEAL WITH PET SUPPORT
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

    -- PET HEALING: Check pets if pet healing mode is enabled
    if settings.PET_HEALING_ENABLED then
        -- Check player pet
        if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
            local healthPercent = (UnitHealth("pet") / UnitHealthMax("pet")) * 100;
            PrintMessage("Checking health of player pet: " .. healthPercent .. "%");
            if healthPercent < settings.HEALTH_THRESHOLD then
                table.insert(lowHealthMembers, "pet");
                PrintMessage("Player pet added to low-health list.");
            end
        end

        -- Check party/raid pets
        if numRaidMembers > 0 then
            -- Check raid pets
            for i = 1, numRaidMembers do
                local petUnit = "raidpet" .. i;
                if UnitExists(petUnit) and not UnitIsDeadOrGhost(petUnit) then
                    local healthPercent = (UnitHealth(petUnit) / UnitManaMax(petUnit)) * 100;
                    PrintMessage("Checking health of raid pet " .. i .. ": " .. healthPercent .. "%");
                    if healthPercent < settings.HEALTH_THRESHOLD then
                        table.insert(lowHealthMembers, petUnit);
                        PrintMessage("Raid pet " .. i .. " added to low-health list.");
                    end
                end
            end
        else
            -- Check party pets
            for i = 1, GetNumPartyMembers() do
                local petUnit = "partypet" .. i;
                if UnitExists(petUnit) and not UnitIsDeadOrGhost(petUnit) then
                    local healthPercent = (UnitHealth(petUnit) / UnitHealthMax(petUnit)) * 100;
                    PrintMessage("Checking health of party pet " .. i .. ": " .. healthPercent .. "%");
                    if healthPercent < settings.HEALTH_THRESHOLD then
                        table.insert(lowHealthMembers, petUnit);
                        PrintMessage("Party pet " .. i .. " added to low-health list.");
                    end
                end
            end
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

-- ... (all the code before the ReportTotemsToParty function)

-- NEW FUNCTION: Report totems to party chat
local function ReportTotemsToParty()
    local message = "Current Totems: ";
    
    -- Helper function to safely format totem names
    local function FormatTotemName(totemString)
        if not totemString or type(totemString) ~= "string" then
            return "Unknown";
        end
        
        -- Remove " Totem" suffix if present
        local name = totemString;
        if string.find(name, " Totem$") then
            name = string.sub(name, 1, -7); -- Remove " Totem" (6 characters + null terminator)
        end
        
        return name;
    end
    
    -- Get current totems from settings with fallbacks
    local airTotem = settings.AIR_TOTEM or "Windfury Totem";
    local earthTotem = settings.EARTH_TOTEM or "Strength of Earth Totem";
    local fireTotem = settings.FIRE_TOTEM or "Flametongue Totem";
    local waterTotem = settings.WATER_TOTEM or "Mana Spring Totem";
    
    -- Handle special water totem modes
    if settings.STRATHOLME_MODE then
        waterTotem = "Disease Cleansing Totem";
    elseif settings.ZG_MODE then
        waterTotem = "Poison Cleansing Totem";
    end
    
    -- Format the names safely
    local airName = FormatTotemName(airTotem);
    local earthName = FormatTotemName(earthTotem);
    local fireName = FormatTotemName(fireTotem);
    local waterName = FormatTotemName(waterTotem);
    
    -- Build the totem list
    local totemList = {};
    table.insert(totemList, airName);
    table.insert(totemList, fireName);
    table.insert(totemList, earthName);
    table.insert(totemList, waterName);
    
    -- Format the message
    message = message .. table.concat(totemList, ", ");
    
    -- Send to party chat
    SendChatMessage(message, "PARTY");
    
    -- Also show locally for confirmation
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Reported totems to party: " .. table.concat(totemList, ", "));
    
    if settings.DEBUG_MODE then
        -- Debug info
        PrintMessage("Air: " .. (airTotem or "nil"));
        PrintMessage("Fire: " .. (fireTotem or "nil"));
        PrintMessage("Earth: " .. (earthTotem or "nil"));
        PrintMessage("Water: " .. (waterTotem or "nil"));
    end
end

-- Add function to toggle farming mode
local function ToggleFarmingMode()
    ToggleSetting("FARMING_MODE", "Farming mode");
    if settings.FARMING_MODE then
        -- Enable shield mode if not already enabled
        if settings.AUTO_SHIELD_MODE then
            settings.AUTO_SHIELD_MODE = false
            BackpackerDB.AUTO_SHIELD_MODE = false
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh mode automatically disabled for farming mode.");
        end
    end
end

-- ===== NEW: Debug command to check buffs =====
SLASH_BPCHECKBUFFS1 = "/bpcheckbuffs";
SlashCmdList["BPCHECKBUFFS"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("=== Checking buffs with UnitBuff() ===");
    for i = 1, 32 do
        local texture, index, spellId = UnitBuff("player", i);
        if not texture then
            DEFAULT_CHAT_FRAME:AddMessage("Total buffs found: " .. (i-1));
            break;
        end
        
        local buffName = SPELL_NAME_BY_ID[spellId] or "Unknown";
        DEFAULT_CHAT_FRAME:AddMessage(string.format("#%d: ID=%d, Name=%s, Texture=%s", 
            i, spellId or 0, buffName, texture));
    end
end;

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
    DEFAULT_CHAT_FRAME:AddMessage("  /bppets - Toggle Pet Healing mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpauto - Toggle Shield auto-refresh mode.");  -- CHANGED: Renamed from /bpws
    DEFAULT_CHAT_FRAME:AddMessage("  SHIELD TYPE (mutually exclusive):");
    DEFAULT_CHAT_FRAME:AddMessage("    /bpwatershield - Use Water Shield");
    DEFAULT_CHAT_FRAME:AddMessage("    /bplightningshield - Use Lightning Shield");
    DEFAULT_CHAT_FRAME:AddMessage("    /bpearthshield - Use Earth Shield");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfarm - Toggle Farming mode (auto-switch Water/Earth Shield based on health:mana ratio).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpreport - Report current totems to party chat.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpcheckbuffs - Debug: Show all current buffs with UnitBuff()"); -- NEW LINE
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
SLASH_BPPETS1 = "/bppets"; SlashCmdList["BPPETS"] = TogglePetHealing;
SLASH_BPAUTO1 = "/bpauto"; SlashCmdList["BPAUTO"] = ToggleAutoShieldMode;  -- CHANGED: Renamed from /bpws

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

-- Shield type commands (mutually exclusive)
SLASH_BPWATERSHIELD1 = "/bpwatershield";
SLASH_BPWATERSHIELD2 = "/bpws";  -- Short alias
SlashCmdList["BPWATERSHIELD"] = SetWaterShield;

SLASH_BPLIGHTNINGSHIELD1 = "/bplightningshield";
SLASH_BPLIGHTNINGSHIELD2 = "/bpls";  -- Short alias
SlashCmdList["BPLIGHTNINGSHIELD"] = SetLightningShield;

SLASH_BPEARTHSHIELD1 = "/bpearthshield";
SLASH_BPEARTHSHIELD2 = "/bpes";  -- Short alias
SlashCmdList["BPEARTHSHIELD"] = SetEarthShield;

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

SLASH_BPFARM1 = "/bpfarm"; SlashCmdList["BPFARM"] = ToggleFarmingMode;
SLASH_BP1 = "/bp"; SLASH_BP2 = "/backpacker"; SlashCmdList["BP"] = PrintUsage;
SLASH_BPREPORT1 = "/bpreport";
SlashCmdList["BPREPORT"] = ReportTotemsToParty;

-- Initialize
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", OnEvent);

PrintUsage();