# Royal Warfare 1 — Mac

This repository is exclusively the first game's native Godot port. Keep it independent of Royal Warfare 2. Preserve the original content, interface and mechanics unless the user explicitly authorizes changes.

Use `/Applications/Godot.app/Contents/MacOS/Godot`. Do not add bundled editors, Flash runtimes, SWF files, reverse engineering sources or conversion tools. All runtime assets belong in this repository. Local recovery material is ignored.

Run `dev/godot.sh test` for content and gameplay changes. Tests use `-- --isolated-profile`; never change a player's saved campaign for testing. Run `tests/campaign_flow.gd` when changing event dispatch. Check rendered screens when altering interface or font placement.

Do not describe resource coverage or accelerated event tests as full gameplay parity. Keep `docs/verification.md` accurate about unresolved differences and manual playthrough coverage.
