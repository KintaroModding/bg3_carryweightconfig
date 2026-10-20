# Carry Weight Config

Sets your party's carry weight limit with a multiplier in the Mod Configuration Menu: 1.0 is the game's limit, 2.0 twice as much.

## What it does

- Multiplies the carry weight limit of all your party members and camp companions with a value that you set in
  the Mod Configuration Menu: 1.0 is the game's limit, 2.0 twice as much, up to 10.0. Values down to 0.25 make the
  game harder. The default is 2.0.
- A change applies at once, also during a game. New party members get it when they join.
- It uses the game's own carry weight boost (the one of Bull's Strength and Enlarge), so the game computes the limits
  as usual. NPCs and enemies keep the game's limits.

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
- **Carry weight multiplier** (default 2.0, from 0.25 to 10.0): the factor for the carry weight limit. 1.0 gives the
  game's limit, values below 1.0 a smaller one. A change applies at once.
- In multiplayer, the host's setting counts for all players.
- The Mod Configuration Menu stores the settings in its profile, not in the savegame.

## Compatibility

- Game version: Patch 8
- Carry weight boosts in the game do not add up: only the highest one counts (per bg3.wiki, except Human Versatility
  and Vaprak's Greed). With 2.5 set, Bull's Strength (2.0) adds nothing more; with 1.5 set, Bull's Strength still
  gives 2.0 while it lasts. The same rule works for low values: with 0.5 set, even Reduce (0.75) raises the limit to
  0.75 while it lasts.
- Mods that change the carry weight values in `Data.txt` work together with this one: the multiplier applies to the
  limit that they set.

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
