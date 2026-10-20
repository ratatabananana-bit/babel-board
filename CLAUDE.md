# Babel Board: notes for Claude

- `docs/CAPABILITIES.md` is the inventory of what a module can do and cannot do. Whenever a
  change adds, removes or alters a capability (a block type or setting, a sheet setting, a
  zone feature, a filter kind, saved state, install limits, tools), update that file in the
  same commit, including its "Last synced with" line and the change log at the bottom.
- When asked whether a game fits the app, start from `docs/CAPABILITIES.md`, then check the
  code only for what the map does not settle.
