# Appearance Menu Mod (AMM)

Appearance Menu Mod is a feature-rich Cyber Engine Tweaks mod for **Cyberpunk 2077**. It lets you spawn NPCs, swap character appearances, teleport around Night City, trigger animations and much more directly from an in-game menu. This repository contains the compiled AMM release along with optional addons used by the mod.

## Repository contents

- `Release/` – the compiled AMM release files.  Copy this directory into your game folder to install the mod.
- `Optional/` – extra archives and collab presets that add optional functionality.
- `Resources/` – helper files such as a list of entity records.
- `docs/` – generated documentation with AMM internal data.
- `.github/workflows/` – CI workflow used for creating GitHub releases when a tag is pushed.

## Requirements

- **Cyberpunk 2077** for PC
- [Cyber Engine Tweaks](https://github.com/yamashi/CyberEngineTweaks)
- `lua5.4` or a compatible Lua runtime for development

## Installation

1. Install Cyber Engine Tweaks if you haven't already.
2. Copy the contents of the `Release` folder into your Cyberpunk 2077 installation directory.  The folder structure should remain intact so that the mod resides under `bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceMenuMod`.
3. (Optional) Copy any `.archive` files from `Optional` into `archive/pc/mod` to enable additional assets.
4. Launch the game and open the CET overlay (`~` by default) to access AMM.

## Development

The repository mainly contains precompiled Lua files.  If you modify any `.lua` scripts, you can verify the Lua interpreter is available by running:

```bash
lua -v
```

No automated tests are provided.  After making changes, ensure `git status` shows a clean working tree.

## Credits

See `Release/bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceMenuMod/credits.lua` for a full list of contributors and community shout‑outs.

## License

This repository mirrors the public Appearance Menu Mod release.  Please refer to the official mod page for license and usage terms.
