This addon was created for backpacking my Shaman in TurtleWow CC2. It assumes you are level 60.

I use this addon by creating a macro for /bpheal bound to mouse wheel up, and a macro for /bpbuff bound to mousewheel down. This way I can have my Warrior window focused and controlled using my keyboard, and my Shamans healing/buffing is controlled by mousing over his window in the background and scroling up/down

How to Use:
    Place the Backpacker folder in your Interface/AddOns/ directory.
    Log in to Turtle WoW.
    Enable the addon in the character selection screen (click "AddOns" in the bottom left).

Backpacker: Usage:

/bpheal - Heal party members (including yourself).
      
/bpbuff - Drop totems based on missing buffs.
      
/bpdebug - Toggle debug messages on or off.

/bpfollow - Toggle follow functionality on or off.
      
/bpchainheal - Toggle Chain Heal functionality on or off.
      
/bpdr <0|1|2> - Set downranking aggressiveness (0 = 100%, 1 = 150%, 2 = 200% (default)).
      
/bp or /backpacker - Show this usage information.


The provided files are part of a World of Warcraft (WoW) addon called Backpacker. This addon is designed to assist players, particularly those playing as Shamans, by automating certain tasks such as healing party members, dropping totems, and following party members. Below is a breakdown of the files and their functionalities:
1. Backpacker.lua

This is the main script for the Backpacker addon. It contains the core logic for the addon's functionality. Here are the key features:

    Configuration Loading: The script attempts to load a configuration file (Backpacker_Config.lua). If the file fails to load, it uses default values for the LESSER_HEALING_WAVE_RANKS table.

    Healing Logic:

        The addon checks the health of the player and party members.

        If a party member's health falls below a certain threshold (HEALTH_THRESHOLD), the addon will cast either Chain Heal (if multiple members need healing) or Lesser Healing Wave (if only one member needs healing).

        The rank of Lesser Healing Wave is selected based on the amount of missing health and the configured downranking aggressiveness.

    Totem Management:

        The addon checks for missing buffs (e.g., Mana Spring, Water Shield, Strength of Earth, etc.) and drops the appropriate totems if they are not active.

    Follow Functionality:

        If enabled, the addon will automatically follow the first party member in the group.

    Debug Mode:

        The addon has a debug mode that can be toggled on or off to display additional messages in the chat frame.

    Slash Commands:

        The addon provides several slash commands to control its behavior:

            /bpheal: Heal party members.

            /bpbuff: Drop totems based on missing buffs.

            /bpdebug: Toggle debug mode.

            /bpfollow: Toggle follow functionality.

            /bpchainheal: Toggle Chain Heal functionality.

            /bpdr <0, 1, 2>: Set downranking aggressiveness.

            /bp or /backpacker: Display usage information.

2. Backpacker.toc

This is the table of contents file for the addon. It defines the addon's metadata and lists the Lua files that should be loaded. In this case, it only loads Backpacker.lua.

    Interface Version: The addon is designed for WoW Classic (Interface version 11200).

    Title and Notes: The addon is named "Backpacker" and is described as an addon that automatically heals party members, drops totems, and follows party members.

    Author and Version: The author is "Ler", and the version is 1.0.

3. Backpacker_Config.lua

This file contains the configuration for the addon, specifically the ranks and properties of the Lesser Healing Wave spell. Each rank has a defined mana cost and healing amount. This file can be customized to adjust the healing behavior of the addon.
Summary

The Backpacker addon is a utility tool for Shamans in WoW Classic, automating healing, totem management, and party following. It is highly configurable through slash commands and a configuration file, allowing players to tailor its behavior to their needs. The addon is designed to be user-friendly, with debug messages and usage information available to help players understand and control its functionality.
New chat
