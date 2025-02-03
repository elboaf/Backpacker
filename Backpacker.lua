-- Backpacker.lua
-- Main script for Backpacker addon

-- SavedVariables table
BackpackerDB = BackpackerDB or {
    DEBUG_MODE = false,
    DOWNRANK_AGGRESSIVENESS = 2,
    FOLLOW_ENABLED = true,
    CHAIN_HEAL_ENABLED = true,
    CHAIN_HEAL_SPELL = "Chain Heal(Rank 1)",
    HEALTH_THRESHOLD = 90,
    STRATHOLME_MODE = false,
    ZG_MODE = false,
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

-- Event handler
local function OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Backpacker" then
        for k, v in pairs(BackpackerDB) do
            settings[k] = v;
        end
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

local function SelectHealingSpellRank(missingHealth)
    for _, rankInfo in ipairs(LESSER_HEALING_WAVE_RANKS) do
        local adjustedHealAmount = rankInfo.healAmount * (1 + settings.DOWNRANK_AGGRESSIVENESS);
        if missingHealth <= adjustedHealAmount then
            return "Lesser Healing Wave(Rank " .. rankInfo.rank .. ")";
        end
    end
    return "Lesser Healing Wave(Rank " .. LESSER_HEALING_WAVE_RANKS[TableLength(LESSER_HEALING_WAVE_RANKS)].rank .. ")";
end

-- Totem logic
local function DropTotems()
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

    -- Drop totems based on missing buffs
    for _, totem in ipairs(totems) do
        if not totem.buff or not buffed(totem.buff, 'player') then
            CastSpellByName(totem.spell);
            PrintMessage("Casting " .. totem.spell .. ".");
            return;
        end
    end
    PrintMessage("All totems and buffs are active.");
end

-- Healing logic
local function HealPartyMembers()
    local lowHealthMembers = {};

    local function CheckHealth(unit)
        local healthPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100;
        if healthPercent < settings.HEALTH_THRESHOLD and not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
            table.insert(lowHealthMembers, unit);
        end
    end

    -- Check player health
    CheckHealth("player");

    -- Check party members
    for i = 1, GetNumPartyMembers() do
        CheckHealth("party" .. i);
    end

    -- Check raid members (if in a raid)
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            CheckHealth("raid" .. i);
        end
    end

    -- Sort low-health members by health percentage (lowest first)
    table.sort(lowHealthMembers, SortByHealth);

    local numLowHealthMembers = TableLength(lowHealthMembers);

    if numLowHealthMembers >= 2 and settings.CHAIN_HEAL_ENABLED then
        CastSpellByName(settings.CHAIN_HEAL_SPELL);
        SpellTargetUnit(lowHealthMembers[1]);
        PrintMessage("Casting " .. settings.CHAIN_HEAL_SPELL .. " on " .. UnitName(lowHealthMembers[1]) .. ".");
    elseif numLowHealthMembers == 1 then
        local spellToCast = SelectHealingSpellRank(UnitHealthMax(lowHealthMembers[1]) - UnitHealth(lowHealthMembers[1]));
        CastSpellByName(spellToCast);
        SpellTargetUnit(lowHealthMembers[1]);
        PrintMessage("Casting " .. spellToCast .. " on " .. UnitName(lowHealthMembers[1]) .. ".");
    else
        PrintMessage("No party or raid members require healing.");
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
        settings.CHAIN_HEAL_SPELL = "Chain Heal(Rank " .. (3 - level) .. ")";
        BackpackerDB.CHAIN_HEAL_SPELL = settings.CHAIN_HEAL_SPELL;
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
SLASH_BP1 = "/bp"; SLASH_BP2 = "/backpacker"; SlashCmdList["BP"] = PrintUsage;

-- Initialize
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", OnEvent);

PrintUsage();