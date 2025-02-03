-- Backpacker.lua
-- Main script for Backpacker addon

-- SavedVariables table
BackpackerDB = BackpackerDB or {
    DEBUG_MODE = false,                  -- Debug mode (off by default)
    DOWNRANK_AGGRESSIVENESS = 2,         -- Downranking aggressiveness (2 = 200% by default)
    FOLLOW_ENABLED = true,               -- Follow functionality (enabled by default)
    CHAIN_HEAL_ENABLED = true,           -- Chain Heal functionality (enabled by default)
    CHAIN_HEAL_SPELL = "Chain Heal(Rank 1)",  -- Default Chain Heal rank (updated to Rank 1 for downranking level 2)
    HEALTH_THRESHOLD = 90,               -- Heal if health is below this percentage (e.g., 90%)
    STRATHOLME_MODE = false,             -- Stratholme mode (disabled by default)
    ZG_MODE = false,                     -- Zul'Gurub mode (disabled by default)
};

-- Local variables to store settings
local Backpacker_DEBUG_MODE = BackpackerDB.DEBUG_MODE;
local Backpacker_DOWNRANK_AGGRESSIVENESS = BackpackerDB.DOWNRANK_AGGRESSIVENESS;
local Backpacker_FOLLOW_ENABLED = BackpackerDB.FOLLOW_ENABLED;
local Backpacker_CHAIN_HEAL_ENABLED = BackpackerDB.CHAIN_HEAL_ENABLED;
local Backpacker_CHAIN_HEAL_SPELL = BackpackerDB.CHAIN_HEAL_SPELL;
local Backpacker_HEALTH_THRESHOLD = BackpackerDB.HEALTH_THRESHOLD;
local Backpacker_STRATHOLME_MODE = BackpackerDB.STRATHOLME_MODE;
local Backpacker_ZG_MODE = BackpackerDB.ZG_MODE;

-- Load configuration file for LESSER_HEALING_WAVE_RANKS
local Backpacker_LESSER_HEALING_WAVE_RANKS = {
    { rank = 1, manaCost = 99, healAmount = 600 },   -- Default Rank 1
    { rank = 2, manaCost = 137, healAmount = 697 },  -- Default Rank 2
    { rank = 3, manaCost = 175, healAmount = 799 },  -- Default Rank 3
    { rank = 4, manaCost = 223, healAmount = 934 },  -- Default Rank 4
    { rank = 5, manaCost = 289, healAmount = 1129 }, -- Default Rank 5
    { rank = 6, manaCost = 350, healAmount = 1300 }, -- Default Rank 6
};

-- Define ranks for Chain Heal
local Backpacker_CHAIN_HEAL_RANKS = {
    { rank = 1, manaCost = 500, healAmount = 800 },  -- Rank 1 (example values, adjust as needed)
    { rank = 2, manaCost = 400, healAmount = 700 },  -- Rank 2
    { rank = 3, manaCost = 300, healAmount = 600 },  -- Rank 3
};

-- Function to handle ADDON_LOADED event
local function Backpacker_OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Backpacker" then
        -- Initialize settings from SavedVariables
        Backpacker_DEBUG_MODE = BackpackerDB.DEBUG_MODE;
        Backpacker_DOWNRANK_AGGRESSIVENESS = BackpackerDB.DOWNRANK_AGGRESSIVENESS;
        Backpacker_FOLLOW_ENABLED = BackpackerDB.FOLLOW_ENABLED;
        Backpacker_CHAIN_HEAL_ENABLED = BackpackerDB.CHAIN_HEAL_ENABLED;
        Backpacker_CHAIN_HEAL_SPELL = BackpackerDB.CHAIN_HEAL_SPELL;
        Backpacker_HEALTH_THRESHOLD = BackpackerDB.HEALTH_THRESHOLD;
        Backpacker_STRATHOLME_MODE = BackpackerDB.STRATHOLME_MODE;
        Backpacker_ZG_MODE = BackpackerDB.ZG_MODE;

        -- Print a message to confirm the addon has loaded
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Addon loaded. Settings initialized.");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: DEBUG_MODE = " .. tostring(Backpacker_DEBUG_MODE));
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: DOWNRANK_AGGRESSIVENESS = " .. Backpacker_DOWNRANK_AGGRESSIVENESS);
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: FOLLOW_ENABLED = " .. tostring(Backpacker_FOLLOW_ENABLED));
    end
end

-- Create a frame and register the ADDON_LOADED event
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:SetScript("OnEvent", Backpacker_OnEvent);

-- Function to count the number of entries in a table
local function Backpacker_TableLength(table)
    local count = 0;
    for _ in pairs(table) do
        count = count + 1;
    end
    return count;
end

-- Function to output messages to the chat frame (if DEBUG_MODE is true)
local function Backpacker_PrintMessage(message)
    if Backpacker_DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: " .. message);
    end
end

-- Function to sort units by health percentage (lowest first)
local function Backpacker_SortByHealth(a, b)
    local healthA = UnitHealth(a) / UnitHealthMax(a);
    local healthB = UnitHealth(b) / UnitHealthMax(b);
    return healthA < healthB;
end

-- Function to select the appropriate rank of Lesser Healing Wave
local function Backpacker_SelectHealingSpellRank(missingHealth)
    for i = 1, Backpacker_TableLength(Backpacker_LESSER_HEALING_WAVE_RANKS) do
        local rankInfo = Backpacker_LESSER_HEALING_WAVE_RANKS[i];
        local adjustedHealAmount = rankInfo.healAmount;

        -- Adjust healAmount based on downranking aggressiveness
        if Backpacker_DOWNRANK_AGGRESSIVENESS == 1 then
            adjustedHealAmount = rankInfo.healAmount * 1.5;  -- 150%
        elseif Backpacker_DOWNRANK_AGGRESSIVENESS == 2 then
            adjustedHealAmount = rankInfo.healAmount * 2.0;  -- 200%
        end

        if missingHealth <= adjustedHealAmount then
            return "Lesser Healing Wave(Rank " .. rankInfo.rank .. ")";
        end
    end
    -- Use max rank if missing health is greater than the largest heal amount
    return "Lesser Healing Wave(Rank " .. Backpacker_LESSER_HEALING_WAVE_RANKS[Backpacker_TableLength(Backpacker_LESSER_HEALING_WAVE_RANKS)].rank .. ")";
end

-- Function to drop totems based on missing buffs
local function Backpacker_DropTotems()
    if not Backpacker_STRATHOLME_MODE and not Backpacker_ZG_MODE then
        -- Normal totem dropping behavior
        if not buffed("Mana Spring", 'player') then
            CastSpellByName("Mana Spring Totem");
            Backpacker_PrintMessage("Casting Mana Spring Totem.");
        elseif not buffed("Water Shield", 'player') then
            CastSpellByName("Water Shield");
            Backpacker_PrintMessage("Casting Water Shield.");
        elseif not buffed("Strength of Earth", 'player') then
            CastSpellByName("Strength of Earth Totem");
            Backpacker_PrintMessage("Casting Strength of Earth Totem.");
        elseif not buffed("Windfury Totem", 'player') then
            CastSpellByName("Windfury Totem");
            Backpacker_PrintMessage("Casting Windfury Totem.");
        elseif not buffed("Flametongue Totem", 'player') then
            CastSpellByName("Flametongue Totem");
            Backpacker_PrintMessage("Casting Flametongue Totem.");
        else
            Backpacker_PrintMessage("All totems and buffs are active.");
        end
    elseif Backpacker_STRATHOLME_MODE then
        -- Stratholme mode: Disable Mana Spring Totem and drop Disease Cleansing Totem last
        if not buffed("Water Shield", 'player') then
            CastSpellByName("Water Shield");
            Backpacker_PrintMessage("Casting Water Shield.");
        elseif not buffed("Strength of Earth", 'player') then
            CastSpellByName("Strength of Earth Totem");
            Backpacker_PrintMessage("Casting Strength of Earth Totem.");
        elseif not buffed("Windfury Totem", 'player') then
            CastSpellByName("Windfury Totem");
            Backpacker_PrintMessage("Casting Windfury Totem.");
        elseif not buffed("Flametongue Totem", 'player') then
            CastSpellByName("Flametongue Totem");
            Backpacker_PrintMessage("Casting Flametongue Totem.");
        else
            -- Drop Disease Cleansing Totem last (cannot be detected as a buff)
            CastSpellByName("Disease Cleansing Totem");
            Backpacker_PrintMessage("Casting Disease Cleansing Totem.");
        end
    elseif Backpacker_ZG_MODE then
        -- Zul'Gurub mode: Disable Mana Spring Totem and drop Poison Cleansing Totem last
        if not buffed("Water Shield", 'player') then
            CastSpellByName("Water Shield");
            Backpacker_PrintMessage("Casting Water Shield.");
        elseif not buffed("Strength of Earth", 'player') then
            CastSpellByName("Strength of Earth Totem");
            Backpacker_PrintMessage("Casting Strength of Earth Totem.");
        elseif not buffed("Windfury Totem", 'player') then
            CastSpellByName("Windfury Totem");
            Backpacker_PrintMessage("Casting Windfury Totem.");
        elseif not buffed("Flametongue Totem", 'player') then
            CastSpellByName("Flametongue Totem");
            Backpacker_PrintMessage("Casting Flametongue Totem.");
        else
            -- Drop Poison Cleansing Totem last (cannot be detected as a buff)
            CastSpellByName("Poison Cleansing Totem");
            Backpacker_PrintMessage("Casting Poison Cleansing Totem.");
        end
    end
end

-- Function to check party members' health and heal if necessary
local function Backpacker_HealPartyMembers()
    local Backpacker_lowHealthMembers = {};  -- Table to store party members (including player) who need healing

    -- Check the player's health
    local playerHealth = UnitHealth("player");
    local playerMaxHealth = UnitHealthMax("player");
    local playerHealthPercent = (playerHealth / playerMaxHealth) * 100;

    if playerHealthPercent < Backpacker_HEALTH_THRESHOLD and not UnitIsDeadOrGhost("player") then
        table.insert(Backpacker_lowHealthMembers, "player");
    end

    -- Check the health of all party members
    for i = 1, GetNumPartyMembers() do
        local partyMember = "party" .. i;
        local health = UnitHealth(partyMember);
        local maxHealth = UnitHealthMax(partyMember);
        local healthPercent = (health / maxHealth) * 100;

        -- Add party members with low health to the table
        if healthPercent < Backpacker_HEALTH_THRESHOLD and UnitIsConnected(partyMember) and not UnitIsDeadOrGhost(partyMember) then
            table.insert(Backpacker_lowHealthMembers, partyMember);
        end
    end

    -- Sort the Backpacker_lowHealthMembers table by health percentage (lowest first)
    table.sort(Backpacker_lowHealthMembers, Backpacker_SortByHealth);

    -- Get the number of low-health members (including player)
    local numLowHealthMembers = Backpacker_TableLength(Backpacker_lowHealthMembers);

    -- Decide which spell to cast based on the number of low-health members
    if numLowHealthMembers >= 2 and Backpacker_CHAIN_HEAL_ENABLED then
        -- Cast Chain Heal if 2 or more party members (including player) need healing
        CastSpellByName(Backpacker_CHAIN_HEAL_SPELL);
        SpellTargetUnit(Backpacker_lowHealthMembers[1]);  -- Target the most injured member
        Backpacker_PrintMessage("Casting " .. Backpacker_CHAIN_HEAL_SPELL .. " on " .. UnitName(Backpacker_lowHealthMembers[1]) .. " (lowest health).");
    elseif numLowHealthMembers == 1 then
        -- Cast Lesser Healing Wave if only 1 party member (including player) needs healing
        local target = Backpacker_lowHealthMembers[1];
        local missingHealth = UnitHealthMax(target) - UnitHealth(target);

        -- Select the appropriate rank of Lesser Healing Wave
        local spellToCast = Backpacker_SelectHealingSpellRank(missingHealth);

        CastSpellByName(spellToCast);
        SpellTargetUnit(target);  -- Target the most injured member
        Backpacker_PrintMessage("Casting " .. spellToCast .. " on " .. UnitName(target) .. " (lowest health).");
    else
        -- No party members (including player) need healing
        Backpacker_PrintMessage("No party members require healing.");

        -- Follow the first available party member (if FOLLOW_ENABLED is true)
        if Backpacker_FOLLOW_ENABLED and GetNumPartyMembers() > 0 then
            local followTarget = "party1";  -- Follow the first party member
            FollowUnit(followTarget);
            Backpacker_PrintMessage("Following " .. UnitName(followTarget) .. ".");
        elseif not Backpacker_FOLLOW_ENABLED then
            Backpacker_PrintMessage("Follow functionality is disabled.");
        else
            Backpacker_PrintMessage("No party members to follow.");
        end
    end
end

-- Function to toggle debug mode
local function Backpacker_ToggleDebugMode()
    Backpacker_DEBUG_MODE = not Backpacker_DEBUG_MODE;  -- Toggle the debug mode
    BackpackerDB.DEBUG_MODE = Backpacker_DEBUG_MODE;  -- Save the updated setting
    if Backpacker_DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Debug mode enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Debug mode disabled.");
    end
end

-- Function to toggle follow functionality
local function Backpacker_ToggleFollow()
    Backpacker_FOLLOW_ENABLED = not Backpacker_FOLLOW_ENABLED;  -- Toggle the follow functionality
    BackpackerDB.FOLLOW_ENABLED = Backpacker_FOLLOW_ENABLED;  -- Save the updated setting
    if Backpacker_FOLLOW_ENABLED then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow functionality enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Follow functionality disabled.");
    end
end

-- Function to toggle Chain Heal functionality
local function Backpacker_ToggleChainHeal()
    Backpacker_CHAIN_HEAL_ENABLED = not Backpacker_CHAIN_HEAL_ENABLED;  -- Toggle the Chain Heal functionality
    BackpackerDB.CHAIN_HEAL_ENABLED = Backpacker_CHAIN_HEAL_ENABLED;  -- Save the updated setting
    if Backpacker_CHAIN_HEAL_ENABLED then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Chain Heal functionality enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Chain Heal functionality disabled.");
    end
end

-- Function to set downranking aggressiveness and Chain Heal rank
local function Backpacker_SetDownrankAggressiveness(level)
    level = tonumber(level);
    if level == 0 or level == 1 or level == 2 then
        Backpacker_DOWNRANK_AGGRESSIVENESS = level;
        BackpackerDB.DOWNRANK_AGGRESSIVENESS = Backpacker_DOWNRANK_AGGRESSIVENESS;  -- Save the updated setting

        -- Set Chain Heal rank based on downranking aggressiveness
        if Backpacker_CHAIN_HEAL_ENABLED then
            if level == 0 then
                Backpacker_CHAIN_HEAL_SPELL = "Chain Heal(Rank 3)";  -- Default rank
            elseif level == 1 then
                Backpacker_CHAIN_HEAL_SPELL = "Chain Heal(Rank 2)";  -- Mid rank
            elseif level == 2 then
                Backpacker_CHAIN_HEAL_SPELL = "Chain Heal(Rank 1)";  -- Lowest rank
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Downranking aggressiveness set to " .. level .. ".");
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Chain Heal rank set to " .. Backpacker_CHAIN_HEAL_SPELL .. ".");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Invalid downranking aggressiveness level. Use 0, 1, or 2.");
    end
end

-- Function to toggle Stratholme mode
local function Backpacker_ToggleStratholmeMode()
    if Backpacker_ZG_MODE then
        Backpacker_ZG_MODE = false;  -- Disable Zul'Gurub mode if it's enabled
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode disabled.");
    end

    Backpacker_STRATHOLME_MODE = not Backpacker_STRATHOLME_MODE;  -- Toggle Stratholme mode
    BackpackerDB.STRATHOLME_MODE = Backpacker_STRATHOLME_MODE;  -- Save the updated setting
    if Backpacker_STRATHOLME_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode enabled. Mana Spring Totem disabled, Disease Cleansing Totem enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode disabled. Normal totem behavior restored.");
    end
end

-- Function to toggle Zul'Gurub mode
local function Backpacker_ToggleZulGurubMode()
    if Backpacker_STRATHOLME_MODE then
        Backpacker_STRATHOLME_MODE = false;  -- Disable Stratholme mode if it's enabled
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Stratholme mode disabled.");
    end

    Backpacker_ZG_MODE = not Backpacker_ZG_MODE;  -- Toggle Zul'Gurub mode
    BackpackerDB.ZG_MODE = Backpacker_ZG_MODE;  -- Save the updated setting
    if Backpacker_ZG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode enabled. Mana Spring Totem disabled, Poison Cleansing Totem enabled.");
    else
        DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Zul'Gurub mode disabled. Normal totem behavior restored.");
    end
end

-- Function to print usage information
local function Backpacker_PrintUsage()
    DEFAULT_CHAT_FRAME:AddMessage("Backpacker: Usage:");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpheal - Heal party members (including yourself).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpbuff - Drop totems based on missing buffs.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdebug - Toggle debug messages on or off.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpfollow - Toggle follow functionality on or off.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpchainheal - Toggle Chain Heal functionality on or off.");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpdr <0, 1, 2> - Set downranking aggressiveness (default: 2 = 200%).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpstrath - Toggle Stratholme mode (disable Mana Spring Totem, enable Disease Cleansing Totem).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bpzg - Toggle Zul'Gurub mode (disable Mana Spring Totem, enable Poison Cleansing Totem).");
    DEFAULT_CHAT_FRAME:AddMessage("  /bp or /backpacker - Show this usage information.");
end

-- Register the slash commands
SLASH_BPHEAL1 = "/bpheal";  -- Define the slash command for healing
SlashCmdList["BPHEAL"] = Backpacker_HealPartyMembers;  -- Link the command to the function

SLASH_BPBUFF1 = "/bpbuff";  -- Define the slash command for dropping totems
SlashCmdList["BPBUFF"] = Backpacker_DropTotems;  -- Link the command to the function

SLASH_BPDEBUG1 = "/bpdebug";  -- Define the slash command for toggling debug mode
SlashCmdList["BPDEBUG"] = Backpacker_ToggleDebugMode;  -- Link the command to the function

SLASH_BPFOLLOW1 = "/bpfollow";  -- Define the slash command for toggling follow functionality
SlashCmdList["BPFOLLOW"] = Backpacker_ToggleFollow;  -- Link the command to the function

SLASH_BPCHAINHEAL1 = "/bpchainheal";  -- Define the slash command for toggling Chain Heal functionality
SlashCmdList["BPCHAINHEAL"] = Backpacker_ToggleChainHeal;  -- Link the command to the function

SLASH_BPDR1 = "/bpdr";  -- Define the slash command for setting downranking aggressiveness
SlashCmdList["BPDR"] = Backpacker_SetDownrankAggressiveness;  -- Link the command to the function

SLASH_BPSTRATH1 = "/bpstrath";  -- Define the slash command for toggling Stratholme mode
SlashCmdList["BPSTRATH"] = Backpacker_ToggleStratholmeMode;  -- Link the command to the function

SLASH_BPZG1 = "/bpzg";  -- Define the slash command for toggling Zul'Gurub mode
SlashCmdList["BPZG"] = Backpacker_ToggleZulGurubMode;  -- Link the command to the function

SLASH_BP1 = "/bp";  -- Define the slash command for usage info
SLASH_BP2 = "/backpacker";  -- Define the slash command for usage info
SlashCmdList["BP"] = Backpacker_PrintUsage;  -- Link the command to the function

-- Print a message when the addon is loaded
Backpacker_PrintUsage();