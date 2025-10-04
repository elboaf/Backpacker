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
local TOTEM_RECALL_COOLDOWN = 3; -- seconds
local TOTEM_RECALL_ACTIVATION_COOLDOWN = 2; -- seconds

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
-- Totem logic
local function DropTotems()
    local currentTime = GetTime();
    
    -- Check if we're in the cooldown period after Totemic Recall
    if currentTime - lastTotemRecallTime < TOTEM_RECALL_COOLDOWN then
        local remainingCooldown = TOTEM_RECALL_COOLDOWN - (currentTime - lastTotemRecallTime);
        PrintMessage("Totems on cooldown after recall. Please wait " .. string.format("%.1f", remainingCooldown) .. " seconds.");
        return;
    end

    local totems = {
        { buff = "Water Shield", spell = "Water Shield" },
        { buff = "Strength of Earth", spell = "Strength of Earth Totem" },
        { buff = "Windfury Totem", spell = "Windfury Totem" },
        { buff = "Flametongue Totem", spell = "Flametongue Totem" },
    };

    -- Add Mana Spring Totem or cleansing totem based on mode
    if settings.STRATHOLME_MODE then
        table.insert(totems, { buff = nil, spell = "Disease Cleansing Totem" });
    elseif settings.ZG_MODE then
        table.insert(totems, { buff = nil, spell = "Poison Cleansing Totem" });
    else
        table.insert(totems, { buff = "Mana Spring", spell = "Mana Spring Totem" });
    end

    local allActive = true;
    
    -- Drop totems based on missing buffs
    for _, totem in ipairs(totems) do
        if not totem.buff or not buffed(totem.buff, 'player') then
            CastSpellByName(totem.spell);
            PrintMessage("Casting " .. totem.spell .. ".");
            allActive = false;
            -- Reset the activation timestamp when we drop a new totem
            lastAllTotemsActiveTime = 0;
            return;
        end
    end
    
    if allActive then
        PrintMessage("All totems and buffs are active.");
        
        -- Only set the timestamp if it hasn't been set yet (first time all are active)
        if lastAllTotemsActiveTime == 0 then
            lastAllTotemsActiveTime = currentTime;
            PrintMessage("Totems now active. Totemic Recall available in " .. TOTEM_RECALL_ACTIVATION_COOLDOWN .. " seconds.");
            return; -- Don't proceed to recall check on this call
        end
        
        -- Check activation cooldown - prevent premature Totemic Recall (applies always, even out of combat)
        if currentTime - lastAllTotemsActiveTime < TOTEM_RECALL_ACTIVATION_COOLDOWN then
            local remainingActivationCooldown = TOTEM_RECALL_ACTIVATION_COOLDOWN - (currentTime - lastAllTotemsActiveTime);
            PrintMessage("Totemic Recall activation cooldown. Please wait " .. string.format("%.1f", remainingActivationCooldown) .. " seconds.");
            return;
        end
        
        -- Check if we can cast Totemic Recall (out of combat)
        if not UnitAffectingCombat("player") then
            CastSpellByName("Totemic Recall");
            lastTotemRecallTime = GetTime(); -- Start cooldown timer
            lastAllTotemsActiveTime = 0; -- Reset activation timestamp
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
SLASH_BP1 = "/bp"; SLASH_BP2 = "/backpacker"; SlashCmdList["BP"] = PrintUsage;

-- Initialize
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", OnEvent);

PrintUsage();