-- Backpacker.lua
-- Main script for Backpacker addon

-- Load configuration file
local configLoaded, config = pcall(loadfile, "Interface\\AddOns\\Backpacker\\Backpacker_Config.lua");
if not configLoaded then
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Failed to load configuration file. Using default values.");
    LESSER_HEALING_WAVE_RANKS = {
        { rank = 1, manaCost = 99, healAmount = 600 },   -- Default Rank 1
        { rank = 2, manaCost = 137, healAmount = 697 },  -- Default Rank 2
        { rank = 3, manaCost = 175, healAmount = 799 },  -- Default Rank 3
        { rank = 4, manaCost = 223, healAmount = 934 },  -- Default Rank 4
        { rank = 5, manaCost = 289, healAmount = 1129 }, -- Default Rank 5
        { rank = 6, manaCost = 350, healAmount = 1300 }, -- Default Rank 6
    };
else
    LESSER_HEALING_WAVE_RANKS = config.LESSER_HEALING_WAVE_RANKS;
end

-- Configuration
local CHAIN_HEAL_SPELL = "Chain Heal";            -- Multi-target heal
local HEALTH_THRESHOLD = 90;                      -- Heal if health is below this percentage (e.g., 90%)
local DEBUG_MODE = false;                         -- Enable/disable debug messages (off by default)
local FOLLOW_ENABLED = true;                      -- Enable/disable follow functionality
local CHAIN_HEAL_ENABLED = true;                  -- Enable/disable Chain Heal functionality
local DOWNRANK_AGGRESSIVENESS = 0;                -- Downranking aggressiveness level (0 = default, 1 = 150%, 2 = 200%)

-- Function to count the number of entries in a table
local function TableLength(table)
    local count = 0;
    for _ in pairs(table) do
        count = count + 1;
    end
    return count;
end

-- Function to output messages to the chat frame (if DEBUG_MODE is true)
local function PrintMessage(message)
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. message);
    end
end

-- Function to sort units by health percentage (lowest first)
local function SortByHealth(a, b)
    local healthA = UnitHealth(a) / UnitHealthMax(a);
    local healthB = UnitHealth(b) / UnitHealthMax(b);
    return healthA < healthB;
end

-- Function to select the appropriate rank of Lesser Healing Wave
local function SelectHealingSpellRank(missingHealth)
    for i = 1, TableLength(LESSER_HEALING_WAVE_RANKS) do
        local rankInfo = LESSER_HEALING_WAVE_RANKS[i];
        local adjustedHealAmount = rankInfo.healAmount;

        -- Adjust healAmount based on downranking aggressiveness
        if DOWNRANK_AGGRESSIVENESS == 1 then
            adjustedHealAmount = rankInfo.healAmount * 1.5;  -- 150%
        elseif DOWNRANK_AGGRESSIVENESS == 2 then
            adjustedHealAmount = rankInfo.healAmount * 2.0;  -- 200%
        end

        if missingHealth <= adjustedHealAmount then
            return "Lesser Healing Wave(Rank " .. rankInfo.rank .. ")";
        end
    end
    -- Use max rank if missing health is greater than the largest heal amount
    return "Lesser Healing Wave(Rank " .. LESSER_HEALING_WAVE_RANKS[TableLength(LESSER_HEALING_WAVE_RANKS)].rank .. ")";
end

-- Function to drop totems based on missing buffs
local function DropTotems()
    if not buffed("Mana Spring", 'player') then
        CastSpellByName("Mana Spring Totem");
        PrintMessage("Casting Mana Spring Totem.");
    elseif not buffed("Water Shield", 'player') then
        CastSpellByName("Water Shield");
        PrintMessage("Casting Water Shield.");
    elseif not buffed("Strength of Earth", 'player') then
        CastSpellByName("Strength of Earth Totem");
        PrintMessage("Casting Strength of Earth Totem.");
    elseif not buffed("Windfury Totem", 'player') then
        CastSpellByName("Windfury Totem");
        PrintMessage("Casting Windfury Totem.");
    elseif not buffed("Flametongue Totem", 'player') then
        CastSpellByName("Flametongue Totem");
        PrintMessage("Casting Flametongue Totem.");
    else
        PrintMessage("All totems and buffs are active.");
    end
end

-- Function to check party members' health and heal if necessary
local function HealPartyMembers()
    local lowHealthMembers = {};  -- Table to store party members (including player) who need healing

    -- Check the player's health
    local playerHealth = UnitHealth("player");
    local playerMaxHealth = UnitHealthMax("player");
    local playerHealthPercent = (playerHealth / playerMaxHealth) * 100;

    if playerHealthPercent < HEALTH_THRESHOLD and not UnitIsDeadOrGhost("player") then
        table.insert(lowHealthMembers, "player");
    end

    -- Check the health of all party members
    for i = 1, GetNumPartyMembers() do
        local partyMember = "party" .. i;
        local health = UnitHealth(partyMember);
        local maxHealth = UnitHealthMax(partyMember);
        local healthPercent = (health / maxHealth) * 100;

        -- Add party members with low health to the table
        if healthPercent < HEALTH_THRESHOLD and UnitIsConnected(partyMember) and not UnitIsDeadOrGhost(partyMember) then
            table.insert(lowHealthMembers, partyMember);
        end
    end

    -- Sort the lowHealthMembers table by health percentage (lowest first)
    table.sort(lowHealthMembers, SortByHealth);

    -- Get the number of low-health members (including player)
    local numLowHealthMembers = TableLength(lowHealthMembers);

    -- Decide which spell to cast based on the number of low-health members
    if numLowHealthMembers >= 2 and CHAIN_HEAL_ENABLED then
        -- Cast Chain Heal if 2 or more party members (including player) need healing
        CastSpellByName(CHAIN_HEAL_SPELL);
        SpellTargetUnit(lowHealthMembers[1]);  -- Target the most injured member
        PrintMessage("Casting Chain Heal on " .. UnitName(lowHealthMembers[1]) .. " (lowest health).");
    elseif numLowHealthMembers == 1 then
        -- Cast Lesser Healing Wave if only 1 party member (including player) needs healing
        local target = lowHealthMembers[1];
        local missingHealth = UnitHealthMax(target) - UnitHealth(target);

        -- Select the appropriate rank of Lesser Healing Wave
        local spellToCast = SelectHealingSpellRank(missingHealth);

        CastSpellByName(spellToCast);
        SpellTargetUnit(target);  -- Target the most injured member
        PrintMessage("Casting " .. spellToCast .. " on " .. UnitName(target) .. " (lowest health).");
    else
        -- No party members (including player) need healing
        PrintMessage("No party members require healing.");

        -- Follow the first available party member (if FOLLOW_ENABLED is true)
        if FOLLOW_ENABLED and GetNumPartyMembers() > 0 then
            local followTarget = "party1";  -- Follow the first party member
            FollowUnit(followTarget);
            PrintMessage("Following " .. UnitName(followTarget) .. ".");
        elseif not FOLLOW_ENABLED then
            PrintMessage("Follow functionality is disabled.");
        else
            PrintMessage("No party members to follow.");
        end
    end
end

-- Function to toggle debug mode
local function ToggleDebugMode()
    DEBUG_MODE = not DEBUG_MODE;  -- Toggle the debug mode
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Debug mode enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Debug mode disabled.");
    end
end

-- Function to toggle follow functionality
local function ToggleFollow()
    FOLLOW_ENABLED = not FOLLOW_ENABLED;  -- Toggle the follow functionality
    if FOLLOW_ENABLED then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow functionality enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow functionality disabled.");
    end
end

-- Function to toggle Chain Heal functionality
local function ToggleChainHeal()
    CHAIN_HEAL_ENABLED = not CHAIN_HEAL_ENABLED;  -- Toggle the Chain Heal functionality
    if CHAIN_HEAL_ENABLED then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Chain Heal functionality enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Chain Heal functionality disabled.");
    end
end

-- Function to set downranking aggressiveness
local function SetDownrankAggressiveness(level)
    level = tonumber(level);
    if level == 0 or level == 1 or level == 2 then
        DOWNRANK_AGGRESSIVENESS = level;
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Downranking aggressiveness set to " .. level .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid downranking aggressiveness level. Use 0, 1, or 2.");
    end
end

-- Function to print usage information
local function PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Usage:");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal - Heal party members (including yourself).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpbuff - Drop totems based on missing buffs.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdebug - Toggle debug messages on or off.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfollow - Toggle follow functionality on or off.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpchainheal - Toggle Chain Heal functionality on or off.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdr <0, 1, 2> - Set downranking aggressiveness (0 = default, 1 = 150%, 2 = 200%).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bp or /backpacker - Show this usage information.");
end

-- Register the slash commands
SLASH_BPHEAL1 = "/bpheal";  -- Define the slash command for healing
SlashCmdList["BPHEAL"] = HealPartyMembers;  -- Link the command to the function

SLASH_BPBUFF1 = "/bpbuff";  -- Define the slash command for dropping totems
SlashCmdList["BPBUFF"] = DropTotems;  -- Link the command to the function

SLASH_BPDEBUG1 = "/bpdebug";  -- Define the slash command for toggling debug mode
SlashCmdList["BPDEBUG"] = ToggleDebugMode;  -- Link the command to the function

SLASH_BPFOLLOW1 = "/bpfollow";  -- Define the slash command for toggling follow functionality
SlashCmdList["BPFOLLOW"] = ToggleFollow;  -- Link the command to the function

SLASH_BPCHAINHEAL1 = "/bpchainheal";  -- Define the slash command for toggling Chain Heal functionality
SlashCmdList["BPCHAINHEAL"] = ToggleChainHeal;  -- Link the command to the function

SLASH_BPDR1 = "/bpdr";  -- Define the slash command for setting downranking aggressiveness
SlashCmdList["BPDR"] = SetDownrankAggressiveness;  -- Link the command to the function

SLASH_BP1 = "/bp";  -- Define the slash command for usage info
SLASH_BP2 = "/backpacker";  -- Define the slash command for usage info
SlashCmdList["BP"] = PrintUsage;  -- Link the command to the function

-- Print a message when the addon is loaded
PrintUsage();