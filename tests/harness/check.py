"""Static checks for Immersive Solar Arrays against the installed build 42.

Every check here exists because the mistake it catches was actually shipped, and because
none of them crash at load: a missing translation renders as its own key, a bad texture
path draws nothing, a tag nothing carries makes a recipe quietly impossible to perform.

Usage: python check.py <gameDir> <modRoot> [<modRoot> ...]
"""
import json
import os
import re
import struct
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

GAME = sys.argv[1]
NEWLINE = b"\x0a"
MOD_ROOTS = sys.argv[2:]

problems = []
notes = []
counts = {}


def counted(name, n=1):
    counts[name] = counts.get(name, 0) + n


def fail(check, message):
    problems.append("%-22s %s" % (check, message))


def note(message):
    notes.append(message)


def walk(root, suffix):
    for base, _dirs, files in os.walk(root):
        for name in files:
            if name.endswith(suffix):
                yield os.path.join(base, name)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def rel(path):
    for root in MOD_ROOTS:
        parent = os.path.dirname(os.path.normpath(root))
        if os.path.normpath(path).startswith(os.path.normpath(root)):
            return os.path.relpath(path, parent).replace("\\", "/")
    return path


# Comments routinely name a retired key or an old field to explain why it is gone, so
# every source scan drops them first.
def strip_lua_comments(text):
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def strip_script_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


MOD_LUA = []
MOD_SCRIPTS = []
for root in MOD_ROOTS:
    MOD_LUA.extend(sorted(walk(root, ".lua")))
    MOD_SCRIPTS.extend(sorted(p for p in walk(os.path.join(root), ".txt")
                              if os.sep + "scripts" + os.sep in p))


# Nothing to check means the paths are wrong, not that the mod is clean. Reporting
# success over an empty scan is how a moved folder hides every other check here.
if not MOD_LUA:
    fail("no-input", "no lua files under: %s" % ", ".join(MOD_ROOTS))
if not MOD_SCRIPTS:
    fail("no-input", "no script files under: %s" % ", ".join(MOD_ROOTS))


# ---------------------------------------------------------------------------------------
# Translations

def load_json_dir(path):
    table = {}
    if not os.path.isdir(path):
        return table
    for name in sorted(os.listdir(path)):
        if not name.endswith(".json"):
            continue
        try:
            data = json.loads(read(os.path.join(path, name)))
        except ValueError as exc:
            fail("translation-json", "%s is not valid json: %s" % (name, exc))
            continue
        if isinstance(data, dict):
            table.update(data)
    return table


game_en = load_json_dir(os.path.join(GAME, "media", "lua", "shared", "Translate", "EN"))

mod_translate_dirs = []
for root in MOD_ROOTS:
    candidate = os.path.join(root, "media", "lua", "shared", "Translate")
    if os.path.isdir(candidate):
        mod_translate_dirs.append(candidate)

mod_en = {}
for directory in mod_translate_dirs:
    mod_en.update(load_json_dir(os.path.join(directory, "EN")))

known_text = set(game_en) | set(mod_en)

# getText with a literal key. Anything built at runtime is skipped rather than guessed at.
GETTEXT = re.compile(r'getText\(\s*"([^"]+)"')
for path in MOD_LUA:
    body = strip_lua_comments(read(path))
    for key in set(GETTEXT.findall(body)):
        counted("getText keys")
        if key not in known_text:
            fail("translation-key", "%s: getText(\"%s\") has no entry" % (rel(path), key))

# The game runs every translated string through String.format, so a lone % is an invalid
# conversion and the whole string fails to render.
for directory in mod_translate_dirs:
    for path in walk(directory, ".json"):
        try:
            data = json.loads(read(path))
        except ValueError:
            continue
        for key, value in data.items():
            if not isinstance(value, str):
                continue
            for match in re.finditer(r"%(.)", value):
                if match.group(1) not in "123456789%s":
                    note("%s: %s has a bare %% (the game escapes it, but logs a warning)"
                         % (rel(path), key))
                    break

# Every language should carry the same keys as English.
for directory in mod_translate_dirs:
    english = load_json_dir(os.path.join(directory, "EN"))
    for lang in sorted(os.listdir(directory)):
        langdir = os.path.join(directory, lang)
        if not os.path.isdir(langdir) or lang == "EN":
            continue
        other = load_json_dir(langdir)
        missing = set(english) - set(other)
        extra = set(other) - set(english)
        if missing:
            note("%s is missing %d key(s) English has" % (lang, len(missing)))
        if extra:
            fail("translation-extra", "%s has %d key(s) English does not: %s"
                 % (lang, len(extra), ", ".join(sorted(extra)[:4])))


# ---------------------------------------------------------------------------------------
# Textures
#
# getSharedTexture throws the path away before it looks anything up. It drops a .png
# extension and every directory, asks the texture packs for the bare name left over, and
# only falls back to a file on disk when no pack claims it. A path ending in .txt or
# containing /mods/ skips the pack lookup entirely.
#
# So a texture moves into a .pack with no code change, and a name with no directory at
# all resolves against media/textures, which is where an item Icon and a model texture
# both land.


def pack_sprites(path):
    """Sprite names in one .pack, without decoding any of the images.

    Two layouts. The newer one opens with "PZPK" and a version, and puts a byte length in
    front of each page's image. The older one opens straight at the page count and ends
    each image with the four bytes EF BE AD DE instead, which is why the game scans for
    them a byte at a time.
    """
    names = []
    with open(path, "rb") as fh:
        def read_int():
            raw = fh.read(4)
            if len(raw) < 4:
                raise EOFError("ran out of file")
            return int.from_bytes(raw, "little")

        version = 0
        if fh.read(4) == b"PZPK":
            version = read_int()
        else:
            fh.seek(0)

        for _ in range(read_int()):
            fh.read(read_int())                 # page name
            count = read_int()
            read_int()                          # alpha flag
            for _ in range(count):
                names.append(fh.read(read_int()).decode("latin-1"))
                fh.seek(32, 1)                  # x, y, w, h, offX, offY, cellW, cellH
            if version:
                fh.seek(read_int(), 1)          # the page's png
            else:
                carry = b""
                while True:
                    chunk = fh.read(1 << 16)
                    if not chunk:
                        raise EOFError("no end-of-image marker")
                    at = (carry + chunk).find(b"\xef\xbe\xad\xde")
                    if at != -1:
                        fh.seek(at + 4 - len(carry) - len(chunk), 1)
                        break
                    carry = chunk[-3:]
    return names


# The mod's own packs first, so a name it defines is reported against the mod rather than
# against whichever base game pack happens to share it.
PACK_FILES = []
for root in MOD_ROOTS:
    PACK_FILES.extend(sorted(walk(os.path.join(root, "media", "texturepacks"), ".pack")))
MOD_PACK_COUNT = len(PACK_FILES)

game_packs = os.path.join(GAME, "media", "texturepacks")
if os.path.isdir(game_packs):
    PACK_FILES.extend(sorted(os.path.join(game_packs, name)
                             for name in os.listdir(game_packs) if name.endswith(".pack")))

PACK_SPRITES = {}
MOD_SPRITES = set()
for index, path in enumerate(PACK_FILES):
    try:
        sprites = pack_sprites(path)
    except (EOFError, ValueError, UnicodeDecodeError) as exc:
        fail("pack-format", "%s: could not be read (%s)" % (rel(path), exc))
        continue
    if index < MOD_PACK_COUNT:
        counted("packed sprites", len(sprites))
        MOD_SPRITES.update(sprites)
    for sprite in sprites:
        PACK_SPRITES.setdefault(sprite, os.path.basename(path))


def texture_sprite(path):
    """The pack sprite a texture path resolves to, or None if it skips the packs."""
    path = path.replace("\\", "/")
    if path.endswith(".txt") or "/mods/" in path:
        return None
    if path.endswith(".png"):
        path = path[:path.rindex(".")]
    return path[path.rfind("/") + 1:]


def texture_file(path):
    """The loose file a texture path falls back to, or None."""
    path = path.replace("\\", "/")
    if not path.lower().startswith("media/"):
        path = "media/textures/" + path + ".png"
    parts = path.split("/")
    for root in MOD_ROOTS:
        candidate = os.path.join(root, *parts)
        if os.path.exists(candidate):
            return candidate
    candidate = os.path.join(GAME, *parts)
    return candidate if os.path.exists(candidate) else None


def texture_exists(path):
    sprite = texture_sprite(path)
    return (sprite in PACK_SPRITES) or texture_file(path) is not None


GETTEXTURE = re.compile(r'getTexture\(\s*"([^"]+)"')
for path in MOD_LUA:
    body = strip_lua_comments(read(path))
    for texture in sorted(set(GETTEXTURE.findall(body))):
        counted("getTexture paths")
        if not texture_exists(texture):
            fail("texture-path", "%s: getTexture(\"%s\") does not resolve" % (rel(path), texture))


# Icon = X is only ever half a name. The engine looks for Item_X, in the packs first and
# then in media/textures, and quietly substitutes a question mark when neither has it.
ICON = re.compile(r"^\s*Icon\s*=\s*([^,\n]+?)\s*,", re.M)
for path in MOD_SCRIPTS:
    body = strip_script_comments(read(path))
    for icon in sorted(set(ICON.findall(body))):
        counted("item icons")
        if not texture_exists("Item_" + icon):
            fail("item-icon", "%s: Icon = %s has no Item_%s in the mod, a pack or the game"
                 % (rel(path), icon, icon))


# A model binds its texture whole and samples it with the mesh's own uvs, which run 0 to 1
# across the entire image. Point one at a packed sprite and it draws a slice of every
# other sprite on that page instead, without an error anywhere. Model textures stay loose,
# which is also why the base game ships its world item textures as thousands of files.
MODEL_TEXTURE = re.compile(r"^\s*texture\s*=\s*([^,\n]+?)\s*,", re.M)
for path in MOD_SCRIPTS:
    body = strip_script_comments(read(path))
    for texture in sorted(set(MODEL_TEXTURE.findall(body))):
        counted("model textures")
        sprite = texture_sprite(texture)
        if sprite in MOD_SPRITES:
            fail("model-texture", "%s: texture = %s is packed in %s, so the model would "
                 "sample the whole atlas" % (rel(path), texture, PACK_SPRITES[sprite]))
        elif texture_file(texture) is None:
            fail("model-texture", "%s: texture = %s resolves to no file" % (rel(path), texture))


# ---------------------------------------------------------------------------------------
# Item scripts

VALID_ITEM_TYPES = set()
for path in walk(os.path.join(GAME, "media", "scripts"), ".txt"):
    for match in re.finditer(r"ItemType\s*=\s*([a-z]+:[a-z]+)", read(path)):
        VALID_ITEM_TYPES.add(match.group(1))

known_tags = set()
known_items = set()


def scan_items(text, module_default="Base"):
    module = module_default
    for line in text.splitlines():
        module_match = re.match(r"\s*module\s+([A-Za-z0-9_]+)", line)
        if module_match:
            module = module_match.group(1)
        item_match = re.match(r"\s*item\s+([A-Za-z0-9_ .\-]+?)\s*$", line)
        if item_match:
            known_items.add("%s.%s" % (module, item_match.group(1)))
        tag_match = re.match(r"\s*Tags\s*=\s*(.+?),?\s*$", line)
        if tag_match:
            for tag in tag_match.group(1).split(";"):
                known_tags.add(tag.strip().lower())


for path in walk(os.path.join(GAME, "media", "scripts"), ".txt"):
    scan_items(read(path))
for path in MOD_SCRIPTS:
    scan_items(strip_script_comments(read(path)))

LEGACY_ITEM_KEYS = {
    "Type": "build 42 does not parse it, leaving getItemType() null",
    "DisplayName": "ignored in build 42, names come from ItemName.json",
    "TeachedRecipes": "renamed to LearnedRecipes",
}

for path in MOD_SCRIPTS:
    body = strip_script_comments(read(path))
    for key, why in LEGACY_ITEM_KEYS.items():
        for match in re.finditer(r"^\s*%s\s*=" % key, body, flags=re.M):
            line = body[:match.start()].count("\n") + 1
            fail("item-legacy-field", "%s:%d: %s is a build 41 field, %s"
                 % (rel(path), line, key, why))
    for match in re.finditer(r"ItemType\s*=\s*([^,\n]+)", body):
        counted("item scripts")
        value = match.group(1).strip()
        if value not in VALID_ITEM_TYPES:
            fail("item-type", "%s: ItemType = %s is not one of the engine's"
                 % (rel(path), value))
    for block in re.finditer(r"^\s*item\s+[A-Za-z0-9_ .\-]+?\s*$\s*\{(.*?)^\s*\}",
                             body, flags=re.M | re.S):
        counted("item tag lines")
        for match in re.finditer(r"^\s*Tags\s*=\s*(.+?),?\s*$", block.group(1), flags=re.M):
            for tag in match.group(1).split(";"):
                tag = tag.strip()
                if ":" not in tag:
                    fail("item-tag", "%s: tag %r is not namespaced, so it matches nothing"
                         % (rel(path), tag))


# ---------------------------------------------------------------------------------------
# Craft recipes

lua_body = "\n".join(strip_lua_comments(read(p)) for p in MOD_LUA)

for path in MOD_SCRIPTS:
    body = strip_script_comments(read(path))
    if "craftRecipe" not in body:
        continue

    for match in re.finditer(r"tags\[([^\]]+)\]", body):
        counted("recipe tag queries")
        for tag in match.group(1).split(";"):
            tag = tag.strip().lower()
            if tag not in known_tags:
                fail("recipe-tag", "%s: no item carries tag %r" % (rel(path), tag))

    for match in re.finditer(r"item\s+[\d.]+\s+\[([^\]]+)\]", body):
        for fulltype in match.group(1).split(";"):
            fulltype = fulltype.strip()
            if fulltype and fulltype not in known_items:
                fail("recipe-item", "%s: input %s is not a script item" % (rel(path), fulltype))

    for match in re.finditer(r"item\s+[\d.]+\s+([A-Za-z0-9_]+\.[A-Za-z0-9_]+)\s*,", body):
        fulltype = match.group(1)
        if fulltype not in known_items:
            fail("recipe-item", "%s: output %s is not a script item" % (rel(path), fulltype))

    # OnCreate / OnTest must resolve to something. A mod owned table has to be defined in
    # the mod's own Lua; anything else is assumed to be one of the engine's exposed
    # classes and left alone.
    for hook in ("OnCreate", "OnTest"):
        for match in re.finditer(r"%s\s*=\s*([A-Za-z0-9_.]+)" % hook, body):
            target = match.group(1)
            head = target.split(".")[0]
            if head in ("RecipeCodeOnCreate", "RecipeCodeOnTest", "ItemCodeOnCreate",
                        "BuildRecipeCode"):
                continue
            leaf = target.split(".")[-1]
            if not re.search(r"function\s+%s\s*\(" % re.escape(target), lua_body) \
               and not re.search(r"%s\s*=\s*function" % re.escape(target), lua_body) \
               and not re.search(r"\b%s\b" % re.escape(leaf), lua_body):
                fail("recipe-hook", "%s: %s = %s is not defined in the mod's Lua"
                     % (rel(path), hook, target))

    # Recipe names double as translation keys.
    for match in re.finditer(r"^\s*craftRecipe\s+([A-Za-z0-9_]+)", body, flags=re.M):
        counted("craft recipes")
        name = match.group(1)
        if name not in known_text:
            fail("recipe-name", "%s: craftRecipe %s has no Recipes.json entry"
                 % (rel(path), name))

# Recipes a magazine teaches have to exist.
recipe_names = set()
for path in MOD_SCRIPTS:
    body = strip_script_comments(read(path))
    recipe_names.update(re.findall(r"^\s*craftRecipe\s+([A-Za-z0-9_]+)", body, flags=re.M))

game_recipe_names = set()
for path in walk(os.path.join(GAME, "media", "scripts"), ".txt"):
    game_recipe_names.update(re.findall(r"^\s*craftRecipe\s+([A-Za-z0-9_]+)", read(path), flags=re.M))

for path in MOD_SCRIPTS:
    body = strip_script_comments(read(path))
    for match in re.finditer(r"LearnedRecipes\s*=\s*([^,\n]+)", body):
        for name in match.group(1).split(";"):
            name = name.strip()
            if name and name not in recipe_names and name not in game_recipe_names:
                fail("learned-recipe", "%s: LearnedRecipes names %s, which no recipe defines"
                     % (rel(path), name))


# ---------------------------------------------------------------------------------------
# Sandbox options

VALID_SANDBOX_TYPES = {"boolean", "integer", "double", "string", "enum"}

for root in MOD_ROOTS:
    path = os.path.join(root, "media", "sandbox-options.txt")
    if not os.path.exists(path):
        continue
    body = strip_script_comments(read(path))

    for match in re.finditer(r"option\s+([A-Za-z0-9_.]+)\s*\{(.*?)\}", body, flags=re.S):
        counted("sandbox options")
        name, block = match.group(1), match.group(2)

        type_match = re.search(r"type\s*=\s*([a-z]+)", block)
        if not type_match:
            fail("sandbox-type", "%s: option %s has no type" % (rel(path), name))
        elif type_match.group(1) not in VALID_SANDBOX_TYPES:
            fail("sandbox-type", "%s: option %s has type %s, which the parser rejects"
                 % (rel(path), name, type_match.group(1)))

        page_match = re.search(r"page\s*=\s*([A-Za-z0-9_]+)", block)
        if page_match and ("Sandbox_" + page_match.group(1)) not in known_text:
            fail("sandbox-label", "%s: page %s has no Sandbox_%s label"
                 % (rel(path), page_match.group(1), page_match.group(1)))

        translation_match = re.search(r"translation\s*=\s*([A-Za-z0-9_]+)", block)
        if not translation_match:
            fail("sandbox-label", "%s: option %s has no translation key" % (rel(path), name))
        else:
            key = "Sandbox_" + translation_match.group(1)
            if key not in known_text:
                fail("sandbox-label", "%s: option %s has no %s label" % (rel(path), name, key))

        value_match = re.search(r"valueTranslation\s*=\s*([A-Za-z0-9_]+)", block)
        count_match = re.search(r"numValues\s*=\s*(\d+)", block)
        if value_match and count_match:
            for i in range(1, int(count_match.group(1)) + 1):
                key = "Sandbox_%s_option%d" % (value_match.group(1), i)
                if key not in known_text:
                    fail("sandbox-label", "%s: option %s has no %s label"
                         % (rel(path), name, key))

# Every SandboxVars.<mod>.<name> the Lua reads has to be an option that exists.
declared = set()
for root in MOD_ROOTS:
    path = os.path.join(root, "media", "sandbox-options.txt")
    if os.path.exists(path):
        declared.update(re.findall(r"option\s+([A-Za-z0-9_.]+)", strip_script_comments(read(path))))

if declared:
    prefixes = set(name.split(".")[0] for name in declared)
    for path in MOD_LUA:
        body = strip_lua_comments(read(path))
        for match in re.finditer(r"SandboxVars\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)", body):
            group, option = match.group(1), match.group(2)
            if group in prefixes and "%s.%s" % (group, option) not in declared:
                fail("sandbox-var", "%s: SandboxVars.%s.%s is not declared"
                     % (rel(path), group, option))
        # sandbox.X, where sandbox is a local alias for SandboxVars.<group>
        alias = re.search(r"local\s+(\w+)\s*=\s*SandboxVars\.([A-Za-z0-9_]+)\s*$", body, flags=re.M)
        if alias:
            var, group = alias.group(1), alias.group(2)
            if group in prefixes:
                for match in re.finditer(r"\b%s\.([A-Za-z0-9_]+)" % re.escape(var), body):
                    option = match.group(1)
                    if "%s.%s" % (group, option) not in declared:
                        fail("sandbox-var", "%s: %s.%s is not a declared option"
                             % (rel(path), var, option))


# ---------------------------------------------------------------------------------------
# Timed actions
#
# The engine does not call a timed action's Lua complete() on a multiplayer client. In
# multiplayer the server runs its own copy of the action and its complete() is the
# authoritative one. A mod action that only exists under client/ has no server copy, so
# its complete() runs nowhere at all: the bar fills, the job ends, and nothing happens.
#
# Work belongs in perform(), which runs on whoever is performing the action either way,
# and fires just before complete() would.

for path in MOD_LUA:
    normalised = path.replace("\\", "/")
    if "/lua/client/" not in normalised:
        continue
    body = strip_lua_comments(read(path))
    if "ISBaseTimedAction:derive" not in body:
        continue
    counted("client timed actions")
    for match in re.finditer(r"function\s+([A-Za-z0-9_]+):complete\s*\(", body):
        fail("timedaction-complete",
             "%s: %s:complete() never runs, this action is client only and the engine "
             "skips complete on a multiplayer client. Move the work to perform()."
             % (rel(path), match.group(1)))


# ---------------------------------------------------------------------------------------
# Method names
#
# Every `:name(` in the mod has to be a method the engine exposes, a function the mod or
# the game defines in Lua, or a Lua string method. PropertyContainer.Is and .Val were
# real in build 41 and are gone in build 42, and Lua calling a method that is not there
# does not fail until the line runs, so placing a battery bank threw every single time
# and nothing caught it before the game did.
#
# Names only. A call site does not say what type it is calling on, so the check is
# whether the name exists anywhere in the API rather than on the right class. That still
# catches a method the engine has retired, which is the case that keeps happening.

api_names_file = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "build", "api-names.txt")
if os.path.exists(api_names_file):
    api_names = set(read(api_names_file).split())

    # Methods defined in Lua rather than by the engine, from the game and from the mod.
    lua_defined = set()
    lua_sources = list(MOD_LUA)
    for folder in ("client", "server", "shared"):
        lua_sources.extend(walk(os.path.join(GAME, "media", "lua", folder), ".lua"))
    for path in lua_sources:
        body = strip_lua_comments(read(path))
        lua_defined.update(re.findall(r"function\s+[A-Za-z0-9_.:]+[.:]([A-Za-z0-9_]+)\s*\(", body))
        lua_defined.update(re.findall(r"([A-Za-z0-9_]+)\s*=\s*function\s*\(", body))
        lua_defined.update(re.findall(r"\[\"([A-Za-z0-9_]+)\"\]\s*=\s*function", body))

    # Lua's own string methods, reachable on any string the engine hands back.
    lua_builtin = {"len", "sub", "gsub", "gmatch", "find", "match", "format", "rep",
                   "byte", "char", "lower", "upper", "reverse", "split", "trim",
                   "contains", "indexOf", "startsWith", "endsWith"}

    known_methods = api_names | lua_defined | lua_builtin
    for path in MOD_LUA:
        body = strip_lua_comments(read(path))
        for name in sorted(set(re.findall(r":([A-Za-z_][A-Za-z0-9_]*)\s*\(", body))):
            counted("method calls")
            if name not in known_methods:
                fail("method-name", "%s: :%s() is not a method this build exposes"
                     % (rel(path), name))
else:
    note("build/api-names.txt not built, method name check skipped")


# ---------------------------------------------------------------------------------------
# Stash houses
#
# A stash building and its cache crate are two points on the map written by hand, and
# neither of them fails loudly when it is wrong.
#
# StashSystem builds the crate at contX, contY, contZ with no fallback: given explicit
# coordinates it calls getGridSquare and, if that answers nil, writes one DebugLog line
# and carries on. doBuildingStash then stocks every container in the house whose type the
# spawn table names, but only where the square has a room belonging to that building. So a
# crate on a floor that does not exist never appears, and a crate outside a room appears
# empty. Either way the player walks into a stash house holding ordinary loot.
#
# Two of the five shipped that way: the Muldraugh crate sat in the gap behind its garage,
# and the Westpoint crate on a second storey the house does not have.
#
# The room rectangles come from the game's own .lotheader files, which is what the engine
# builds IsoMetaGrid from.

CELL = 256


def lotheader_rooms(path):
    """(name, level, [(x, y, w, h)]) per room, in cell local coordinates.

    LOTH, version, tile count, that many newline terminated tile names, then five ints:
    width and height in chunks, min and max level, room count. Each room is a newline
    terminated name, its level, its rectangles, then a count of objects whose records are
    a fixed width this does not need to read.
    """
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"LOTH":
        return None

    def ints(offset, n):
        return struct.unpack_from("<%di" % n, data, offset)

    p = 8
    tiles = ints(p, 1)[0]
    p += 4
    for _ in range(tiles):
        p = data.index(NEWLINE, p) + 1
    room_count = ints(p, 5)[4]
    p += 20
    if not 0 <= room_count < 20000:
        return None

    # The object record width is not written down anywhere this can read, so it is
    # derived: the only size that walks every room without running off the end or landing
    # on a nonsense rectangle is the right one. Three ints on every build seen so far.
    for width in (12, 16, 8, 20, 4):
        try:
            rooms, q = [], p
            for _ in range(room_count):
                end = data.index(NEWLINE, q)
                name = data[q:end].decode("utf-8", "replace")
                q = end + 1
                level, rect_count = ints(q, 2)
                q += 8
                if not -32 <= level <= 32 or not 0 <= rect_count < 4096:
                    raise ValueError
                rects = []
                for _ in range(rect_count):
                    x, y, w, h = ints(q, 4)
                    q += 16
                    if not (0 <= x < 4096 and 0 <= y < 4096 and 0 < w < 4096 and 0 < h < 4096):
                        raise ValueError
                    rects.append((x, y, w, h))
                objects = ints(q, 1)[0]
                q += 4
                if not 0 <= objects < 100000:
                    raise ValueError
                q += objects * width
                if q > len(data):
                    raise ValueError
                rooms.append((name, level, rects))
        except (ValueError, struct.error):
            continue
        return rooms
    return None


_cell_rooms = {}


def rooms_in_cell(cx, cy):
    key = (cx, cy)
    if key not in _cell_rooms:
        found = None
        maps = os.path.join(GAME, "media", "maps")
        if os.path.isdir(maps):
            for town in sorted(os.listdir(maps)):
                candidate = os.path.join(maps, town, "%d_%d.lotheader" % (cx, cy))
                if os.path.exists(candidate):
                    found = lotheader_rooms(candidate)
                    break
        _cell_rooms[key] = found
    return _cell_rooms[key]


def room_at(x, y, z):
    """Room name covering this world square, None for open ground, False when unreadable."""
    rooms = rooms_in_cell(x // CELL, y // CELL)
    if rooms is None:
        return False
    lx, ly = x % CELL, y % CELL
    for name, level, rects in rooms:
        if level != z:
            continue
        for rx, ry, rw, rh in rects:
            if rx <= lx < rx + rw and ry <= ly < ry + rh:
                return name
    return None


stash_file = None
for root in MOD_ROOTS:
    for path in walk(root, ".lua"):
        if os.path.basename(path) == "StashDescriptions.lua":
            stash_file = path

if stash_file:
    body = strip_lua_comments(read(stash_file))
    for block in re.split(r"Stash\.newStash\(", body)[1:]:
        name = re.search(r'name\s*=\s*"([^"]+)"', block)
        bx = re.search(r"buildingX\s*=\s*(\d+)", block)
        by = re.search(r"buildingY\s*=\s*(\d+)", block)
        if not (name and bx and by):
            continue
        name, bx, by = name.group(1), int(bx.group(1)), int(by.group(1))

        counted("stash houses")
        where = room_at(bx, by, 0)
        if where is False:
            note("no .lotheader for %s, its coordinates went unchecked" % name)
            continue
        if where is None:
            fail("stash-building",
                 "%s: buildingX/buildingY %d,%d is in no room, so the engine finds no "
                 "building to prepare" % (name, bx, by))

        for cont in re.finditer(
                r"contX\s*=\s*(\d+)\s*,\s*contY\s*=\s*(\d+)\s*,\s*contZ\s*=\s*(\d+)", block):
            counted("stash crates")
            cx, cy, cz = (int(g) for g in cont.groups())
            if room_at(cx, cy, cz) is False:
                continue
            if room_at(cx, cy, cz) is None:
                levels = [z for z in range(8) if room_at(cx, cy, z)]
                fail("stash-crate",
                     "%s: crate at %d,%d,%d is in no room of the house, so it is never "
                     "stocked%s" % (name, cx, cy, cz,
                                    " (rooms there at z %s)"
                                    % ", ".join(str(z) for z in levels) if levels else ""))


# ---------------------------------------------------------------------------------------
# Requires

game_lua_modules = set()
for base in ("client", "server", "shared"):
    root = os.path.join(GAME, "media", "lua", base)
    for path in walk(root, ".lua"):
        module = os.path.relpath(path, root)[:-4].replace("\\", "/")
        game_lua_modules.add(module.lower())

mod_lua_modules = set()
for path in MOD_LUA:
    normalised = path.replace("\\", "/")
    for base in ("/lua/client/", "/lua/server/", "/lua/shared/"):
        if base in normalised:
            mod_lua_modules.add(normalised.split(base, 1)[1][:-4].lower())

# Modules that come from a separate mod the player installs. Not in this repository,
# because that mod is not ours to redistribute, and not in the game either.
#
# Two gates rather than a bare allowlist. The mod that provides it has to still be named
# in mod.info, so dropping the dependency cannot go unnoticed, and if a copy happens to be
# sitting in original-mods the module name is checked against it, so a typo in the require
# is caught rather than waved through.
EXTERNAL_MODULES = {
    "!_targetsquare_onload": "TargetSquareOnLoad",
}

# Local reference copies of other people's mods, kept out of the published tree.
reference_modules = set()
reference_root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                              "original-mods")
if os.path.isdir(reference_root):
    for path in walk(reference_root, ".lua"):
        normalised = path.replace("\\", "/")
        for folder in ("/lua/client/", "/lua/server/", "/lua/shared/"):
            if folder in normalised:
                reference_modules.add(normalised.split(folder, 1)[1][:-4].lower())

# require= and loadModAfter= both name another mod, and the engine strips backslashes out
# of either before splitting on commas, so \Mod1\,\Mod2 and Mod1,Mod2 are the same list.
#
# The difference is what happens when that mod is absent. require= makes this one
# unavailable, and the mod selector then refuses to activate it without printing anything,
# which reads to the player as the list bouncing them back. loadModAfter= only orders the
# two when both are present. An optional dependency belongs in the second.
declared_dependencies = set()
for root in MOD_ROOTS:
    for info in walk(root, "mod.info"):
        for match in re.finditer(r"^(?:require|loadModAfter)=(.+)$", read(info), flags=re.M):
            for mod_id in match.group(1).replace("\\", "").split(","):
                declared_dependencies.add(mod_id.strip())

for path in MOD_LUA:
    body = strip_lua_comments(read(path))
    # Both quote styles. Matching only double quotes let a wrong path in a single
    # quoted require sit there logging "require failed" at every boot.
    modules = set(re.findall(r'require\s*"([^"]+)"', body))
    modules |= set(re.findall(r"require\s*'([^']+)'", body))
    for module in modules:
        counted("requires")
        key = module.lower()
        if key in mod_lua_modules or key in game_lua_modules:
            continue
        provider = EXTERNAL_MODULES.get(key)
        if provider:
            if provider not in declared_dependencies:
                fail("require-undeclared",
                     "%s: require \"%s\" comes from %s, which no mod.info names in "
                     "require= or loadModAfter=" % (rel(path), module, provider))
            elif reference_modules and key not in reference_modules:
                fail("require-external",
                     "%s: require \"%s\" is not a module the reference copy of %s provides"
                     % (rel(path), module, provider))
            else:
                counted("external requires")
            continue
        fail("require-path", "%s: require \"%s\" resolves to no lua file" % (rel(path), module))


# ---------------------------------------------------------------------------------------

print("checked %d lua file(s), %d script file(s)" % (len(MOD_LUA), len(MOD_SCRIPTS)))
print("        " + ", ".join("%d %s" % (n, name) for name, n in sorted(counts.items())))
print()

for message in notes:
    print("note   " + message)
if notes:
    print()

if problems:
    for message in sorted(problems):
        print("FAIL   " + message)
    print()
    print("%d problem(s)" % len(problems))
    sys.exit(1)

print("all static checks passed")
