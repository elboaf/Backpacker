# Backpacker - Shaman Automation Suite

This addon was created for backpacking my Shaman in TurtleWow CC2. It assumes you are level 60, or atleast that you have all 4 totem elements available.

I use this addon by creating a macro for `/bpheal` bound to mouse wheel up, and a macro for `/bpbuff` bound to mousewheel down. This way I can have my Warrior window focused and controlled using my keyboard, and my Shaman's healing/buffing is controlled by mousing over his window in the background and scrolling up/down.

## YouTube Demo

[![Video](https://img.youtube.com/vi/68p6u27n1M0/0.jpg)](https://youtu.be/68p6u27n1M0)

## How to Use:
- Place the Backpacker folder in your `Interface/AddOns/` directory.
- Log in to Turtle WoW.
- Enable the addon in the character selection screen (click "AddOns" in the bottom left).

## Features

### Smart Healing System (QuickHeal Integration)
- Uses QuickHeal addon for all healing decisions
- Automatically decides between single-target heal or chain heal
- No manual rank selection - QuickHeal handles all healing optimization
- Hybrid mode: Switches to DPS when healing not needed

### Advanced Totem Management
- **Fully customizable totems** for each element
- Configurable delay between totem casts
- Continuous maintenance of all totems (auto-recast if destroyed/expired/out-of-range)
- Fast totem dropping with local verification flags
- Independent server buff verification with buffer periods
- **Smart Totemic Recall** with dual cooldown system
- Separate Water Shield handling (self-buff, not affected by totem recall)
- **ZG/Stratholme combat mode**: Spammable cleansing totems for mass dispels

## Backpacker Commands:

### Core Commands
- `/bpheal` - Heal party and raid members using QuickHeal
- `/bpbuff` - Drop totems with smart verification system
- `/bprecall` - Manually cast Totemic Recall (works in combat)
- `/bpdebug` - Toggle debug messages on/off
- `/bpfollow` - Toggle follow functionality
- `/bpchainheal` - Toggle Chain Heal functionality
- `/bpstrath` - Toggle Stratholme mode (Disease Cleansing Totem)
- `/bpzg` - Toggle Zul'Gurub mode (Poison Cleansing Totem)
- `/bphybrid` - Toggle Hybrid mode (lower healing threshold + DPS)
- `/bpdelay <seconds>` - Set totem cast delay (default: 0.25)
- `/bp` or `/backpacker` - Show usage information

### Totem Customization Commands

#### Earth Totems
- `/bpsoe` - Strength of Earth Totem
- `/bpss` - Stoneskin Totem
- `/bptremor` - Tremor Totem
- `/bpstoneclaw` - Stoneclaw Totem
- `/bpearthbind` - Earthbind Totem

#### Fire Totems
- `/bpft` - Flametongue Totem
- `/bpfrr` - Frost Resistance Totem
- `/bpfirenova` - Fire Nova Totem
- `/bpsearing` - Searing Totem
- `/bpmagma` - Magma Totem

#### Air Totems
- `/bpwf` - Windfury Totem
- `/bpgoa` - Grace of Air Totem
- `/bpnr` - Nature Resistance Totem
- `/bpgrounding` - Grounding Totem
- `/bpsentry` - Sentry Totem
- `/bpwindwall` - Windwall Totem

#### Water Totems
- `/bpms` - Mana Spring Totem
- `/bphs` - Healing Stream Totem
- `/bpfr` - Fire Resistance Totem
- `/bppoison` - Poison Cleansing Totem
- `/bpdisease` - Disease Cleansing Totem

## Important Notes:

- **Requires QuickHeal addon** for healing functionality
- Totem system features intelligent state tracking with both local and server verification
- Manual Totemic Recall (`/bprecall`) works even in combat for emergency situations
- In ZG/Stratholme modes, cleansing totems become spammable during combat for mass dispels
- Hybrid mode automatically adjusts healing threshold and enables DPS rotation when healing isn't needed

The Backpacker addon is a comprehensive utility tool for Shamans in WoW Classic, automating healing, advanced totem management, and party following. It is highly configurable through slash commands, allowing players to tailor its behavior to their specific needs and playstyle.
