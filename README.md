# Night Shift: Drive-Thru 🍔

*"Welcome to Munchie's! Open Late. Open Always. Please pull forward."*

A 1–4 player co-op Roblox game: work the overnight shift at Munchie's, a slightly-too-cheerful
24-hour drive-thru. Cook, bag, and hand out orders — and refuse the **Late Customers** pretending
to be people. When the lights flicker three times, **hide**, or Mr. Munch boops you into a
**Shift Ghost** and your crew has to cover your station.

This repo is a **greybox build of the full §9.1 MVP** from the design doc: everything is built from
plain blocks by code, with placeholder sounds, so you can play it end-to-end and judge the fun
before any art goes in.

---

## Open it in Roblox Studio (2 minutes)

**Option A — just open the place file (easiest)**

1. Download `NightShiftDriveThru.rbxlx` from this repo.
2. Double-click it (or Studio → File → Open from File).
3. Press **Play** (F5). You spawn in the parking lot. Hit **START YOUR FIRST SHIFT**.

**Option B — Rojo (if you want to edit code in VS Code)**

1. Install [Rojo](https://rojo.space) 7.x and the Rojo Studio plugin.
2. Open `NightShiftDriveThru.rbxlx` in Studio (it contains the prebuilt map).
3. In this folder run `rojo serve`, then click **Connect** in the Rojo plugin.

> Tip: In Studio, open **Game Settings → Avatar** and make sure avatars are **R15**
> (crouching lowers your hip height, which only works on R15 rigs).

### Testing with friends in Studio

Test tab → **Clients and Servers** → set players to **2–4** → **Start**. Each window is a
player. Have everyone step on the same **CLOCK-IN** pad in the parking lot (the leader picks the
night and Solo / Friends / Public, then **CLOCK IN NOW**).

In Studio, shifts run **in the same server** (only one crew at a time). In a published game, each
crew is teleported to its own private shift server.

---

## How to play

| | PC | Phone / tablet |
|---|---|---|
| Use a station (take order, grill, fryer, bag, window...) | **E** at the prompt | tap the prompt |
| Hold to pour a drink / shake | **hold E**, let go in the green | hold the prompt |
| Hide | **F** at a hiding spot | tap **Hide** |
| Leave hiding spot | **F** | **LEAVE** |
| Crouch (High Beams!) | **C** | **CROUCH** |
| Quick-chat callouts | **Q** | **CHAT** |
| Ping a spot | **G** | **PING** |
| UV flashlight (Night 4+) | **U** | **UV** |
| Ghost: point / Boo! | **G** / **B** | **POINT** / **BOO!** |
| Inspection tabs at the window | **← / →** | swipe or tap tabs |

**The loop:** a car pulls up to the speaker → someone **takes the order** at the CRT (read the
words, tap the menu, flag it ⚠ if it sounds weird) → **grill** a patty (FLIP! at the sizzle, take
it when DONE) → **build** the burger on the plate following the ticket stack → **fries**
(pull at the DING, scoop) and **drinks** (hold to pour) → carry each item to the **bag counter**
→ when the car reaches the window, **inspect** it (Window / Mirror / Lane Cam / Receipt / UV) and
**HAND OUT** or **REFUSE**.

You cook *before* you're sure. That's the point.

---

## What's in this build (design doc §9.1)

- **Lobby** — the Munchie's parking lot: 2 clock-in pads (party up 1–4, pick an unlocked night,
  Solo / Friends / Public, countdown), first-play **Quick Start**, **Rejoin** after a crash,
  locker room (cosmetics), corporate fax (codes), Field Guide kiosk, leaderboard billboard,
  lobby TV, supporter credits wall.
- **5 nights** with story beats (§3.4): Welcome to the Team! · The Regulars · Mr. Munch Is Here
  for Inspection · Where's Deb? · Closing Time. Night 1 is a guided first shift (Deb on the
  headset + station beacons; Toby the trainee).
- **4 stations** (Order, Grill + Assembly, Fry/Drinks, Bag & Window), **6-item menu**
  (#1 Munch Burger, #2 Cheeseburger, #3 Fries, #4 Munch Stack, #5 Drink, #6 Shake) with
  burger mods (no pickles, extra sauce...). There is no #7.
- **Carry & snap cooking** — one item in your hands at a time; burgers stack visibly; bagging
  snaps into whichever ticket needs that exact item.
- **11 Late Customers** (the 10 MVP ones + The Twins) and the **Hendersons** decoy, plus Gerald,
  Officer Brisket, Karen-Bot, the guy with a cast, SpookyPriya, Trucker Ray on the CB.
- **Inspection channels** — Speaker, Window, Mirror, Lane Cam, Receipt, and UV (Night 4+).
- **Scares** — Rush Hour (Mr. Munch walks the floor, line-of-sight, chases, boops; checks hiding
  spots on Night 4+ with a hold-your-breath minigame) and High Beams (crouch below the window
  line). Night 2 has a safe tutorial Lights Out. Scare Director pacing rules from §5.3.
- **5 hiding spots** (under the counter, walk-in freezer ×2, costume closet, bathroom stall,
  ball pit ×3) with anti-camping.
- **Shift Ghosts** — booped players float through walls with a visible respawn timer, can
  Ghost Point and Boo!; whole crew booped = Ghost Town.
- **Gizmo the Fry-Bot** — covers fry/drinks solo (60%) and booped teammates' stations (30%);
  hides behind a napkin; always gets booped.
- **Stars, Weird Meter, 11 weird events** (Ear Rain, Raccoons, Mirror Mess, Grabby Hands,
  Gravity Fries, Doilies, Ghost Rider, Mandatory Fun, Channel Surf, Mascot Mob, Double Trouble).
- **Night 5 reveal** + **Last Call** (Freed), **Employee of the Month** (Company), **Fired!**
  endings, plus the secret **The Mascot** ending.
- **Saves** — nights unlocked, Paychecks, cosmetics, Field Guide, 39 badges, endings, settings.
- **Cosmetics** — 10 Paycheck items + 6 Robux items + Supporter Pass (cosmetic only; no
  revives, no stats, no purchases mid-shift — §11.3).
- **Accessibility** — reduced-flashing toggle, captions with direction for every audio cue,
  mobile-first UI, Fast Start toggle.

Out (post-launch, per the doc): Second Shift, Speaker Voice + Grease Burp scares, extra
locations, decorating, Chill/Graveyard modes, weekly challenges, true ending, UGC.

---

## Studio DEBUG panel

In Studio only, a purple **DEBUG** button appears on the left. Use it to jump straight to the
thing you want to test:

- **Night 1–5** — start that night solo right away
- **+1 Hour / Win Night / Fail Night / End Shift**
- **Rush Hour / High Beams / Lights Out** — trigger a scare now
- **Late Car / Normal Car / Hendersons / Gerald** — spawn a customer
- **Weird 100% / Stars ±1 / Boop Me / Reveal / Give UV**
- **Unlock All / +500 Pay** — test the lobby and locker
- **Next Weird Event** — cycles through all 11 weird events

### A 15-minute playtest checklist

1. **Night 1 (guided):** follow Deb's beacons through one full order; refuse Earl of Ears
   ("...Uh. Look closely."). Check the Field Guide card appears.
2. **Wrong stuff:** enter a wrong order on purpose → the bag matches the ticket but the
   customer complains. Burn a patty. Overflow a drink (sticky floor).
3. **Night 3:** DEBUG → Night 3 → Rush Hour. Hide in the freezer; then try getting caught —
   you become a ghost with a timer. POINT and BOO! at Gizmo.
4. **Night 4:** DEBUG → Night 4 → High Beams (crouch with C). Rush Hour again and hide — he
   may knock (hold your breath). DEBUG → Give UV and check the Employee of the Month wall.
5. **Night 5:** DEBUG → Night 5 → Reveal. Read the photo backs with UV, cook a usual
   (e.g. Marv: #4 Munch Stack, no pickles, extra sauce) and HAND OUT to free them.
   DEBUG → Win Night to see the ending.
6. **Lobby:** buy/equip a hat in the locker, enter code `OPENLATE` at the fax, check badges.

---

## Tuning (src/shared/Config.luau)

| Setting | What it does |
|---|---|
| `Profile = "Test"` | ~6-minute nights for playtesting. Set to `"Design"` for ~15-minute nights. |
| `Patience`, `CarInterval` | how long customers wait / how often they arrive |
| `Cook` | grill, fryer and pour timings |
| `Stars`, `Weird` | scoring and Weird Meter rules |
| `Scare`, `Munch`, `HighBeams`, `Hide` | scare pacing, Mr. Munch's speed and vision, anti-camping |
| `Gizmo` | Gizmo's efficiency and mistake rate |
| `Sounds` | placeholder sounds — swap in Creator Store audio ids |
| `DevProducts`, `SupporterPassId`, `RobloxBadgeIds` | monetization + badge ids (0 = off) |
| `HostingMode` | `"Auto"` (reserved shift servers when published), `"InPlace"` |

Content is data-driven (§8.2): add a Late Customer in `src/shared/Data/Anomalies.luau`, a night
event in `Data/Nights.luau`, a cosmetic in `Data/Cosmetics.luau`, a code in `Data/Codes.luau`.

## Publishing checklist

1. File → Publish to Roblox. Game Settings → Security → **Enable Studio Access to API
   Services** (so saves work in Studio too).
2. Create developer products / the Supporter game pass / badges on the Creator Dashboard and
   paste their ids into `Config.luau`.
3. Set content maturity to **Mild** (jump scares, no gore).
4. Replace placeholder sounds (`Config.Sounds`) — especially Mr. Munch's squeak-squeak and the
   Munchie's jingle (currently played note-by-note from a built-in ping sound).

---

## Project layout

```
default.project.json        Rojo project
NightShiftDriveThru.rbxlx   ready-to-open place file (built from this repo)
assets/Munchies.rbxmx       the prebuilt greybox map (generated by tools/build-map)
src/shared/                 ReplicatedStorage.Shared — Config, data tables, OrderLogic, builders
src/server/Services/        ServerScriptService — Shift Director, Customers, Orders, Stations,
                            Window, Scares, Hiding, Ghosts, Gizmo, Story, Lobby, saves, shop...
src/client/                 StarterPlayerScripts — HUD, panels, window inspection, effects
tools/                      Lune scripts: tests, map prebuild, module harness
```

### Rebuilding

```bash
lune run tools/test        # 22 offline tests (order logic, data integrity, builds every model)
lune run tools/build-map   # regenerate assets/Munchies.rbxmx from MapBuilder
rojo build default.project.json -o NightShiftDriveThru.rbxlx
```

If `assets/Munchies.rbxmx` is missing, the server builds the map at runtime instead.
