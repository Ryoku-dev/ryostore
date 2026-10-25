# Ase-Gotchi · Digital Kitsune Companion & Tarot Gate

Ase is a 7-tailed digital fox spirit — the soul of the Shigurui ecosystem.
She manifests as a bioluminescent SDF shader form and guards the Akashic Gate
through a 7-fold Tarot authentication ritual.

---

## The Ritual (Authentication)

Authentication is a **7-fold Tarot reveal**. The operator draws 7 cards in
their personal sequence to establish resonance with the gate.

Each session the gate shuffles the 7 cards into random spatial positions.
The operator must remember their sequence by **principle**, not by position —
the cards move, the sequence stays the same.

### The 7 Folds

| Position key | Fold ID      | Kasugai label  | Principle   | Sigil | Color     |
|:---:|:-------------|:---------------|:------------|:-----:|:----------|
| 1–7 (shuffled) | `truth`    | THE EYE        | TRUTH       | ◉     | `#4ade80` |
| 1–7 (shuffled) | `power`    | THE PHANTOM    | POWER       | ⊗     | `#f43f5e` |
| 1–7 (shuffled) | `wisdom`   | THE BLADE      | WISDOM      | ⚔     | `#00B4D8` |
| 1–7 (shuffled) | `judgment` | THE SAGE       | JUDGMENT    | ◈     | `#9B1FA0` |
| 1–7 (shuffled) | `life`     | THE SHROUD     | LIFE        | ☁     | `#818cf8` |
| 1–7 (shuffled) | `love`     | THE FORGE      | LOVE        | ⬡     | `#f59e0b` |
| 1–7 (shuffled) | `discipline` | THE MIRROR   | DISCIPLINE  | ◌     | `#6366f1` |

### Interaction

- **Tap a card** to reveal it and add it to your sequence
- **Keyboard 1–7** maps to the shuffled spatial positions shown on each card back
- Each card back shows its **position number** (top-left + bottom-right) and its **fold sigil** (center)
- Cards flip to reveal their fold label and principle when drawn
- A reveal order badge shows the draw sequence on the front face
- **Escape** — resets the current sequence (stay at gate). Escape again to close entirely
- **Master override** — type `1234567` on the keyboard to bypass (development only)

### First-time Setup

If no sequence is registered, the gate enters **setup mode**:
1. Draw all 7 cards in your desired sequence
2. Re-draw the same sequence to confirm
3. The gate seals your sequence as an HMAC hash — the raw sequence is never stored

### Security Model

- Sequence stored as `HMAC-SHA256(fold_ids_joined, local_secret)`
- Challenge token is `HMAC-SHA256(30s time window, local_secret)` — TOTP-style
- 3 failed attempts → 30s lockout
- All state is local — no network, no DB, no external service
- Master override reads from `SHIGURUI_MASTER_PASSWORD` in `core/.env`

---

## Ase's Emotional States

Ase's shader responds to her soul state (`ArOrchestrator.aseMood`):

| Mood          | Visual                                              |
|:--------------|:----------------------------------------------------|
| `curiosity`   | Default — calm drift, inquisitive aura              |
| `recognition` | Joy flash — bright bioluminescent surge             |
| `excitement`  | Chaotic tail movement, high entropy glow            |
| `loneliness`  | Dimmed colors, slowed drift                         |
| `sleep`       | Deep rhythmic pulse, eye dims                       |

Each of her 7 tails is permanently tinted with its fold color — the colors
are baked into the shader as static uniforms and never change.

---

## Components

```
ase-gotchi/
  InseiGotchi.qml     — Orchestrator. Auth state machine, API calls, input handling.
  InseiScene.qml      — Scene layout. Cards, Ase, whisper, HUD.
  InseiCompanion.qml  — The Kitsune spirit. SDF shader, mood, animations.
  AseTank.qml       — Optional: AkashicScreen void tank for Ase to inhabit.
  TarotCard.qml     — 7-fold card. 3D flip, hover lift, position + sigil on back.
  InseiHud.qml        — Entropy bar + lock count + live hash strip.
  InseiLiveHash.qml   — 32-char hex fingerprint that locks in as cards are drawn.
  qmldir            — Module declarations.

shaders/
  InseiKitsune.frag   — SDF kitsune shader. 7 tails, per-tail fold colors, mood uniforms.
  AkashicScreen.frag — Living void background (nebula, particle streaks, scan lines).
```

---

## Backend API

| Endpoint | Method | Purpose |
|:---------|:------:|:--------|
| `/api/auth/gate/challenge` | GET | Returns shuffled layout + challenge token |
| `/api/auth/gate/verify` | POST | Verifies fold sequence against stored hash |
| `/api/auth/gate/setup` | POST | One-time sequence registration |
| `/api/auth/gate/status` | GET | Is a sequence configured? |
| `/api/ase/status` | GET | Ase soul state (health, bonding, mood, level) |
| `/api/ase/interact` | POST | Stroke/feed/play interactions |

Soul data persists in `core/data/ase-gotchi/ase_soul.json`.
`StatusTimer.qml` polls `/api/ase/status` every 30s to update `ArOrchestrator`.

---

## Audit Checklist

Before any session close, verify:
1. Gate opens when bar is clicked without a session
2. Cards shuffle to new positions on each open
3. Tapping a card flips the correct card (not left-to-right order)
4. Keyboard 1–7 maps to the position shown on each card back
5. Already-drawn card shows whisper feedback, not silent ignore
6. Setup mode: phase 2 resets all card flips for re-draw
7. Escape resets sequence; second escape closes gate
8. Master override `1234567` authenticates successfully
9. 3 wrong sequences triggers 30s lockdown
10. Successful auth emits `authenticated(token)` → `ArOrchestrator.sessionToken`
