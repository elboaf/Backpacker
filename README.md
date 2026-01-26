# Backpacker - Shaman Automation Suite

requires superwow https://github.com/balakethelock/SuperWoW

This addon was created for backpacking my Shaman in TurtleWow CC2. It assumes you are level 60.

I use this addon by creating a macro for `/bpheal` bound to mouse wheel up, and a macro for `/bpbuff` bound to mousewheel down. This way I can have my Warrior window focused and controlled using my keyboard, and my Shaman's healing/buffing is controlled by mousing over his window in the background and scrolling up/down.

## YouTube Demo

[![Video](https://img.youtube.com/vi/68p6u27n1M0/0.jpg)](https://youtu.be/68p6u27n1M0)
# Backpacker Addon - Slash Commands Reference

## Core Commands

### Healing & Buffing
| Command | Description |
|---------|-------------|
| `/bpheal` | Heal party/raid members using QuickHeal integration |
| `/bpbuff` | Drop totems (with auto-shield refresh if enabled) |
| `/bpchainheal` | Toggle Chain Heal functionality |
| `/bprecall` | Manually cast Totemic Recall (works in combat) |
| `/bpreport` | Report current totems to party chat |

### Debugging
| Command | Description |
|---------|-------------|
| `/bpdebug` | Toggle debug messages |
| `/bpcheckbuffs` | Debug: Show all current buffs with UnitBuff() |

### Modes & Settings
| Command | Description |
|---------|-------------|
| `/bpstrath` | Toggle Stratholme mode (uses Disease Cleansing Totem) |
| `/bpzg` | Toggle Zul'Gurub mode (uses Poison Cleansing Totem) |
| `/bphybrid` | Toggle Hybrid mode (heals + DPS) |
| `/bpfarm` | Toggle Farming mode (auto-switches Water/Earth Shield) |
| `/bpdelay <seconds>` | Set totem cast delay (default: 0.25) |

### Follow System
| Command | Description |
|---------|-------------|
| `/bpf` | Toggle follow functionality |
| `/bpl` | Set follow target to current target |

### Pet Healing
| Command | Description |
|---------|-------------|
| `/bppets` | Toggle Pet Healing mode |

## Shield Management

### Shield Types (Mutually Exclusive)
| Command | Alias | Description |
|---------|-------|-------------|
| `/bpwatershield` | `/bpws` | Use Water Shield |
| `/bplightningshield` | `/bpls` | Use Lightning Shield |
| `/bpearthshield` | `/bpes` | Use Earth Shield |

### Shield Auto-Refresh
| Command | Description |
|---------|-------------|
| `/bpauto` | Toggle Shield auto-refresh mode |

## Totem Customization

### Earth Totems
| Command | Totem Set |
|---------|-----------|
| `/bpsoe` | Strength of Earth Totem |
| `/bpss` | Stoneskin Totem |
| `/bptremor` | Tremor Totem |
| `/bpstoneclaw` | Stoneclaw Totem |
| `/bpearthbind` | Earthbind Totem |

### Fire Totems
| Command | Totem Set |
|---------|-----------|
| `/bpft` | Flametongue Totem |
| `/bpfrr` | Frost Resistance Totem |
| `/bpfirenova` | Fire Nova Totem |
| `/bpsearing` | Searing Totem |
| `/bpmagma` | Magma Totem |

### Air Totems
| Command | Totem Set |
|---------|-----------|
| `/bpwf` | Windfury Totem |
| `/bpgoa` | Grace of Air Totem |
| `/bpnr` | Nature Resistance Totem |
| `/bpgrounding` | Grounding Totem |
| `/bpsentry` | Sentry Totem |
| `/bpwindwall` | Windwall Totem |

### Water Totems
| Command | Totem Set |
|---------|-----------|
| `/bpms` | Mana Spring Totem |
| `/bphs` | Healing Stream Totem |
| `/bpfr` | Fire Resistance Totem |
| `/bppoison` | Poison Cleansing Totem |
| `/bpdisease` | Disease Cleansing Totem |

## Help & Information
| Command | Description |
|---------|-------------|
| `/bp` | Show usage information |
| `/backpacker` | Same as `/bp` |

## Key Notes
1. **QuickHeal Integration**: Healing commands require the QuickHeal addon
2. **Farming Mode**: Automatically switches between Water Shield and Earth Shield based on health:mana ratio
3. **Auto-Refresh**: When enabled, `/bpbuff` automatically refreshes shields when charges are low
4. **Special Modes**: Stratholme and ZG modes override water totem settings
5. **Totem Reporting**: `/bpreport` sends a clean list of your current totems to party chat

## Usage Tips
- Run `/bp` anytime to see all available commands
- Shield types are mutually exclusive - setting one disables others
- Farming mode automatically disables auto-refresh mode
- Manual recall (`/bprecall`) works even in combat
- `/bpl` sets your follow target to whatever player you have targeted
