# Carry Weight Config

Sets your party's carry weight limit with a multiplier in the Mod Configuration Menu: 1.0 is the game's limit, 2.0 twice as much.

## What it does

- Multiplies the carry weight limit with a value that you set in the Mod Configuration Menu: 1.0 is the game's
  limit, 2.0 twice as much, up to 90.0. Values down to 0.25 make the game harder. The default is 2.0.
- It changes the game's own carry values (the ones that a `Data.txt` mod changes) while the game runs, so the limit
  counts for every character, NPCs too, and the Encumbered thresholds move with it.
- A change applies at once, also during a game.

## Screenshots

![Carry Weight Config cover](docs/cover.png)

## How to install

1. Install [Norbyte's Script Extender](https://github.com/Norbyte/bg3se). It updates itself.
2. Install the [Mod Configuration Menu](https://github.com/KintaroModding/bg3_mcm/releases/latest), version 1.41 or
   later. The official Mod Configuration Menu 1.41 or later works too; keep only one of them.
3. Download `bg3_carryweightconfig.pak` from the latest release on GitHub.
4. Copy it to `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`.
5. Enable **Carry Weight Config** in your mod manager (BG3 Mod Manager or the in-game mod manager), below the Mod
   Configuration Menu.

To update the mod, replace the `.pak` with the one from the new release. To remove it, disable it in the mod manager
and delete the `.pak`. Saves made with the mod can then show a warning about a missing mod.

## How to use

- Open the Mod Configuration Menu (main menu, Esc menu, or the Insert key) and select **Carry Weight Config**.
- **Carry weight multiplier** (default 2.0, from 0.25 to 90.0): the factor for the carry weight limit. 1.0 gives the
  game's limit, values below 1.0 a smaller one. A change applies at once.
- In multiplayer, the host's setting counts for all players.
- The Mod Configuration Menu stores the settings in its profile, not in the savegame.

## Compatibility

- Game version: Patch 8
- The game's carry boosts (Bull's Strength, Enlarge, Human Versatility, ...) work as usual on top of the limit that
  this mod sets.
- Mods that change the carry weight values in `Data.txt` work together with this one: the multiplier applies to the
  values that they set.

## Known issues

None yet.

## How to build

Anyone can build this mod from its source code and check that the download matches it.

1. Install the tools: Windows PowerShell 5.1 (part of Windows) and [LSLib](https://github.com/Norbyte/lslib/releases)
   v1.20.4. Put LSLib into a folder `_tools\lslib\` above the repository, or set `BG3_TOOLS` to the folder that holds
   `lslib\`.
2. Build it: `powershell -ExecutionPolicy Bypass -File .\build.ps1`
3. Find the file: `dist\bg3_carryweightconfig.pak`

The offline tests need Python 3 with lupa: `python -m pip install lupa`, then `python tests\run_tests.py`.

## Credits

Made by Kintaro. MIT license: you may use, change and share this mod.
