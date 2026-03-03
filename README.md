# Backpacker

**Version:** 1.5.0 | **Author:** Rel | **WoW 1.12 Vanilla**

A Shaman multiboxing addon. Automates totem dropping, party healing, shield upkeep, and follow logic.

---

## Dependencies

- **SuperWoW** — precise totem detection via unit IDs and range checking. Falls back to buff-based detection without it.
- **DoiteAuras** — animated glow on the totem bar in ZG/Strath mode.
- **Quickheal** — Healing logic backend.

---

## Totem Bar

Toggle with `/bpmenu`. Four buttons — one per element — showing your configured totem. Drag anywhere to reposition.

- **Hover** a button to open a flyout showing all totems for that element. Click to select.
- **Left-click** to cast the configured totem.
- **Right-click** to toggle the flyout.
- **Timer** counts down on the button when a totem is active (white → yellow at 50% → red under 10s).
- **Active indicator** — if you manually drop a different totem than what's configured, a smaller button appears below showing the active totem and its timer. Disappears when they match again.
- **ZG/Strath glow** — Water button icon switches to the cleanse totem and pulses with a DoiteGlow border when a mode is active.

---

## Core Commands

| Command | Description |
|---|---|
| `/bpbuff` | Drop any missing totems. Handles full rotation including ZG/Strath cleansing pulse. |
| `/bpfirebuff` | Drop fire totem only if no fire totem is active. Respects Fire Nova — won't override it while it's burning. |
| `/bprecall` | Cast Totemic Recall and clear all bar timers. |
| `/bpheal` | Heal party members below the health threshold. |
| `/bpl` | Set follow target to current target. |
| `/bpf` | Toggle follow on/off. |
| `/bpmenu` | Toggle totem bar visible/hidden. |

---

## Totem Setup

Set your configured totem per element. Persists across sessions.

**Earth:** `/bpsoe` `/bpss` `/bptremor` `/bpstoneclaw` `/bpearthbind`

**Fire:** `/bpft` `/bpfrr` `/bpfirenova` `/bpsearing` `/bpmagma`

**Air:** `/bpwf` `/bpgoa` `/bpnr` `/bpgrounding` `/bpsentry` `/bpwindwall` `/bptranquil`

**Water:** `/bpms` `/bphs` `/bpfr` `/bppoison` `/bpdisease`

---

## Manual Casts

Cast a specific totem without changing your configuration. Useful for situational swaps mid-pull without disrupting `/bpbuff` behaviour.

Append `-cast` to any totem command above — e.g. `/bptremor-cast`, `/bpfirenova-cast`, `/bpms-cast`.

---

## Modes

| Command | Description |
|---|---|
| `/bpzg` | **ZG Mode** — overrides Water slot with Poison Cleansing Totem, recasts on every `/bpbuff`. Water button glows green. |
| `/bpstrath` | **Strath Mode** — overrides Water slot with Disease Cleansing Totem, recasts on every `/bpbuff`. Water button glows purple. |
| `/bpfarm` | **Farming Mode** — suppresses Fire and Water totems to save reagents. |

ZG and Strath are mutually exclusive — enabling one disables the other.

---

## Shield

| Command | Description |
|---|---|
| `/bpws` | Switch to Water Shield. |
| `/bpls` | Switch to Lightning Shield. |
| `/bpes` | Switch to Earth Shield. |

---

## Totem Durations

| Totem | Duration |
|---|---|
| Most totems | 120s |
| Mana Spring | 60s |
| Grounding / Earthbind | 45s |
| Searing | 30s |
| Magma | 20s |
| Stoneclaw | 15s |
| Fire Nova | 5s |

Adjust in the `TOTEM_DURATIONS` table in `Backpacker.lua` if your server differs.

---

## Defaults

| Element | Default Totem |
|---|---|
| Earth | Strength of Earth |
| Fire | Flametongue |
| Air | Windfury |
| Water | Mana Spring |
