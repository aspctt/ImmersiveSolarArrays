# Immersive Solar Arrays checks

Static checks that run against the installed copy of the game, without launching it.

```bash
pwsh tests/run-checks.ps1
```

Set `ISA_PZ_DIR` if the script cannot find the install on its own. A JDK is needed;
the JRE the game ships cannot compile the Lua checker.

## What it does

**Pass zero, the API list.** `harness/DumpApi.java` writes every public method name in
`projectzomboid.jar` to `build/api-names.txt`, rebuilt whenever the game updates. Around
50,000 names from 23,000 classes.

**Pass one, syntax.** `projectzomboid.jar` contains Kahlua, the Lua 5.1 VM the game runs
mods on. `harness/CheckLua.java` boots that compiler outside the game and parses every
mod Lua file with it. Because it is the shipped compiler, the check tracks the game
rather than a hand written imitation.

**Pass two, cross-reference.** `harness/check.py` reads the mod against the installed
build. None of what it looks for crashes at load, which is exactly why it is worth
checking: a missing translation renders as its own key, a wrong texture path draws
nothing, and a tag no item carries makes a recipe quietly impossible to perform.

| Check | Why it exists |
| --- | --- |
| `translation-key` | Every literal `getText("...")` resolves, in the mod's English JSON or the game's. Build 42 reads only `Translate/<LANG>/<File>.json`; the build 41 `.txt` tables are not loaded at all, so the whole mod rendered as raw keys. |
| `translation-extra` | A language carries a key English does not, which usually means a stale entry nothing reads. Missing keys are reported as a note rather than a failure. |
| `texture-path` | Every `getTexture` path resolves. The engine drops the extension and every directory first, asks the texture packs for the bare name, and only then looks for a file, so this follows the same order across the mod's packs, the mod's trees, the game's packs and the game's `media`. |
| `item-icon` | `Icon = X` is half a name. The engine wants `Item_X` and quietly draws a question mark when nothing has it. |
| `model-texture` | A model texture is loose rather than packed. A model binds its texture whole and samples it with uvs that run 0 to 1 across the whole image, so a packed one draws a slice of every other sprite on that page, with no error anywhere. |
| `pack-format` | Every `.pack` in the mod parses. Both layouts are read: the newer one opens with `PZPK` and puts a length in front of each page's image, the older one ends each image with `EF BE AD DE` instead. |
| `item-legacy-field` | `Type`, `DisplayName` and `TeachedRecipes` are build 41 fields. `Type` is not parsed at all now, which leaves `getItemType()` null. |
| `item-type` | `ItemType` is one of the values the engine actually defines. |
| `item-tag` | Item tags are namespaced. Tag strings are compared literally after lowercasing, so a bare `Generator` matches nothing. |
| `recipe-tag` | Every `tags[...]` query in a recipe names a tag some item carries. |
| `recipe-item` | Every recipe input and output is a real script item. |
| `recipe-hook` | `OnCreate` and `OnTest` point at something the mod defines, or at one of the engine's exposed classes. |
| `recipe-name` | A recipe name doubles as its translation key, so each one has a `Recipes.json` entry. |
| `learned-recipe` | A magazine only teaches recipes that exist. |
| `sandbox-type` | Option types are among the five the parser accepts. |
| `sandbox-label` | Every option, page and enum value has its label in `Sandbox.json`. Neither mistake crashes: the option is silently dropped or renders as a raw key. |
| `sandbox-var` | Every `SandboxVars.ISA.x` the Lua reads is a declared option. |
| `method-name` | Every `:name(` is a method this build exposes, a function the mod or game defines in Lua, or a Lua string method. `PropertyContainer.Is` and `.Val` were real in build 41 and are gone in build 42; Lua calling a method that is not there does not fail until the line runs, so placing a battery bank threw every single time and nothing noticed until the game did. Names only, not per class, since a call site does not say what type it is calling on. |
| `require-path` | Every `require` resolves to a Lua file in the mod or the game. Case matters on Linux servers, and the build 41 tree had several that pointed at moved files. |
| `require-undeclared` | A require into a separate mod is only allowed while `mod.info` still names that mod in `require=` or `loadModAfter=`, so dropping the dependency cannot go unnoticed. Which of the two matters: `require=` makes this mod unavailable when the other is absent, and the mod selector then refuses to activate it without saying why, so an optional dependency belongs in `loadModAfter=`. |

## Calibration

Run the same checks against `original-mods/`, which holds the unmodified upstream copy:

```bash
python tests/harness/check.py "<game dir>" "original-mods/Immersive Solar Arrays/mods/ImmersiveSolarArrays/42.1" "original-mods/Immersive Solar Arrays/mods/ImmersiveSolarArrays/common"
```

That reports around 165 problems, which is what these checks were written from. The
current tree reports none.
