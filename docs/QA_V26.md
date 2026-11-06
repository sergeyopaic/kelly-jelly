# Kelly Jelly 2.6 — UI, facing, readable combat

## Scope

- Replaced the generated frame/button textures in active UI with a consistent code-drawn candy style: raised buttons, asymmetrical rounded panels, strawberry health medallion, mint XP wrapper, compact timer. Fonts: Lilita One for English display text; Nunito 750 for body text and Cyrillic, raster oversampling 2. Original pixel art and licenses retained.
- Pause upgrade icons and numeric ranks remain. No new mass/armor/speed symbols were added to the combat HUD; failed-hit text spam was removed while internal reason values remain available.
- Kelly stores facing per run. Ordinary motion uses horizontal velocity with an 18 world-unit/s dead zone after scale normalization. Charging uses aim with a 0.18 horizontal dead zone. Stationary and near-vertical motion retain facing. Sprites mirror; collision, speed, ring placement, and stamina rules remain unchanged.
- Body normalization uses hand-selected body rectangles in RunArt.BODY_BOUNDS, not complete image dimensions. Equal mass has equal body-rectangle area (2.65 × collision radius squared). This is an art calibration, not a claim that opaque silhouettes have identical pixel area. Waffle eyes belong to its body; feet do not. All eight enemy types use this mapping.
- Waffle has no always-on mass-ratio armor. Approach → 0.45 s shield windup → 0.95 s directional guard → 1.6 s vulnerable recovery. Face is locked throughout windup/guard. Only the front 120 degrees blocks; rear, windup and stunned state are vulnerable under ordinary impact rules. Rendered gold shield arc uses the same angular sector. Contact damage rules remain unchanged.
- Telegraph lanes use shared enemy attack speed/duration helpers. Dash distances at base scale: gummy 85, fork 150, pudding/whisk ram 350, rolling boss 470. Width is the enemy collision diameter, excluding Kelly's own radius. Projectile lanes use exactly the same 3/9 angles, speeds, radii and 5-second lifetime as actual volleys. Warning fill uses the actual preparation duration. No approximate universal 200-unit dashed line remains.

## Validation

144 deterministic checks passed, including existing mechanics plus waffle front/rear guard, guard facing lock and expiry, windup vulnerability, player facing/dead zone/aim, real dash travel vs telegraph length, volley count/direction/speed, equal-mass body calibration.

20 minutes of simulated physics ticks with the ordinary combat bot, assist off, restart on death: 2 runs, 1 death, 1,408 kills, peak 74 enemies and 63 pickups; no script errors. This is a stability check, not a human playthrough or rendering/performance benchmark. Hit pauses are included in the simulated tick time. Report: docs/survivors_stress.json; log: docs/stress26.log.

Source captures inspected: arena, menu, pause with all 15 upgrades, settings, upgrade selection, waffle recovery/guard, three attack warnings, left/right facing. Windows Release captures: arena at 1280×720; partial HUD, waffle, warnings and menu at 1440×810; Russian settings at 1280×720. All six exported processes exited 0, stderr logs empty. Visual states are seeded/staged; all modifiers in those captures are test-only. Physical controller and subjective sound were not tested in this iteration.

Build: build/windows-v2.6/KellyJelly.exe. Archive: build/KellyJelly-TheSweetWilds-v2.6-Windows.zip. Previous source snapshot: docs/archive/survivors-v25-ui-source.zip. Prior executable versions remain intact.
