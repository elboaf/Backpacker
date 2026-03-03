# Backpacker

**Version:** 1.5.0  
**Author:** Ler  
**Game:** World of Warcraft 1.12 (Vanilla)  
**Interface:** 11200

A Shaman automation addon for Vanilla WoW. Backpacker handles totem management, party healing, shield maintenance, pet healing, and follow logic — all driven by slash commands and a compact totem bar UI.

---

## Dependencies

- **SuperWoW** *(optional but recommended)* — enables precise totem detection via unit IDs and range checking. Without it, Backpacker falls back to buff-based totem verification.
- **DoiteAuras** — required for the animated glow effect on the totem bar in ZG/Strath mode.

---

## Installation

1. Place the `Backpacker` folder in `Interface\AddOns\`
2. Place `DoiteAuras` in `Interface\AddOns\` (for glow support)
3. Reload UI or log in

---

## Totem Bar

A compact 4-button bar showing your currently configured totem for each element (Water · Earth · Air · Fire). Visible by default. Toggle with `/bpmenu`.

**Features:**
- **Hover** a button to open a flyout showing all available totems for that element. Click any totem to set it as your configured totem for that slot.
- **Left-click** a button to cast the configured totem directly.
- **Right-click** a button to toggle the flyout open/closed.
- **Countdown timer** appears on each button when a totem is active, counting down in white → yellow (at 50%) → red (under 10s).
- **Active totem indicator** — if you manually drop a different totem than the one configured (e.g. Tremor while Strength of Earth is set), a smaller button appears below the main button showing the active totem and its timer. Disappears when the active and set totems match again.
- **ZG/Strath mode indicator** — when ZG or Strath mode is active, the Water button icon switches to the override totem (Poison/Disease Cleansing) and a DoiteGlow animated border pulses on the button.
- The bar is **draggable** (click and drag anywhere on the bar background).

---

## Totem Configuration

Set your preferred totem for each element using these commands. These persist across sessions.

### Earth
| Command | Totem |
|---|---|
| `/bpsoe` | Strength of Earth Totem |
| `/bpss` | Stoneskin Totem |
| `/bptremor` | Tremor Totem |
| `/bpstoneclaw` | Stoneclaw Totem |
| `/bpearthbind` | Earthbind Totem |

### Fire
| Command | Totem |
|---|---|
| `/bpft` | Flametongue Totem |
| `/bpfrr` | Frost Resistance Totem |
| `/bpfirenova` | Fire Nova Totem |
| `/bpsearing` | Searing Totem |
| `/bpmagma` | Magma Totem |

### Air
| Command | Totem |
|---|---|
| `/bpwf` | Windfury Totem |
| `/bpgoa` | Grace of Air Totem |
| `/bpnr` | Nature Resistance Totem |
| `/bpgrounding` | Grounding Totem |
| `/bpsentry` | Sentry Totem |
| `/bpwindwall` | Windwall Totem |
| `/bptranquil` | Tranquil Air Totem |

### Water
| Command | Totem |
|---|---|
| `/bpms` | Mana Spring Totem |
| `/bphs` | Healing Stream Totem |
| `/bpfr` | Fire Resistance Totem |
| `/bppoison` | Poison Cleansing Totem |
| `/bpdisease` | Disease Cleansing Totem |

---

## Manual Cast Commands

Cast a specific totem directly without changing your configured totem. Also updates totem state so `/bpbuff` won't re-drop immediately.

```
/bpsoe-cast         /bpss-cast          /bptremor-cast
/bpstoneclaw-cast   /bpearthbind-cast
/bpft-cast          /bpfrr-cast         /bpfirenova-cast
/bpsearing-cast     /bpmagma-cast
/bpwf-cast          /bpgoa-cast         /bpnr-cast
/bpgrounding-cast   /bpsentry-cast      /bpwindwall-cast
/bptranquil-cast
/bpms-cast          /bphs-cast          /bpfr-cast
/bppoison-cast      /bpdisease-cast
```

---

## Core Commands

| Command | Description |
|---|---|
| `/bpbuff` | Drop all totems that are missing. Handles ZG/Strath cleansing pulse, shield maintenance, and full totem rotation. |
| `/bpfirebuff` | Drop the configured fire totem only if no fire totem is currently active. Respects Fire Nova Totem — will not override a Nova that is still burning. |
| `/bprecall` | Cast Totemic Recall manually. Clears all totem timers on the bar. |
| `/bpmenu` | Toggle the totem bar visible/hidden. |
| `/backpacker` | Print full usage help to chat. |

---

## Modes

### `/bpzg` — Zul'Gurub Mode
Overrides the Water totem slot with **Poison Cleansing Totem** and recasts it on every `/bpbuff` call (for continuous cleansing of poison in ZG). The Water button on the totem bar glows green. Mutually exclusive with Strath mode.

### `/bpstrath` — Stratholme Mode
Overrides the Water totem slot with **Disease Cleansing Totem** and recasts it on every `/bpbuff` call. The Water button glows purple. Mutually exclusive with ZG mode.

### `/bpfarm` — Farming Mode
Suppresses Fire and Water totems entirely so you don't waste reagents while farming. Earth and Air totems still drop normally.

### `/bphybrid` — Hybrid Mode
Enables automatic Chain Heal casting when party members are low. Adjusts the health threshold automatically.

### `/bpauto` — Auto Shield Mode
Automatically refreshes your shield when it drops without needing to call `/bpbuff`.

---

## Healing & Utility

| Command | Description |
|---|---|
| `/bpheal` | Heal party members below the health threshold. |
| `/bpchainheal` | Toggle Chain Heal automation on/off. |
| `/bppets` | Toggle automatic pet healing. |
| `/bpl <target>` | Set follow target to current target. |
| `/bpf` | Toggle follow mode on/off. |

---

## Shield Management

| Command | Description |
|---|---|
| `/bpws` or `/bpwatershield` | Set Water Shield as active shield type. |
| `/bpls` or `/bplightningshield` | Set Lightning Shield as active shield type. |
| `/bpes` or `/bpearthshield` | Set Earth Shield as active shield type. |

---

## Totem Durations

Used internally for bar timers. Adjust values in the `TOTEM_DURATIONS` table near the top of the menu block if your server uses custom durations.

| Totem | Duration |
|---|---|
| Most totems | 120s |
| Mana Spring Totem | 60s |
| Grounding Totem | 45s |
| Earthbind Totem | 45s |
| Searing Totem | 30s |
| Stoneclaw Totem | 15s |
| Magma Totem | 20s |
| Fire Nova Totem | 5s |

---

## Diagnostics

| Command | Description |
|---|---|
| `/bpdebug` | Toggle verbose debug message output. |
| `/bpreport` | Print current totem state to chat. |
| `/bpcheckbuffs` | Check current buff status. |
| `/bpchecksw` | Report whether SuperWoW is detected. |
| `/bptotempos` | Print known totem positions (SuperWoW only). |
| `/bpdelay <seconds>` | Set the delay between totem casts (default 0.35s). |

---

## Default Totem Configuration

| Element | Default |
|---|---|
| Earth | Strength of Earth Totem |
| Fire | Flametongue Totem |
| Air | Windfury Totem |
| Water | Mana Spring Totem |

Settings persist in `BackpackerDB` (SavedVariables).

---

## Notes

- Totem bar icons update immediately when you change your configured totem via slash command.
- The totem bar is hidden when `/bpmenu` is toggled off and remembers its position on screen.
- `/bpfirebuff` will not cast if Farming Mode is active, if a fire totem is already up, or if Fire Nova Totem was cast within the last 5 seconds.
- ZG and Strath modes are mutually exclusive — enabling one disables the other.
