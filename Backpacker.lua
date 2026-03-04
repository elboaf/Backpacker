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
    EARTH_TOTEM = "Strength of Earth Totem",
    FIRE_TOTEM = "Flametongue Totem",
    AIR_TOTEM = "Windfury Totem",
    WATER_TOTEM = "Mana Spring Totem",
    FOLLOW_TARGET_NAME = nil,
    FOLLOW_TARGET_UNIT = "party1",
};

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
    EARTH_TOTEM = BackpackerDB.EARTH_TOTEM,
    FIRE_TOTEM = BackpackerDB.FIRE_TOTEM,
    AIR_TOTEM = BackpackerDB.AIR_TOTEM,
    WATER_TOTEM = BackpackerDB.WATER_TOTEM,
    FOLLOW_TARGET_NAME = BackpackerDB.FOLLOW_TARGET_NAME,
    FOLLOW_TARGET_UNIT = BackpackerDB.FOLLOW_TARGET_UNIT or "party1",
};

local SPELL_ID_LOOKUP = {
    ["Water Shield"] = 51536,
    ["Lightning Shield"] = 10432,
    ["Earth Shield"] = 45525,
    ["Strength of Earth"] = 10441,
    ["Stoneskin"] = 10405,
    ["Flametongue Totem"] = 16388,
    ["Frost Resistance"] = 10476,
    ["Fire Resistance"] = 10535,
    ["Windfury Totem"] = 51367,
    ["Grace of Air"] = 10626,
    ["Nature Resistance"] = 10599,
    ["Windwall Totem"] = 15108,
    ["Mana Spring"] = 10494,
    ["Healing Stream"] = 10461,
};

local SPELL_NAME_BY_ID = {};
for name, id in pairs(SPELL_ID_LOOKUP) do
    SPELL_NAME_BY_ID[id] = name;
end

local superwowEnabled = SUPERWOW_VERSION and true or false
local totemUnitIds = {}
local totemPositions = { air=nil, fire=nil, earth=nil, water=nil }
local RANGE_CHECK_INTERVAL = 2.0
local lastRangeCheckTime = 0
local TOTEM_RANGE = 30

local TOTEM_RANGE_OVERRIDE = {
    ["Searing Totem"] = 20,
    ["Magma Totem"]   = 8,
};

local function HasBuff(buffName, unit)
    if not buffName or not unit then return false end
    local spellId = SPELL_ID_LOOKUP[buffName];
    if not spellId or spellId == 0 then return false end
    for i = 1, 32 do
        local texture, index, buffSpellId = UnitBuff(unit, i);
        if not texture then break end
        if buffSpellId and buffSpellId == spellId then return true end
    end
    return false;
end

local function GetDistance(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then return nil end
    return sqrt((x2-x1)^2 + (y2-y1)^2)
end

local TOTEM_DEFINITIONS = {
    ["Strength of Earth Totem"] = { buff="Strength of Earth", element="earth" },
    ["Stoneskin Totem"]         = { buff="Stoneskin",          element="earth" },
    ["Tremor Totem"]            = { buff=nil,                  element="earth" },
    ["Stoneclaw Totem"]         = { buff=nil,                  element="earth" },
    ["Earthbind Totem"]         = { buff=nil,                  element="earth" },
    ["Flametongue Totem"]       = { buff="Flametongue Totem",  element="fire"  },
    ["Frost Resistance Totem"]  = { buff="Frost Resistance",   element="fire"  },
    ["Fire Nova Totem"]         = { buff=nil,                  element="fire"  },
    ["Searing Totem"]           = { buff=nil,                  element="fire"  },
    ["Magma Totem"]             = { buff=nil,                  element="fire"  },
    ["Windfury Totem"]          = { buff="Windfury Totem",     element="air"   },
    ["Grace of Air Totem"]      = { buff="Grace of Air",       element="air"   },
    ["Nature Resistance Totem"] = { buff="Nature Resistance",  element="air"   },
    ["Grounding Totem"]         = { buff=nil,                  element="air"   },
    ["Sentry Totem"]            = { buff=nil,                  element="air"   },
    ["Windwall Totem"]          = { buff="Windwall Totem",     element="air"   },
    ["Tranquil Air Totem"]      = { buff=nil,                  element="air"   },
    ["Mana Spring Totem"]       = { buff="Mana Spring",        element="water" },
    ["Healing Stream Totem"]    = { buff="Healing Stream",     element="water" },
    ["Fire Resistance Totem"]   = { buff="Fire Resistance",    element="water" },
    ["Poison Cleansing Totem"]  = { buff=nil,                  element="water" },
    ["Disease Cleansing Totem"] = { buff=nil,                  element="water" },
};

local SHIELD_DEFINITIONS = {
    ["Water Shield"]    = { spell="Water Shield",    texture="watershield",   baseCharges=3, spellId=51536 },
    ["Lightning Shield"]= { spell="Lightning Shield",texture="lightningshield",baseCharges=3,spellId=10432 },
    ["Earth Shield"]    = { spell="Earth Shield",    texture="skinofearth",   baseCharges=3, spellId=45525 },
};

local lastTotemRecallTime = 0;
local lastAllTotemsActiveTime = 0;
local lastActiveMessageTime = 0;
local lastTotemCastTime = 0;
local lastFireNovaCastTime = 0;
local FIRE_NOVA_DURATION = 5;
local pendingTotems = {};
local TOTEM_RECALL_COOLDOWN = 3;
local TOTEM_RECALL_ACTIVATION_COOLDOWN = 3;
local TOTEM_VERIFICATION_TIME = 3;
local TOTEM_CAST_DELAY = 0.35;
local lastShieldCheckTime = 0;
local SHIELD_CHECK_INTERVAL = 1.0;

local function InitializeTotemState()
    return {
        { element="air",   spell=settings.AIR_TOTEM,   buff=TOTEM_DEFINITIONS[settings.AIR_TOTEM]   and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff,   locallyVerified=false, serverVerified=false, localVerifyTime=0, unitId=nil },
        { element="fire",  spell=settings.FIRE_TOTEM,  buff=TOTEM_DEFINITIONS[settings.FIRE_TOTEM]  and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff,  locallyVerified=false, serverVerified=false, localVerifyTime=0, unitId=nil },
        { element="earth", spell=settings.EARTH_TOTEM, buff=TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff, locallyVerified=false, serverVerified=false, localVerifyTime=0, unitId=nil },
        { element="water", spell=settings.WATER_TOTEM, buff=TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff, locallyVerified=false, serverVerified=false, localVerifyTime=0, unitId=nil },
    };
end

local totemState = InitializeTotemState();

local swFrame = CreateFrame("Frame")
swFrame:RegisterEvent("UNIT_MODEL_CHANGED")
swFrame:SetScript("OnEvent", function()
    if not superwowEnabled then return end
    local unitId = arg1
    if not unitId then return end
    local unitName = UnitName(unitId)
    if not unitName then return end
    if string.find(unitName, "Totem") and UnitName(unitId.."owner") == UnitName("player") then
        if settings.DEBUG_MODE then
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: SuperWoW detected our totem: "..unitName, 0,1,0)
        end
        local tx, ty = UnitPosition(unitId)
        for i, totem in ipairs(totemState) do
            if totem.locallyVerified and not totem.serverVerified then
                local expectedName = totem.spell
                if expectedName and string.find(unitName, expectedName, 1, true) then
                    totemState[i].serverVerified = true
                    totemState[i].unitId = unitId
                    if tx and ty then totemPositions[totem.element] = { x=tx, y=ty } end
                    if settings.DEBUG_MODE then
                        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Matched "..totem.element.." totem via SuperWoW", 0,1,0)
                    end
                    break
                end
            end
        end
    end
end)

local function GetTotemIndexByElement(element)
    for i, totem in ipairs(totemState) do
        if totem.element == element then return i end
    end
    return nil
end

local function CheckTotemRange()
    if not superwowEnabled then return false end
    local currentTime = GetTime()
    if currentTime - lastRangeCheckTime < RANGE_CHECK_INTERVAL then return false end
    lastRangeCheckTime = currentTime
    local px, py = UnitPosition("player")
    if not px or not py then return false end
    local outOfRange = false
    for element, pos in pairs(totemPositions) do
        if pos and pos.x and pos.y then
            local spellName = nil
            for i, totem in ipairs(totemState) do
                if totem.element == element then spellName = totem.spell; break end
            end
            local effectiveRange = (spellName and TOTEM_RANGE_OVERRIDE[spellName]) or TOTEM_RANGE
            local dist = GetDistance(px, py, pos.x, pos.y)
            if dist and dist > effectiveRange then
                PrintMessage(element.." totem out of range ("..math.floor(dist).." yards)")
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

local function GetStableShieldsRank()
    for tabIndex = 1, GetNumTalentTabs() do
        for talentIndex = 1, GetNumTalents(tabIndex) do
            local name, _, _, _, rank = GetTalentInfo(tabIndex, talentIndex)
            if name == "Stable Shields" then return rank end
        end
    end
    return 0
end

local function GetMaxShieldCharges(shieldType)
    local shieldDef = SHIELD_DEFINITIONS[shieldType]
    if not shieldDef then return 3 end
    local bonusCharges = 0
    if shieldType == "Water Shield" or shieldType == "Lightning Shield" then
        bonusCharges = GetStableShieldsRank() * 2
    end
    return shieldDef.baseCharges + bonusCharges
end

local function GetCurrentShieldCharges(shieldType)
    local shieldDef = SHIELD_DEFINITIONS[shieldType]
    if not shieldDef then return 0 end
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
    local manaPercent   = (UnitMana("player")   / UnitManaMax("player"))   * 100
    if IsShieldActive("Earth Shield") then return "Earth Shield" end
    if manaPercent > healthPercent and healthPercent < 70 then
        return "Earth Shield"
    else
        return "Water Shield"
    end
end

local function PrintMessage(message)
    if settings.DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: "..message);
    end
end

local lastRecallMessageTime = 0;
local RECALL_MESSAGE_COOLDOWN = 6;
local function PrintRecallMessage()
    local now = GetTime();
    if now - lastRecallMessageTime >= RECALL_MESSAGE_COOLDOWN then
        lastRecallMessageTime = now;
        DEFAULT_CHAT_FRAME:AddMessage("Totems: RECALLED", 0, 1, 0);
    end
end

local lastShieldMessageTime = 0;
local SHIELD_MESSAGE_COOLDOWN = 1;
local function PrintShieldMessage(msg)
    local now = GetTime();
    if now - lastShieldMessageTime >= SHIELD_MESSAGE_COOLDOWN then
        lastShieldMessageTime = now;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: "..msg);
    end
end

local lastShieldSetMessageTime = 0;
local SHIELD_SET_MESSAGE_COOLDOWN = 1;
local function PrintShieldSetMessage(msg)
    local now = GetTime();
    if now - lastShieldSetMessageTime >= SHIELD_SET_MESSAGE_COOLDOWN then
        lastShieldSetMessageTime = now;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: "..msg);
    end
end

local function CheckAndRefreshShield()
    if not settings.FARMING_MODE then
        if not settings.AUTO_SHIELD_MODE then return false end
    end
    local currentTime = GetTime();
    if currentTime - lastShieldCheckTime < SHIELD_CHECK_INTERVAL then return false end
    lastShieldCheckTime = currentTime;
    local shieldSpell
    if settings.FARMING_MODE then
        shieldSpell = GetFarmingModeShield()
    else
        shieldSpell = settings.SHIELD_TYPE
    end
    local currentShield, currentCharges = nil, 0
    if IsShieldActive("Earth Shield") then
        currentShield = "Earth Shield"; currentCharges = GetCurrentShieldCharges("Earth Shield")
    elseif IsShieldActive("Water Shield") then
        currentShield = "Water Shield"; currentCharges = GetCurrentShieldCharges("Water Shield")
    elseif IsShieldActive("Lightning Shield") then
        currentShield = "Lightning Shield"; currentCharges = GetCurrentShieldCharges("Lightning Shield")
    end
    if settings.FARMING_MODE then
        if currentShield ~= shieldSpell then
            CastSpellByName(shieldSpell);
            PrintShieldMessage("Farming mode: Switching to "..shieldSpell);
            lastTotemCastTime = currentTime;
            return true;
        end
    else
        local maxCharges = GetMaxShieldCharges(shieldSpell);
        if currentShield ~= shieldSpell or currentCharges < 1 or currentCharges < maxCharges then
            CastSpellByName(shieldSpell);
            PrintShieldMessage(shieldSpell.." needs refreshing ("..currentCharges.."/"..maxCharges.." charges)");
            lastTotemCastTime = currentTime;
            return true;
        end
    end
    return false;
end

local function ToggleSetting(settingName, displayName)
    settings[settingName] = not settings[settingName];
    BackpackerDB[settingName] = settings[settingName];
    if settings[settingName] then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: "..displayName.." enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: "..displayName.." disabled.");
    end
end

local function ResetTotemState()
    for i, totem in ipairs(totemState) do
        totemState[i].locallyVerified = false;
        totemState[i].serverVerified  = false;
        totemState[i].localVerifyTime = 0;
        totemState[i].unitId = nil;
    end
    totemPositions = { air=nil, fire=nil, earth=nil, water=nil }
    lastAllTotemsActiveTime = 0;
    PrintMessage("Totem state reset.");
end

local function ResetWaterTotemState()
    for i, totem in ipairs(totemState) do
        if totem.element == "water" then
            totemState[i].locallyVerified = false;
            totemState[i].serverVerified  = false;
            totemState[i].localVerifyTime = 0;
            totemState[i].unitId = nil;
            totemPositions.water = nil;
            break;
        end
    end
    lastAllTotemsActiveTime = 0;
    PrintMessage("Water totem state reset.");
end

local function DropTotems()
    local currentTime = GetTime();
    if superwowEnabled and CheckTotemRange() then lastAllTotemsActiveTime = 0 end
    if CheckAndRefreshShield() then return end
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        PrintMessage("Totems on cooldown after recall.");
        return;
    end
    if currentTime - lastTotemCastTime < TOTEM_CAST_DELAY then return end

    for i, totem in ipairs(totemState) do
        if totem.element == "air" then
            totemState[i].spell = settings.AIR_TOTEM;
            totemState[i].buff  = TOTEM_DEFINITIONS[settings.AIR_TOTEM] and TOTEM_DEFINITIONS[settings.AIR_TOTEM].buff;
        elseif totem.element == "fire" then
            if settings.FARMING_MODE then
                totemState[i].spell = nil; totemState[i].buff = nil;
            else
                totemState[i].spell = settings.FIRE_TOTEM;
                totemState[i].buff  = TOTEM_DEFINITIONS[settings.FIRE_TOTEM] and TOTEM_DEFINITIONS[settings.FIRE_TOTEM].buff;
            end
        elseif totem.element == "earth" then
            totemState[i].spell = settings.EARTH_TOTEM;
            totemState[i].buff  = TOTEM_DEFINITIONS[settings.EARTH_TOTEM] and TOTEM_DEFINITIONS[settings.EARTH_TOTEM].buff;
        elseif totem.element == "water" then
            if settings.FARMING_MODE then
                totemState[i].spell = nil; totemState[i].buff = nil;
            elseif settings.STRATHOLME_MODE then
                totemState[i].spell = "Disease Cleansing Totem"; totemState[i].buff = nil;
            elseif settings.ZG_MODE then
                totemState[i].spell = "Poison Cleansing Totem"; totemState[i].buff = nil;
            else
                totemState[i].spell = settings.WATER_TOTEM;
                totemState[i].buff  = TOTEM_DEFINITIONS[settings.WATER_TOTEM] and TOTEM_DEFINITIONS[settings.WATER_TOTEM].buff;
            end
        end
    end

    if not settings.FARMING_MODE then
        if not HasBuff(settings.SHIELD_TYPE, 'player') then
            CastSpellByName(settings.SHIELD_TYPE);
            PrintMessage("Casting "..settings.SHIELD_TYPE..".");
            lastTotemCastTime = currentTime;
            return;
        end
    end

    local cleansingTotemSpell = nil;
    if settings.STRATHOLME_MODE then cleansingTotemSpell = "Disease Cleansing Totem"
    elseif settings.ZG_MODE then      cleansingTotemSpell = "Poison Cleansing Totem" end

    if cleansingTotemSpell and UnitAffectingCombat("player") then
        local otherTotemsActive = true;
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            elseif totem.element ~= "water" and not totem.serverVerified then
                otherTotemsActive = false; break;
            end
        end
        if otherTotemsActive then
            for i, totem in ipairs(totemState) do
                if totem.element == "water" then
                    totemState[i].locallyVerified = false; totemState[i].serverVerified = false;
                    totemState[i].localVerifyTime = 0;    totemState[i].unitId = nil;
                    totemPositions.water = nil;
                    PrintMessage("COMBAT: Preparing "..cleansingTotemSpell.." for mass dispel.");
                    break;
                end
            end
        end
    end

    -- PHASE 1: expired totem check
    local hadExpiredTotems = false;
    if superwowEnabled then
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                totemState[i].locallyVerified = true; totemState[i].serverVerified = true;
            elseif totem.unitId then
                if not UnitExists(totem.unitId) then
                    PrintMessage(totem.element.." totem expired/destroyed");
                    totemState[i].serverVerified = false; totemState[i].locallyVerified = false;
                    totemState[i].unitId = nil; totemPositions[totem.element] = nil;
                    hadExpiredTotems = true;
                else
                    if UnitName(totem.unitId.."owner") ~= UnitName("player") then
                        PrintMessage(totem.element.." totem no longer belongs to us");
                        totemState[i].serverVerified = false; totemState[i].locallyVerified = false;
                        totemState[i].unitId = nil; totemPositions[totem.element] = nil;
                        hadExpiredTotems = true;
                    end
                end
            elseif totem.locallyVerified and not totem.unitId then
                PrintMessage(totem.element.." has no unitId - resetting");
                totemState[i].serverVerified = false; totemState[i].locallyVerified = false;
                totemPositions[totem.element] = nil;
                hadExpiredTotems = true;
            end
        end
    else
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
                totemState[i].locallyVerified = true; totemState[i].serverVerified = true;
            elseif totem.locallyVerified and totem.serverVerified then
                if totem.buff and not HasBuff(totem.buff, 'player') then
                    PrintMessage(totem.buff.." has expired - resetting.");
                    totemState[i].locallyVerified = false; totemState[i].serverVerified = false;
                    totemState[i].localVerifyTime = 0;
                    hadExpiredTotems = true;
                end
            end
        end
    end

    if hadExpiredTotems and lastAllTotemsActiveTime > 0 then
        PrintMessage("Expired totems detected - resetting recall cooldown.");
        lastAllTotemsActiveTime = 0;
    end

    -- PHASE 2: drop missing totems
    for i, totem in ipairs(totemState) do
        local isCleansingTotem = false
        if settings.STRATHOLME_MODE and totem.element == "water" and totem.spell == "Disease Cleansing Totem" then isCleansingTotem = true
        elseif settings.ZG_MODE and totem.element == "water" and totem.spell == "Poison Cleansing Totem" then isCleansingTotem = true end

        if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            if not totem.locallyVerified then
                totemState[i].locallyVerified = true; totemState[i].serverVerified = true;
            end
        elseif isCleansingTotem then
            CastSpellByName(totem.spell);
            if BP_TotemBar_StartTimer then
                local el = string.upper(string.sub(totem.element,1,1))..string.sub(totem.element,2);
                BP_TotemBar_StartTimer(el, totem.spell);
            end
            PrintMessage("Casting "..totem.spell.." (forced recast for cleanse pulse).");
            totemState[i].locallyVerified = true; totemState[i].localVerifyTime = currentTime;
            totemState[i].unitId = nil; totemPositions.water = nil;
            lastTotemCastTime = currentTime; return;
        elseif not totem.locallyVerified then
            if not totem.spell or totem.spell == "" then
                totemState[i].locallyVerified = true; totemState[i].serverVerified = true;
                PrintMessage("Skipping "..totem.element.." totem (disabled)");
            else
                CastSpellByName(totem.spell);
                if BP_TotemBar_StartTimer then
                    local el = string.upper(string.sub(totem.element,1,1))..string.sub(totem.element,2);
                    BP_TotemBar_StartTimer(el, totem.spell);
                end
                PrintMessage("Casting "..totem.spell..".");
                totemState[i].locallyVerified = true; totemState[i].localVerifyTime = currentTime;
                totemState[i].unitId = nil; totemPositions[totem.element] = nil;
                lastTotemCastTime = currentTime; return;
            end
        end
    end

    local allLocallyVerified = true;
    for i, totem in ipairs(totemState) do
        if not totem.locallyVerified then allLocallyVerified = false; break end
    end
    if allLocallyVerified and lastAllTotemsActiveTime == 0 then
        PrintMessage("All totems locally verified. Waiting for confirmation...");
    end

    -- PHASE 3: verify totems
    local allServerVerified = true;
    local needsFastDropRestart = false;

    if superwowEnabled then
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            elseif totem.locallyVerified and not totem.serverVerified then
                if totem.unitId then
                    if UnitExists(totem.unitId) and UnitName(totem.unitId.."owner") == UnitName("player") then
                        PrintMessage(totem.element.." totem confirmed via SuperWoW")
                        totemState[i].serverVerified = true
                    else
                        PrintMessage(totem.element.." unitId invalid - resetting")
                        totemState[i].unitId = nil; totemState[i].serverVerified = false;
                        totemState[i].locallyVerified = false; totemState[i].localVerifyTime = 0;
                        totemPositions[totem.element] = nil;
                        allServerVerified = false; needsFastDropRestart = true;
                    end
                else
                    local t = currentTime - totem.localVerifyTime;
                    if t > TOTEM_VERIFICATION_TIME then
                        PrintMessage(totem.element.." totem missing after "..string.format("%.1f",t).."s - resetting.");
                        totemState[i].locallyVerified = false; totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;    totemState[i].unitId = nil;
                        totemPositions[totem.element] = nil;
                        allServerVerified = false; needsFastDropRestart = true;
                    else
                        PrintMessage(totem.element.." waiting for SuperWoW ("..string.format("%.1f",TOTEM_VERIFICATION_TIME-t).."s)");
                        allServerVerified = false;
                    end
                end
            end
            if not totem.serverVerified then allServerVerified = false end
        end
    else
        for i, totem in ipairs(totemState) do
            if (totem.element == "fire" or totem.element == "water") and settings.FARMING_MODE then
            elseif totem.locallyVerified and not totem.serverVerified then
                if totem.buff then
                    if HasBuff(totem.buff, 'player') then
                        PrintMessage(totem.buff.." confirmed active.");
                        totemState[i].serverVerified = true;
                    else
                        local t = currentTime - totem.localVerifyTime;
                        if t > TOTEM_VERIFICATION_TIME then
                            PrintMessage(totem.buff.." missing after "..string.format("%.1f",t).."s - resetting.");
                            totemState[i].locallyVerified = false; totemState[i].serverVerified = false;
                            totemState[i].localVerifyTime = 0;
                            allServerVerified = false; needsFastDropRestart = true;
                        else
                            PrintMessage(totem.buff.." not yet confirmed ("..string.format("%.1f",TOTEM_VERIFICATION_TIME-t).."s)");
                            allServerVerified = false;
                        end
                    end
                else
                    local t = currentTime - totem.localVerifyTime;
                    local resetInterval = 1.0;
                    if totem.spell == "Tremor Totem" or totem.spell == "Poison Cleansing Totem" or totem.spell == "Disease Cleansing Totem" then
                        resetInterval = 0.5;
                    end
                    if t > resetInterval then
                        PrintMessage(totem.spell.." assumed expired - resetting.");
                        totemState[i].locallyVerified = false; totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;
                        allServerVerified = false; needsFastDropRestart = true;
                    else
                        PrintMessage(totem.spell.." waiting ("..string.format("%.1f",resetInterval-t).."s)");
                        allServerVerified = false;
                    end
                end
            end
            if not totem.serverVerified then allServerVerified = false end
        end
    end

    -- PHASE 4: recall
    if allServerVerified then
        PrintMessage("All totems are active.");
        if lastAllTotemsActiveTime == 0 then
            lastAllTotemsActiveTime = currentTime;
            if currentTime - lastActiveMessageTime >= 1.0 then
                lastActiveMessageTime = currentTime;
                DEFAULT_CHAT_FRAME:AddMessage("Totems: ACTIVE", 1, 0, 0);
            end
            return;
        end
        if currentTime - lastAllTotemsActiveTime < TOTEM_RECALL_ACTIVATION_COOLDOWN then
            PrintMessage("Totemic Recall activation cooldown.");
            return;
        end
        if not UnitAffectingCombat("player") then
            CastSpellByName("Totemic Recall");
            if BP_TotemBar_StopAllTimers then BP_TotemBar_StopAllTimers() end
            lastTotemRecallTime = GetTime();
            lastAllTotemsActiveTime = 0;
            lastTotemCastTime = currentTime;
            PrintRecallMessage();
            ResetTotemState();
            PrintMessage("Casting Totemic Recall.");
        else
            PrintMessage("Cannot cast Totemic Recall while in combat.");
        end
    else
        lastAllTotemsActiveTime = 0;
    end
end

-- HEALING
local function ExecuteQuickHeal()
    if QuickHeal then QuickHeal() else RunMacroText("/qh") end
end
local function ExecuteQuickChainHeal()
    if QuickChainHeal then QuickChainHeal() else RunMacroText("/qh chainheal") end
end
local function SortByHealth(a, b)
    return (UnitHealth(a)/UnitHealthMax(a)) < (UnitHealth(b)/UnitHealthMax(b))
end

local function HealPartyMembers()
    local lowHealthMembers = {};
    local function CheckHealth(unit)
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
            local hp = (UnitHealth(unit)/UnitHealthMax(unit))*100;
            if hp < settings.HEALTH_THRESHOLD then table.insert(lowHealthMembers, unit) end
        end
    end
    CheckHealth("player");
    local numRaid = GetNumRaidMembers();
    if numRaid > 0 then
        for i=1,numRaid do CheckHealth("raid"..i) end
    else
        for i=1,GetNumPartyMembers() do CheckHealth("party"..i) end
    end
    if settings.PET_HEALING_ENABLED then
        if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
            if (UnitHealth("pet")/UnitHealthMax("pet"))*100 < settings.HEALTH_THRESHOLD then
                table.insert(lowHealthMembers, "pet")
            end
        end
        if numRaid > 0 then
            for i=1,numRaid do
                local pu = "raidpet"..i;
                if UnitExists(pu) and not UnitIsDeadOrGhost(pu) then
                    if (UnitHealth(pu)/UnitHealthMax(pu))*100 < settings.HEALTH_THRESHOLD then
                        table.insert(lowHealthMembers, pu)
                    end
                end
            end
        else
            for i=1,GetNumPartyMembers() do
                local pu = "partypet"..i;
                if UnitExists(pu) and not UnitIsDeadOrGhost(pu) then
                    if (UnitHealth(pu)/UnitHealthMax(pu))*100 < settings.HEALTH_THRESHOLD then
                        table.insert(lowHealthMembers, pu)
                    end
                end
            end
        end
    end
    table.sort(lowHealthMembers, SortByHealth);
    local n = 0; for _ in pairs(lowHealthMembers) do n=n+1 end
    if n >= 2 and settings.CHAIN_HEAL_ENABLED then
        ExecuteQuickChainHeal()
    elseif n >= 1 then
        ExecuteQuickHeal()
    else
        if settings.FOLLOW_ENABLED then
            if settings.FOLLOW_TARGET_NAME then
                FollowByName(settings.FOLLOW_TARGET_NAME, true)
            elseif GetNumPartyMembers() > 0 then
                FollowUnit("party1")
            end
        end
        if settings.HYBRID_MODE then
            local followTarget = nil;
            if settings.FOLLOW_TARGET_NAME then
                local nr = GetNumRaidMembers();
                if nr > 0 then
                    for i=1,nr do
                        if UnitExists("raid"..i) and UnitName("raid"..i)==settings.FOLLOW_TARGET_NAME then followTarget="raid"..i; break end
                    end
                else
                    for i=1,GetNumPartyMembers() do
                        if UnitExists("party"..i) and UnitName("party"..i)==settings.FOLLOW_TARGET_NAME then followTarget="party"..i; break end
                    end
                end
            else
                followTarget = "party1"
            end
            if followTarget and UnitExists(followTarget) and not UnitIsDeadOrGhost(followTarget) and UnitIsConnected(followTarget) then
                if UnitName(followTarget.."target") then
                    AssistUnit(followTarget);
                    CastSpellByName("Chain Lightning");
                    CastSpellByName("Fire Nova Totem");
                    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire","Fire Nova Totem") end
                    lastFireNovaCastTime = GetTime();
                    CastSpellByName("Lightning Bolt");
                else
                    FollowUnit(followTarget)
                end
            end
        end
    end
end

-- TOTEM SETTERS
local function SetEarthTotem(totemName, displayName)
    if not totemName or totemName == "" then
        settings.EARTH_TOTEM = nil; BackpackerDB.EARTH_TOTEM = nil;
        for i,totem in ipairs(totemState) do
            if totem.element=="earth" then
                totemState[i].spell=nil; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.earth=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Earth totem disabled.");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    elseif TOTEM_DEFINITIONS[totemName] then
        settings.EARTH_TOTEM = totemName; BackpackerDB.EARTH_TOTEM = totemName;
        for i,totem in ipairs(totemState) do
            if totem.element=="earth" then
                totemState[i].spell=totemName; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.earth=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Earth totem set to "..displayName..".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown earth totem: "..totemName);
    end
end

local function SetFireTotem(totemName, displayName)
    if not totemName or totemName == "" then
        settings.FIRE_TOTEM = nil; BackpackerDB.FIRE_TOTEM = nil;
        for i,totem in ipairs(totemState) do
            if totem.element=="fire" then
                totemState[i].spell=nil; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.fire=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Fire totem disabled.");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    elseif TOTEM_DEFINITIONS[totemName] then
        settings.FIRE_TOTEM = totemName; BackpackerDB.FIRE_TOTEM = totemName;
        for i,totem in ipairs(totemState) do
            if totem.element=="fire" then
                totemState[i].spell=totemName; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.fire=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Fire totem set to "..displayName..".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown fire totem: "..totemName);
    end
end

local function SetAirTotem(totemName, displayName)
    if not totemName or totemName == "" then
        settings.AIR_TOTEM = nil; BackpackerDB.AIR_TOTEM = nil;
        for i,totem in ipairs(totemState) do
            if totem.element=="air" then
                totemState[i].spell=nil; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.air=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Air totem disabled.");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    elseif TOTEM_DEFINITIONS[totemName] then
        settings.AIR_TOTEM = totemName; BackpackerDB.AIR_TOTEM = totemName;
        for i,totem in ipairs(totemState) do
            if totem.element=="air" then
                totemState[i].spell=totemName; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.air=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Air totem set to "..displayName..".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown air totem: "..totemName);
    end
end

local function SetWaterTotem(totemName, displayName)
    if not totemName or totemName == "" then
        settings.WATER_TOTEM = nil; BackpackerDB.WATER_TOTEM = nil;
        for i,totem in ipairs(totemState) do
            if totem.element=="water" then
                totemState[i].spell=nil; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.water=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Water totem disabled.");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    elseif TOTEM_DEFINITIONS[totemName] then
        settings.WATER_TOTEM = totemName; BackpackerDB.WATER_TOTEM = totemName;
        for i,totem in ipairs(totemState) do
            if totem.element=="water" then
                totemState[i].spell=totemName; totemState[i].locallyVerified=false;
                totemState[i].serverVerified=false; totemState[i].localVerifyTime=0;
                totemState[i].unitId=nil; totemPositions.water=nil; break;
            end
        end
        lastAllTotemsActiveTime=0;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Water totem set to "..displayName..".");
        if BP_TotemBar_RefreshIcons then BP_TotemBar_RefreshIcons() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Unknown water totem: "..totemName);
    end
end

-- MODE TOGGLES
local function ToggleStratholmeMode()
    if settings.ZG_MODE then
        settings.ZG_MODE=false; BackpackerDB.ZG_MODE=false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode disabled.");
    end
    ToggleSetting("STRATHOLME_MODE","Stratholme mode");
    ResetWaterTotemState();
    if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode() end
end

local function ToggleZulGurubMode()
    if settings.STRATHOLME_MODE then
        settings.STRATHOLME_MODE=false; BackpackerDB.STRATHOLME_MODE=false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode disabled.");
    end
    ToggleSetting("ZG_MODE","Zul'Gurub mode");
    ResetWaterTotemState();
    if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode() end
end

local function ToggleHybridMode()
    ToggleSetting("HYBRID_MODE","Hybrid mode");
    if settings.HYBRID_MODE then
        settings.HEALTH_THRESHOLD=80; BackpackerDB.HEALTH_THRESHOLD=80;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Healing threshold set to 80% for hybrid mode.");
    else
        settings.HEALTH_THRESHOLD=90; BackpackerDB.HEALTH_THRESHOLD=90;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Healing threshold reset to 90%.");
    end
end

local function SetTotemCastDelay(delay)
    delay = tonumber(delay);
    if delay and delay >= 0 then
        TOTEM_CAST_DELAY = delay;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Totem cast delay set to "..delay.." seconds.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid delay.");
    end
end

local function ManualTotemicRecall()
    local currentTime = GetTime();
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then return end
    CastSpellByName("Totemic Recall");
    if BP_TotemBar_StopAllTimers then BP_TotemBar_StopAllTimers() end
    lastAllTotemsActiveTime=0; lastTotemCastTime=currentTime;
    PrintRecallMessage();
    ResetTotemState();
end

local function TogglePetHealing()    ToggleSetting("PET_HEALING_ENABLED","Pet healing mode") end
local function ToggleAutoShieldMode()
    ToggleSetting("AUTO_SHIELD_MODE","Shield auto-refresh mode");
    if settings.AUTO_SHIELD_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh enabled for "..settings.SHIELD_TYPE..".");
    end
end

local function SetWaterShield()
    if settings.FARMING_MODE then PrintShieldSetMessage("Cannot change shield while farming mode is active."); return end
    settings.SHIELD_TYPE="Water Shield"; BackpackerDB.SHIELD_TYPE="Water Shield";
    PrintShieldSetMessage("Shield type set to Water Shield.");
end
local function SetLightningShield()
    if settings.FARMING_MODE then PrintShieldSetMessage("Cannot change shield while farming mode is active."); return end
    settings.SHIELD_TYPE="Lightning Shield"; BackpackerDB.SHIELD_TYPE="Lightning Shield";
    PrintShieldSetMessage("Shield type set to Lightning Shield.");
end
local function SetEarthShield()
    if settings.FARMING_MODE then PrintShieldSetMessage("Cannot change shield while farming mode is active."); return end
    settings.SHIELD_TYPE="Earth Shield"; BackpackerDB.SHIELD_TYPE="Earth Shield";
    PrintShieldSetMessage("Shield type set to Earth Shield.");
end

local function ReportTotemsToParty()
    local function Fmt(s)
        if not s or type(s)~="string" then return "Unknown" end
        if string.find(s," Totem$") then return string.sub(s,1,-7) end
        return s
    end
    local air   = settings.AIR_TOTEM   or "Windfury Totem"
    local earth = settings.EARTH_TOTEM or "Strength of Earth Totem"
    local fire  = settings.FIRE_TOTEM  or "Flametongue Totem"
    local water = settings.WATER_TOTEM or "Mana Spring Totem"
    if settings.STRATHOLME_MODE then water="Disease Cleansing Totem"
    elseif settings.ZG_MODE then     water="Poison Cleansing Totem" end
    local list = { Fmt(air), Fmt(fire), Fmt(earth), Fmt(water) }
    local msg = "Current Totems: "..table.concat(list,", ")
    SendChatMessage(msg,"PARTY")
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: "..msg)
end

local function ToggleFarmingMode()
    ToggleSetting("FARMING_MODE","Farming mode");
    if settings.FARMING_MODE and settings.AUTO_SHIELD_MODE then
        settings.AUTO_SHIELD_MODE=false; BackpackerDB.AUTO_SHIELD_MODE=false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Auto-refresh disabled for farming mode.");
    end
    ResetTotemState();
end

-- DEBUG SLASH COMMANDS
SLASH_BPCHECKSUPERWOW1="/bpchecksw";
SlashCmdList["BPCHECKSUPERWOW"]=function()
    if superwowEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("=== SuperWoW Detected === v"..tostring(SUPERWOW_VERSION));
        for i,totem in ipairs(totemState) do
            local s="Inactive"
            if totem.unitId then s=UnitExists(totem.unitId) and "Active" or "Expired"
            elseif totem.serverVerified then s="Verified"
            elseif totem.locallyVerified then s="Pending" end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s (Unit: %s)",totem.element,s,totem.unitId or "none"))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("=== SuperWoW NOT Detected === Using fallback buff detection");
    end
end

SLASH_BPTOTEMPOS1="/bptotempos";
SlashCmdList["BPTOTEMPOS"]=function()
    DEFAULT_CHAT_FRAME:AddMessage("=== Totem Positions ===");
    local px,py=UnitPosition("player")
    if px and py then DEFAULT_CHAT_FRAME:AddMessage("Player: "..math.floor(px)..","..math.floor(py)) end
    for element,pos in pairs(totemPositions) do
        if pos and pos.x and pos.y then
            local dist=GetDistance(px,py,pos.x,pos.y)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %d,%d (%.1f yds) - %s",
                element,math.floor(pos.x),math.floor(pos.y),dist or 0,
                (dist and dist>TOTEM_RANGE) and "OUT OF RANGE" or "In range"))
        else
            DEFAULT_CHAT_FRAME:AddMessage(element..": No position data")
        end
    end
end

SLASH_BPCHECKBUFFS1="/bpcheckbuffs";
SlashCmdList["BPCHECKBUFFS"]=function()
    DEFAULT_CHAT_FRAME:AddMessage("=== Buffs ===");
    for i=1,32 do
        local texture,index,spellId=UnitBuff("player",i);
        if not texture then DEFAULT_CHAT_FRAME:AddMessage("Total: "..(i-1)); break end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("#%d: ID=%d Name=%s",i,spellId or 0,SPELL_NAME_BY_ID[spellId] or "Unknown"))
    end
end

-- MANUAL CAST COMMANDS
local function ManualCastEarth(spell)
    CastSpellByName(spell)
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Earth",spell) end
    for i,totem in ipairs(totemState) do
        if totem.element=="earth" then
            totemState[i].locallyVerified=true; totemState[i].localVerifyTime=GetTime();
            totemState[i].serverVerified=false; totemState[i].unitId=nil; totemPositions.earth=nil; break
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual "..spell.." cast",1,1,0)
end
local function ManualCastFire(spell)
    CastSpellByName(spell)
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire",spell) end
    if spell=="Fire Nova Totem" then lastFireNovaCastTime=GetTime() end
    for i,totem in ipairs(totemState) do
        if totem.element=="fire" then
            totemState[i].locallyVerified=true; totemState[i].localVerifyTime=GetTime();
            totemState[i].serverVerified=false; totemState[i].unitId=nil; totemPositions.fire=nil; break
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual "..spell.." cast",1,1,0)
end
local function ManualCastAir(spell)
    CastSpellByName(spell)
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Air",spell) end
    for i,totem in ipairs(totemState) do
        if totem.element=="air" then
            totemState[i].locallyVerified=true; totemState[i].localVerifyTime=GetTime();
            totemState[i].serverVerified=false; totemState[i].unitId=nil; totemPositions.air=nil; break
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual "..spell.." cast",1,1,0)
end
local function ManualCastWater(spell)
    CastSpellByName(spell)
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Water",spell) end
    for i,totem in ipairs(totemState) do
        if totem.element=="water" then
            totemState[i].locallyVerified=true; totemState[i].localVerifyTime=GetTime();
            totemState[i].serverVerified=false; totemState[i].unitId=nil; totemPositions.water=nil; break
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Manual "..spell.." cast",1,1,0)
end

SLASH_BPSOECAST1="/bpsoe-cast";     SlashCmdList["BPSOECAST"]=function() ManualCastEarth("Strength of Earth Totem") end
SLASH_BPSSCAST1="/bpss-cast";       SlashCmdList["BPSSCAST"]=function() ManualCastEarth("Stoneskin Totem") end
SLASH_BPTREMORCAST1="/bptremor-cast"; SlashCmdList["BPTREMORCAST"]=function() ManualCastEarth("Tremor Totem") end
SLASH_BPSTONECLAWCAST1="/bpstoneclaw-cast"; SlashCmdList["BPSTONECLAWCAST"]=function() ManualCastEarth("Stoneclaw Totem") end
SLASH_BPEARTHBINDCAST1="/bpearthbind-cast"; SlashCmdList["BPEARTHBINDCAST"]=function() ManualCastEarth("Earthbind Totem") end

SLASH_BPFTCAST1="/bpft-cast";       SlashCmdList["BPFTCAST"]=function() ManualCastFire("Flametongue Totem") end
SLASH_BPFRRCAST1="/bpfrr-cast";     SlashCmdList["BPFRRCAST"]=function() ManualCastFire("Frost Resistance Totem") end
SLASH_BPFIRENOVACAST1="/bpfirenova-cast"; SlashCmdList["BPFIRENOVACAST"]=function() ManualCastFire("Fire Nova Totem") end
SLASH_BPSEARINGCAST1="/bpsearing-cast"; SlashCmdList["BPSEARINGCAST"]=function() ManualCastFire("Searing Totem") end
SLASH_BPMAGMACAST1="/bpmagma-cast"; SlashCmdList["BPMAGMACAST"]=function() ManualCastFire("Magma Totem") end

SLASH_BPWFCAST1="/bpwf-cast";       SlashCmdList["BPWFCAST"]=function() ManualCastAir("Windfury Totem") end
SLASH_BPGOACAST1="/bpgoa-cast";     SlashCmdList["BPGOACAST"]=function() ManualCastAir("Grace of Air Totem") end
SLASH_BPNRCAST1="/bpnr-cast";       SlashCmdList["BPNRCAST"]=function() ManualCastAir("Nature Resistance Totem") end
SLASH_BPGROUNDINGCAST1="/bpgrounding-cast"; SlashCmdList["BPGROUNDINGCAST"]=function() ManualCastAir("Grounding Totem") end
SLASH_BPSENTRYCAST1="/bpsentry-cast"; SlashCmdList["BPSENTRYCAST"]=function() ManualCastAir("Sentry Totem") end
SLASH_BPWINDWALLCAST1="/bpwindwall-cast"; SlashCmdList["BPWINDWALLCAST"]=function() ManualCastAir("Windwall Totem") end
SLASH_BPTRANQUILCAST1="/bptranquil-cast"; SlashCmdList["BPTRANQUILCAST"]=function() ManualCastAir("Tranquil Air Totem") end

SLASH_BPMSCAST1="/bpms-cast";       SlashCmdList["BPMSCAST"]=function() ManualCastWater("Mana Spring Totem") end
SLASH_BPHSCAST1="/bphs-cast";       SlashCmdList["BPHSCAST"]=function() ManualCastWater("Healing Stream Totem") end
SLASH_BPFRCAST1="/bpfr-cast";       SlashCmdList["BPFRCAST"]=function() ManualCastWater("Fire Resistance Totem") end
SLASH_BPPOISONCAST1="/bppoison-cast"; SlashCmdList["BPPOISONCAST"]=function() ManualCastWater("Poison Cleansing Totem") end
SLASH_BPDISEASECAST1="/bpdisease-cast"; SlashCmdList["BPDISEASECAST"]=function() ManualCastWater("Disease Cleansing Totem") end

-- Public API
Backpacker = Backpacker or {};
Backpacker.API = {
    GetTotem = function(element) return settings[string.upper(element).."_TOTEM"] end,
    SetTotem = function(element, totemName)
        local el=string.lower(element)
        if     el=="earth" then SetEarthTotem(totemName,totemName)
        elseif el=="fire"  then SetFireTotem(totemName,totemName)
        elseif el=="air"   then SetAirTotem(totemName,totemName)
        elseif el=="water" then SetWaterTotem(totemName,totemName)
        end
    end,
};

local function PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker commands:");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal /bpbuff /bpfirebuff /bprecall /bpdebug");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpf (follow) /bpl (set follow target) /bpchainheal");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpstrath /bpzg /bphybrid /bpdelay /bppets /bpauto");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpws /bpls /bpes (shield type)");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfarm /bpreport /bpmenu");
    DEFAULT_CHAT_FRAME:AddMessage("  EARTH: /bpsoe /bpss /bptremor /bpstoneclaw /bpearthbind");
    DEFAULT_CHAT_FRAME:AddMessage("  FIRE:  /bpft /bpfrr /bpfirenova /bpsearing /bpmagma");
    DEFAULT_CHAT_FRAME:AddMessage("  AIR:   /bpwf /bpgoa /bpnr /bpgrounding /bpsentry /bpwindwall /bptranquil");
    DEFAULT_CHAT_FRAME:AddMessage("  WATER: /bpms /bphs /bpfr /bppoison /bpdisease");
    DEFAULT_CHAT_FRAME:AddMessage("  Add -cast suffix for manual cast variants");
end

SLASH_BPHEAL1="/bpheal"; SlashCmdList["BPHEAL"]=HealPartyMembers;

local function DropFireTotem()
    local currentTime = GetTime();
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Totems on cooldown after recall."); return
    end
    if currentTime - lastTotemCastTime < TOTEM_CAST_DELAY then return end
    if settings.FARMING_MODE then DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Fire totem suppressed in farming mode."); return end
    local fireSpell = settings.FIRE_TOTEM;
    if not fireSpell or fireSpell=="" then DEFAULT_CHAT_FRAME:AddMessage("Backpacker: No fire totem configured."); return end
    if currentTime - lastFireNovaCastTime < FIRE_NOVA_DURATION then return end

    if superwowEnabled then
        local px,py = UnitPosition("player")
        local pos = totemPositions["fire"]
        if px and py and pos and pos.x and pos.y then
            local effectiveRange = TOTEM_RANGE_OVERRIDE[fireSpell] or TOTEM_RANGE
            local dist = GetDistance(px,py,pos.x,pos.y)
            if dist and dist > effectiveRange then
                for i,totem in ipairs(totemState) do
                    if totem.element=="fire" then
                        totemState[i].locallyVerified=false; totemState[i].serverVerified=false;
                        totemState[i].unitId=nil; totemPositions["fire"]=nil; break
                    end
                end
            end
        end
    end

    local fireActive = false;
    for i,totem in ipairs(totemState) do
        if totem.element=="fire" then
            if superwowEnabled then
                if totem.unitId and UnitExists(totem.unitId) then fireActive=true end
            else
                if totem.buff and HasBuff(totem.buff,"player") then fireActive=true
                elseif totem.locallyVerified and totem.serverVerified then fireActive=true end
            end
            break
        end
    end
    if fireActive then return end

    CastSpellByName(fireSpell);
    if BP_TotemBar_StartTimer then BP_TotemBar_StartTimer("Fire",fireSpell) end
    for i,totem in ipairs(totemState) do
        if totem.element=="fire" then
            totemState[i].spell=fireSpell; totemState[i].locallyVerified=true;
            totemState[i].localVerifyTime=currentTime; totemState[i].serverVerified=false;
            totemState[i].unitId=nil; totemPositions.fire=nil; break
        end
    end
    lastTotemCastTime = currentTime;
end

SLASH_BPBUFF1="/bpbuff";           SlashCmdList["BPBUFF"]=DropTotems;
SLASH_BPFIREBUFF1="/bpfirebuff";   SlashCmdList["BPFIREBUFF"]=DropFireTotem;
SLASH_BPDEBUG1="/bpdebug";         SlashCmdList["BPDEBUG"]=function() ToggleSetting("DEBUG_MODE","Debug mode") end
SLASH_BPF1="/bpf";                 SlashCmdList["BPF"]=function() ToggleSetting("FOLLOW_ENABLED","Follow functionality") end
SLASH_BPCHAINHEAL1="/bpchainheal"; SlashCmdList["BPCHAINHEAL"]=function() ToggleSetting("CHAIN_HEAL_ENABLED","Chain Heal functionality") end
SLASH_BPSTRATH1="/bpstrath";       SlashCmdList["BPSTRATH"]=ToggleStratholmeMode;
SLASH_BPZG1="/bpzg";               SlashCmdList["BPZG"]=ToggleZulGurubMode;
SLASH_BPHYBRID1="/bphybrid";       SlashCmdList["BPHYBRID"]=ToggleHybridMode;
SLASH_BPDELAY1="/bpdelay";         SlashCmdList["BPDELAY"]=SetTotemCastDelay;
SLASH_BPRECALL1="/bprecall";       SlashCmdList["BPRECALL"]=ManualTotemicRecall;
SLASH_BPPETS1="/bppets";           SlashCmdList["BPPETS"]=TogglePetHealing;
SLASH_BPAUTO1="/bpauto";           SlashCmdList["BPAUTO"]=ToggleAutoShieldMode;

SLASH_BPL1="/bpl";
SlashCmdList["BPL"]=function()
    if UnitExists("target") and UnitIsPlayer("target") then
        local n=UnitName("target"); settings.FOLLOW_TARGET_NAME=n; BackpackerDB.FOLLOW_TARGET_NAME=n;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow target set to "..n..".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: No valid player target selected.");
    end
end

SLASH_BPWATERSHIELD1="/bpwatershield"; SLASH_BPWATERSHIELD2="/bpws"; SlashCmdList["BPWATERSHIELD"]=SetWaterShield;
SLASH_BPLIGHTNINGSHIELD1="/bplightningshield"; SLASH_BPLIGHTNINGSHIELD2="/bpls"; SlashCmdList["BPLIGHTNINGSHIELD"]=SetLightningShield;
SLASH_BPEARTHSHIELD1="/bpearthshield"; SLASH_BPEARTHSHIELD2="/bpes"; SlashCmdList["BPEARTHSHIELD"]=SetEarthShield;

SLASH_BPSOE1="/bpsoe";       SlashCmdList["BPSOE"]=function() SetEarthTotem("Strength of Earth Totem","Strength of Earth") end
SLASH_BPSS1="/bpss";         SlashCmdList["BPSS"]=function() SetEarthTotem("Stoneskin Totem","Stoneskin") end
SLASH_BPTREMOR1="/bptremor"; SlashCmdList["BPTREMOR"]=function() SetEarthTotem("Tremor Totem","Tremor") end
SLASH_BPSTONECLAW1="/bpstoneclaw"; SlashCmdList["BPSTONECLAW"]=function() SetEarthTotem("Stoneclaw Totem","Stoneclaw") end
SLASH_BPEARTHBIND1="/bpearthbind"; SlashCmdList["BPEARTHBIND"]=function() SetEarthTotem("Earthbind Totem","Earthbind") end

SLASH_BPFT1="/bpft";         SlashCmdList["BPFT"]=function() SetFireTotem("Flametongue Totem","Flametongue") end
SLASH_BPFRR1="/bpfrr";       SlashCmdList["BPFRR"]=function() SetFireTotem("Frost Resistance Totem","Frost Resistance") end
SLASH_BPFIRENOVA1="/bpfirenova"; SlashCmdList["BPFIRENOVA"]=function() SetFireTotem("Fire Nova Totem","Fire Nova") end
SLASH_BPSEARING1="/bpsearing"; SlashCmdList["BPSEARING"]=function() SetFireTotem("Searing Totem","Searing") end
SLASH_BPMAGMA1="/bpmagma";   SlashCmdList["BPMAGMA"]=function() SetFireTotem("Magma Totem","Magma") end

SLASH_BPWF1="/bpwf";         SlashCmdList["BPWF"]=function() SetAirTotem("Windfury Totem","Windfury") end
SLASH_BPGOA1="/bpgoa";       SlashCmdList["BPGOA"]=function() SetAirTotem("Grace of Air Totem","Grace of Air") end
SLASH_BPNR1="/bpnr";         SlashCmdList["BPNR"]=function() SetAirTotem("Nature Resistance Totem","Nature Resistance") end
SLASH_BPGROUNDING1="/bpgrounding"; SlashCmdList["BPGROUNDING"]=function() SetAirTotem("Grounding Totem","Grounding") end
SLASH_BPSENTRY1="/bpsentry"; SlashCmdList["BPSENTRY"]=function() SetAirTotem("Sentry Totem","Sentry") end
SLASH_BPWINDWALL1="/bpwindwall"; SlashCmdList["BPWINDWALL"]=function() SetAirTotem("Windwall Totem","Windwall") end
SLASH_BPTRANQUIL1="/bptranquil"; SlashCmdList["BPTRANQUIL"]=function() SetAirTotem("Tranquil Air Totem","Tranquil Air") end

SLASH_BPMS1="/bpms";         SlashCmdList["BPMS"]=function() SetWaterTotem("Mana Spring Totem","Mana Spring") end
SLASH_BPHS1="/bphs";         SlashCmdList["BPHS"]=function() SetWaterTotem("Healing Stream Totem","Healing Stream") end
SLASH_BPFR1="/bpfr";         SlashCmdList["BPFR"]=function() SetWaterTotem("Fire Resistance Totem","Fire Resistance") end
SLASH_BPPOISON1="/bppoison"; SlashCmdList["BPPOISON"]=function() SetWaterTotem("Poison Cleansing Totem","Poison Cleansing") end
SLASH_BPDISEASE1="/bpdisease"; SlashCmdList["BPDISEASE"]=function() SetWaterTotem("Disease Cleansing Totem","Disease Cleansing") end

SLASH_BPFARM1="/bpfarm";     SlashCmdList["BPFARM"]=ToggleFarmingMode;
SLASH_BP1="/bp"; SLASH_BP2="/backpacker"; SlashCmdList["BP"]=PrintUsage;
SLASH_BPREPORT1="/bpreport"; SlashCmdList["BPREPORT"]=ReportTotemsToParty;

local function OnEvent(event, arg1)
    if event=="ADDON_LOADED" and arg1=="Backpacker" then
        for k,v in pairs(BackpackerDB) do settings[k]=v end
        totemState = InitializeTotemState();
        if SUPERWOW_VERSION then
            superwowEnabled=true
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: SuperWoW v"..tostring(SUPERWOW_VERSION).." detected.");
        else
            superwowEnabled=false
            DEFAULT_CHAT_FRAME:AddMessage("Backpacker: SuperWoW not detected - using fallback buff detection.");
        end
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Loaded.");
    end
end
local f=CreateFrame("Frame"); f:RegisterEvent("ADDON_LOADED"); f:SetScript("OnEvent",OnEvent);
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

    local function GetCurrentTotem(dbKey) return settings[dbKey] end

    local NONE_ICON = "Interface\\Icons\\spell_shadow_sacrificialshield";

    local function ApplyTotemSelection(elementKey, totemName)
        local el=string.lower(elementKey)
        if     el=="earth" then SetEarthTotem(totemName, totemName or "none")
        elseif el=="fire"  then SetFireTotem(totemName,  totemName or "none")
        elseif el=="air"   then SetAirTotem(totemName,   totemName or "none")
        elseif el=="water" then SetWaterTotem(totemName, totemName or "none")
        end
    end

    local tt = CreateFrame("GameTooltip","BP_MenuTT",UIParent,"GameTooltipTemplate");
    tt:SetOwner(UIParent,"ANCHOR_NONE");
    local function ShowSpellTip(anchor, spellName)
        tt:ClearLines(); tt:SetOwner(anchor,"ANCHOR_RIGHT");
        local i=1;
        while true do
            local n=GetSpellName(i,BOOKTYPE_SPELL); if not n then break end
            if n==spellName then tt:SetSpell(i,BOOKTYPE_SPELL); tt:Show(); return end
            i=i+1;
        end
        tt:AddLine(spellName,1,1,1); tt:Show();
    end

    -- All size constants defined together, in dependency order
    local BAR_BTN_SIZE    = 40;
    local ACTIVE_BTN_SIZE = 28;
    local FLY_BTN_SIZE    = 36;
    local FLY_PADDING     = 0;
    local FLY_ROW_H       = FLY_BTN_SIZE;
    local FLY_WIDTH       = FLY_BTN_SIZE + FLY_PADDING * 2;
    local TOGGLE_BTN_SIZE = 14;
    local SLIDER_H        = TOGGLE_BTN_SIZE + 4;
    local BAR_PADDING     = 0;
    local TOGGLE_PADDING  = 0;
    local HANDLE_H        = 14;

    local barW = BAR_BTN_SIZE * 4;
    local barH = BAR_BTN_SIZE + HANDLE_H;

    local bar = CreateFrame("Frame","BP_TotemBar",UIParent);
    bar:SetWidth(barW); bar:SetHeight(barH);
    bar:SetPoint("CENTER",UIParent,"CENTER",0,-300);
    bar:SetMovable(true); bar:EnableMouse(true); bar:SetFrameStrata("MEDIUM");
    bar:SetScript("OnMouseDown",function() if arg1=="LeftButton" then bar:StartMoving() end end);
    bar:SetScript("OnMouseUp",function() bar:StopMovingOrSizing() end);

    -- Unified background panel (fades in on hover, covers the whole bar incl. handle strip)
    local barBg = CreateFrame("Frame", nil, bar);
    barBg:SetAllPoints(bar);
    local barBgTex = barBg:CreateTexture(nil, "BACKGROUND");
    barBgTex:SetAllPoints(barBg);
    barBgTex:SetTexture(0.05, 0.05, 0.05, 0.88);

    local dragLabel = barBg:CreateFontString(nil, "OVERLAY");
    dragLabel:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE");
    dragLabel:SetPoint("CENTER", barBg, "BOTTOM", 0, HANDLE_H / 2);
    dragLabel:SetTextColor(0.55, 0.55, 0.55, 1);
    dragLabel:SetText("drag");

    local flyoutFrames = {};
    local barButtons   = {};

    -- Controls (toggle buttons + sliders) that fade in on bar mouseover
    local fadeControls = {};
    local barHovered   = false;
    local FADE_SPEED   = 4.0; -- alpha units per second

    local fadeFrame = CreateFrame("Frame");
    fadeFrame:SetScript("OnUpdate", function()
        local dt = arg1;
        for i = 1, table.getn(fadeControls) do
            local ctrl = fadeControls[i];
            if ctrl and ctrl.GetAlpha then
                local cur = ctrl:GetAlpha();
                if barHovered then
                    local next = cur + FADE_SPEED * dt;
                    if next >= 1 then next = 1 end
                    ctrl:SetAlpha(next);
                else
                    local next = cur - FADE_SPEED * dt;
                    if next <= 0 then next = 0 end
                    ctrl:SetAlpha(next);
                end
            end
        end
    end);

    -- bar-level enter/leave to drive fade (fires when mouse enters/leaves the whole bar region)
    bar:SetScript("OnEnter", function() barHovered = true  end);
    bar:SetScript("OnLeave", function() barHovered = false end);

    barBg:SetAlpha(0);
    fadeControls[table.getn(fadeControls)+1] = barBg;

    -- Resize the bar height depending on whether any active-totem row is visible
    local function ResizeBar()
        local anyActive = false;
        for i = 1, table.getn(ELEMENTS) do
            local bb = barButtons[ELEMENTS[i].key];
            if bb and bb.activeBtn and bb.activeBtn:IsVisible() then
                anyActive = true; break;
            end
        end
        local newH = anyActive and (BAR_BTN_SIZE + ACTIVE_BTN_SIZE + HANDLE_H)
                                 or (BAR_BTN_SIZE + HANDLE_H);
        bar:SetHeight(newH);
        barBg:SetHeight(newH);
    end

    local tickFrame = CreateFrame("Frame");
    tickFrame:SetScript("OnUpdate",function()
        local now=GetTime();
        for i=1,table.getn(ELEMENTS) do
            local el=ELEMENTS[i]; local bb=barButtons[el.key]; local ts=timerState[el.key];
            if not bb then return end

            local function SetTD(fs,layers,text,r,g,b)
                fs:SetText(text); fs:SetTextColor(r,g,b,1); fs:Show();
                for li=1,table.getn(layers) do layers[li]:SetText(text); layers[li]:Show() end
            end
            local function HideTD(fs,layers)
                fs:Hide(); for li=1,table.getn(layers) do layers[li]:Hide() end
            end
            local function TC(rem,dur)
                if rem>dur*0.5 then return 1,1,1 elseif rem>10 then return 1,0.8,0 else return 1,0.2,0.2 end
            end
            local function FT(r) if r<10 then return string.format("%.1f",r) else return string.format("%d",r) end end

            local setTotem=GetCurrentTotem(el.dbKey)
            if el.key=="Water" then
                if settings.STRATHOLME_MODE then setTotem="Disease Cleansing Totem"
                elseif settings.ZG_MODE then setTotem="Poison Cleansing Totem" end
            end
            local activeTotem=ts and ts.totemName
            local showActive=activeTotem and activeTotem~=setTotem

            if ts then
                local rem=ts.duration-(now-ts.startTime)
                if ts.duration==0 or rem<=0 then
                    timerState[el.key]=nil; HideTD(bb.timer,bb.timerLayers)
                    if bb.activeBtn then bb.activeBtn:Hide(); ResizeBar() end
                else
                    local text=FT(rem); local r,g,b=TC(rem,ts.duration)
                    if showActive then
                        HideTD(bb.timer,bb.timerLayers)
                        if bb.activeBtn then
                            bb.activeIcon:SetTexture(TOTEM_ICONS[activeTotem] or FALLBACK_ICON)
                            SetTD(bb.activeTimer,bb.activeTimerLayers,text,r,g,b)
                            bb.activeBtn:Show(); ResizeBar()
                        end
                    else
                        SetTD(bb.timer,bb.timerLayers,text,r,g,b)
                        if bb.activeBtn then bb.activeBtn:Hide(); ResizeBar() end
                    end
                end
            else
                HideTD(bb.timer,bb.timerLayers)
                if bb.activeBtn then bb.activeBtn:Hide(); ResizeBar() end
            end
        end
    end);

    local closeScheduled={};
    local function CloseFlyout(key) if flyoutFrames[key] then flyoutFrames[key]:Hide() end; closeScheduled[key]=false end
    local function CloseAllFlyouts() for i=1,table.getn(ELEMENTS) do CloseFlyout(ELEMENTS[i].key) end end
    local function ScheduleClose(key)
        closeScheduled[key]=true; local elapsed=0;
        bar:SetScript("OnUpdate",function()
            elapsed=elapsed+arg1; if elapsed<0.12 then return end
            bar:SetScript("OnUpdate",nil)
            if closeScheduled[key] then CloseFlyout(key) end
        end)
    end
    local function CancelClose(key) closeScheduled[key]=false end

    -- BUILD COLUMNS
    for colIdx=1,table.getn(ELEMENTS) do
        local elDef=ELEMENTS[colIdx]; local elementKey=elDef.key; local dbKey=elDef.dbKey;

        local mainBtn=CreateFrame("Button",nil,bar);
        mainBtn:SetWidth(BAR_BTN_SIZE); mainBtn:SetHeight(SLIDER_H);
        mainBtn:SetHitRectInsets(0, 0, 0, -math.floor(BAR_BTN_SIZE * 0.8 - SLIDER_H));
        mainBtn:SetPoint("TOPLEFT",bar,"TOPLEFT",(colIdx-1)*BAR_BTN_SIZE,0);

        local slotTex=mainBtn:CreateTexture(nil,"BACKGROUND");
        slotTex:SetTexture("Interface\\Buttons\\UI-EmptySlot"); slotTex:SetAllPoints(mainBtn);

        local barIcon=mainBtn:CreateTexture(nil,"ARTWORK");
        barIcon:SetWidth(BAR_BTN_SIZE); barIcon:SetHeight(BAR_BTN_SIZE);
        barIcon:SetPoint("CENTER",mainBtn,"CENTER",0,0);

        local hiTex=mainBtn:CreateTexture(nil,"HIGHLIGHT");
        hiTex:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hiTex:SetAllPoints(mainBtn);
        hiTex:SetBlendMode("ADD"); mainBtn:SetHighlightTexture(hiTex);

        local timerText=mainBtn:CreateFontString(nil,"OVERLAY");
        timerText:SetFont("Fonts\\FRIZQT__.TTF",14,"THICKOUTLINE");
        timerText:SetPoint("CENTER",mainBtn,"CENTER",0,0);
        timerText:SetTextColor(1,1,1,1); timerText:Hide();
        local timerLayers={};

        local activeBtn=CreateFrame("Button",nil,bar);
        activeBtn:SetWidth(BAR_BTN_SIZE); activeBtn:SetHeight(BAR_BTN_SIZE);
        activeBtn:SetPoint("TOP",mainBtn,"BOTTOM",0,-(BAR_BTN_SIZE - SLIDER_H - HANDLE_H));

        local aSlot=activeBtn:CreateTexture(nil,"BACKGROUND");
        aSlot:SetTexture("Interface\\Buttons\\UI-EmptySlot"); aSlot:SetAllPoints(activeBtn);
        local aIcon=activeBtn:CreateTexture(nil,"ARTWORK");
        aIcon:SetWidth(BAR_BTN_SIZE); aIcon:SetHeight(BAR_BTN_SIZE);
        aIcon:SetPoint("CENTER",activeBtn,"CENTER",0,0);
        local aHi=activeBtn:CreateTexture(nil,"HIGHLIGHT");
        aHi:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); aHi:SetAllPoints(activeBtn);
        aHi:SetBlendMode("ADD"); activeBtn:SetHighlightTexture(aHi);
        local aTimer=activeBtn:CreateFontString(nil,"OVERLAY");
        aTimer:SetFont("Fonts\\FRIZQT__.TTF",10,"THICKOUTLINE");
        aTimer:SetPoint("CENTER",activeBtn,"CENTER",0,0); aTimer:SetTextColor(1,1,1,1); aTimer:Hide();
        local aTimerLayers={};
        activeBtn:SetScript("OnClick",function()
            local ts=timerState[elementKey]; if ts and ts.totemName then CastSpellByName(ts.totemName); BP_TotemBar_StartTimer(elementKey,ts.totemName) end
        end);
        activeBtn:SetScript("OnEnter",function() local ts=timerState[elementKey]; if ts and ts.totemName then ShowSpellTip(activeBtn,ts.totemName) end end);
        activeBtn:SetScript("OnLeave",function() tt:Hide() end);
        activeBtn:Hide();

        barButtons[elementKey]={btn=mainBtn,icon=barIcon,timer=timerText,timerLayers=timerLayers,
            activeBtn=activeBtn,activeIcon=aIcon,activeTimer=aTimer,activeTimerLayers=aTimerLayers};

        -- FLYOUT
        local maxRows=table.getn(elDef.totems);
        local flyH=FLY_PADDING*2+maxRows*FLY_ROW_H;
        local fly=CreateFrame("Frame",nil,UIParent);
        fly:SetWidth(FLY_WIDTH); fly:SetHeight(flyH);
        fly:SetFrameStrata("HIGH"); fly:EnableMouse(true); fly:Hide();
        flyoutFrames[elementKey]=fly;

        local flyBg=fly:CreateTexture(nil,"BACKGROUND"); flyBg:SetTexture(0,0,0,0); flyBg:SetAllPoints(fly);
        fly:SetScript("OnLeave",function() ScheduleClose(elementKey) end);
        fly:SetScript("OnEnter",function() CancelClose(elementKey) end);

        local flyBtns={};
        for slotIdx=1,table.getn(elDef.totems) do
            local thisTotem=elDef.totems[slotIdx]; local thisSlot=slotIdx;
            local fb=CreateFrame("CheckButton",nil,fly);
            fb:SetWidth(FLY_BTN_SIZE); fb:SetHeight(FLY_BTN_SIZE);
            fb:SetPoint("TOP",fly,"TOP",0,-(FLY_PADDING+(thisSlot-1)*FLY_ROW_H));
            local fbSlot=fb:CreateTexture(nil,"BACKGROUND");
            fbSlot:SetTexture("Interface\\Buttons\\UI-EmptySlot"); fbSlot:SetAllPoints(fb);
            local fbIcon=fb:CreateTexture(nil,"ARTWORK");
            fbIcon:SetWidth(FLY_BTN_SIZE); fbIcon:SetHeight(FLY_BTN_SIZE);
            fbIcon:SetPoint("CENTER",fb,"CENTER",0,0);
            fb.icon=fbIcon; fb.totemPath=TOTEM_ICONS[thisTotem] or FALLBACK_ICON;
            local fbHi=fb:CreateTexture(nil,"HIGHLIGHT");
            fbHi:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); fbHi:SetAllPoints(fb);
            fbHi:SetBlendMode("ADD"); fb:SetHighlightTexture(fbHi);
            local fbCk=fb:CreateTexture(nil,"OVERLAY");
            fbCk:SetTexture("Interface\\Buttons\\CheckButtonHilight"); fbCk:SetAllPoints(fb);
            fbCk:SetBlendMode("ADD"); fb:SetCheckedTexture(fbCk);
            fb.totemName=thisTotem; fb.elementKey=elementKey;
            fb:SetScript("OnClick",function()
                ApplyTotemSelection(elementKey,thisTotem);
                barButtons[elementKey].icon:SetTexture(TOTEM_ICONS[thisTotem] or FALLBACK_ICON);
                barButtons[elementKey].icon:SetVertexColor(1, 1, 1, 1);
                for i=1,table.getn(flyBtns) do
                    flyBtns[i]:SetChecked(flyBtns[i].totemName==thisTotem and 1 or nil)
                end
                if elementKey=="Fire" and BP_TotemBar_RefreshFireSlider then BP_TotemBar_RefreshFireSlider() end
                CloseFlyout(elementKey); tt:Hide();
            end);
            fb:SetScript("OnEnter",function() CancelClose(elementKey); ShowSpellTip(fb,thisTotem) end);
            fb:SetScript("OnLeave",function() tt:Hide(); ScheduleClose(elementKey) end);
            flyBtns[thisSlot]=fb;
        end

        -- "None" button at the bottom of the flyout
        local noneSlot = table.getn(elDef.totems) + 1;
        local noneBtn = CreateFrame("CheckButton", nil, fly);
        noneBtn:SetWidth(FLY_BTN_SIZE); noneBtn:SetHeight(FLY_BTN_SIZE);
        noneBtn:SetPoint("TOP", fly, "TOP", 0, -(FLY_PADDING + (noneSlot-1) * FLY_ROW_H));
        local noneBg = noneBtn:CreateTexture(nil, "BACKGROUND");
        noneBg:SetTexture("Interface\\Buttons\\UI-EmptySlot"); noneBg:SetAllPoints(noneBtn);
        local noneIcon = noneBtn:CreateTexture(nil, "ARTWORK");
        noneIcon:SetWidth(FLY_BTN_SIZE - 8); noneIcon:SetHeight(FLY_BTN_SIZE - 8);
        noneIcon:SetPoint("CENTER", noneBtn, "CENTER", 0, 0);
        noneIcon:SetTexture(NONE_ICON);
        noneIcon:SetVertexColor(0.5, 0.5, 0.5, 1);
        local noneHi = noneBtn:CreateTexture(nil, "HIGHLIGHT");
        noneHi:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); noneHi:SetAllPoints(noneBtn);
        noneHi:SetBlendMode("ADD"); noneBtn:SetHighlightTexture(noneHi);
        local noneCk = noneBtn:CreateTexture(nil, "OVERLAY");
        noneCk:SetTexture("Interface\\Buttons\\CheckButtonHilight"); noneCk:SetAllPoints(noneBtn);
        noneCk:SetBlendMode("ADD"); noneBtn:SetCheckedTexture(noneCk);
        local noneLabel = noneBtn:CreateFontString(nil, "OVERLAY");
        noneLabel:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE");
        noneLabel:SetPoint("CENTER", noneBtn, "CENTER", 0, 0);
        noneLabel:SetTextColor(0.55, 0.55, 0.55, 1);
        noneLabel:SetText("none");
        noneBtn.totemName = nil; noneBtn.elementKey = elementKey;
        noneBtn:SetScript("OnClick", function()
            ApplyTotemSelection(elementKey, nil);
            barButtons[elementKey].icon:SetTexture(NONE_ICON);
            barButtons[elementKey].icon:SetVertexColor(0.35, 0.35, 0.35, 1);
            for i=1,table.getn(flyBtns) do flyBtns[i]:SetChecked(nil) end
            noneBtn:SetChecked(1);
            if elementKey=="Fire" and BP_TotemBar_RefreshFireSlider then BP_TotemBar_RefreshFireSlider() end
            CloseFlyout(elementKey); tt:Hide();
        end);
        noneBtn:SetScript("OnEnter", function()
            CancelClose(elementKey);
            tt:ClearLines(); tt:SetOwner(noneBtn, "ANCHOR_RIGHT");
            tt:AddLine("None", 1, 1, 1);
            tt:AddLine("Skip this element — no totem will be dropped.", 0.8, 0.8, 0.8);
            tt:Show();
        end);
        noneBtn:SetScript("OnLeave", function() tt:Hide(); ScheduleClose(elementKey) end);
        -- resize flyout to fit the extra row
        fly:SetHeight(FLY_PADDING * 2 + noneSlot * FLY_ROW_H);

        fly:SetScript("OnShow",function()
            local cur=GetCurrentTotem(dbKey);
            for i=1,table.getn(flyBtns) do
                local b=flyBtns[i]; b.icon:SetTexture(b.totemPath);
                b:SetChecked(cur and b.totemName==cur and 1 or nil)
            end
            noneBtn:SetChecked(not cur and 1 or nil);
        end);

        -- HOVER open
        mainBtn:SetScript("OnEnter",function()
            barHovered = true;
            CancelClose(elementKey);
            for i=1,table.getn(ELEMENTS) do if ELEMENTS[i].key~=elementKey then CloseFlyout(ELEMENTS[i].key) end end
            fly:ClearAllPoints(); fly:SetPoint("BOTTOM",mainBtn,"TOP",0,4); fly:Show();
        end);
        mainBtn:SetScript("OnLeave",function() barHovered = false; ScheduleClose(elementKey) end);

        -- CLICK handler
        local TOGGLE_PAIRS={
            ["Fire"] ={ "Searing Totem",          "Magma Totem"          },
            ["Water"]={ "Mana Spring Totem",       "Healing Stream Totem" },
            ["Earth"]={ "Strength of Earth Totem", "Stoneskin Totem"      },
            ["Air"]  ={ "Windfury Totem",           "Grace of Air Totem"  },
        };
        mainBtn:RegisterForClicks("LeftButtonUp","RightButtonUp");
        mainBtn:SetScript("OnClick",function()
            if arg1=="RightButton" then
                local pair=TOGGLE_PAIRS[elementKey]; local cur=GetCurrentTotem(dbKey);
                if pair and (cur==pair[1] or cur==pair[2]) then
                    local next=(cur==pair[1]) and pair[2] or pair[1];
                    ApplyTotemSelection(elementKey,next);
                    barButtons[elementKey].icon:SetTexture(TOTEM_ICONS[next] or FALLBACK_ICON);
                    barButtons[elementKey].icon:SetVertexColor(1, 1, 1, 1);
                    if elementKey=="Fire" and BP_TotemBar_RefreshFireSlider then BP_TotemBar_RefreshFireSlider() end
                else
                    if fly:IsVisible() then CloseFlyout(elementKey)
                    else
                        CancelClose(elementKey);
                        for i=1,table.getn(ELEMENTS) do if ELEMENTS[i].key~=elementKey then CloseFlyout(ELEMENTS[i].key) end end
                        fly:ClearAllPoints(); fly:SetPoint("BOTTOM",mainBtn,"TOP",0,4); fly:Show();
                    end
                end
            else
                local cur=GetCurrentTotem(dbKey);
                if cur then CastSpellByName(cur); BP_TotemBar_StartTimer(elementKey,cur)
                else DEFAULT_CHAT_FRAME:AddMessage("Backpacker: No "..elementKey.." totem selected.") end
            end
        end);
    end

    -- SLASH
    SLASH_BPMENU1="/bpmenu";
    SlashCmdList["BPMENU"]=function()
        if bar:IsVisible() then CloseAllFlyouts(); bar:Hide() else bar:Show() end
        PlaySound("igMainMenuOption");
    end;

    function BP_TotemBar_StartTimer(elementKey, totemName)
        local dur=TOTEM_DURATIONS[totemName];
        timerState[elementKey]={ startTime=GetTime(), duration=(dur and dur>0) and dur or 0, totemName=totemName };
    end

    function BP_TotemBar_StopAllTimers()
        for i=1,table.getn(ELEMENTS) do
            local key=ELEMENTS[i].key; timerState[key]=nil;
            local bb=barButtons[key];
            if bb then
                if bb.activeBtn then bb.activeBtn:Hide() end
                bb.timer:Hide();
                for li=1,table.getn(bb.timerLayers) do bb.timerLayers[li]:Hide() end
            end
        end
        ResizeBar();
    end

    function BP_TotemBar_UpdateMode()
        local wb=barButtons["Water"]; if not wb then return end
        if settings.STRATHOLME_MODE then
            wb.icon:SetTexture(TOTEM_ICONS["Disease Cleansing Totem"] or FALLBACK_ICON);
            wb.icon:SetVertexColor(1, 1, 1, 1);
        elseif settings.ZG_MODE then
            wb.icon:SetTexture(TOTEM_ICONS["Poison Cleansing Totem"] or FALLBACK_ICON);
            wb.icon:SetVertexColor(1, 1, 1, 1);
        else
            local cur=GetCurrentTotem("WATER_TOTEM");
            wb.icon:SetTexture(cur and TOTEM_ICONS[cur] or NONE_ICON);
            wb.icon:SetVertexColor(cur and 1 or 0.35, cur and 1 or 0.35, cur and 1 or 0.35, 1);
        end
    end

    function BP_TotemBar_RefreshIcons()
        for i=1,table.getn(ELEMENTS) do
            local el=ELEMENTS[i]; local cur=GetCurrentTotem(el.dbKey);
            barButtons[el.key].icon:SetTexture(cur and TOTEM_ICONS[cur] or NONE_ICON);
            barButtons[el.key].icon:SetVertexColor(cur and 1 or 0.35, cur and 1 or 0.35, cur and 1 or 0.35, 1);
        end
        BP_TotemBar_UpdateMode();
    end

    BP_TotemBar_RefreshIcons();

    -- --------------------------------------------------------
    -- TOGGLE BUTTONS
    -- --------------------------------------------------------
    local toggleDefs={
        { key="ZG", label="Z", tip="Zul'Gurub mode",  setting="ZG_MODE",
          onToggle=function()
              if settings.STRATHOLME_MODE then settings.STRATHOLME_MODE=false; BackpackerDB.STRATHOLME_MODE=false end
              ToggleSetting("ZG_MODE","Zul'Gurub mode"); ResetWaterTotemState();
              if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode() end
          end },
        { key="ST", label="S", tip="Stratholme mode", setting="STRATHOLME_MODE",
          onToggle=function()
              if settings.ZG_MODE then settings.ZG_MODE=false; BackpackerDB.ZG_MODE=false end
              ToggleSetting("STRATHOLME_MODE","Stratholme mode"); ResetWaterTotemState();
              if BP_TotemBar_UpdateMode then BP_TotemBar_UpdateMode() end
          end },
        { key="CH", label="C", tip="Chain Heal",      setting="CHAIN_HEAL_ENABLED",
          onToggle=function() ToggleSetting("CHAIN_HEAL_ENABLED","Chain Heal") end },
        { key="FL", label="F", tip="Follow mode",     setting="FOLLOW_ENABLED",
          onToggle=function() ToggleSetting("FOLLOW_ENABLED","Follow functionality") end },
    };

    local toggleButtons={};
    local function RefreshToggleColors()
        for i=1,table.getn(toggleDefs) do
            local def=toggleDefs[i]; local btn=toggleButtons[def.key];
            if btn then
                if settings[def.setting] then btn.bg:SetTexture(0.15,0.65,0.15,0.85)
                else                          btn.bg:SetTexture(0.12,0.12,0.12,0.75) end
            end
        end
    end
    function BP_TotemBar_RefreshToggles() RefreshToggleColors() end

    for i=1,table.getn(toggleDefs) do
        local def=toggleDefs[i];
        local btn=CreateFrame("Button",nil,bar);
        btn:SetWidth(TOGGLE_BTN_SIZE); btn:SetHeight(TOGGLE_BTN_SIZE);
        btn:SetPoint("BOTTOMLEFT",bar,"TOPLEFT",(i-1)*TOGGLE_BTN_SIZE,6);
        local bg=btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(btn); bg:SetTexture(0.12,0.12,0.12,0.75); btn.bg=bg;
        local lbl=btn:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\FRIZQT__.TTF",8,"OUTLINE");
        lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE");
        lbl:SetTextColor(0.75,0.75,0.75,1); lbl:SetText(def.label);
        local hi=btn:CreateTexture(nil,"HIGHLIGHT"); hi:SetTexture(1,1,1,0.15); hi:SetAllPoints(btn); btn:SetHighlightTexture(hi);
        btn:SetScript("OnClick",function() def.onToggle(); RefreshToggleColors() end);
        btn:SetScript("OnEnter",function() barHovered = true; tt:ClearLines(); tt:SetOwner(btn,"ANCHOR_RIGHT"); tt:AddLine(def.tip,1,1,1); tt:Show() end);
        btn:SetScript("OnLeave",function() barHovered = false; tt:Hide() end);
        btn:SetAlpha(0);
        fadeControls[table.getn(fadeControls)+1] = btn;
        toggleButtons[def.key]=btn;
    end
    RefreshToggleColors();

    -- --------------------------------------------------------
    -- GLOBAL RANGE SLIDER
    -- --------------------------------------------------------
    local toggleRowEnd = table.getn(toggleDefs) * TOGGLE_BTN_SIZE;
    local SLIDER_W     = barW - toggleRowEnd;
    local RANGE_STOPS  = { 10, 15, 20, 25, 30, 35, 40 };

    local rangeSlider=CreateFrame("Slider","BP_RangeSlider",bar);
    rangeSlider:SetOrientation("HORIZONTAL");
    rangeSlider:SetWidth(SLIDER_W); rangeSlider:SetHeight(SLIDER_H);
    rangeSlider:SetPoint("BOTTOMLEFT",bar,"TOPLEFT",toggleRowEnd,6);
    rangeSlider:SetMinMaxValues(10,40); rangeSlider:SetValueStep(1); rangeSlider:SetValue(TOTEM_RANGE);
    rangeSlider:SetBackdrop({ bgFile="Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile="Interface\\Buttons\\UI-SliderBar-Border", tile=true, tileSize=8, edgeSize=8,
        insets={left=3,right=3,top=6,bottom=6} });
    local rThumb=rangeSlider:CreateTexture(nil,"OVERLAY");
    rThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal");
    rThumb:SetWidth(14); rThumb:SetHeight(14); rangeSlider:SetThumbTexture(rThumb);
    local rangeLabel=rangeSlider:CreateFontString(nil,"OVERLAY");
    rangeLabel:SetFont("Fonts\\FRIZQT__.TTF",8,"OUTLINE");
    rangeLabel:SetPoint("CENTER",rangeSlider,"CENTER",0,0);
    rangeLabel:SetTextColor(0.65,0.65,0.65,1); rangeLabel:SetText(TOTEM_RANGE.."y");
    rangeSlider:SetScript("OnValueChanged",function()
        local raw=rangeSlider:GetValue();
        local best,bestDist=RANGE_STOPS[1],math.abs(raw-RANGE_STOPS[1]);
        for i=2,table.getn(RANGE_STOPS) do
            local d=math.abs(raw-RANGE_STOPS[i]); if d<bestDist then best=RANGE_STOPS[i]; bestDist=d end
        end
        TOTEM_RANGE=best; rangeLabel:SetText(best.."y");
    end);
    rangeSlider:SetScript("OnEnter",function()
        barHovered = true;
        tt:ClearLines(); tt:SetOwner(rangeSlider,"ANCHOR_RIGHT");
        tt:AddLine("Global totem range threshold",1,1,1);
        tt:AddLine("Totems beyond this distance will be re-dropped.",0.8,0.8,0.8); tt:Show();
    end);
    rangeSlider:SetScript("OnLeave",function() barHovered = false; tt:Hide() end);
    rangeSlider:SetAlpha(0);
    fadeControls[table.getn(fadeControls)+1] = rangeSlider;

    -- --------------------------------------------------------
    -- FIRE TOTEM RANGE SLIDER (Searing / Magma only)
    -- --------------------------------------------------------
    local FIRE_RANGE_STOPS = { 3, 5, 8, 10, 12, 15, 18, 20 };
    local fireRangeIniting = false;

    local fireRangeSlider=CreateFrame("Slider","BP_FireRangeSlider",bar);
    fireRangeSlider:SetOrientation("HORIZONTAL");
    fireRangeSlider:SetWidth(SLIDER_W); fireRangeSlider:SetHeight(SLIDER_H);
    fireRangeSlider:SetPoint("BOTTOMLEFT",rangeSlider,"TOPLEFT",0,-6);
    fireRangeSlider:SetMinMaxValues(3,20); fireRangeSlider:SetValueStep(1);
    fireRangeSlider:SetBackdrop({ bgFile="Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile="Interface\\Buttons\\UI-SliderBar-Border", tile=true, tileSize=8, edgeSize=8,
        insets={left=3,right=3,top=6,bottom=6} });
    local fThumb=fireRangeSlider:CreateTexture(nil,"OVERLAY");
    fThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal");
    fThumb:SetWidth(14); fThumb:SetHeight(14); fireRangeSlider:SetThumbTexture(fThumb);
    local fireRangeLabel=fireRangeSlider:CreateFontString(nil,"OVERLAY");
    fireRangeLabel:SetFont("Fonts\\FRIZQT__.TTF",8,"OUTLINE");
    fireRangeLabel:SetPoint("CENTER",fireRangeSlider,"CENTER",0,0);
    fireRangeLabel:SetTextColor(1.0,0.55,0.15,1);

    local function RefreshFireRangeSlider()
        local cur=settings.FIRE_TOTEM;
        if cur=="Searing Totem" or cur=="Magma Totem" then
            local range=TOTEM_RANGE_OVERRIDE[cur] or (cur=="Searing Totem" and 20 or 8);
            fireRangeIniting=true;
            fireRangeSlider:SetValue(range-1); fireRangeSlider:SetValue(range);
            fireRangeIniting=false;
            fireRangeLabel:SetText((cur=="Searing Totem" and "Sear: " or "Magma: ")..range.."y");
            fireRangeSlider:Show();
        else
            fireRangeSlider:Hide();
        end
    end
    function BP_TotemBar_RefreshFireSlider() RefreshFireRangeSlider() end

    fireRangeSlider:SetScript("OnValueChanged",function()
        if fireRangeIniting then return end
        local raw=fireRangeSlider:GetValue();
        local best,bestDist=FIRE_RANGE_STOPS[1],math.abs(raw-FIRE_RANGE_STOPS[1]);
        for i=2,table.getn(FIRE_RANGE_STOPS) do
            local d=math.abs(raw-FIRE_RANGE_STOPS[i]); if d<bestDist then best=FIRE_RANGE_STOPS[i]; bestDist=d end
        end
        local cur=settings.FIRE_TOTEM;
        if cur=="Searing Totem" or cur=="Magma Totem" then
            TOTEM_RANGE_OVERRIDE[cur]=best;
            fireRangeLabel:SetText((cur=="Searing Totem" and "Sear: " or "Magma: ")..best.."y");
        end
    end);
    fireRangeSlider:SetScript("OnEnter",function()
        barHovered = true;
        tt:ClearLines(); tt:SetOwner(fireRangeSlider,"ANCHOR_RIGHT");
        tt:AddLine("Range override: "..(settings.FIRE_TOTEM or "fire totem"),1,1,1);
        tt:AddLine("Totem will be re-dropped beyond this distance.",0.8,0.8,0.8); tt:Show();
    end);
    fireRangeSlider:SetScript("OnLeave",function() barHovered = false; tt:Hide() end);
    fireRangeSlider:Hide();
    fireRangeSlider:SetAlpha(0);
    fadeControls[table.getn(fadeControls)+1] = fireRangeSlider;

    bar:SetScript("OnShow",function()
        rangeSlider:SetValue(TOTEM_RANGE-1); rangeSlider:SetValue(TOTEM_RANGE);
        RefreshFireRangeSlider();
    end);

    -- Deferred thumb nudge for when bar is visible at load
    local thumbFrame=CreateFrame("Frame"); local thumbElapsed=0;
    thumbFrame:SetScript("OnUpdate",function()
        thumbElapsed=thumbElapsed+arg1;
        if thumbElapsed>=0.05 then
            thumbFrame:SetScript("OnUpdate",nil);
            rangeSlider:SetValue(TOTEM_RANGE-1); rangeSlider:SetValue(TOTEM_RANGE);
            RefreshFireRangeSlider();
        end
    end);

    RefreshFireRangeSlider();
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: /bpmenu ready.");
end