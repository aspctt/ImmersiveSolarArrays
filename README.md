Immersive Solar Arrays
======================

Harvest solar power for the needs of your base. Wire car batteries into a battery
bank, put panels on the roof, and run your fridges and freezers off the sun
instead of a generator that has to be fed.

This is a fork of RadX5 and Poltergeist's mod, rebuilt for build 42. Support for
build 41 has been dropped. Most of the work was not porting features across but
fixing ones that had quietly stopped doing anything, because almost nothing that
broke in build 42 breaks loudly.

**Build 42.20+ | Singleplayer and multiplayer**


What it does
------------

- **Battery banks** - Wire car batteries, build a bank, and it powers everything
  a generator would, in the same radius, without fuel.

- **Solar panels** - Flat, wall mounted and floor mounted. Connect them to a bank
  and they charge it through the day. Cloud, fog, temperature and the length of
  the day all move the number.

- **Status window** - The summary tab says whether the panels are keeping up and
  how long the charge lasts at the current draw. The details tab lists what is
  actually pulling power.

- **Generator backup** - A generator plugged in near a bank becomes its backup.
  Put a failsafe trigger on the generator's square and the bank starts it when
  the charge runs low, then stops it once it has caught up.

- **Loot and world spawns** - Panels, batteries, inverters and the skill magazine
  spawn in the containers you would expect. Pre-placed crates and battery banks
  appear around the map, and five stash houses hide a solar cache behind an
  annotated map.

- **Sandbox options** - Panel efficiency, battery wear, DIY battery capacity,
  charge frequency, how power draw is calculated, loot rarity per item group,
  world spawns and stash houses.


Putting one up
--------------

Panels and battery banks are moveables, not build menu entries, so nothing from
this mod appears under construction. The order is:

1. Craft a panel from the crafting menu. The loose solar panel you find as loot
   is a part, not something you can install. Turn it into a roof tile, a wall
   panel or a floor panel first.
2. Put the crafted panel in your main inventory. Not in a bag and not in your
   hands, or the option below will not show.
3. Right click it and choose **Place Object**, then place it outdoors.
4. Right click the battery bank, pick **Connect panels**, and click the panel.

You need a screwdriver on you and Electrical 3 to place a panel or pick one back
up, which is the same requirement as the crafting recipes.


What is fixed in this fork
--------------------------

Every one of these was silent. The mod loaded, showed up in the mod list, and did
the wrong thing without writing anything to the log.

- **Translations** - Build 42 reads only `Translate/<LANG>/<File>.json`. The mod
  shipped build 41 `.txt` tables, which are not loaded at all, so every string in
  it rendered as its own key. Converted across all 27 languages.

- **Items** - `Type =` is not parsed in build 42, which left every item with a
  null item type. Rewritten to `ItemType = base:*`, with `LearnedRecipes` in
  place of `TeachedRecipes` and namespaced tags.

- **Recipes** - Tag queries are matched literally, so `tags[Screwdriver]` matched
  nothing and every recipe asking for one was impossible to perform. The recipe
  hooks pointed at a global table build 42 deleted. Both rewritten, hooks against
  the current `OnCreate(craftRecipeData, character)` signature.

- **Loot tables** - A misspelt field name meant a weight went into vanilla item
  lists with no item name in front of it, shifting every name and weight pair
  after it. This corrupted the base game's own loot, not just the mod's.

- **Stash houses** - Errored on load, taking all five with them, and gave their
  containers coordinates under names the engine does not read.

- **Multiplayer** - Plugging a generator, flipping the bank switch, connecting a
  panel and moving a battery all reached into the server system, which does not
  exist on a multiplayer client. They travel as commands now.

- **Smaller things** - Three requires pointing at moved or wrongly cased files,
  an item type in the wrong module, a typo that stopped battery banks spawning in
  rooms, stash maps drawn without their street names, and several nil
  dereferences on unloaded squares.


Installing
----------

Copy `ImmersiveSolarArrays/Contents/mods/ImmersiveSolarArrays` into your Zomboid
`mods` folder. Only run one version of this mod; the mod id is `ISA`.

**Target Square: On Load Commands** is needed for the pre-placed crates that spawn
around the map. Without it everything else still works, you just do not get those
crates. It is safe to add or remove on an existing save. Get it from the
[Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2969455858).

Some options need a game reload, and stash houses want a new save to appear
properly. Test on a save you are willing to lose before adding it to a long
running one.


Checks
------

```
pwsh tests/run-checks.ps1
```

Compiles every Lua file with the Kahlua compiler out of `projectzomboid.jar`, the
same one the game uses, then cross-references the mod against the installed build:
translation keys, texture paths, item script fields, recipe inputs and hooks,
sandbox options and requires.

Nothing it looks for crashes at load, which is the point. See
[tests/README.md](tests/README.md) for what each check exists to catch.


Textures
--------

Everything the mod draws through the sprite renderer ships in one file,
`common/media/texturepacks/solarmod_tileset.pack`: the tiles, the UI icons and the
item icons. Source art for the icons lives in `tools/textures`.

```
python tools/pack_textures.py
```

Rebuilds the pack from the tiles already in it plus every PNG in that folder. A
sprite is named after the file it replaces, which is all the engine looks at, so
nothing in the Lua or the item scripts refers to a path any more.

The two model textures stay loose in `common/media/textures`. A model binds its
texture whole and samples it with uvs that run across the entire image, so a
packed one would draw a slice of every other sprite on the page.


Credits
-------

Original mod by RadX5 and Poltergeist, with thanks to everyone who contributed to
it over the years, translators included.

Licensed under the Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Original: https://github.com/radx5Blue/ImmersiveSolarArrays
