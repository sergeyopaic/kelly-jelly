# Kelly Jelly v2.7 — Candy Orbit

## Implemented

- First three boss victories unlock Candy Orbit, widen its radius, then increase petals from 3 to 5. Subsequent bosses retain normal XP and heart loot. Reward cards appear after attack settlement, before pending level choices, and pause combat. Boss ability resets each run.
- Petals orbit the moving player during dashes only. Radius is 1.65 body radii at stage 1 and 2.0 at stages 2–3; angular speed is one turn per 0.36 seconds. Swept petal segments use the dash's six movement substeps; contact thickness is 0.24 body radii.
- Ordinary prey at <=20% of the attack's starting mass is sliced immediately unless shielded. Other targets use normal minimum mass/speed checks with 45% impact power and the existing Heavy impact bonus. Boss armor and waffle directional guards are respected at the petal contact point.
- One orbital hit per enemy per dash, separately from direct ram. Orbital hits do not grant general invulnerability, stun, projectile clearing, or repeat damage. Orbital kills share clean-attack settlement: any HP loss cancels absorption for the whole dash, while kills/XP/hearts remain.
- Code-drawn amber caramel petals, short trails, reward emblem and pause icon; no generated assets, extra action bindings, or combat HUD indicators. English and Russian reward descriptions. Existing 15 upgrades and level-up celebration retained.
- Later boss stages currently unlock in sequence, without an alternative special-reward pool. The three proposed synergy perks are deferred.

## Validation

171 deterministic checks passed (existing suite plus 16 orbital checks), covering clean and damaged orbital kills, delayed absorption, mass floor, one-hit limit, independent direct ram, directional shields, boss armor, reward timing, progression cap and reset.

20 simulated minutes with the ordinary bot, assist off: 1 run, 0 deaths, 2,112 kills, 13,664 ticks with orbit active during dashes, peak 110 enemies and 77 pickups. No script errors. Report: `survivors_stress_orbit.json`. This checks stability, not final difficulty balance or human play quality. Rapid long-run growth needs human assessment before treating the numbers as settled.

Visually inspected source captures for orbit, English reward card and all 16 pause icons. Fixed reward text wrapping. Inspected Windows Release captures for orbit and Russian reward card at 1440x810; both processes exited 0. English reward card checked in source runtime. These are staged captures; controller play and subjective sound were not tested.

Restricted environment could not create Godot user/editor cache directories; export and rendered release captures succeeded. The release capture logs contain a shader-cache creation warning, not a game script error.

## Delivery

- `build/windows-v2.7/KellyJelly.exe`
- `build/KellyJelly-TheSweetWilds-v2.7-Windows.zip`
- Pre-change source snapshot: `docs/archive/pre-candy-orbit-source.zip`
- Earlier builds remain intact.
