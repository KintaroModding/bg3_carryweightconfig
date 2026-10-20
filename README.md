# Carry Weight Config

Sets your party's carry weight limit with a multiplier in the Mod Configuration Menu: 1.0 is the game's limit, 2.0 twice as much.

A mod for Baldur's Gate 3 (Patch 8), made with game version 4.1.1.7398727. It needs
[Norbyte's Script Extender](https://github.com/Norbyte/bg3se) and the
[Mod Configuration Menu](https://github.com/AtilioA/BG3-MCM) (MCM) 1.41. This README is for developers. What the mod
does, how to install it and its compatibility are in [openmods.md](openmods.md), the mod page on
[openmods](https://openmods.nexus).

## How it works

- The MCM setting `carry_multiplier` (`slider_float`, 1.0 to 10.0, default 2.0) is the factor. `Server/Carry.lua`
  rounds it to two decimals, clamps it to the slider range, and gives every party member (`DB_Players`) and camp
  companion (`DB_PartOfTheTeam`), without summons, the game's boost `CarryCapacityMultiplier(<factor>)` with
  `Osi.AddBoosts(character, boost, "bg3_carryweightconfig", NULL)`. For 1.0 it gives no boost.
- The boost text each character got is kept in the mod variable `AppliedBoosts` (saved with the game,
  `Shared/Vars.lua`), so that a change removes exactly the old boost (`Osi.RemoveBoosts`) before it adds the new one,
  also for characters that left the team.
- It applies on `SessionLoaded`, `LevelGameplayStarted`, `CharacterJoinedParty`, `CharacterLeftParty` and after each
  MCM change or profile switch; characters whose boost is already right are left alone.
- A second after a change, `server.log` lists the weights the game computed (`EncumbranceStats`, in kg).
- Per bg3.wiki, carry weight boosts do not add up: only the highest one counts (except Human Versatility and Vaprak's
  Greed). The limit is (40 + 10 x Strength) kg (`CarryWeightBase`, `CarryLimitMultiplier` in `Data.txt`); the boost
  multiplies it.

## Settings

The Mod Configuration Menu shows the settings of `MCM_blueprint.json`. `Shared/Settings.lua` reads them:
`Settings.Get(id)` returns the value and its source (`MCM` or `default`), and `Settings.OnChange(fn)` reports a change
or an MCM profile switch. Without MCM (missing, or loaded after this mod) the values of `Settings.Defaults` apply. The
tests check that `Settings.Defaults` and the blueprint list the same settings with the same defaults. `meta.lsx` lists
MCM 1.41.0.0 (`755a8a72-407f-4f0d-9a33-274ac0f0b53d`) as a dependency, so the mod managers load MCM first; only then
does MCM put its `MCM` table into this mod. The setting ids are part of the players' saved settings: never rename one
after a release.

## Build

Requirements: Windows PowerShell and [LSLib](https://github.com/Norbyte/lslib/releases) (`Divine.exe`).
`build.ps1` looks for `_tools\lslib\Packed\Tools\Divine.exe` in the parent folders of the project; set `BG3_TOOLS` to
a folder that holds `lslib\` to use another place.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1             # dist\bg3_carryweightconfig.pak
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy     # build, then copy the .pak to the Mods folder
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Wait      # copy the .pak when the game is closed
```

`deploy.ps1` copies the .pak to the `Mods` folder below `BG3_DATA_DIR` (the BG3 user-data folder), else to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`; `-ModsDir` overrides both. The running game locks the .pak, so
the script stops (exit code 2) or, with `-Wait`, waits until the game is closed.

## Project layout

```
src/                                     Mod files (packed into the .pak)
  Mods/bg3_carryweightconfig/meta.lsx           Mod metadata (UUID 1f7fa506-b6b0-4f16-a067-e6388070f041), MCM dependency
  Mods/bg3_carryweightconfig/MCM_blueprint.json The Mod Configuration Menu page (the settings)
  Mods/bg3_carryweightconfig/ScriptExtender/
    Config.json
    Lua/BootstrapServer.lua              Server entry point
    Lua/BootstrapClient.lua              Client entry point
    Lua/Shared/Common.lua                Shared helpers (mod version)
    Lua/Shared/FileWriter.lua            Throttled file output in the Script Extender folder
    Lua/Shared/Settings.lua              MCM settings with defaults (Settings.Defaults)
    Lua/Shared/Vars.lua                  The mod variable AppliedBoosts (registered in both contexts)
    Lua/Server/Carry.lua                 The carry weight boosts
    Lua/Server/ServerLog.lua             server.log
    Lua/Client/ClientLog.lua             client.log
docs/                                    Cover and screenshots for openmods.md
tests/                                   Offline tests (Lua 5.4 through lupa)
scripts/bump_version.py                  Raises the last version digit in meta.lsx
scripts/show_log.py                      Prints the mod's log files and MCM settings
build.ps1                                Builds dist/bg3_carryweightconfig.pak from src/ (.loca.xml -> .loca, .lsf.lsx -> .lsf)
deploy.ps1                               Copies the .pak to the Mods folder
openmods.json, openmods.md               Data and mod page for openmods.nexus
```

Versioning: every change raises the last version digit (1.0.0.0 -> 1.0.0.1):

```powershell
python scripts\bump_version.py           # both Version64 values in meta.lsx
python scripts\bump_version.py --show
```

Logs: the mod writes `server.log` and `client.log` to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\bg3_carryweightconfig\`. Each load writes a line like
`Carry Weight Config 1.0.0.1 loaded.`, so the logs show which version runs, and server.log gets a line with every
setting, for example `Settings: carry_multiplier = 2.0 (MCM).`. Each apply writes a line such as `Setting changed:
multiplier 2.50 (MCM), boost CarryCapacityMultiplier(2.50): 3 changed, ...`. MCM stores the settings in
`Script Extender\BG3MCM\Profiles\<Profile>\bg3_carryweightconfig\settings.json`. `python scripts\show_log.py` prints the
newest log lines and these settings (from `BG3_DATA_DIR`, if set).

Tests:

```powershell
python -m pip install lupa
python tests\run_tests.py
```

The tests run every mod script against mocks of the Script Extender API (`tests/harness.lua`). The IMGUI, audio and
resource mocks are checked against the Script Extender IDE helpers (`tests/gen_extui_api.py` refreshes
`tests/extui_api.json`), so a property or method that does not exist in the real API fails the tests.

## License

MIT, see [LICENSE](LICENSE).
