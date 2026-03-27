# RotationTracker (WoW Addon)

This project now includes a local release workflow for CurseForge:
- `RotationTracker.lua` handles tracking and slash commands.
- `RotationTracker.toc` contains publish metadata.
- `package.ps1` builds a release zip from this folder.
- `CHANGELOG.md` tracks release notes.

## Slash commands

- `/rt` - show help
- `/rt start` - start manual session
- `/rt stop` - stop and print session summary
- `/rt target <dps>` - set benchmark DPS
- `/rt best` - show best recorded DPS
- `/rt history` - show recent run list
- `/rt rotation` - show current fight rotation events

