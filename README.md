# RotationTracker (WoW Addon)

This project now includes a local release workflow for CurseForge:
- `RotationTracker.lua` handles tracking and slash commands.
- `RotationTracker.toc` contains publish metadata.
- `package.ps1` builds a release zip from this folder.
- `CHANGELOG.md` tracks release notes.

## How to prepare for CurseForge upload

1. Open `RotationTracker.toc` and update:
   - `## Title`
   - `## Notes`
   - `## Author`
   - `## Version` (start at `1.0.1`)
   - `## X-Curse-Project-ID` (replace `000000` after project creation)
2. Set the interface compatibility if needed:
   - default `## Interface: 100200` (DF 10.2.x)
3. Set your target/default profile settings in the Lua file if desired:
   - defaults live in `RotationTracker.lua` near the top.

## Package the addon

From `C:\Users\Luke\OneDrive\Documents\GitHub\wow-rotation-tracker` run:

```powershell
cd C:\Users\Luke\OneDrive\Documents\GitHub\wow-rotation-tracker
.\package.ps1 -ProjectName RotationTracker
```

Output:

- Zip: `dist/RotationTracker-<Version>.zip`
- Version is read from `RotationTracker.toc` (`## Version: ...`)
- Optional: pass `-Version <x.y.z>` to override the `.toc` version.

## Create a CurseForge project (manual, one-time)

1. Create/login to your CurseForge account.
2. New project:
   - Game: World of Warcraft
   - Project type: AddOn
   - Name: RotationTracker
3. Set description, tags, images, and visibility.
4. Copy the assigned project ID into:
   - `RotationTracker.toc` (`X-Curse-Project-ID`)
5. Note the ID in this README/changelog for future releases.

## Upload release on CurseForge

1. Open the project page and create a new file release.
2. Set supported WoW versions, and the file version matching `.toc`.
3. Add release notes from `CHANGELOG.md`.
4. Upload `dist/RotationTracker-<Version>.zip`.
5. Publish as public.

## Verify in-game

1. Extract zip to:
   - `World of Warcraft/_retail_/Interface/AddOns/`
2. Enable the addon in the character select screen addons.
3. `/reload` in-game.
4. Quick checks:
   - `/rt target 25000`
   - start a clean pull and do combat
   - `/rt stop` prints total DPS and target gap
   - `/rt best` and `/rt history` return values.

## Release process (repeatable)

For each new release:
- bump `.toc` `## Version`
- update `CHANGELOG.md`
- regenerate zip with `package.ps1`
- upload new release file in CurseForge
- test with a short combat run.

## Slash commands

- `/rt` — show help
- `/rt start` — start manual session
- `/rt stop` — stop and print session summary
- `/rt target <dps>` — set benchmark DPS
- `/rt best` — show best recorded DPS
- `/rt history` — show recent run list
- `/rt rotation` — show current fight rotation events
