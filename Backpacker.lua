--[[
================================================================================
BACKPACKER ADDON - SHAMAN AUTOMATION SUITE
================================================================================

VERSION COMPATIBILITY:
- World of Warcraft: Vanilla 1.12.1
- Lua Version: 5.0
- API: Classic WoW 1.12 API

CORE FUNCTIONALITY:
1. SMART HEALING SYSTEM:
   - Heals party/raid members below health threshold
   - Uses downranking for Lesser Healing Wave based on missing health
   - Automatically detects available spell ranks (won't try to cast unlearned ranks)
   - Chain Heal support when multiple members need healing
   - Hybrid mode: Switches to DPS when healing not needed

2. ADVANCED TOTEM MANAGEMENT:
   - Configurable delay between totem casts (TOTEM_CAST_DELAY - default 0.25s)
   - Continuous maintenance of all totems (auto-recast if destroyed/expired/out-of-range)
   - Fast totem dropping with local verification flags
   - Independent server buff verification with buffer periods
   - Parallel totem verification (no sequential dependencies)
   - Smart Totemic Recall with dual cooldown system
   - Separate Water Shield handling (self-buff, not affected by totem recall)
   - ZG/Stratholme combat mode: Spammable cleansing totems for mass dispels

TOTEM SYSTEM BEHAVIOR (CRITICAL DESIGN):
- PHASE 1: CONTINUOUS MAINTENANCE
  * Constantly monitors all active totems via buff presence
  * Automatically detects expired/destroyed/out-of-range totems
  * Resets state for any missing totems to trigger recasting

- PHASE 2: FAST DROPPING WITH DELAY
  * Spam /bpbuff to drop all totems (one per call)
  * Configurable delay between casts (default 0.25s optimal)
  * Each totem gets local verification flag and independent timestamp
  * No waiting for server responses during initial dropping

- PHASE 3: PARALLEL VERIFICATION  
  * Each totem has independent buffer period (TOTEM_VERIFICATION_TIME)
  * All totems verified in parallel, not sequentially
  * After buffer period, local flags sync with server buff status
  * Missing buffs reset local flags for fast re-dropping

- PHASE 4: TOTEMIC RECALL
  * Only available when all totems server-verified
  * Activation cooldown prevents premature recall (TOTEM_RECALL_ACTIVATION_COOLDOWN)
  * Cooldown after recall before new totems (TOTEM_RECALL_COOLDOWN)
  * Only works out of combat

ZG/STRATHOLME COMBAT MODE SPECIAL BEHAVIOR:
- Normal Operation: Drops and maintains all 4 totems (Strength, Windfury, Flametongue, Cleansing)
- Combat Behavior: When all 3 buff totems are active, spamming /bpbuff rapidly recasts ONLY the cleansing totem
- Mass Dispel: Allows instant poison/disease removal on demand during combat
- Buff Preservation: Strength, Windfury, and Flametongue totems remain active during combat

WATER SHIELD SPECIAL HANDLING:
- Treated as self-buff, not totem
- No local verification flags - only server buff checks
- Not affected by Totemic Recall
- Cast immediately when buff missing

COOLDOWN SYSTEM:
- Cast Delay: Configurable delay between totem casts (TOTEM_CAST_DELAY)
- Recall-to-Drop: 3 seconds after Totemic Recall before new totems
- Drop-to-Recall: 2 seconds after all totems active before recall available
- Each totem: Buffer period for server verification

KEY DESIGN DECISIONS:
1. Configurable cast delay (0.25s optimal) prevents server overload while feeling instant
2. Continuous monitoring maintains totem presence automatically
3. Independent buffer periods prevent "cascading" verification delays  
4. Parallel verification allows simultaneous invalidation of multiple totems
5. Fast recovery when totems expire/out-of-range via local flag resets
6. Server buff partial matching handles custom server buff names
7. ZG/Strath mode provides emergency mass dispels without losing buff totems

DEBUGGING:
- Use /bpdebug to toggle debug messages
- Debug shows totem states, verification timing, and decision logic

SLASH COMMANDS:
/bpheal - Execute healing logic
/bpbuff - Drop totems / Recall totems (context-aware)
/bpdebug - Toggle debug messages
/bpfollow - Toggle auto-follow
/bpchainheal - Toggle Chain Heal
/bpdr <0|1|2> - Set downranking aggressiveness
/bpstrath - Toggle Stratholme mode (Disease Cleansing)
/bpzg - Toggle ZG mode (Poison Cleansing) 
/bphybrid - Toggle Hybrid mode (80% threshold + DPS)
/bpdelay <seconds> - Set totem cast delay (default: 0.25)
/bp or /backpacker - Show usage

RECENT OPTIMIZATIONS:
- Configurable cast delay (0.25s optimal) for perfect server responsiveness
- Continuous totem maintenance (auto-recast on expiry/destruction)
- ZG/Strath combat mode for spammable mass dispels
- Independent totem buffer periods (no sequential verification delays)
- Parallel invalidation of multiple expired totems
- Fast dropping sequence restarts immediately after invalidation
- Water Shield separated from totem logic
- Server buff partial matching for custom server implementations

================================================================================
]]

-- Backpacker.lua
-- Main script for Backpacker addon


-- SavedVariables table
BackpackerDB = BackpackerDB or {
    DEBUG_MODE = false,
    DOWNRANK_AGGRESSIVENESS = 0,
    FOLLOW_ENABLED = true,
    CHAIN_HEAL_ENABLED = true,
    CHAIN_HEAL_SPELL = "Chain Heal(Rank 1)",
    HEALTH_THRESHOLD = 90,
    STRATHOLME_MODE = false,
    ZG_MODE = false,
    HYBRID_MODE = false,  -- New hybrid mode
};

-- Local variables to store settings
local settings = {
    DEBUG_MODE = BackpackerDB.DEBUG_MODE,
    DOWNRANK_AGGRESSIVENESS = BackpackerDB.DOWNRANK_AGGRESSIVENESS,
    FOLLOW_ENABLED = BackpackerDB.FOLLOW_ENABLED,
    CHAIN_HEAL_ENABLED = BackpackerDB.CHAIN_HEAL_ENABLED,
    CHAIN_HEAL_SPELL = BackpackerDB.CHAIN_HEAL_SPELL,
    HEALTH_THRESHOLD = BackpackerDB.HEALTH_THRESHOLD,
    STRATHOLME_MODE = BackpackerDB.STRATHOLME_MODE,
    ZG_MODE = BackpackerDB.ZG_MODE,
    HYBRID_MODE = BackpackerDB.HYBRID_MODE,  -- New hybrid mode
};

-- Spell configurations
local LESSER_HEALING_WAVE_RANKS = {
    { rank = 1, manaCost = 99, healAmount = 600 },
    { rank = 2, manaCost = 137, healAmount = 697 },
    { rank = 3, manaCost = 175, healAmount = 799 },
    { rank = 4, manaCost = 223, healAmount = 934 },
    { rank = 5, manaCost = 289, healAmount = 1129 },
    { rank = 6, manaCost = 350, healAmount = 1300 },
};

local CHAIN_HEAL_RANKS = {
    { rank = 1, manaCost = 500, healAmount = 800 },
    { rank = 2, manaCost = 400, healAmount = 700 },
    { rank = 3, manaCost = 300, healAmount = 600 },
};

-- Cooldown variables for totem logic
local lastTotemRecallTime = 0;
local lastAllTotemsActiveTime = 0;
local lastTotemCastTime = 0;  -- Track last totem cast time for delay
local pendingTotems = {};  -- Initialize as empty table
local TOTEM_RECALL_COOLDOWN = 3; -- seconds
local TOTEM_RECALL_ACTIVATION_COOLDOWN = 3; -- seconds
local TOTEM_VERIFICATION_TIME = 1; -- How long to wait before verifying totems
local TOTEM_CAST_DELAY = 0.25; -- Delay between totem casts (configurable)

-- Totem state tracking
-- Totem state tracking (excluding Water Shield)
-- Totem state tracking (excluding Water Shield)
local totemState = {
    { buff = "Strength of Earth", spell = "Strength of Earth Totem", locallyVerified = false, serverVerified = false, localVerifyTime = 0 },
    { buff = "Windfury Totem", spell = "Windfury Totem", locallyVerified = false, serverVerified = false, localVerifyTime = 0 },
    { buff = "Flametongue Totem", spell = "Flametongue Totem", locallyVerified = false, serverVerified = false, localVerifyTime = 0 },
    { buff = "Mana Spring", spell = "Mana Spring Totem", locallyVerified = false, serverVerified = false, localVerifyTime = 0 },
};



-- Event handler
local function OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Backpacker" then
        for k, v in pairs(BackpackerDB) do
            settings[k] = v;
        end
        InitializeChainHealSpell();  -- Initialize chain heal based on available spells
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Addon loaded. Settings initialized.");
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

-- Utility function to check if a spell is available (Lua 5.0 compatible)
local function IsSpellKnown(spellName)
    local name, rank;
    for i = 1, 200 do  -- Check a large range of spell slots
        name, rank = GetSpellName(i, BOOKTYPE_SPELL);
        if name then
            local fullSpellName = name;
            if rank and rank ~= "" then
                fullSpellName = name .. "(Rank " .. rank .. ")";
            end
            if fullSpellName == spellName then
                return true;
            end
        else
            break;
        end
    end
    return false;
end

-- Update the Chain Heal selection in the settings initialization
local function InitializeChainHealSpell()
    -- Check available chain heal ranks from highest to lowest
    for i = table.getn(CHAIN_HEAL_RANKS), 1, -1 do
        local rankInfo = CHAIN_HEAL_RANKS[i];
        local spellName = "Chain Heal(Rank " .. rankInfo.rank .. ")";
        
        if IsSpellKnown(spellName) then
            settings.CHAIN_HEAL_SPELL = spellName;
            BackpackerDB.CHAIN_HEAL_SPELL = spellName;
            return;
        end
    end
    
    -- Fallback
    settings.CHAIN_HEAL_SPELL = "Chain Heal(Rank 1)";
    BackpackerDB.CHAIN_HEAL_SPELL = "Chain Heal(Rank 1)";
end

-- Updated function to select healing spell rank based on available spells
local function SelectHealingSpellRank(missingHealth)
    -- Check available ranks from highest to lowest
    for i = table.getn(LESSER_HEALING_WAVE_RANKS), 1, -1 do
        local rankInfo = LESSER_HEALING_WAVE_RANKS[i];
        local spellName = "Lesser Healing Wave(Rank " .. rankInfo.rank .. ")";
        
        if IsSpellKnown(spellName) then
            local adjustedHealAmount = rankInfo.healAmount * (1 + settings.DOWNRANK_AGGRESSIVENESS);
            if missingHealth <= adjustedHealAmount then
                return spellName;
            end
        end
    end
    
    -- If no appropriate rank found, use the highest available rank
    for i = table.getn(LESSER_HEALING_WAVE_RANKS), 1, -1 do
        local rankInfo = LESSER_HEALING_WAVE_RANKS[i];
        local spellName = "Lesser Healing Wave(Rank " .. rankInfo.rank .. ")";
        
        if IsSpellKnown(spellName) then
            return spellName;
        end
    end
    
    -- Fallback - shouldn't happen if you have at least one rank
    return "Lesser Healing Wave(Rank 1)";
end

-- Totem logic
-- Updated Totem logic with pending system (no artificial cooldown)
-- Updated Totem logic with better timeout handling
-- Updated Totem logic with independent totem tracking
-- Updated Totem logic - much simpler
-- Updated Totem logic with separate Water Shield handling
-- Updated Totem logic with buffer period for server response
-- Updated Totem logic with independent buffer periods
-- Updated Totem logic with configurable cast delay
-- Totem logic with instant-cast cleansing totems for ZG/Strath modes
-- Totem logic with proper cleansing totem handling
-- Totem logic with proper maintenance of all totems
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

    -- Update cleansing totem based on mode
    local cleansingTotemSpell = nil;
    totemState[4].spell = "Mana Spring Totem";
    totemState[4].buff = "Mana Spring";
    if settings.STRATHOLME_MODE then
        cleansingTotemSpell = "Disease Cleansing Totem";
        totemState[4].spell = cleansingTotemSpell;
        totemState[4].buff = nil;
    elseif settings.ZG_MODE then
        cleansingTotemSpell = "Poison Cleansing Totem";
        totemState[4].spell = cleansingTotemSpell;
        totemState[4].buff = nil;
    end

    -- WATER SHIELD: Only check server buff status, no local verification
    if not buffed("Water Shield", 'player') then
        CastSpellByName("Water Shield");
        PrintMessage("Casting Water Shield.");
        lastTotemCastTime = currentTime;
        return; -- One spell per call
    end

    -- SPECIAL CASE: If in ZG/Strath mode and in combat, AND all other totems are active, allow recasting cleansing totem
    if cleansingTotemSpell and UnitAffectingCombat("player") then
        -- First, check if the first 3 totems (Strength, Windfury, Flametongue) are all server verified
        local otherTotemsActive = true;
        for i = 1, 3 do
            if not totemState[i].serverVerified then
                otherTotemsActive = false;
                break;
            end
        end
        
        -- If all other totems are active, allow recasting the cleansing totem as a mass dispel
        if otherTotemsActive then
            -- Reset the cleansing totem state to force a recast
            totemState[4].locallyVerified = false;
            totemState[4].serverVerified = false;
            totemState[4].localVerifyTime = 0;
            PrintMessage("COMBAT: Preparing " .. cleansingTotemSpell .. " for mass dispel.");
        end
    end

    -- PHASE 1: Check for expired/destroyed totems and reset their state
    for i, totem in ipairs(totemState) do
        if totem.locallyVerified and totem.serverVerified then
            -- This totem was previously verified, but check if it's still active
            if totem.buff then
                -- Totems with buffs - check if the buff is still present
                if not buffed(totem.buff, 'player') then
                    -- Buff is missing - totem was destroyed, expired, or outranged
                    PrintMessage(totem.buff .. " has expired/destroyed - resetting for recast.");
                    totemState[i].locallyVerified = false;
                    totemState[i].serverVerified = false;
                    totemState[i].localVerifyTime = 0;
                end
            else
                -- Cleansing totems - we can't verify via buff, so we rely on the combat recast logic
                -- They'll be automatically recast via the normal rotation if needed
            end
        end
    end

    -- PHASE 2: Drop all totems that need to be dropped (local verification only)
    for i, totem in ipairs(totemState) do
        if not totem.locallyVerified then
            -- This totem hasn't been dropped yet or needs recasting - drop it!
            CastSpellByName(totem.spell);
            PrintMessage("Casting " .. totem.spell .. ".");
            totemState[i].locallyVerified = true; -- Mark as locally verified
            totemState[i].localVerifyTime = currentTime; -- Record independent timestamp
            lastTotemCastTime = currentTime; -- Update cast time for delay
            return; -- One totem per call
        end
    end

    -- PHASE 3: Verify locally verified totems that aren't yet server verified
    local allServerVerified = true;
    local needsFastDropRestart = false;
    
    for i, totem in ipairs(totemState) do
        -- Only check totems that are locally verified but not server verified
        if totem.locallyVerified and not totem.serverVerified then
            if totem.buff then
                -- Totems with buffs - check if server confirms they're active
                if buffed(totem.buff, 'player') then
                    PrintMessage(totem.buff .. " confirmed active by server.");
                    totemState[i].serverVerified = true;
                else
                    -- Server says buff is not active - check if enough time has passed for THIS totem
                    local timeSinceLocalVerify = currentTime - totem.localVerifyTime;
                    if timeSinceLocalVerify > TOTEM_VERIFICATION_TIME then
                        -- Enough time has passed for this specific totem - reset for recast
                        PrintMessage(totem.buff .. " missing after " .. string.format("%.1f", timeSinceLocalVerify) .. "s - resetting for recast.");
                        totemState[i].locallyVerified = false;
                        totemState[i].serverVerified = false;
                        totemState[i].localVerifyTime = 0;
                        allServerVerified = false;
                        needsFastDropRestart = true;
                    else
                        -- Still within buffer period for this totem, keep waiting
                        PrintMessage(totem.buff .. " not yet confirmed (waiting " .. string.format("%.1f", TOTEM_VERIFICATION_TIME - timeSinceLocalVerify) .. "s)");
                        allServerVerified = false;
                    end
                end
            else
                -- Totems without buffs (cleansing) - we assume they're active once cast
                PrintMessage(totem.spell .. " assumed active.");
                totemState[i].serverVerified = true;
            end
        end
        
        -- Update allServerVerified flag based on current state
        if not totem.serverVerified then
            allServerVerified = false;
        end
    end
    
    -- If any totems had their local flags reset after their individual buffer periods, restart fast dropping
    if needsFastDropRestart then
        lastAllTotemsActiveTime = 0;
        return; -- Return early to allow fast dropping on next call
    end

    -- PHASE 4: All totems server verified - handle Totemic Recall
    if allServerVerified then
        PrintMessage("All totems and buffs are active.");
        
        -- Only set the timestamp if it hasn't been set yet
        if lastAllTotemsActiveTime == 0 then
            lastAllTotemsActiveTime = currentTime;
            DEFAULT_CHAT_FRAME:AddMessage("Totems: ACTIVE", 1, 0, 0);
            PrintMessage("Totems now active. Totemic Recall available in " .. TOTEM_RECALL_ACTIVATION_COOLDOWN .. " seconds.");
            return;
        end
        
        -- Check activation cooldown
        if currentTime - lastAllTotemsActiveTime < TOTEM_RECALL_ACTIVATION_COOLDOWN then
            local remainingActivationCooldown = TOTEM_RECALL_ACTIVATION_COOLDOWN - (currentTime - lastAllTotemsActiveTime);
            PrintMessage("Totemic Recall activation cooldown. Please wait " .. string.format("%.1f", remainingActivationCooldown) .. " seconds.");
            return;
        end
        
        -- Cast Totemic Recall if out of combat
        if not UnitAffectingCombat("player") then
            CastSpellByName("Totemic Recall");
            lastTotemRecallTime = GetTime();
            lastAllTotemsActiveTime = 0;
            lastTotemCastTime = currentTime; -- Update cast time for delay
            DEFAULT_CHAT_FRAME:AddMessage("Totems: RECALLED", 1, 1, 0);
            -- Reset all totem states (but NOT Water Shield)
            for i, totem in ipairs(totemState) do
                totemState[i].locallyVerified = false;
                totemState[i].serverVerified = false;
                totemState[i].localVerifyTime = 0;
            end
            PrintMessage("Casting Totemic Recall. Totems will be available in " .. TOTEM_RECALL_COOLDOWN .. " seconds.");
        else
            PrintMessage("Cannot cast Totemic Recall while in combat.");
        end
    else
        -- Reset the all totems active timestamp if not all totems are active
        lastAllTotemsActiveTime = 0;
    end
end

-- Healing logic
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
        -- Cast Chain Heal if enabled and at least 2 members are low on health
        CastSpellByName(settings.CHAIN_HEAL_SPELL);
        SpellTargetUnit(lowHealthMembers[1]);
        PrintMessage("Casting " .. settings.CHAIN_HEAL_SPELL .. " on " .. UnitName(lowHealthMembers[1]) .. ".");
    elseif numLowHealthMembers >= 1 then
        -- Cast Lesser Healing Wave if at least 1 member is low on health
        local spellToCast = SelectHealingSpellRank(UnitHealthMax(lowHealthMembers[1]) - UnitHealth(lowHealthMembers[1]));
        CastSpellByName(spellToCast);
        PrintMessage("Attempting to cast " .. spellToCast .. " on " .. UnitName(lowHealthMembers[1]) .. ".");
        SpellTargetUnit(lowHealthMembers[1]);
    else
        PrintMessage("No party or raid members require healing.");
        if settings.HYBRID_MODE then
            -- In hybrid mode, assist party member by casting Lightning Bolt at their target
            local partyMember = "party1";
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) and UnitIsConnected(partyMember) then
                local target = UnitName(partyMember .. "target");
                if target then
                    AssistUnit("party1");
                    CastSpellByName("Chain Lightning");
                    CastSpellByName("Fire Nova Totem");
                    CastSpellByName("Lightning Bolt");
                    PrintMessage("Casting Lightning Bolt at " .. target .. ".");
                else
                    PrintMessage("No valid target for Lightning Bolt.");
                    FollowUnit("party1");
                end
            else
                PrintMessage("No valid party member to assist.");
            end
        end
        if settings.FOLLOW_ENABLED and GetNumPartyMembers() > 0 then
            FollowUnit("party1");
            PrintMessage("Following " .. UnitName("party1") .. ".");
        end
    end
end

-- Slash command handlers
local function ToggleSetting(setting, message)
    settings[setting] = not settings[setting];
    BackpackerDB[setting] = settings[setting];
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. message .. (settings[setting] and " enabled." or " disabled."));
end

local function SetDownrankAggressiveness(level)
    level = tonumber(level);
    if level and (level == 0 or level == 1 or level == 2) then
        settings.DOWNRANK_AGGRESSIVENESS = level;
        BackpackerDB.DOWNRANK_AGGRESSIVENESS = level;
        
        -- Update chain heal spell based on available ranks and downranking level
        InitializeChainHealSpell();
        
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Downranking aggressiveness set to " .. level .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid downranking aggressiveness level. Use 0, 1, or 2.");
    end
end

local function ToggleStratholmeMode()
    if settings.ZG_MODE then
        settings.ZG_MODE = false;
        BackpackerDB.ZG_MODE = false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode disabled.");
    end
    ToggleSetting("STRATHOLME_MODE", "Stratholme mode");
end

local function ToggleZulGurubMode()
    if settings.STRATHOLME_MODE then
        settings.STRATHOLME_MODE = false;
        BackpackerDB.STRATHOLME_MODE = false;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode disabled.");
    end
    ToggleSetting("ZG_MODE", "Zul'Gurub mode");
end

-- New function to toggle hybrid mode
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

-- New function to set totem cast delay
local function SetTotemCastDelay(delay)
    delay = tonumber(delay);
    if delay and delay >= 0 then
        TOTEM_CAST_DELAY = delay;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Totem cast delay set to " .. delay .. " seconds.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid delay. Use a number >= 0 (e.g., 0.5 for 500ms).");
    end
end

local function PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Usage:");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal - Heal party and raid members.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpbuff - Drop totems.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdebug - Toggle debug messages.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfollow - Toggle follow functionality.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpchainheal - Toggle Chain Heal functionality.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdr <0, 1, 2> - Set downranking aggressiveness.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpstrath - Toggle Stratholme mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpzg - Toggle Zul'Gurub mode.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bphybrid - Toggle Hybrid mode.");  -- New hybrid mode command
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdelay <seconds> - Set totem cast delay (default: 0.5)");  -- New delay command
    DEFAULT_CHAT_FRAME:AddMessage("  /bp or /backpacker - Show usage information.");
end

-- Register slash commands
SLASH_BPHEAL1 = "/bpheal"; SlashCmdList["BPHEAL"] = HealPartyMembers;
SLASH_BPBUFF1 = "/bpbuff"; SlashCmdList["BPBUFF"] = DropTotems;
SLASH_BPDEBUG1 = "/bpdebug"; SlashCmdList["BPDEBUG"] = function() ToggleSetting("DEBUG_MODE", "Debug mode"); end;
SLASH_BPFOLLOW1 = "/bpfollow"; SlashCmdList["BPFOLLOW"] = function() ToggleSetting("FOLLOW_ENABLED", "Follow functionality"); end;
SLASH_BPCHAINHEAL1 = "/bpchainheal"; SlashCmdList["BPCHAINHEAL"] = function() ToggleSetting("CHAIN_HEAL_ENABLED", "Chain Heal functionality"); end;
SLASH_BPDR1 = "/bpdr"; SlashCmdList["BPDR"] = SetDownrankAggressiveness;
SLASH_BPSTRATH1 = "/bpstrath"; SlashCmdList["BPSTRATH"] = ToggleStratholmeMode;
SLASH_BPZG1 = "/bpzg"; SlashCmdList["BPZG"] = ToggleZulGurubMode;
SLASH_BPHYBRID1 = "/bphybrid"; SlashCmdList["BPHYBRID"] = ToggleHybridMode;  -- New hybrid mode command
SLASH_BPDELAY1 = "/bpdelay"; SlashCmdList["BPDELAY"] = SetTotemCastDelay;  -- New delay command
SLASH_BP1 = "/bp"; SLASH_BP2 = "/backpacker"; SlashCmdList["BP"] = PrintUsage;

-- Initialize
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", OnEvent);

PrintUsage();