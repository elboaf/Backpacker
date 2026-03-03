-- Backpacker.lua
-- Main script for Backpacker addon with SuperWoW totem detection and range checking

-- SavedVariables table
BackpackerDB = BackpackerDB or {
    DEBUG_MODE = false,
    FOLLOW_ENABLED = false,
    CHAIN_HEAL_ENABLED = false,
    HEALTH_THRESHOLD = 90,
    STRATHOLME_MODE = false,
    ZG_MODE = false,
    HYBRID_MODE = false,
    PET_HEALING_ENABLED = false,
    AUTO_SHIELD_MODE = false,
    SHIELD_TYPE = "Water Shield",
    FARMING_MODE = false,
    
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
    PET_HEALING_ENABLED = BackpackerDB.PET_HEALING_ENABLED,
    AUTO_SHIELD_MODE = BackpackerDB.AUTO_SHIELD_MODE,
    SHIELD_TYPE = BackpackerDB.SHIELD_TYPE or "Water Shield",
    FARMING_MODE = BackpackerDB.FARMING_MODE or false,
    
    -- Customizable totem settings
    EARTH_TOTEM = BackpackerDB.EARTH_TOTEM,
    FIRE_TOTEM = BackpackerDB.FIRE_TOTEM,
    AIR_TOTEM = BackpackerDB.AIR_TOTEM,
    WATER_TOTEM = BackpackerDB.WATER_TOTEM,
    
    -- Follow target settings
    FOLLOW_TARGET_NAME = BackpackerDB.FOLLOW_TARGET_NAME,
    FOLLOW_TARGET_UNIT = BackpackerDB.FOLLOW_TARGET_UNIT or "party1",
};

-- Spell ID lookup table (for buff checking fallback)
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
    ["Fire Resistance"] = 10535,
    
    -- Air Totem buffs
    ["Windfury Totem"] = 51367,
    ["Grace of Air"] = 10626,
    ["Nature Resistance"] = 10599,
    ["Windwall Totem"] = 15108,
    
    -- Water Totem buffs
    ["Mana Spring"] = 10494,
    ["Healing Stream"] = 10461,
    ["Fire Resistance"] = 10535,
};

-- Reverse lookup for debugging
local SPELL_NAME_BY_ID = {};
for name, id in pairs(SPELL_ID_LOOKUP) do
    SPELL_NAME_BY_ID[id] = name;
end

-- SUPERWOW TOTEM DETECTION
local superwowEnabled = SUPERWOW_VERSION and true or false
local totemUnitIds = {}   -- Map element to unitId
local totemPositions = {   -- Track where totems were placed
    air = nil,
    fire = nil,
    earth = nil,
    water = nil
}
local RANGE_CHECK_INTERVAL = 2.0 -- Check every 2 seconds
local lastRangeCheckTime = 0
local TOTEM_RANGE = 30 -- yards

-- Fallback buff checking function (for non-SuperWoW)
local function HasBuff(buffName, unit)
    if not buffName or not unit then
        return false;
    end
    
    local spellId = SPELL_ID_LOOKUP[buffName];
    if not spellId or spellId == 0 then
        return false;
    end
    
    for i = 1, 32 do
        local texture, index, buffSpellId = UnitBuff(unit, i);
        if not texture then
            break;
        end
        if buffSpellId and buffSpellId == spellId then
            return true;
        end
    end
    return false;
end

-- Calculate distance between two sets of coordinates
local function GetDistance(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then return nil end
    return sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Totem definitions
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
    ["Tranquil Air Totem"] = { buff = nil, element = "air" },
    
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
        spellId = 51536
    },
    ["Lightning Shield"] = {
        spell = "Lightning Shield", 
        texture = "lightningshield",
        baseCharges = 3,
        spellId = 10432
    },
    ["Earth Shield"] = {
        spell = "Earth Shield",
        texture = "skinofearth",
        baseCharges = 3,
        spellId = 45525
    }
};

-- Cooldown variables
local lastTotemRecallTime = 0;
local lastAllTotemsActiveTime = 0;
local lastTotemCastTime = 0;
local lastFireNovaCastTime = 0;
local FIRE_NOVA_DURATION = 5;
local pendingTotems = {};
local TOTEM_RECALL_COOLDOWN = 3;
local TOTEM_RECALL_ACTIVATION_COOLDOWN = 3;
local TOTEM_VERIFICATION_TIME = 3;
local TOTEM_CAST_DELAY = 0.35;

-- Shield charge tracking
local lastShieldCheckTime = 0;
local SHIELD_CHECK_INTERVAL = 1.0;

-- Initialize totem state
local function InitializeTotemState()
    return {
        { 
            element = "air",
            spell = settings.AIR_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.AIR_TOTEM] and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0,
            unitId = nil
        },
        { 
            element = "fire",
            spell = settings.FIRE_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.FIRE_TOTEM] and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0,
            unitId = nil
        },
        { 
            element = "earth",
            spell = settings.EARTH_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0,
            unitId = nil
        },
        { 
            element = "water",
            spell = settings.WATER_TOTEM, 
            buff = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff,
            locallyVerified = false, 
            serverVerified = false, 
            localVerifyTime = 0,
            unitId = nil
        },
    };
end

local totemState = InitializeTotemState();

-- SUPERWOW EVENT HANDLER - With position tracking
local swFrame = CreateFrame("Frame")
swFrame:RegisterEvent("UNIT_MODEL_CHANGED")
swFrame:SetScript("OnEvent", function()
    if not superwowEnabled then return end
    
    local unitId = arg1
    if not unitId then return end
    
    local unitName = UnitName(unitId)
    if not unitName then return end
    
    -- Check if this is a totem and belongs to us
    if string.find(unitName, "Totem") and UnitName(unitId .. "owner") == UnitName("player") then
        -- This is our totem!
        if settings.DEBUG_MODE then
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: SuperWoW detected our totem: " .. unitName, 0, 1, 0)
        end
        
        -- Get totem position
        local tx, ty = UnitPosition(unitId)
        
        -- Try to match this totem to an element
        for i, totem in ipairs(totemState) do
            if totem.locallyVerified and not totem.serverVerified then
                -- Check if the totem name contains what we're expecting
                local expectedName = totem.spell
                if expectedName and string.find(unitName, expectedName, 1, true) then
                    totemState[i].serverVerified = true
                    totemState[i].unitId = unitId
                    -- Store the position
                    if tx and ty then
                        totemPositions[totem.element] = { x = tx, y = ty }
                    end
                    if settings.DEBUG_MODE then
                        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Matched " .. totem.element .. " totem via SuperWoW", 0, 1, 0)
                    end
                    break
                end
            end
        end
    end
end)

-- Helper function to get totem index by element
local function GetTotemIndexByElement(element)
    for i, totem in ipairs(totemState) do
        if totem.element == element then
            return i
        end
    end
    return nil
end

-- Check if any totems are out of range
local function CheckTotemRange()
    if not superwowEnabled then return false end
    
    local currentTime = GetTime()
    if currentTime - lastRangeCheckTime < RANGE_CHECK_INTERVAL then
        return false
    end
    lastRangeCheckTime = currentTime
    
    -- Get player position
    local px, py = UnitPosition("player")
    if not px or not py then return false end
    
    local outOfRange = false
    
    -- Check each totem that has a position
    for element, pos in pairs(totemPositions) do
        if pos and pos.x and pos.y then
            local dist = GetDistance(px, py, pos.x, pos.y)
            if dist and dist > TOTEM_RANGE then
                PrintMessage(element .. " totem out of range (" .. math.floor(dist) .. " yards)")
                
                -- Find and reset this totem
                for i, totem in ipairs(totemState) do
                    if totem.element == element then
                        totemState[i].locallyVerified = false
                        totemState[i].serverVerified = false
                        totemState[i].unitId = nil
                        totemPositions[element] = nil
                        outOfRange = true
                        break
                    end
                end
            end
        end
    end
    
    if outOfRange then
        DEFAULT_CHAT_FRAME:AddMessage("Totems: OUT OF RANGE - redropping", 1, 0.5, 0)
    end
    
    return outOfRange
end

-- SHIELD FUNCTIONS
local function GetStableShieldsRank()
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

local function GetMaxShieldCharges(shieldType)
    local shieldDef = SHIELD_DEFINITIONS[shieldType]
    if not shieldDef then
        return 3
    end
    local baseCharges = shieldDef.baseCharges
    local bonusCharges = 0
    if shieldType == "Water Shield" or shieldType == "Lightning Shield" then
        local talentRank = GetStableShieldsRank()
        bonusCharges = talentRank * 2
    end
    return baseCharges + bonusCharges
end

local function GetCurrentShieldCharges(shieldType)
    local shieldDef = SHIELD_DEFINITIONS[shieldType]
    if not shieldDef then
        return 0
    end
    local texturePattern = shieldDef.texture
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

local function IsShieldActive(shieldName)
    return HasBuff(shieldName, "player");
end

local function GetFarmingModeShield()
    local healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
    local manaPercent = (UnitMana("player") / UnitManaMax("player")) * 100
    
    if IsShieldActive("Earth Shield") then
        return "Earth Shield"
    end
    
    if manaPercent > healthPercent and healthPercent < 70 then
        return "Earth Shield"
    else
        return "Water Shield"
    end
end

local function CheckAndRefreshShield()
    if not settings.FARMING_MODE then
        if not settings.AUTO_SHIELD_MODE then
            return false;
        end
    end
    local currentTime = GetTime();
    
    if currentTime - lastShieldCheckTime < SHIELD_CHECK_INTERVAL then
        return false;
    end
    lastShieldCheckTime = currentTime;
    
    local shieldSpell
    if settings.FARMING_MODE then
        shieldSpell = GetFarmingModeShield()
    else
        shieldSpell = settings.SHIELD_TYPE
    end
    
    local currentShield = nil
    local currentCharges = 0
    
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
    
    if settings.FARMING_MODE then
        if currentShield ~= shieldSpell then
            CastSpellByName(shieldSpell);
            PrintShieldMessage("Farming mode: Switching to " .. shieldSpell);
            lastTotemCastTime = currentTime;
            return true;
        end
    else
        local maxCharges = GetMaxShieldCharges(shieldSpell);
        if currentShield ~= shieldSpell or currentCharges < 1 or currentCharges < maxCharges then
            CastSpellByName(shieldSpell);
            PrintShieldMessage(shieldSpell .. " needs refreshing (" .. currentCharges .. "/" .. maxCharges .. " charges)");
            lastTotemCastTime = currentTime;
            return true;
        end
    end
    return false;
end

-- Utility functions
local function PrintMessage(message)
    if settings.DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. message);
    end
end

-- Recall message throttle
local lastRecallMessageTime = 0;
local RECALL_MESSAGE_COOLDOWN = 6;

-- Shield message throttle
local lastShieldMessageTime = 0;
local SHIELD_MESSAGE_COOLDOWN = 1;

local function PrintShieldMessage(msg)
    local now = GetTime();
    if now - lastShieldMessageTime >= SHIELD_MESSAGE_COOLDOWN then
        lastShieldMessageTime = now;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. msg);
    end
end

-- Shield-set message throttle (for SetWaterShield etc.)
local lastShieldSetMessageTime = 0;
local SHIELD_SET_MESSAGE_COOLDOWN = 1;

local function PrintShieldSetMessage(msg)
    local now = GetTime();
    if now - lastShieldSetMessageTime >= SHIELD_SET_MESSAGE_COOLDOWN then
        lastShieldSetMessageTime = now;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. msg);
    end
end

local function PrintRecallMessage()
    local now = GetTime();
    if now - lastRecallMessageTime >= RECALL_MESSAGE_COOLDOWN then
        lastRecallMessageTime = now;
        DEFAULT_CHAT_FRAME:AddMessage("Totems: RECALLED", 0, 1, 0);
    end
end

local function ToggleSetting(settingName, displayName)
    settings[settingName] = not settings[settingName];
    BackpackerDB[settingName] = settings[settingName];
    
    if settings[settingName] then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. displayName .. " enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. displayName .. " disabled.");
    end
end

local function ResetTotemState()
    for i, totem in ipairs(totemState) do
        totemState[i].locallyVerified = false;
        totemState[i].serverVerified = false;
        totemState[i].localVerifyTime = 0;
        totemState[i].unitId = nil;
    end
    totemPositions = { air = nil, fire = nil, earth = nil, water = nil }
    lastAllTotemsActiveTime = 0;
    PrintMessage("Totem state reset.");
end

-- MAIN TOTEM FUNCTION
local function DropTotems()
    local currentTime = GetTime();
    
    -- Check if any totems are out of range
    if superwowEnabled and CheckTotemRange() then
        lastAllTotemsActiveTime = 0
    end
    
    if CheckAndRefreshShield() then
        return;
    end
    
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        local remainingCooldown = TOTEM_RECALL_COOLDOWN - (currentTime - lastTotemRecallTime);
        PrintMessage("Totems on cooldown after recall. Please wait " .. string.format("%.1f", remainingCooldown) .. " seconds.");
        return;
    end

    if currentTime - lastTotemCastTime < TOTEM_CAST_DELAY then
        return;
    end

    -- Update all totems with current customization
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].spell = settings.AIR_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.AIR_TOTEM] and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff;
        elseif totem.element == "fire" then
            if settings.FARMING_MODE then
                totemState[i].spell = nil;
                totemState[i].buff = nil;
            else
                totemState[i].spell = settings.FIRE_TOTEM;
                totemState[i].buff = TOTEM_DEFINITIONS[settings.FIRE_TOTEM] and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff;
            end
        elseif totem.element == "earth" then
            totemState[i].spell = settings.EARTH_TOTEM;
            totemState[i].buff = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff;
        elseif totem.element == "water" then
            if settings.FARMING_MODE then
                totemState[i].spell = nil;
                totemState[i].buff = nil;
            elseif settings.STRATHOLME_MODE then
                totemState[i].spell = "Disease Cleansing Totem";
                totemState[i].buff = nil;
            elseif settings.ZG_MODE then
                totemState[i].spell = "Poison Cleansing Totem";
                totemState[i].buff = nil;
            else
                totemState[i].spell = settings.WATER_TOTEM;
                totemState[i].buff = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff;
            end
        end
    end

    -- Skip shield check in farming mode
    if not settings.FARMING_MODE then
        if not HasBuff(settings.SHIELD_TYPE, 'player') then
            CastSpellByName(settings.SHIELD_TYPE);
            PrintMessage("Casting " .. settings.SHIELD_TYPE .. ".");
            lastTotemCastTime = currentTime;
            return;
        end
    end

    -- SPECIAL CASE: ZG/Strath mode in combat
    local cleansingTotemSpell = nil;
    if settings.STRATHOLME_MODE then
        cleansingTotemSpell = "Disease Cleansing Totem";
    elseif settings.ZG_MODE then
        cleansingTotemSpell = "Poison Cleansing Totem";
    end

    if cleansingTotemSpell and UnitAffectingCombat("player") then
        local otherTotemsActive = true;
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                -- Skip
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
                    totemState[i].unitId = nil;
                    totemPositions.water = nil;
                    PrintMessage("COMBAT: Preparing " .. cleansingTotemSpell .. " for mass dispel.");
                    break;
                end
            end
        end
    end

    -- PHASE 1: Check for expired/destroyed totems
    local hadExpiredTotems = false;
    
    if superwowEnabled then
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                totemState[i].locallyVerified = true;
                totemState[i].serverVerified = true;
            elseif totem.unitId then
                if not UnitExists(totem.unitId) then
                    PrintMessage(totem.element .. " totem expired/destroyed (Unit no longer exists)");
                    totemState[i].serverVerified = false;
                    totemState[i].locallyVerified = false;
                    totemState[i].unitId = nil;
                    totemPositions[totem.element] = nil;
                    hadExpiredTotems = true;
                else
                    if UnitName(totem.unitId .. "owner") ~= UnitName("player") then
                        PrintMessage(totem.element .. " totem no longer belongs to us");
                        totemState[i].serverVerified = false;
                        totemState[i].locallyVerified = false;
                        totemState[i].unitId = nil;
                        totemPositions[totem.element] = nil;
                        hadExpiredTotems = true;
                    end
                end
            elseif totem.locallyVerified and not totem.unitId then
                PrintMessage(totem.element .. " has no unitId - resetting");
                totemState[i].serverVerified = false;
                totemState[i].locallyVerified = false;
                totemPositions[totem.element] = nil;
                hadExpiredTotems = true;
            end
        end
    else
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                totemState[i].locallyVerified = true;
                totemState[i].serverVerified = true;
            elseif totem.locallyVerified and totem.serverVerified then
                if totem.buff then
                    if not HasBuff(totem.buff, 'player') then
                        PrintMessage(totem.buff .. " has expired/destroyed - resetting.");
                        totemState[i].locallyVerified = false;
                        totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;
                        hadExpiredTotems = true;
                    end
                end
            end
        end
    end

    if hadExpiredTotems and lastAllTotemsActiveTime > 0 then
        PrintMessage("Expired totems detected - resetting recall cooldown.");
        lastAllTotemsActiveTime = 0;
    end

    -- PHASE 2: Drop totems that need to be dropped
    for i, totem in ipairs(totemState) do
        local isCleansingTotem = false
        if settings.STRATHOLME_MODE and totem.element == "water" and totem.spell == "Disease Cleansing Totem" then
            isCleansingTotem = true
        elseif settings.ZG_MODE and totem.element == "water" and totem.spell == "Poison Cleansing Totem" then
            isCleansingTotem = true
        end
        
        if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            if not totem.locallyVerified then
                totemState[i].locallyVerified = true;
                totemState[i].serverVerified = true;
            end
        elseif isCleansingTotem then
            CastSpellByName(totem.spell);
            if BP_TotemBar_StartTimer then
                local el = string.upper(string.sub(totem.element,1,1))..string.sub(totem.element,2);
                BP_TotemBar_StartTimer(el, totem.spell);
            end
            PrintMessage("Casting " .. totem.spell .. " (forced recast for cleanse pulse).");
            totemState[i].locallyVerified = true;
            totemState[i].localVerifyTime = currentTime;
            totemState[i].unitId = nil;
            totemPositions.water = nil;
            lastTotemCastTime = currentTime;
            return;
        elseif not totem.locallyVerified then
            if not totem.spell or totem.spell == "" then
                totemState[i].locallyVerified = true;
                totemState[i].serverVerified = true;
                PrintMessage("Skipping " .. totem.element .. " totem (disabled)");
            else
                CastSpellByName(totem.spell);
                if BP_TotemBar_StartTimer then
                    local el = string.upper(string.sub(totem.element,1,1))..string.sub(totem.element,2);
                    BP_TotemBar_StartTimer(el, totem.spell);
                end
                PrintMessage("Casting " .. totem.spell .. ".");
                totemState[i].locallyVerified = true;
                totemState[i].localVerifyTime = currentTime;
                totemState[i].unitId = nil;
                totemPositions[totem.element] = nil;
                lastTotemCastTime = currentTime;
                return;
            end
        end
    end

    -- Check if all totems are locally verified
    local allLocallyVerified = true;
    for i, totem in ipairs(totemState) do
        if not totem.locallyVerified then
            allLocallyVerified = false;
            break;
        end
    end

    if allLocallyVerified and lastAllTotemsActiveTime == 0 then
        PrintMessage("All totems locally verified. Waiting for confirmation...");
    end

    -- PHASE 3: Verify totems
    local allServerVerified = true;
    local needsFastDropRestart = false;
    
    if superwowEnabled then
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                -- Already marked verified
            elseif totem.locallyVerified and not totem.serverVerified then
                if totem.unitId then
                    if UnitExists(totem.unitId) and UnitName(totem.unitId .. "owner") == UnitName("player") then
                        PrintMessage(totem.element .. " totem confirmed via SuperWoW")
                        totemState[i].serverVerified = true
                    else
                        PrintMessage(totem.element .. " unitId invalid - resetting")
                        totemState[i].unitId = nil
                        totemState[i].serverVerified = false
                        totemState[i].locallyVerified = false
                        totemState[i].localVerifyTime = 0
                        totemPositions[totem.element] = nil
                        allServerVerified = false
                        needsFastDropRestart = true
                    end
                else
                    local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                    if timeSinceLocalVerify > TOTEM_VERIFICATION_TIME then
                        PrintMessage(totem.element .. " totem missing after " .. string.format("%.1f", timeSinceLocalVerify) .. "s - resetting.");
                        totemState[i].locallyVerified = false;
                        totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;
                        totemState[i].unitId = nil;
                        totemPositions[totem.element] = nil;
                        allServerVerified = false;
                        needsFastDropRestart = true;
                    else
                        PrintMessage(totem.element .. " totem waiting for SuperWoW (" .. string.format("%.1f", TOTEM_VERIFICATION_TIME - timeSinceLocalVerify) .. "s)");
                        allServerVerified = false;
                    end
                end
            end
            
            if not totem.serverVerified then
                allServerVerified = false;
            end
        end
    else
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                -- Skip
            elseif totem.locallyVerified and not totem.serverVerified then
                if totem.buff then
                    if HasBuff(totem.buff, 'player') then
                        PrintMessage(totem.buff .. " confirmed active.");
                        totemState[i].serverVerified = true;
                    else
                        local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                        if timeSinceLocalVerify > TOTEM_VERIFICATION_TIME then
                            PrintMessage(totem.buff .. " missing after " .. string.format("%.1f", timeSinceLocalVerify) .. "s - resetting.");
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
                    local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                    local resetInterval = 1.0;
                    
                    if totem.spell == "Tremor Totem" or 
                       totem.spell == "Poison Cleansing Totem" or 
                       totem.spell == "Disease Cleansing Totem" then
                        resetInterval = 0.5;
                    end
                    
                    if timeSinceLocalVerify > resetInterval then
                        PrintMessage(totem.spell .. " assumed expired after " .. string.format("%.1f", timeSinceLocalVerify) .. "s - resetting.");
                        totemState[i].locallyVerified = false;
                        totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;
                        allServerVerified = false;
                        needsFastDropRestart = true;
                    else
                        PrintMessage(totem.spell .. " waiting (" .. string.format("%.1f", resetInterval - timeSinceLocalVerify) .. "s)");
                        allServerVerified = false;
                    end
                end
            end
            
            if not totem.serverVerified then
                allServerVerified = false;
            end
        end
    end

    -- PHASE 4: All totems verified - handle Totemic Recall
    if allServerVerified then
        PrintMessage("All totems are active.");
        
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
            if BP_TotemBar_StopAllTimers then BP_TotemBar_StopAllTimers(); end;
            lastTotemRecallTime = GetTime();
            lastAllTotemsActiveTime = 0;
            lastTotemCastTime = currentTime;
            PrintRecallMessage();
            ResetTotemState()
            PrintMessage("Casting Totemic Recall. Totems will be available in " .. TOTEM_RECALL_COOLDOWN .. " seconds.");
        else
            PrintMessage("Cannot cast Totemic Recall while in combat.");
        end
    else
        lastAllTotemsActiveTime = 0;
    end
end

-- HEALING FUNCTIONS
local function ExecuteQuickHeal()
    if QuickHeal then
        QuickHeal();
    else
        RunMacroText("/qh");
    end
end

local function ExecuteQuickChainHeal()
    if QuickChainHeal then
        QuickChainHeal();
    else
        RunMacroText("/qh chainheal");
    end
end

local function SortByHealth(a, b)
    return (UnitHealth(a) / UnitHealthMax(a)) < (UnitHealth(b) / UnitHealthMax(b));
end

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

    CheckHealth("player");

    local numRaidMembers = GetNumRaidMembers();
    if numRaidMembers > 0 then
        for i = 1, numRaidMembers do
            CheckHealth("raid" .. i);
        end
    else
        for i = 1, GetNumPartyMembers() do
            CheckHealth("party" .. i);
        end
    end

    if settings.PET_HEALING_ENABLED then
        if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
            local healthPercent = (UnitHealth("pet") / UnitHealthMax("pet")) * 100;
            PrintMessage("Checking health of player pet: " .. healthPercent .. "%");
            if healthPercent < settings.HEALTH_THRESHOLD then
                table.insert(lowHealthMembers, "pet");
                PrintMessage("Player pet added to low-health list.");
            end
        end

        if numRaidMembers > 0 then
            for i = 1, numRaidMembers do
                local petUnit = "raidpet" .. i;
                if UnitExists(petUnit) and not UnitIsDeadOrGhost(petUnit) then
                    local healthPercent = (UnitHealth(petUnit) / UnitHealthMax(petUnit)) * 100;
                    PrintMessage("Checking health of raid pet " .. i .. ": " .. healthPercent .. "%");
                    if healthPercent < settings.HEALTH_THRESHOLD then
                        table.insert(lowHealthMembers, petUnit);
                        PrintMessage("Raid pet " .. i .. " added to low-health list.");
                    end
                end
            end
        else
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

    table.sort(lowHealthMembers, SortByHealth);

    local numLowHealthMembers = 0;
    for _ in pairs(lowHealthMembers) do numLowHealthMembers = numLowHealthMembers + 1 end

    if numLowHealthMembers >= 2 and settings.CHAIN_HEAL_ENABLED then
        PrintMessage("Multiple low-health members detected - using QuickHeal chain heal.");
        ExecuteQuickChainHeal();
    elseif numLowHealthMembers >= 1 then
        PrintMessage("Single low-health member detected - using QuickHeal single target heal.");
        ExecuteQuickHeal();
    else
        PrintMessage("No party or raid members require healing.");
        
        if settings.FOLLOW_ENABLED then
            if settings.FOLLOW_TARGET_NAME then
                FollowByName(settings.FOLLOW_TARGET_NAME, true);
                PrintMessage("Following " .. settings.FOLLOW_TARGET_NAME .. " by name.");
            elseif GetNumPartyMembers() > 0 then
                FollowUnit("party1");
                PrintMessage("Following party1 by default.");
            else
                PrintMessage("Follow enabled but no valid follow target available.");
            end
        end
        
        if settings.HYBRID_MODE then
            local followTarget = nil;
            
            if settings.FOLLOW_TARGET_NAME then
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
                followTarget = "party1";
            end
            
            if followTarget and UnitExists(followTarget) and not UnitIsDeadOrGhost(followTarget) and UnitIsConnected(followTarget) then
                local target = UnitName(followTarget .. "target");
                if target then
                    AssistUnit(followTarget);
                    CastSpellByName("Chain Lightning");
                    CastSpellByName("Fire Nova Totem");
                    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", "Fire Nova Totem"); end;
                    lastFireNovaCastTime = GetTime();
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

-- TOTEM CUSTOMIZATION FUNCTIONS
local function SetEarthTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.EARTH_TOTEM = totemName;
        BackpackerDB.EARTH_TOTEM = totemName;
        
        for i, totem in ipairs(totemState) do
            if totem.element == "earth" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                totemState[i].unitId = nil;
                totemPositions.earth = nil;
                break;
            end
        end
        
        lastAllTotemsActiveTime = 0;
        PrintMessage("Earth totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Earth totem set to " .. displayName .. ".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons(); end;
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown earth totem: " .. totemName);
    end
end

local function SetFireTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.FIRE_TOTEM = totemName;
        BackpackerDB.FIRE_TOTEM = totemName;
        
        for i, totem in ipairs(totemState) do
            if totem.element == "fire" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                totemState[i].unitId = nil;
                totemPositions.fire = nil;
                break;
            end
        end
        
        lastAllTotemsActiveTime = 0;
        PrintMessage("Fire totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Fire totem set to " .. displayName .. ".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons(); end;
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown fire totem: " .. totemName);
    end
end

local function SetAirTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.AIR_TOTEM = totemName;
        BackpackerDB.AIR_TOTEM = totemName;
        
        for i, totem in ipairs(totemState) do
            if totem.element == "air" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                totemState[i].unitId = nil;
                totemPositions.air = nil;
                break;
            end
        end
        
        lastAllTotemsActiveTime = 0;
        PrintMessage("Air totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Air totem set to " .. displayName .. ".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons(); end;
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown air totem: " .. totemName);
    end
end

local function SetWaterTotem(totemName, displayName)
    if TOTEM_DEFINITIONS[totemName] then
        settings.WATER_TOTEM = totemName;
        BackpackerDB.WATER_TOTEM = totemName;
        
        for i, totem in ipairs(totemState) do
            if totem.element == "water" then
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
                totemState[i].unitId = nil;
                totemPositions.water = nil;
                break;
            end
        end
        
        lastAllTotemsActiveTime = 0;
        PrintMessage("Water totem changed to " .. totemName .. " - resetting verification state.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Water totem set to " .. displayName .. ".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons(); end;
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown water totem: " .. totemName);
    end
end

-- MODE TOGGLES
local function ResetWaterTotemState()
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = false;
            totemState[i].serverVerified = false;
            totemState[i].localVerifyTime = 0;
            totemState[i].unitId = nil;
            totemPositions.water = nil;
            break;
        end
    end
    lastAllTotemsActiveTime = 0;
    PrintMessage("Water totem state reset.");
end

local function ToggleStratholmeMode()
    if settings.ZG_MODE then
        settings.ZG_MODE = false;
        BackpackerDB.ZG_MODE = false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode disabled.");
    end
    ToggleSetting("STRATHOLME_MODE", "Stratholme mode");
    ResetWaterTotemState();
    if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode(); end;
end

local function ToggleZulGurubMode()
    if settings.STRATHOLME_MODE then
        settings.STRATHOLME_MODE = false;
        BackpackerDB.STRATHOLME_MODE = false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode disabled.");
    end
    ToggleSetting("ZG_MODE", "Zul'Gurub mode");
    ResetWaterTotemState();
    if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode(); end;
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

local function ManualTotemicRecall()
    local currentTime = GetTime();
    
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        return;
    end
    
    CastSpellByName("Totemic Recall");
    if BP_TotemBar_StopAllTimers then BP_TotemBar_StopAllTimers(); end;
    lastAllTotemsActiveTime = 0;
    lastTotemCastTime = currentTime;
    PrintRecallMessage();
    ResetTotemState();
end

local function TogglePetHealing()
    ToggleSetting("PET_HEALING_ENABLED", "Pet healing mode");
end

local function ToggleAutoShieldMode()
    ToggleSetting("AUTO_SHIELD_MODE", "Shield auto-refresh mode");
    if settings.AUTO_SHIELD_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: /bpbuff will now automatically refresh " .. settings.SHIELD_TYPE .. " when charges are low.");
    end
end

local function SetWaterShield()
    if settings.FARMING_MODE then
        PrintShieldSetMessage("Cannot change shield type while farming mode is active. Disable farming mode first with /bpfarm");
        return
    end
    settings.SHIELD_TYPE = "Water Shield"
    BackpackerDB.SHIELD_TYPE = "Water Shield"
    PrintShieldSetMessage("Shield type set to Water Shield.");
end

local function SetLightningShield()
    if settings.FARMING_MODE then
        PrintShieldSetMessage("Cannot change shield type while farming mode is active. Disable farming mode first with /bpfarm");
        return
    end
    settings.SHIELD_TYPE = "Lightning Shield"
    BackpackerDB.SHIELD_TYPE = "Lightning Shield"
    PrintShieldSetMessage("Shield type set to Lightning Shield.");
end

local function SetEarthShield()
    if settings.FARMING_MODE then
        PrintShieldSetMessage("Cannot change shield type while farming mode is active. Disable farming mode first with /bpfarm");
        return
    end
    settings.SHIELD_TYPE = "Earth Shield"
    BackpackerDB.SHIELD_TYPE = "Earth Shield"
    PrintShieldSetMessage("Shield type set to Earth Shield.");
end

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

local function ReportTotemsToParty()
    local message = "Current Totems: ";
    
    local function FormatTotemName(totemString)
        if not totemString or type(totemString) ~= "string" then
            return "Unknown";
        end
        local name = totemString;
        if string.find(name, " Totem$") then
            name = string.sub(name, 1, -7);
        end
        return name;
    end
    
    local airTotem = settings.AIR_TOTEM or "Windfury Totem";
    local earthTotem = settings.EARTH_TOTEM or "Strength of Earth Totem";
    local fireTotem = settings.FIRE_TOTEM or "Flametongue Totem";
    local waterTotem = settings.WATER_TOTEM or "Mana Spring Totem";
    
    if settings.STRATHOLME_MODE then
        waterTotem = "Disease Cleansing Totem";
    elseif settings.ZG_MODE then
        waterTotem = "Poison Cleansing Totem";
    end
    
    local airName = FormatTotemName(airTotem);
    local earthName = FormatTotemName(earthTotem);
    local fireName = FormatTotemName(fireTotem);
    local waterName = FormatTotemName(waterTotem);
    
    local totemList = {};
    table.insert(totemList, airName);
    table.insert(totemList, fireName);
    table.insert(totemList, earthName);
    table.insert(totemList, waterName);
    
    message = message .. table.concat(totemList, ", ");
    
    SendChatMessage(message, "PARTY");
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Reported totems to party: " .. table.concat(totemList, ", "));
end

local function ToggleFarmingMode()
    ToggleSetting("FARMING_MODE", "Farming mode");
    if settings.FARMING_MODE then
        if settings.AUTO_SHIELD_MODE then
            settings.AUTO_SHIELD_MODE = false
            BackpackerDB.AUTO_SHIELD_MODE = false
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh mode automatically disabled for farming mode.");
        end
    end
    ResetTotemState();
end

-- DEBUG COMMANDS
SLASH_BPCHECKSUPERWOW1 = "/bpchecksw";
SlashCmdList["BPCHECKSUPERWOW"] = function()
    if superwowEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("=== SuperWoW Detected ===");
        DEFAULT_CHAT_FRAME:AddMessage("Version: " .. tostring(SUPERWOW_VERSION));
        DEFAULT_CHAT_FRAME:AddMessage("Totem Tracking:");
        
        for i, totem in ipairs(totemState) do
            local status = "Unknown"
            if totem.unitId then
                if UnitExists(totem.unitId) then
                    status = "Active"
                else
                    status = "Expired"
                end
            elseif totem.serverVerified then
                status = "Verified (no unitId)"
            elseif totem.locallyVerified then
                status = "Pending"
            else
                status = "Inactive"
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s (Unit: %s)", 
                totem.element, status, totem.unitId or "none"))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("=== SuperWoW NOT Detected ===");
        DEFAULT_CHAT_FRAME:AddMessage("Using fallback buff detection");
    end
end;

SLASH_BPTOTEMPOS1 = "/bptotempos";
SlashCmdList["BPTOTEMPOS"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("=== Totem Positions ===");
    local px, py = UnitPosition("player")
    if px and py then
        DEFAULT_CHAT_FRAME:AddMessage("Player: " .. math.floor(px) .. "," .. math.floor(py))
    end
    
    for element, pos in pairs(totemPositions) do
        if pos and pos.x and pos.y then
            local dist = GetDistance(px, py, pos.x, pos.y)
            local status = "In range"
            if dist and dist > TOTEM_RANGE then
                status = "OUT OF RANGE"
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %d,%d (%.1f yds) - %s", 
                element, math.floor(pos.x), math.floor(pos.y), dist or 0, status))
        else
            DEFAULT_CHAT_FRAME:AddMessage(element .. ": No position data")
        end
    end
end;

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
        DEFAULT_CHAT_FRAME:AddMessage(string.format("#%d: ID=%d, Name=%s, Texture=%s", i, spellId or 0, buffName, texture));
    end
end;

-- MANUAL TOTEM CAST COMMANDS

-- EARTH TOTEMS
SLASH_BPSOECAST1 = "/bpsoe-cast";
SlashCmdList["BPSOECAST"] = function()
    CastSpellByName("Strength of Earth Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Earth", "Strength of Earth Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "earth" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.earth = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Strength of Earth Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPSSCAST1 = "/bpss-cast";
SlashCmdList["BPSSCAST"] = function()
    CastSpellByName("Stoneskin Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Earth", "Stoneskin Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "earth" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.earth = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Stoneskin Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPTREMORCAST1 = "/bptremor-cast";
SlashCmdList["BPTREMORCAST"] = function()
    CastSpellByName("Tremor Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Earth", "Tremor Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "earth" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.earth = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Tremor Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPSTONECLAWCAST1 = "/bpstoneclaw-cast";
SlashCmdList["BPSTONECLAWCAST"] = function()
    CastSpellByName("Stoneclaw Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Earth", "Stoneclaw Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "earth" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.earth = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Stoneclaw Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPEARTHBINDCAST1 = "/bpearthbind-cast";
SlashCmdList["BPEARTHBINDCAST"] = function()
    CastSpellByName("Earthbind Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Earth", "Earthbind Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "earth" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.earth = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Earthbind Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

-- FIRE TOTEMS
SLASH_BPFTCAST1 = "/bpft-cast";
SlashCmdList["BPFTCAST"] = function()
    CastSpellByName("Flametongue Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", "Flametongue Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.fire = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Flametongue Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPFRRCAST1 = "/bpfrr-cast";
SlashCmdList["BPFRRCAST"] = function()
    CastSpellByName("Frost Resistance Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", "Frost Resistance Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.fire = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Frost Resistance Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPFIRENOVACAST1 = "/bpfirenova-cast";
SlashCmdList["BPFIRENOVACAST"] = function()
    CastSpellByName("Fire Nova Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", "Fire Nova Totem"); end;
    lastFireNovaCastTime = GetTime();
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.fire = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Fire Nova Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPSEARINGCAST1 = "/bpsearing-cast";
SlashCmdList["BPSEARINGCAST"] = function()
    CastSpellByName("Searing Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", "Searing Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.fire = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Searing Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPMAGMACAST1 = "/bpmagma-cast";
SlashCmdList["BPMAGMACAST"] = function()
    CastSpellByName("Magma Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", "Magma Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.fire = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Magma Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

-- AIR TOTEMS
SLASH_BPWFCAST1 = "/bpwf-cast";
SlashCmdList["BPWFCAST"] = function()
    CastSpellByName("Windfury Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Windfury Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Windfury Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPGOACAST1 = "/bpgoa-cast";
SlashCmdList["BPGOACAST"] = function()
    CastSpellByName("Grace of Air Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Grace of Air Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Grace of Air Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPNRCAST1 = "/bpnr-cast";
SlashCmdList["BPNRCAST"] = function()
    CastSpellByName("Nature Resistance Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Nature Resistance Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Nature Resistance Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPGROUNDINGCAST1 = "/bpgrounding-cast";
SlashCmdList["BPGROUNDINGCAST"] = function()
    CastSpellByName("Grounding Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Grounding Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Grounding Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPSENTRYCAST1 = "/bpsentry-cast";
SlashCmdList["BPSENTRYCAST"] = function()
    CastSpellByName("Sentry Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Sentry Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Sentry Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPWINDWALLCAST1 = "/bpwindwall-cast";
SlashCmdList["BPWINDWALLCAST"] = function()
    CastSpellByName("Windwall Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Windwall Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Windwall Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPTRANQUILCAST1 = "/bptranquil-cast";
SlashCmdList["BPTRANQUILCAST"] = function()
    CastSpellByName("Tranquil Air Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air", "Tranquil Air Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.air = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Tranquil Air Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

-- WATER TOTEMS
SLASH_BPMSCAST1 = "/bpms-cast";
SlashCmdList["BPMSCAST"] = function()
    CastSpellByName("Mana Spring Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Water", "Mana Spring Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.water = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Mana Spring Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPHSCAST1 = "/bphs-cast";
SlashCmdList["BPHSCAST"] = function()
    CastSpellByName("Healing Stream Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Water", "Healing Stream Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.water = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Healing Stream Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPFRCAST1 = "/bpfr-cast";
SlashCmdList["BPFRCAST"] = function()
    CastSpellByName("Fire Resistance Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Water", "Fire Resistance Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.water = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Fire Resistance Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPPOISONCAST1 = "/bppoison-cast";
SlashCmdList["BPPOISONCAST"] = function()
    CastSpellByName("Poison Cleansing Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Water", "Poison Cleansing Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.water = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Poison Cleansing Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

SLASH_BPDISEASECAST1 = "/bpdisease-cast";
SlashCmdList["BPDISEASECAST"] = function()
    CastSpellByName("Disease Cleansing Totem")
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Water", "Disease Cleansing Totem"); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = true
            totemState[i].localVerifyTime = GetTime()
            totemState[i].serverVerified = false
            totemState[i].unitId = nil
            totemPositions.water = nil
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual Disease Cleansing Totem cast - awaiting detection", 1, 1, 0)
            break
        end
    end
end

-- Public API table used by Backpacker_TotemMenu
Backpacker = Backpacker or {};
Backpacker.API = {
    GetTotem = function(element)
        local key = string.upper(element) .. "_TOTEM";
        return settings[key];
    end,

    SetTotem = function(element, totemName)
        local el = string.lower(element);
        if     el == "earth" then SetEarthTotem(totemName, totemName);
        elseif el == "fire"  then SetFireTotem(totemName, totemName);
        elseif el == "air"   then SetAirTotem(totemName, totemName);
        elseif el == "water" then SetWaterTotem(totemName, totemName);
        end
    end,
};

-- USAGE INFORMATION
local function PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Usage (QuickHeal Integration):");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal - Heal party and raid members using QuickHeal.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpbuff - Drop totems.")
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfirebuff - Drop fire totem only if not active.");
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
    DEFAULT_CHAT_FRAME:AddMessage("  /bpauto - Toggle Shield auto-refresh mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  SHIELD TYPE (mutually exclusive):");
    DEFAULT_CHAT_FRAME:AddMessage("    /bpwatershield - Use Water Shield");
    DEFAULT_CHAT_FRAME:AddMessage("    /bplightningshield - Use Lightning Shield");
    DEFAULT_CHAT_FRAME:AddMessage("    /bpearthshield - Use Earth Shield");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfarm - Toggle Farming mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpreport - Report current totems to party chat.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bptotempos - Show totem positions and range status");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpcheckbuffs - Debug: Show all current buffs");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpchecksw - Debug: Show SuperWoW status");
    DEFAULT_CHAT_FRAME:AddMessage("  TOTEM CUSTOMIZATION:");
    DEFAULT_CHAT_FRAME:AddMessage("    EARTH: /bpsoe, /bpss, /bptremor, /bpstoneclaw, /bpearthbind");
    DEFAULT_CHAT_FRAME:AddMessage("    FIRE: /bpft, /bpfrr, /bpfirenova, /bpsearing, /bpmagma");
    DEFAULT_CHAT_FRAME:AddMessage("    AIR: /bpwf, /bpgoa, /bpnr, /bpgrounding, /bpsentry, /bpwindwall, /bptranquil");
    DEFAULT_CHAT_FRAME:AddMessage("    WATER: /bpms, /bphs, /bpfr, /bppoison, /bpdisease");
    DEFAULT_CHAT_FRAME:AddMessage("  MANUAL CAST COMMANDS (use when casting outside /bpbuff):");
    DEFAULT_CHAT_FRAME:AddMessage("    EARTH: /bpsoe-cast, /bpss-cast, /bptremor-cast, /bpstoneclaw-cast, /bpearthbind-cast");
    DEFAULT_CHAT_FRAME:AddMessage("    FIRE: /bpft-cast, /bpfrr-cast, /bpfirenova-cast, /bpsearing-cast, /bpmagma-cast");
    DEFAULT_CHAT_FRAME:AddMessage("    AIR: /bpwf-cast, /bpgoa-cast, /bpnr-cast, /bpgrounding-cast, /bpsentry-cast, /bpwindwall-cast, /bptranquil-cast");
    DEFAULT_CHAT_FRAME:AddMessage("    WATER: /bpms-cast, /bphs-cast, /bpfr-cast, /bppoison-cast, /bpdisease-cast");
    DEFAULT_CHAT_FRAME:AddMessage("  /bp or /backpacker - Show usage information.");
    DEFAULT_CHAT_FRAME:AddMessage("  NOTE: Requires QuickHeal addon for healing functionality.");
end

-- REGISTER SLASH COMMANDS
SLASH_BPHEAL1 = "/bpheal"; SlashCmdList["BPHEAL"] = HealPartyMembers;

local function DropFireTotem()
    local currentTime = GetTime();

    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Totems on cooldown after recall.");
        return;
    end

    if currentTime - lastTotemCastTime < TOTEM_CAST_DELAY then
        return;
    end

    if settings.FARMING_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Fire totem suppressed in farming mode.");
        return;
    end

    local fireSpell = settings.FIRE_TOTEM;
    if not fireSpell or fireSpell == "" then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: No fire totem configured.");
        return;
    end

    if currentTime - lastFireNovaCastTime < FIRE_NOVA_DURATION then
        return;
    end

    local fireActive = false;
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            if superwowEnabled then
                if totem.unitId and UnitExists(totem.unitId) then
                    fireActive = true;
                end
            else
                if totem.buff then
                    if HasBuff(totem.buff, "player") then
                        fireActive = true;
                    end
                elseif totem.locallyVerified and totem.serverVerified then
                    fireActive = true;
                end
            end
            break;
        end
    end

    if fireActive then
        return;
    end

    CastSpellByName(fireSpell);
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire", fireSpell); end;
    for i, totem in ipairs(totemState) do
        if totem.element == "fire" then
            totemState[i].spell = fireSpell;
            totemState[i].locallyVerified = true;
            totemState[i].localVerifyTime = currentTime;
            totemState[i].serverVerified = false;
            totemState[i].unitId = nil;
            totemPositions.fire = nil;
            break;
        end
    end
    lastTotemCastTime = currentTime;
end

SLASH_BPBUFF1 = "/bpbuff"; SlashCmdList["BPBUFF"] = DropTotems;
SLASH_BPFIREBUFF1 = "/bpfirebuff"; SlashCmdList["BPFIREBUFF"] = DropFireTotem;
SLASH_BPDEBUG1 = "/bpdebug"; SlashCmdList["BPDEBUG"] = function() ToggleSetting("DEBUG_MODE", "Debug mode"); end;
SLASH_BPF1 = "/bpf"; SlashCmdList["BPF"] = function() ToggleSetting("FOLLOW_ENABLED", "Follow functionality"); end;
SLASH_BPCHAINHEAL1 = "/bpchainheal"; SlashCmdList["BPCHAINHEAL"] = function() ToggleSetting("CHAIN_HEAL_ENABLED", "Chain Heal functionality"); end;
SLASH_BPSTRATH1 = "/bpstrath"; SlashCmdList["BPSTRATH"] = ToggleStratholmeMode;
SLASH_BPZG1 = "/bpzg"; SlashCmdList["BPZG"] = ToggleZulGurubMode;
SLASH_BPHYBRID1 = "/bphybrid"; SlashCmdList["BPHYBRID"] = ToggleHybridMode;
SLASH_BPDELAY1 = "/bpdelay"; SlashCmdList["BPDELAY"] = SetTotemCastDelay;
SLASH_BPRECALL1 = "/bprecall"; SlashCmdList["BPRECALL"] = ManualTotemicRecall;
SLASH_BPPETS1 = "/bppets"; SlashCmdList["BPPETS"] = TogglePetHealing;
SLASH_BPAUTO1 = "/bpauto"; SlashCmdList["BPAUTO"] = ToggleAutoShieldMode;

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

SLASH_BPWATERSHIELD1 = "/bpwatershield";
SLASH_BPWATERSHIELD2 = "/bpws";
SlashCmdList["BPWATERSHIELD"] = SetWaterShield;

SLASH_BPLIGHTNINGSHIELD1 = "/bplightningshield";
SLASH_BPLIGHTNINGSHIELD2 = "/bpls";
SlashCmdList["BPLIGHTNINGSHIELD"] = SetLightningShield;

SLASH_BPEARTHSHIELD1 = "/bpearthshield";
SLASH_BPEARTHSHIELD2 = "/bpes";
SlashCmdList["BPEARTHSHIELD"] = SetEarthShield;

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

SLASH_BPTREMOR1 = "/bptremor"; SlashCmdList["BPTREMOR"] = function() SetEarthTotem("Tremor Totem", "Tremor"); end;
SLASH_BPSTONECLAW1 = "/bpstoneclaw"; SlashCmdList["BPSTONECLAW"] = function() SetEarthTotem("Stoneclaw Totem", "Stoneclaw"); end;
SLASH_BPEARTHBIND1 = "/bpearthbind"; SlashCmdList["BPEARTHBIND"] = function() SetEarthTotem("Earthbind Totem", "Earthbind"); end;

SLASH_BPFIRENOVA1 = "/bpfirenova"; SlashCmdList["BPFIRENOVA"] = function() SetFireTotem("Fire Nova Totem", "Fire Nova"); end;
SLASH_BPSEARING1 = "/bpsearing"; SlashCmdList["BPSEARING"] = function() SetFireTotem("Searing Totem", "Searing"); end;
SLASH_BPMAGMA1 = "/bpmagma"; SlashCmdList["BPMAGMA"] = function() SetFireTotem("Magma Totem", "Magma"); end;

SLASH_BPGROUNDING1 = "/bpgrounding"; SlashCmdList["BPGROUNDING"] = function() SetAirTotem("Grounding Totem", "Grounding"); end;
SLASH_BPSENTRY1 = "/bpsentry"; SlashCmdList["BPSENTRY"] = function() SetAirTotem("Sentry Totem", "Sentry"); end;
SLASH_BPWINDWALL1 = "/bpwindwall"; SlashCmdList["BPWINDWALL"] = function() SetAirTotem("Windwall Totem", "Windwall"); end;
SLASH_BPTRANQUIL1 = "/bptranquil"; SlashCmdList["BPTRANQUIL"] = function() SetAirTotem("Tranquil Air Totem", "Tranquil Air"); end;

SLASH_BPPOISON1 = "/bppoison"; SlashCmdList["BPPOISON"] = function() SetWaterTotem("Poison Cleansing Totem", "Poison Cleansing"); end;
SLASH_BPDISEASE1 = "/bpdisease"; SlashCmdList["BPDISEASE"] = function() SetWaterTotem("Disease Cleansing Totem", "Disease Cleansing"); end;

SLASH_BPFARM1 = "/bpfarm"; SlashCmdList["BPFARM"] = ToggleFarmingMode;
SLASH_BP1 = "/bp"; SLASH_BP2 = "/backpacker"; SlashCmdList["BP"] = PrintUsage;
SLASH_BPREPORT1 = "/bpreport"; SlashCmdList["BPREPORT"] = ReportTotemsToParty;

-- MAIN EVENT HANDLER
local function OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Backpacker" then
        for k, v in pairs(BackpackerDB) do
            settings[k] = v;
        end
        totemState = InitializeTotemState();
        
        if SUPERWOW_VERSION then
            superwowEnabled = true
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: SuperWoW v" .. tostring(SUPERWOW_VERSION) .. " detected - using enhanced totem tracking with range checking");
        else
            superwowEnabled = false
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: SuperWoW not detected - using fallback buff detection");
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Addon loaded. QuickHeal integration enabled.");
    end
end

local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", OnEvent);

PrintUsage();

-- =============================================================
-- TOTEM BAR  (/bpmenu)
-- =============================================================

do
    local TOTEM_ICONS = {
        ["Strength of Earth Totem"] = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
        ["Stoneskin Totem"]         = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
        ["Tremor Totem"]            = "Interface\\Icons\\Spell_Nature_TremorTotem",
        ["Stoneclaw Totem"]         = "Interface\\Icons\\Spell_Nature_StoneclawTotem",
        ["Earthbind Totem"]         = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
        ["Flametongue Totem"]       = "Interface\\Icons\\spell_nature_guardianward",
        ["Frost Resistance Totem"]  = "Interface\\Icons\\Spell_FrostResistanceTotem_01",
        ["Fire Nova Totem"]         = "Interface\\Icons\\Spell_Fire_SealOfFire",
        ["Searing Totem"]           = "Interface\\Icons\\Spell_Fire_SearingTotem",
        ["Magma Totem"]             = "Interface\\Icons\\Spell_Fire_SelfDestruct",
        ["Windfury Totem"]          = "Interface\\Icons\\spell_nature_windfury",
        ["Grace of Air Totem"]      = "Interface\\Icons\\spell_nature_invisibilitytotem",
        ["Nature Resistance Totem"] = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",
        ["Grounding Totem"]         = "Interface\\Icons\\Spell_Nature_GroundingTotem",
        ["Sentry Totem"]            = "Interface\\Icons\\Spell_Nature_RemoveCurse",
        ["Windwall Totem"]          = "Interface\\Icons\\spell_nature_earthbind",
        ["Tranquil Air Totem"]      = "Interface\\Icons\\spell_nature_brilliance",
        ["Mana Spring Totem"]       = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
        ["Healing Stream Totem"]    = "Interface\\Icons\\INV_Spear_04",
        ["Fire Resistance Totem"]   = "Interface\\Icons\\Spell_FireResistanceTotem_01",
        ["Poison Cleansing Totem"]  = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
        ["Disease Cleansing Totem"] = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem",
    };

    local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Idol_03";

    local TOTEM_DURATIONS = {
        ["Strength of Earth Totem"] = 120,
        ["Stoneskin Totem"]         = 120,
        ["Tremor Totem"]            = 120,
        ["Stoneclaw Totem"]         =  15,
        ["Earthbind Totem"]         =  45,
        ["Flametongue Totem"]       = 120,
        ["Frost Resistance Totem"]  = 120,
        ["Searing Totem"]           =  55,
        ["Fire Nova Totem"]         =   5,
        ["Magma Totem"]             =  20,
        ["Windfury Totem"]          = 120,
        ["Grace of Air Totem"]      = 120,
        ["Nature Resistance Totem"] = 120,
        ["Grounding Totem"]         =  45,
        ["Sentry Totem"]            = 120,
        ["Windwall Totem"]          = 120,
        ["Tranquil Air Totem"]      = 120,
        ["Mana Spring Totem"]       =  60,
        ["Healing Stream Totem"]    = 120,
        ["Fire Resistance Totem"]   = 120,
        ["Poison Cleansing Totem"]  = 120,
        ["Disease Cleansing Totem"] = 120,
    };

    local timerState = {};

    local ELEMENTS = {
        { key="Water", r=0.30, g=0.65, b=1.00, dbKey="WATER_TOTEM",
          totems={"Mana Spring Totem","Healing Stream Totem","Fire Resistance Totem","Poison Cleansing Totem","Disease Cleansing Totem"} },
        { key="Earth", r=0.80, g=0.60, b=0.20, dbKey="EARTH_TOTEM",
          totems={"Strength of Earth Totem","Stoneskin Totem","Tremor Totem","Stoneclaw Totem","Earthbind Totem"} },
        { key="Air",   r=0.55, g=0.85, b=1.00, dbKey="AIR_TOTEM",
          totems={"Windfury Totem","Grace of Air Totem","Nature Resistance Totem","Windwall Totem","Grounding Totem","Sentry Totem","Tranquil Air Totem"} },
        { key="Fire",  r=1.00, g=0.40, b=0.10, dbKey="FIRE_TOTEM",
          totems={"Flametongue Totem","Frost Resistance Totem","Searing Totem","Fire Nova Totem","Magma Totem"} },
    };

    local function PlayerKnowsSpell(spellName)
        local i = 1;
        while true do
            local n = GetSpellName(i, BOOKTYPE_SPELL);
            if not n then break end;
            if n == spellName then return true end;
            i = i + 1;
        end
        return false;
    end

    local function GetCurrentTotem(dbKey)
        return settings[dbKey];
    end

    local function ApplyTotemSelection(elementKey, totemName)
        local el = string.lower(elementKey);
        if     el == "earth" then SetEarthTotem(totemName, totemName);
        elseif el == "fire"  then SetFireTotem(totemName, totemName);
        elseif el == "air"   then SetAirTotem(totemName, totemName);
        elseif el == "water" then SetWaterTotem(totemName, totemName);
        end
    end

    local tt = CreateFrame("GameTooltip", "BP_MenuTT", UIParent, "GameTooltipTemplate");
    tt:SetOwner(UIParent, "ANCHOR_NONE");

    local function ShowSpellTip(anchor, spellName)
        tt:ClearLines();
        tt:SetOwner(anchor, "ANCHOR_RIGHT");
        local i = 1;
        while true do
            local n = GetSpellName(i, BOOKTYPE_SPELL);
            if not n then break end;
            if n == spellName then
                tt:SetSpell(i, BOOKTYPE_SPELL);
                tt:Show();
                return;
            end
            i = i + 1;
        end
        tt:AddLine(spellName, 1, 1, 1);
        tt:Show();
    end

    local BAR_BTN_SIZE    = 40;
    local BAR_PADDING     = 3;
    local ACTIVE_BTN_SIZE = 28;
    local FLY_BTN_SIZE = 36;
    local FLY_PADDING  = 4;
    local FLY_ROW_H    = FLY_BTN_SIZE + 3;
    local FLY_WIDTH    = FLY_BTN_SIZE + FLY_PADDING * 2;

    local barW = BAR_BTN_SIZE * 4 + BAR_PADDING * 5;
    local barH = BAR_BTN_SIZE + BAR_PADDING * 3 + ACTIVE_BTN_SIZE;

    local bar = CreateFrame("Frame", "BP_TotemBar", UIParent);
    bar:SetWidth(barW);
    bar:SetHeight(barH);
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -300);
    bar:SetMovable(true);
    bar:EnableMouse(true);
    bar:SetFrameStrata("MEDIUM");

    bar:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then bar:StartMoving() end
    end);
    bar:SetScript("OnMouseUp", function()
        bar:StopMovingOrSizing()
    end);

    local barBg = bar:CreateTexture(nil, "BACKGROUND");
    barBg:SetTexture(0, 0, 0, 0);
    barBg:SetAllPoints(bar);

    local flyoutFrames  = {};
    local barButtons    = {};

    local tickFrame = CreateFrame("Frame");
    tickFrame:SetScript("OnUpdate", function()
        local now = GetTime();
        for i = 1, table.getn(ELEMENTS) do
            local el = ELEMENTS[i];
            local bb = barButtons[el.key];
            local ts = timerState[el.key];
            if not bb then return end;

            local function SetTimerDisplay(fs, layers, text, r, g, b)
                fs:SetText(text);
                fs:SetTextColor(r, g, b, 1);
                fs:Show();
                for li = 1, table.getn(layers) do
                    layers[li]:SetText(text);
                    layers[li]:Show();
                end
            end
            local function HideTimerDisplay(fs, layers)
                fs:Hide();
                for li = 1, table.getn(layers) do layers[li]:Hide() end;
            end
            local function TimerColor(remaining, duration)
                if remaining > duration * 0.5 then return 1.0, 1.0, 1.0;
                elseif remaining > 10        then return 1.0, 0.8, 0.0;
                else                              return 1.0, 0.2, 0.2;
                end
            end
            local function FormatTime(remaining)
                if remaining < 10 then return string.format("%.1f", remaining);
                else                   return string.format("%d", remaining);
                end
            end

            local setTotem = GetCurrentTotem(el.dbKey);
            if el.key == "Water" then
                if settings.STRATHOLME_MODE then
                    setTotem = "Disease Cleansing Totem";
                elseif settings.ZG_MODE then
                    setTotem = "Poison Cleansing Totem";
                end
            end
            local activeTotem = ts and ts.totemName;
            local showActive = activeTotem and activeTotem ~= setTotem;

            if ts then
                local remaining = ts.duration - (now - ts.startTime);

                if ts.duration == 0 or remaining <= 0 then
                    timerState[el.key] = nil;
                    HideTimerDisplay(bb.timer, bb.timerLayers);
                    if bb.activeBtn then bb.activeBtn:Hide() end;
                else
                    local text = FormatTime(remaining);
                    local r, g, b = TimerColor(remaining, ts.duration);

                    if showActive then
                        HideTimerDisplay(bb.timer, bb.timerLayers);
                        if bb.activeBtn then
                            bb.activeIcon:SetTexture(
                                TOTEM_ICONS[activeTotem] or FALLBACK_ICON);
                            SetTimerDisplay(bb.activeTimer, bb.activeTimerLayers, text, r, g, b);
                            bb.activeBtn:Show();
                        end
                    else
                        SetTimerDisplay(bb.timer, bb.timerLayers, text, r, g, b);
                        if bb.activeBtn then bb.activeBtn:Hide() end;
                    end
                end
            else
                HideTimerDisplay(bb.timer, bb.timerLayers);
                if bb.activeBtn then bb.activeBtn:Hide() end;
            end
        end
    end);

    local closeScheduled = {};

    local function CloseFlyout(key)
        if flyoutFrames[key] then flyoutFrames[key]:Hide() end;
        closeScheduled[key] = false;
    end

    local function CloseAllFlyouts()
        for i = 1, table.getn(ELEMENTS) do
            CloseFlyout(ELEMENTS[i].key);
        end
    end

    local function ScheduleClose(key)
        closeScheduled[key] = true;
        local elapsed = 0;
        bar:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1;
            if elapsed < 0.12 then return end;
            bar:SetScript("OnUpdate", nil);
            if closeScheduled[key] then CloseFlyout(key) end;
        end);
    end

    local function CancelClose(key)
        closeScheduled[key] = false;
    end

    local function RefreshBarIcon(key, dbKey, iconTex)
        local cur = GetCurrentTotem(dbKey);
        local path = (cur and TOTEM_ICONS[cur]) or FALLBACK_ICON;
        iconTex:SetTexture(path);
    end

    -- BUILD COLUMNS
    for colIdx = 1, table.getn(ELEMENTS) do
        local elDef      = ELEMENTS[colIdx];
        local elementKey = elDef.key;
        local dbKey      = elDef.dbKey;

        -- MAIN BAR BUTTON
        local mainBtn = CreateFrame("Button", nil, bar);
        mainBtn:SetWidth(BAR_BTN_SIZE);
        mainBtn:SetHeight(BAR_BTN_SIZE);
        mainBtn:SetPoint("TOPLEFT", bar, "TOPLEFT",
            BAR_PADDING + (colIdx-1) * (BAR_BTN_SIZE + BAR_PADDING),
            -BAR_PADDING);

        local slotTex = mainBtn:CreateTexture(nil, "BACKGROUND");
        slotTex:SetTexture("Interface\\Buttons\\UI-EmptySlot");
        slotTex:SetAllPoints(mainBtn);

        local barIcon = mainBtn:CreateTexture(nil, "ARTWORK");
        barIcon:SetWidth(BAR_BTN_SIZE - 6);
        barIcon:SetHeight(BAR_BTN_SIZE - 6);
        barIcon:SetPoint("CENTER", mainBtn, "CENTER", 0, 0);

        local hiTex = mainBtn:CreateTexture(nil, "HIGHLIGHT");
        hiTex:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
        hiTex:SetAllPoints(mainBtn);
        hiTex:SetBlendMode("ADD");
        mainBtn:SetHighlightTexture(hiTex);

        local timerText = mainBtn:CreateFontString(nil, "OVERLAY");
        timerText:SetFont("Fonts\\FRIZQT__.TTF", 14, "THICKOUTLINE");
        timerText:SetPoint("CENTER", mainBtn, "CENTER", 0, 0);
        timerText:SetTextColor(1, 1, 1, 1);
        timerText:Hide();
        local timerLayers = {};

        -- ACTIVE TOTEM BUTTON
        local activeBtn = CreateFrame("Button", nil, bar);
        activeBtn:SetWidth(ACTIVE_BTN_SIZE);
        activeBtn:SetHeight(ACTIVE_BTN_SIZE);
        activeBtn:SetPoint("TOP", mainBtn, "BOTTOM", 0, -BAR_PADDING);

        local aSlot = activeBtn:CreateTexture(nil, "BACKGROUND");
        aSlot:SetTexture("Interface\\Buttons\\UI-EmptySlot");
        aSlot:SetAllPoints(activeBtn);

        local aIcon = activeBtn:CreateTexture(nil, "ARTWORK");
        aIcon:SetWidth(ACTIVE_BTN_SIZE - 4);
        aIcon:SetHeight(ACTIVE_BTN_SIZE - 4);
        aIcon:SetPoint("CENTER", activeBtn, "CENTER", 0, 0);

        local aHi = activeBtn:CreateTexture(nil, "HIGHLIGHT");
        aHi:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
        aHi:SetAllPoints(activeBtn);
        aHi:SetBlendMode("ADD");
        activeBtn:SetHighlightTexture(aHi);

        local aTimer = activeBtn:CreateFontString(nil, "OVERLAY");
        aTimer:SetFont("Fonts\\FRIZQT__.TTF", 10, "THICKOUTLINE");
        aTimer:SetPoint("CENTER", activeBtn, "CENTER", 0, 0);
        aTimer:SetTextColor(1, 1, 1, 1);
        aTimer:Hide();
        local aTimerLayers = {};

        activeBtn:SetScript("OnClick", function()
            local ts = timerState[elementKey];
            if ts and ts.totemName then
                CastSpellByName(ts.totemName);
                BP_TotemBar_StartTimer(elementKey, ts.totemName);
            end
        end);
        activeBtn:SetScript("OnEnter", function()
            local ts = timerState[elementKey];
            if ts and ts.totemName then ShowSpellTip(activeBtn, ts.totemName) end;
        end);
        activeBtn:SetScript("OnLeave", function() tt:Hide() end);
        activeBtn:Hide();

        barButtons[elementKey] = {
            btn=mainBtn, icon=barIcon, timer=timerText, timerLayers=timerLayers,
            activeBtn=activeBtn, activeIcon=aIcon,
            activeTimer=aTimer, activeTimerLayers=aTimerLayers
        };

        -- FLYOUT FRAME
        local maxRows = table.getn(elDef.totems);
        local flyH    = FLY_PADDING * 2 + maxRows * FLY_ROW_H;

        local fly = CreateFrame("Frame", nil, UIParent);
        fly:SetWidth(FLY_WIDTH);
        fly:SetHeight(flyH);
        fly:SetFrameStrata("HIGH");
        fly:EnableMouse(true);
        fly:Hide();
        flyoutFrames[elementKey] = fly;

        local flyBg = fly:CreateTexture(nil, "BACKGROUND");
        flyBg:SetTexture(0, 0, 0, 0.82);
        flyBg:SetAllPoints(fly);

        for _, anchor in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local b = fly:CreateTexture(nil, "BORDER");
            b:SetTexture(elDef.r, elDef.g, elDef.b, 0.7);
            if anchor == "TOP" or anchor == "BOTTOM" then
                b:SetHeight(1);
                b:SetPoint(anchor.."LEFT", fly, anchor.."LEFT", 0, 0);
                b:SetPoint(anchor.."RIGHT", fly, anchor.."RIGHT", 0, 0);
            else
                b:SetWidth(1);
                b:SetPoint("TOP"..anchor, fly, "TOP"..anchor, 0, 0);
                b:SetPoint("BOTTOM"..anchor, fly, "BOTTOM"..anchor, 0, 0);
            end
        end

        fly:SetScript("OnLeave", function() ScheduleClose(elementKey) end);
        fly:SetScript("OnEnter", function() CancelClose(elementKey) end);

        -- FLYOUT BUTTONS
        local flyBtns = {};

        for slotIdx = 1, table.getn(elDef.totems) do
            local thisTotem = elDef.totems[slotIdx];
            local thisSlot  = slotIdx;

            local fb = CreateFrame("CheckButton", nil, fly);
            fb:SetWidth(FLY_BTN_SIZE);
            fb:SetHeight(FLY_BTN_SIZE);
            fb:SetPoint("TOP", fly, "TOP",
                0, -(FLY_PADDING + (thisSlot-1) * FLY_ROW_H));

            local fbSlot = fb:CreateTexture(nil, "BACKGROUND");
            fbSlot:SetTexture("Interface\\Buttons\\UI-EmptySlot");
            fbSlot:SetAllPoints(fb);

            local fbIcon = fb:CreateTexture(nil, "ARTWORK");
            fbIcon:SetWidth(FLY_BTN_SIZE - 4);
            fbIcon:SetHeight(FLY_BTN_SIZE - 4);
            fbIcon:SetPoint("CENTER", fb, "CENTER", 0, 0);
            fb.icon = fbIcon;
            fb.totemPath = TOTEM_ICONS[thisTotem] or FALLBACK_ICON;

            local fbHi = fb:CreateTexture(nil, "HIGHLIGHT");
            fbHi:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
            fbHi:SetAllPoints(fb);
            fbHi:SetBlendMode("ADD");
            fb:SetHighlightTexture(fbHi);

            local fbCk = fb:CreateTexture(nil, "OVERLAY");
            fbCk:SetTexture("Interface\\Buttons\\CheckButtonHilight");
            fbCk:SetAllPoints(fb);
            fbCk:SetBlendMode("ADD");
            fb:SetCheckedTexture(fbCk);

            fb.totemName  = thisTotem;
            fb.elementKey = elementKey;

            fb:SetScript("OnClick", function()
                ApplyTotemSelection(elementKey, thisTotem);
                barButtons[elementKey].icon:SetTexture(
                    TOTEM_ICONS[thisTotem] or FALLBACK_ICON);
                for i = 1, table.getn(flyBtns) do
                    if flyBtns[i].totemName == thisTotem then
                        flyBtns[i]:SetChecked(1);
                    else
                        flyBtns[i]:SetChecked(nil);
                    end
                end
                CloseFlyout(elementKey);
                tt:Hide();
            end);

            fb:SetScript("OnEnter", function()
                CancelClose(elementKey);
                ShowSpellTip(fb, thisTotem);
            end);
            fb:SetScript("OnLeave", function()
                tt:Hide();
                ScheduleClose(elementKey);
            end);

            flyBtns[thisSlot] = fb;
        end

        fly:SetScript("OnShow", function()
            local cur = GetCurrentTotem(dbKey);
            for i = 1, table.getn(flyBtns) do
                local b = flyBtns[i];
                b.icon:SetTexture(b.totemPath);
                if b.totemName == cur then
                    b:SetChecked(1);
                else
                    b:SetChecked(nil);
                end
            end
        end);

        -- HOVER TO OPEN FLYOUT
        mainBtn:SetScript("OnEnter", function()
            CancelClose(elementKey);
            for i = 1, table.getn(ELEMENTS) do
                if ELEMENTS[i].key ~= elementKey then
                    CloseFlyout(ELEMENTS[i].key);
                end
            end
            fly:ClearAllPoints();
            fly:SetPoint("BOTTOM", mainBtn, "TOP", 0, 4);
            fly:Show();
        end);

        mainBtn:SetScript("OnLeave", function()
            ScheduleClose(elementKey);
        end);

        -- CLICK HANDLER
        -- Right-click toggles between the 2 most common totems per element.
        -- If the current totem is neither of the pair, opens the flyout instead.
        local TOGGLE_PAIRS = {
            ["Fire"]  = { "Searing Totem",            "Magma Totem" },
            ["Water"] = { "Mana Spring Totem",         "Healing Stream Totem" },
            ["Earth"] = { "Strength of Earth Totem",   "Stoneskin Totem" },
            ["Air"]   = { "Windfury Totem",             "Grace of Air Totem" },
        };

        mainBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        mainBtn:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                local pair = TOGGLE_PAIRS[elementKey];
                local cur  = GetCurrentTotem(dbKey);
                if pair and (cur == pair[1] or cur == pair[2]) then
                    -- Toggle to the other one
                    local next = (cur == pair[1]) and pair[2] or pair[1];
                    ApplyTotemSelection(elementKey, next);
                    barButtons[elementKey].icon:SetTexture(
                        TOTEM_ICONS[next] or FALLBACK_ICON);
                else
                    -- Totem not in the pair: open flyout normally
                    if fly:IsVisible() then
                        CloseFlyout(elementKey);
                    else
                        CancelClose(elementKey);
                        for i = 1, table.getn(ELEMENTS) do
                            if ELEMENTS[i].key ~= elementKey then
                                CloseFlyout(ELEMENTS[i].key);
                            end
                        end
                        fly:ClearAllPoints();
                        fly:SetPoint("BOTTOM", mainBtn, "TOP", 0, 4);
                        fly:Show();
                    end
                end
            else
                -- Left-click: cast the current totem
                local cur = GetCurrentTotem(dbKey);
                if cur then
                    CastSpellByName(cur);
                    BP_TotemBar_StartTimer(elementKey, cur);
                else
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "Backpacker: No " .. elementKey .. " totem selected.");
                end
            end
        end);
    end

    -- SLASH COMMAND
    SLASH_BPMENU1 = "/bpmenu";
    SlashCmdList["BPMENU"] = function()
        if bar:IsVisible() then
            CloseAllFlyouts();
            bar:Hide();
        else
            bar:Show();
        end
        PlaySound("igMainMenuOption");
    end;

    function BP_TotemBar_StartTimer(elementKey, totemName)
        local dur = TOTEM_DURATIONS[totemName];
        if dur and dur > 0 then
            timerState[elementKey] = { startTime=GetTime(), duration=dur, totemName=totemName };
        else
            timerState[elementKey] = { startTime=GetTime(), duration=0, totemName=totemName };
        end
    end

    function BP_TotemBar_StopAllTimers()
        for i = 1, table.getn(ELEMENTS) do
            local key = ELEMENTS[i].key;
            timerState[key] = nil;
            local bb = barButtons[key];
            if bb then
                if bb.activeBtn then bb.activeBtn:Hide() end;
                bb.timer:Hide();
                for li = 1, table.getn(bb.timerLayers) do
                    bb.timerLayers[li]:Hide();
                end
            end
        end
    end

    function BP_TotemBar_UpdateMode()
        local waterBtn = barButtons["Water"];
        if not waterBtn then return end;

        if settings.STRATHOLME_MODE then
            waterBtn.icon:SetTexture(TOTEM_ICONS["Disease Cleansing Totem"] or FALLBACK_ICON);
            if DoiteGlow then DoiteGlow.Start(waterBtn.btn); end
        elseif settings.ZG_MODE then
            waterBtn.icon:SetTexture(TOTEM_ICONS["Poison Cleansing Totem"] or FALLBACK_ICON);
            if DoiteGlow then DoiteGlow.Start(waterBtn.btn); end
        else
            local cur = GetCurrentTotem("WATER_TOTEM");
            waterBtn.icon:SetTexture((cur and TOTEM_ICONS[cur]) or FALLBACK_ICON);
            if DoiteGlow then DoiteGlow.Stop(waterBtn.btn); end
        end
    end

    function BP_TotemBar_RefreshIcons()
        for i = 1, table.getn(ELEMENTS) do
            local el = ELEMENTS[i];
            local cur = GetCurrentTotem(el.dbKey);
            local path = (cur and TOTEM_ICONS[cur]) or FALLBACK_ICON;
            barButtons[el.key].icon:SetTexture(path);
        end
        BP_TotemBar_UpdateMode();
    end

    BP_TotemBar_RefreshIcons();

    -- --------------------------------------------------------
    -- TOGGLE BUTTONS  (small row below the active-totem strip)
    -- --------------------------------------------------------
    local TOGGLE_BTN_SIZE = 14;
    local TOGGLE_PADDING  = 2;

    local toggleDefs = {
        { key="ZG",        label="Z", tip="Zul'Gurub mode",  setting="ZG_MODE",
          onToggle = function()
              if settings.STRATHOLME_MODE then
                  settings.STRATHOLME_MODE = false;
                  BackpackerDB.STRATHOLME_MODE = false;
              end
              ToggleSetting("ZG_MODE", "Zul'Gurub mode");
              ResetWaterTotemState();
              if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode(); end;
          end },
        { key="ST",        label="S", tip="Stratholme mode", setting="STRATHOLME_MODE",
          onToggle = function()
              if settings.ZG_MODE then
                  settings.ZG_MODE = false;
                  BackpackerDB.ZG_MODE = false;
              end
              ToggleSetting("STRATHOLME_MODE", "Stratholme mode");
              ResetWaterTotemState();
              if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode(); end;
          end },
        { key="CH",        label="C", tip="Chain Heal",      setting="CHAIN_HEAL_ENABLED",
          onToggle = function() ToggleSetting("CHAIN_HEAL_ENABLED", "Chain Heal"); end },
        { key="FL",        label="F", tip="Follow mode",     setting="FOLLOW_ENABLED",
          onToggle = function() ToggleSetting("FOLLOW_ENABLED", "Follow functionality"); end },
    };

    local totalToggleW = table.getn(toggleDefs) * (TOGGLE_BTN_SIZE + TOGGLE_PADDING) - TOGGLE_PADDING;

    -- Reuse the shared tooltip already created above (BP_MenuTT / tt)
    local function ShowToggleTip(anchor, text)
        tt:ClearLines();
        tt:SetOwner(anchor, "ANCHOR_RIGHT");
        tt:AddLine(text, 1, 1, 1);
        tt:Show();
    end

    local toggleButtons = {};

    local function RefreshToggleColors()
        for i = 1, table.getn(toggleDefs) do
            local def = toggleDefs[i];
            local btn = toggleButtons[def.key];
            if btn then
                if settings[def.setting] then
                    btn.bg:SetTexture(0.15, 0.65, 0.15, 0.85);  -- green: active
                else
                    btn.bg:SetTexture(0.12, 0.12, 0.12, 0.75);  -- dark: inactive
                end
            end
        end
    end

    -- Expose so ToggleSetting callers outside this block can refresh
    function BP_TotemBar_RefreshToggles()
        RefreshToggleColors();
    end

    for i = 1, table.getn(toggleDefs) do
        local def = toggleDefs[i];
        local xOff = BAR_PADDING + (i-1) * (TOGGLE_BTN_SIZE + TOGGLE_PADDING);

        local btn = CreateFrame("Button", nil, bar);
        btn:SetWidth(TOGGLE_BTN_SIZE);
        btn:SetHeight(TOGGLE_BTN_SIZE);
        -- sits just above the main totem buttons
        btn:SetPoint("BOTTOMLEFT", bar, "TOPLEFT",
            xOff,
            -(TOGGLE_PADDING));

        local bg = btn:CreateTexture(nil, "BACKGROUND");
        bg:SetAllPoints(btn);
        bg:SetTexture(0.12, 0.12, 0.12, 0.75);
        btn.bg = bg;

        local lbl = btn:CreateFontString(nil, "OVERLAY");
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE");
        lbl:SetAllPoints(btn);
        lbl:SetJustifyH("CENTER");
        lbl:SetJustifyV("MIDDLE");
        lbl:SetTextColor(0.75, 0.75, 0.75, 1);
        lbl:SetText(def.label);

        local hiTex = btn:CreateTexture(nil, "HIGHLIGHT");
        hiTex:SetTexture(1, 1, 1, 0.15);
        hiTex:SetAllPoints(btn);
        btn:SetHighlightTexture(hiTex);

        btn:SetScript("OnClick", function()
            def.onToggle();
            RefreshToggleColors();
        end);
        btn:SetScript("OnEnter", function() ShowToggleTip(btn, def.tip) end);
        btn:SetScript("OnLeave", function() tt:Hide() end);

        toggleButtons[def.key] = btn;
    end

    -- Set initial colours
    RefreshToggleColors();

    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: /bpmenu ready.");
end