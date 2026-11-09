#!/usr/bin/env python3
"""generovat-katalog.py - Generuje katalog animaci pro KCD:MP (kcdmp-animace)
Cte:
  1. C:/Games/KCDC-server/KCDC-1.7.3/server/data/animace/katalog-ladeni.json
  2. D:/Program Files (x86)/Steam/steamapps/common/KingdomComeDeliverance2/Data/Animations.pak (pro presne klipy SetActorAnim)
  3. data/rekvizity-navic.json

Vytvari:
  - data/katalog-animaci.json (kompletni JSON s vyhledavacimi indexy a metadaty)
  - server/animace_data.lua (rychly Lua modul pro serverove lookupy v KCD:MP)
"""
import json
import os
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

KATALOG_JSON = r"C:/Games/KCDC-server/KCDC-1.7.3/server/data/animace/katalog-ladeni.json"
ANIMATIONS_PAK = r"D:/Program Files (x86)/Steam/steamapps/common/KingdomComeDeliverance2/Data/Animations.pak"
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRA_PROPS_FILE = os.path.join(ROOT_DIR, "data", "rekvizity-navic.json")
OUT_JSON = os.path.join(ROOT_DIR, "data", "katalog-animaci.json")
OUT_LUA = os.path.join(ROOT_DIR, "server", "animace_data.lua")

print(f"Nacitam {KATALOG_JSON}...")
with open(KATALOG_JSON, "r", encoding="utf-8") as f:
    katalog = json.load(f)

anims = katalog["anims"]
props_raw = katalog.get("rekvizity", [])
furniture_raw = katalog.get("nabytek", [])

extra_props = []
if os.path.exists(EXTRA_PROPS_FILE):
    with open(EXTRA_PROPS_FILE, "r", encoding="utf-8") as f:
        extra_props = json.load(f)

print(f"Pocet animaci ze hry: {len(anims)}")
print(f"Pocet rekvizit: {len(props_raw)} + {len(extra_props)} navic")

# 1. Prohledat ADB soubory v Animations.pak pro presne nazvy klipu (male i female)
frag_to_clip = {}
if os.path.exists(ANIMATIONS_PAK):
    print("Skenuji Animations.pak pro Mannequin ADB klipy...")
    try:
        with zipfile.ZipFile(ANIMATIONS_PAK) as z:
            for name in z.namelist():
                if name.startswith("Animations/Mannequin/ADB/") and name.endswith(".adb"):
                    try:
                        with z.open(name) as f:
                            tree = ET.parse(f)
                            fl = tree.find("FragmentList")
                            if fl is None:
                                continue
                            for frag in fl:
                                fname = frag.tag
                                for fentry in frag:
                                    tags = fentry.attrib.get("Tags", "")
                                    for part in fentry:
                                        if part.tag == "AnimLayer":
                                            for item in part:
                                                if item.tag == "Animation" and "name" in item.attrib:
                                                    clip = item.attrib["name"]
                                                    key = f"{fname}|{tags}"
                                                    if key not in frag_to_clip:
                                                        frag_to_clip[key] = clip
                                                    if fname not in frag_to_clip:
                                                        frag_to_clip[fname] = clip
                    except Exception:
                        pass
        print(f"Nalezeno {len(frag_to_clip)} mapovanych klipu.")
    except Exception as e:
        print(f"Varovani pri cteni PAK: {e}")

# 2. Definice kategorii
KATEGORIE = [
    ("sezeni", "Sezení", []),
    ("lezeni", "Ležení a spánek", ["sleep", "unconscious", "corpse", "dead", "knocked", "dying", "ragdoll"]),
    ("tanec", "Tanec", ["danc"]),
    ("jidlo", "Jídlo a pití", ["eat", "eats", "eating", "drink", "tankard", "mug", "bowl", "bread", "apple", "spoon", "cup", "wine", "beer", "food", "feast", "meal", "chew", "bottle", "flask", "soup", "mash", "meat", "stein"]),
    ("hudba", "Hudba", ["lute", "flute", "drum", "bagpipe", "music", "sing", "singing", "piper", "trumpet", "fiddle", "hurdy", "shawm", "horn", "bell"]),
    ("remesla", "Práce a řemesla", ["smith", "anvil", "hammer", "chop", "wood", "axe", "saw", "mill", "miller", "baker", "bake", "dough", "sweep", "broom", "rake", "hoe", "dig", "digging", "shovel", "pitchfork", "scythe", "sickle", "harvest", "plough", "plow", "farm", "farmer", "well", "bucket", "wash", "laundry", "cook", "cooking", "stir", "knead", "forge", "forging", "carpenter", "tanner", "butcher", "fish", "fishing", "repair", "craft", "alchemy", "alchemist", "herb", "herbs", "pick", "carry", "sack", "crate", "basket", "barrel", "load", "work", "worker", "write", "writing", "read", "reading", "book", "scribe", "sew", "spin", "weave", "grind", "pour", "fill", "clean", "tool", "hay", "logs", "water", "sharpen", "mason", "apothecary", "mortar", "housekeeper", "coal", "coalman", "charcoal", "lumber", "embroidery", "tailor", "churn", "cast", "casting", "heating", "tongs", "firewood", "egg", "hen", "chicken", "blacksmithing", "hoeing", "weeding", "sowing", "kiln", "mintage", "resin", "drying", "scooping", "stoke", "transcribing", "prospecting", "grating", "hardening", "unload", "flowerbed", "schumacher"]),
    ("boj", "Boj a zbraně", ["sword", "longsword", "crossbow", "arrow", "combat", "fight", "block", "attack", "weapon", "shield", "spear", "mace", "halberd", "duel", "parry", "sheath", "unsheath", "dagger", "polearm", "archery", "bow", "shoot", "shot", "aim", "hit", "kick", "punch", "fist", "battle", "soldier", "charge", "tournament", "rifle", "sabre", "lngsw", "huntingsw", "guard", "parade", "kill", "murder", "draw", "holster", "trebuchet", "pikeman", "hlbrd", "cover", "armored"]),
    ("kun", "Kůň, vůz a zvířata", ["horse", "ride", "rider", "riding", "saddle", "dog", "animal", "cow", "pig", "sheep", "goat", "feed", "stable", "groom", "mount", "dismount", "cart", "wagon", "capon"]),
    ("vira", "Víra", ["pray", "praying", "church", "priest", "kneel", "bless", "mass", "monk", "nun", "confess", "confession", "altar", "preach", "chapel", "meditation"]),
    ("zajeti", "Zajetí a tresty", ["tied", "prison", "prisoner", "captive", "stocks", "pillory", "hang", "hanged", "execute", "execution", "torture", "beg", "begging", "beggar", "chain", "chained", "slave", "master", "cage", "hostage", "surrender", "crime"]),
    ("hospoda", "Hospoda a hry", ["tavern", "inn", "dice", "card", "cards", "drunk", "barmaid", "bartender", "serve", "tray", "toast", "cheers", "party", "brothel", "bathhouse", "minigame", "game"]),
    ("obchod", "Obchod a trh", ["shopping", "shop", "seller", "customer", "pay", "trade", "stall", "buy", "sell", "merchant", "shopkeeper", "haggle", "service", "classify"]),
    ("dvere", "Dveře, zámky a věci", ["door", "gate", "cabinet", "wardrobe", "lock", "unlock", "lockpick", "lockpicking", "chest", "barricade", "open", "close", "controlled", "grab", "take", "drop", "throw", "place", "item", "torch", "lamp", "window", "placing", "inventory", "loot", "stash", "interact"]),
    ("pece", "Mytí, péče a zranění", ["bath", "bathrobes", "shave", "comb", "dress", "undress", "toilet", "pee", "piss", "vomit", "scratch", "itch", "heal", "healing", "bandage", "wound", "wounded", "treatment", "treating", "sick", "injured", "injury", "spa", "sunbathing", "poison", "poisoning", "ankle", "pain", "stomach", "outhouse", "exhausted", "potion"]),
    ("gesta", "Gesta a emoce", ["wave", "salute", "clap", "cheer", "laugh", "cry", "crying", "angry", "point", "shrug", "nod", "greet", "beckon", "facepalm", "gesture", "emote", "insult", "threat", "scared", "scare", "fear", "happy", "sad", "celebrate", "curtsy", "hug", "kiss", "yes", "no", "think", "count", "bow", "applause", "come", "cower", "nervous", "reaction", "victory", "urge", "shock", "weeping", "teasing", "abuse", "cruel"]),
    ("rozhovor", "Rozhovor a proslovy", ["adlg", "dialog", "dialogue", "talk", "talking", "conversation", "listen", "listener", "teller", "argue", "discuss", "gossip", "whisper", "speech", "command", "commander", "chat", "monologue", "call"]),
    ("oblicej", "Obličej", ["fe", "facial", "face"]),
    ("stani", "Stání a čekání", ["idle", "stand", "standing", "lean", "leaning", "wait", "waiting", "bored", "look", "watch", "arms", "warm", "fire", "patrol", "rest", "yawn", "stretch", "crowd", "audience", "curious", "spectator", "snooze", "camp", "overlooking", "viewing"]),
    ("pohyb", "Pohyb a plížení", ["walk", "run", "running", "jump", "climb", "fall", "crouch", "sneak", "turn", "step", "ladder", "swim", "stumble", "getup", "standup", "stealth", "hiding", "hide", "ledge", "vault", "crawl", "decoy", "sprint", "dash", "stair", "stairs", "motion", "movement", "slide", "search"]),
    ("ukoly", "Úkoly (quest)", ["quest", "cutscene", "cin"]),
]

LEZI_WORDS = ["sleep", "unconscious", "corpse", "dead", "knocked", "dying", "ragdoll", "lie", "lying", "liedown", "laying", "bed"]
SEDI_WORDS = ["sit", "sits", "sitting", "seated", "sitdown", "bench", "chair", "stool", "throne"]

def rozdel(s):
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", s)
    return re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)

def text_anim(a):
    f = rozdel(a.get("fragment", ""))
    t = rozdel(a.get("tags", "").replace("+", " "))
    s = rozdel(a.get("sequence", ""))
    return f"{f} {t} {s}".lower()

def slova_anim(a):
    return [w for w in re.split(r"[^a-z]+", text_anim(a)) if w]

def sedi_slovo(slovo, kw):
    if slovo == kw: return True
    if len(kw) >= 4 and slovo.startswith(kw): return True
    if len(kw) >= 5 and slovo.endswith(kw): return True
    return False

def ma_slova(sl, kws):
    return any(any(sedi_slovo(s, k) for k in kws) for s in sl)

def postoj(a):
    sl = slova_anim(a)
    na_zemi = any(s in ("ground", "floor", "pavise") for s in sl)
    if ma_slova(sl, LEZI_WORDS):
        if na_zemi: na = "zem"
        elif any(s in ("shelter", "tent") for s in sl): na = "stan"
        elif "bench" in sl: na = "lavicePostel"
        else: na = "postel"
        return {"poza": "lezi", "na": na}
    if ma_slova(sl, SEDI_WORDS):
        if na_zemi: return {"poza": "sedi", "na": "zem"}
        if any(s in ("chair", "stool") for s in sl): return {"poza": "sedi", "na": "zidle"}
        t = text_anim(a)
        stul = "table" in t and not bool(re.search(r"no_?table", t))
        return {"poza": "sedi", "na": "stul" if stul else "lavice"}
    return None

def kategorie_anim(a):
    sl = [w for w in re.split(r"[^a-z]+", f"{rozdel(a.get('fragment',''))} {rozdel(a.get('sequence',''))}".lower()) if w]
    p = postoj(a)
    out = []
    for kid, knazev, kslova in KATEGORIE:
        if (kid == "sezeni" and p and p["poza"] == "sedi") or (kid == "lezeni" and p and p["poza"] == "lezi") or ma_slova(sl, kslova):
            out.append(kid)
    return out if out else ["ostatni"]

# 3. Rekvizity
ALIAS_DRUHU = {
    "shortWeapon": "sword", "swords": "sword", "shortSwords": "sword", "bluntWeapon": "mace",
    "noweapon": "", "noShield": "", "bowl": "plate", "wine": "stein", "wood": "firewood",
    "ingredience": "cookingIngredience",
}

def druh_z_tagu(tags, ruka):
    pre = "r_" if ruka == "right" else "l_"
    for t in tags.split("+"):
        if t.startswith(pre):
            d = re.sub(r"^(pick|equip)_", "", t[2:])
            return ALIAS_DRUHU.get(d, d)
    return ""

def druh_ruky(a, ruka):
    val = a.get("rightHand" if ruka == "right" else "leftHand", "")
    return val if val else druh_z_tagu(a.get("tags", ""), ruka)

PRAVIDLA_REKVIZIT = [
    {"slova": ["eating", "mash"], "props": [{"hand": "right", "item": "wooden_spoon_mash"}]},
    {"slova": ["eating", "chicken"], "props": [{"hand": "right", "item": "thigh_chicken"}]},
    {"slova": ["drink*", "beer"], "props": [{"hand": "right", "item": "tankard_beer"}]},
    {"slova": ["cheers", "beer"], "props": [{"hand": "right", "item": "tankard_beer"}]},
    {"slova": ["serve", "beer"], "bez": ["guest"], "props": [{"hand": "right", "item": "tankard_beer"}]},
    {"slova": ["tankard"], "bez": ["poisoning"], "props": [{"hand": "right", "item": "tankard_beer"}]},
    {"slova": ["stein"], "props": [{"hand": "right", "item": "wooden_stein"}]},
    {"slova": ["camp", "wine"], "props": [{"hand": "right", "item": "wineskin_rustic"}]},
    {"slova": ["wineskin"], "props": [{"hand": "right", "item": "wineskin_rustic"}]},
    {"slova": ["drink*", "wine"], "props": [{"hand": "right", "item": "player_cup"}]},
    {"slova": ["holding", "cup"], "props": [{"hand": "right", "item": "player_cup"}]},
    {"slova": ["picking", "cup"], "props": [{"hand": "right", "item": "player_cup"}]},
    {"slova": ["reading", "book"], "bez": ["bookstand"], "props": [{"hand": "right", "item": "book_a"}]},
    {"slova": ["reading", "shelf"], "props": [{"hand": "right", "item": "book_a"}]},
    {"slova": ["scribe", "book"], "props": [{"hand": "right", "item": "book_a"}]},
    {"slova": ["alchemy", "pick", "book"], "props": [{"hand": "right", "item": "book_alchemy_closed"}]},
    {"slova": ["alchemy", "place", "book"], "props": [{"hand": "right", "item": "book_alchemy_closed"}]},
    {"slova": ["writing", "letter"], "props": [{"hand": "right", "item": "quill"}]},
    {"slova": ["dice", "shake"], "props": [{"hand": "right", "item": "dice_cup"}]},
    {"slova": ["dice", "throw"], "props": [{"hand": "right", "item": "dice_cup"}]},
    {"slova": ["sweeping"], "props": [{"hand": "right", "druh": "broom"}]},
    {"slova": ["toasting", "fish"], "props": [{"hand": "right", "item": "herding_stick"}]},
    {"slova": ["fishing"], "props": [{"hand": "right", "druh": "fishingRod"}]},
    {"slova": ["apothecary", "mortar"], "props": [{"hand": "right", "item": "pestle"}, {"hand": "left", "item": "mortar"}]},
    {"slova": ["cooking", "scoop"], "props": [{"hand": "right", "item": "wooden_scoop"}]},
    {"slova": ["cooking", "pan"], "props": [{"hand": "right", "item": "pan_a"}]},
    {"slova": ["cooking"], "bez": ["pan", "scoop", "herbs", "ingredience", "water", "pick", "put"], "props": [{"hand": "right", "item": "ladle_a"}]},
    {"slova": ["knife", "sharpening"], "props": [{"hand": "right", "item": "knife_eating"}, {"hand": "left", "item": "whetstone"}]},
    {"slova": ["razor", "sharpening"], "props": [{"hand": "right", "item": "barber_razor"}, {"hand": "left", "item": "whetstone"}]},
    {"slova": ["sharpening", "sword"], "props": [{"hand": "right", "druh": "sword"}, {"hand": "left", "item": "whetstone"}]},
    {"slova": ["sewing"], "props": [{"hand": "right", "item": "needle"}]},
    {"slova": ["spindle"], "props": [{"hand": "right", "item": "spindle"}]},
    {"slova": ["painter", "brush"], "props": [{"hand": "right", "item": "paint_brush_a"}]},
    {"slova": ["repair", "hammer"], "props": [{"hand": "right", "item": "hammer"}]},
    {"slova": ["blacksmithing", "stroke"], "props": [{"hand": "right", "item": "big_blacksmith_hammer"}]},
    {"slova": ["blacksmithing"], "tag": "slaveTongs", "props": [{"hand": "left", "item": "tongs_a"}]},
    {"slova": ["return", "hammer"], "props": [{"hand": "right", "item": "big_blacksmith_hammer"}]},
    {"slova": ["forging"], "props": [{"hand": "right", "item": "big_blacksmith_hammer"}]},
    {"slova": ["cast", "tongs"], "props": [{"hand": "right", "item": "casting_tongs"}]},
    {"slova": ["playing", "lute"], "props": [{"hand": "left", "item": "kejkliri_lute", "position": {"x": -0.045, "y": 0.025, "z": -0.385}, "rotation": {"x": 100, "y": 90, "z": 0}}]},
    {"slova": ["flute"], "props": [{"hand": "right", "item": "flute", "position": {"x": 0, "y": 0, "z": -0.14}}]},
    {"slova": ["healing", "potion"], "props": [{"hand": "right", "item": "player_potion"}]},
    {"slova": ["spill*", "potion"], "props": [{"hand": "right", "item": "player_potion"}]},
    {"slova": ["sleep", "potion"], "props": [{"hand": "right", "item": "player_potion"}]},
    {"slova": ["bartender", "bowl"], "props": [{"hand": "right", "item": "bowl"}]},
    {"slova": ["tray"], "props": [{"hand": "right", "druh": "tray"}]},
    {"slova": ["baker", "bake"], "props": [{"hand": "right", "item": "wooden_peel"}]},
    {"slova": [], "tag": "alchemyFlask", "props": [{"hand": "right", "item": "flask"}]},
]

# Spojit rekvizity
vsechny_rekvizity = {}
for p in props_raw:
    vsechny_rekvizity[p["name"]] = p
for p in extra_props:
    if p["name"] not in vsechny_rekvizity:
        vsechny_rekvizity[p["name"]] = {"name": p["name"], "model": p["model"], "hand": p["hand"], "navic": True}

props_by_hand = {}
for name, p in vsechny_rekvizity.items():
    h = p["hand"].lower()
    props_by_hand.setdefault(h, []).append(p)

def najdi_rekvizitu(druh, frag, tags):
    cand = props_by_hand.get(druh.lower(), [])
    if not cand: return None
    f_words = [w for w in re.split(r"[^a-z]+", rozdel(frag).lower()) if len(w) > 2]
    t_words = [w for w in re.split(r"[^a-z]+", rozdel(tags.replace("+", " ")).lower()) if len(w) > 2]
    all_words = f_words + t_words
    best = cand[0]
    best_score = -1
    for p in cand:
        p_words = [w for w in re.split(r"[^a-z]+", rozdel(p["name"]).lower()) if len(w) > 2]
        score = sum(1 for pw in p_words if any(pw in aw or aw in pw for aw in all_words))
        if score > best_score:
            best_score = score
            best = p
    return best

def vychozi_rekvizity(a):
    frag = a.get("fragment", "")
    tags = a.get("tags", "")
    f_words = [w for w in re.split(r"[^a-z]+", rozdel(frag).lower()) if w]
    t_list = tags.lower().split("+")
    out = []
    for hand in ("right", "left"):
        druh = druh_ruky(a, hand)
        p = najdi_rekvizitu(druh, frag, tags) if druh else None
        if p:
            r = {"hand": hand, "item": p["name"], "model": p["model"]}
            if p.get("navic"): r["navic"] = True
            out.append(r)
            continue
        # Pravidla
        matched = False
        for pr in PRAVIDLA_REKVIZIT:
            slova_match = all(any(w.startswith(k[:-1]) if k.endswith("*") else w == k for w in f_words) for k in pr["slova"])
            bez_match = any(any(w.startswith(k[:-1]) if k.endswith("*") else w == k for w in f_words) for k in pr.get("bez", []))
            tag_match = not pr.get("tag") or pr["tag"].lower() in t_list
            if slova_match and not bez_match and tag_match:
                for xp in pr["props"]:
                    if xp["hand"] == hand:
                        item_obj = vsechny_rekvizity.get(xp.get("item", ""))
                        if not item_obj and xp.get("druh"):
                            item_obj = najdi_rekvizitu(xp["druh"], frag, tags)
                        if item_obj:
                            r = {"hand": hand, "item": item_obj["name"], "model": item_obj["model"]}
                            if "position" in xp: r["position"] = xp["position"]
                            if "rotation" in xp: r["rotation"] = xp["rotation"]
                            out.append(r)
                            matched = True
                            break
            if matched: break
    return out

# 4. Pary / Dvojice
ROLE_JMENA = [
    ("Master", "Slave"), ("Leader", "Minion"), ("Player", "Female"), ("Player", "Guard"),
    ("Player", "Bandit"), ("Player", "Capon"), ("Player", "Albie"), ("Henry", "Sigi"),
    ("Hostage", "Kidnapper"), ("Bartender", "Guest"), ("BeingInteracted", "Interactant"),
]
ROLE_PRIDANE = ["Slave", "Player"]
PARY_TABULKA = [
    ("SickPotionFemaleSlave", "SickPotion"),
    ("Quest_HostageSituation_PlayerUntyingHostageOnGround", "Quest_HostageSituation_HostageTiedOnGround_Untying"),
    ("Quest_HostageSituation_HostageGetsHit_HostageDies_HostageTiedDiedToGround", "Quest_HostageSituation_HostageGetsHit_HostageDies_KidnapperToCombat"),
    ("Quest_HostageSituation_KidnapperKillsHostage_HostageTiedKilledToGround", "Quest_HostageSituation_KidnapperKillsHostage_KidnapperToCombat"),
]
SPOLU_REGEX = [re.compile(r"^Party_Duo_Standing_Dancing_"), re.compile(r"^Quest_Hug(Long|Short)$"), re.compile(r"^Quest_(Pickup|Putdown)Female$"), re.compile(r"^Quest_HostageSituation_HoldHostage_")]

anims_by_frag = {}
anims_by_key = {}
for a in anims:
    f = a["fragment"]
    t = a.get("tags", "")
    k = f"{f}|{t}" if t else f
    anims_by_frag.setdefault(f, []).append(a)
    anims_by_key[k] = a

def nejlepsi_partner(frag, tags):
    cand = anims_by_frag.get(frag, [])
    if not cand: return None
    t_set = set(tags.split("+"))
    best = cand[0]
    best_score = -1
    for x in cand:
        xt = x.get("tags", "")
        score = 1000 if xt == tags else len(t_set.intersection(xt.split("+")))
        if score > best_score:
            best_score = score
            best = x
    return best

def najdi_partnera(a):
    f = a["fragment"]
    t = a.get("tags", "")
    k = f"{f}|{t}" if t else f

    # Ze hry
    p_game = a.get("partner", "")
    if p_game:
        cand = nejlepsi_partner(p_game, t)
        if cand:
            ck = f"{cand['fragment']}|{cand.get('tags','')}" if cand.get("tags") else cand["fragment"]
            return {"klic": ck, "zdroj": "hra"}

    # Tabulka
    for p1, p2 in PARY_TABULKA:
        if f == p1:
            cand = nejlepsi_partner(p2, t)
            if cand: return {"klic": f"{cand['fragment']}|{cand.get('tags','')}" if cand.get("tags") else cand["fragment"], "zdroj": "tabulka"}
        elif f == p2:
            cand = nejlepsi_partner(p1, t)
            if cand: return {"klic": f"{cand['fragment']}|{cand.get('tags','')}" if cand.get("tags") else cand["fragment"], "zdroj": "tabulka"}

    # Role ve jmenu
    for r1, r2 in ROLE_JMENA:
        for z, na in ((r1, r2), (r2, r1)):
            if z in f:
                mod_f = re.sub(rf"(?<![A-Z]){z}(?![a-z])", na, f)
                if mod_f != f and mod_f in anims_by_frag:
                    cand = nejlepsi_partner(mod_f, t)
                    if cand: return {"klic": f"{cand['fragment']}|{cand.get('tags','')}" if cand.get("tags") else cand["fragment"], "zdroj": "jmeno"}
    for z in ROLE_PRIDANE:
        if z in f:
            mod_f = re.sub(rf"_?{z}_?", "", f)
            if mod_f != f and mod_f in anims_by_frag:
                cand = nejlepsi_partner(mod_f, t)
                if cand: return {"klic": f"{cand['fragment']}|{cand.get('tags','')}" if cand.get("tags") else cand["fragment"], "zdroj": "jmeno"}

    # Role v tagu
    if t:
        mod_t = []
        changed = False
        for tag in t.split("+"):
            m = re.match(r"^(.*Partner)([A-D])$", tag)
            if m:
                changed = True
                flip = {"A": "B", "B": "A", "C": "D", "D": "C"}[m.group(2)]
                mod_t.append(f"{m.group(1)}{flip}")
                continue
            m = re.match(r"^(.+)(Master|Slave)$", tag)
            if m:
                changed = True
                flip = "Slave" if m.group(2) == "Master" else "Master"
                mod_t.append(f"{m.group(1)}{flip}")
                continue
            mod_t.append(tag)
        if changed:
            ck = f"{f}|{'+'.join(mod_t)}"
            if ck in anims_by_key:
                return {"klic": ck, "zdroj": "tag"}

    # Spolu
    if a.get("male") and a.get("female") and any(r.search(f) for r in SPOLU_REGEX):
        return {"klic": k, "zdroj": "spolu"}

    return None

# 5. Zpracovani celeho katalogu
print("Zpracovavam katalog animaci a odvozuji pravidla...")
vysledek_list = []
paired_count = 0
for a in anims:
    f = a["fragment"]
    t = a.get("tags", "")
    k = f"{f}|{t}" if t else f
    pst = postoj(a)
    kat = kategorie_anim(a)
    props = vychozi_rekvizity(a)
    pair = najdi_partnera(a)
    if pair: paired_count += 1

    # Ziskat clip ze skenu
    clip = frag_to_clip.get(k) or frag_to_clip.get(f) or ""

    # Priznaky
    priznaky = ""
    if a.get("fullBody"): priznaky += "C"
    if any(p["hand"] == "right" for p in props): priznaky += "R"
    if any(p["hand"] == "left" for p in props): priznaky += "L"
    if a.get("male"): priznaky += "M"
    if a.get("female"): priznaky += "F"
    if pst and pst["poza"] == "sedi": priznaky += "S"
    if pst and pst["poza"] == "lezi": priznaky += "B"
    if pst and pst["na"] == "zem": priznaky += "G"
    if pair: priznaky += "P"
    if a.get("sequence"): priznaky += "Q"
    if a.get("oneShot"): priznaky += "O"

    entry = {
        "klic": k,
        "fragment": f,
        "tags": t,
        "clip": clip,
        "duration": round(a.get("duration", 0), 3),
        "oneShot": bool(a.get("oneShot")),
        "fullBody": bool(a.get("fullBody")),
        "male": bool(a.get("male")),
        "female": bool(a.get("female")),
        "sequence": a.get("sequence", ""),
        "phase": a.get("phase", ""),
        "kat": kat,
        "priznaky": priznaky,
        "props": props,
    }
    if pst:
        entry["postoj"] = pst
    if pair:
        entry["dvojice"] = pair
        # Default posun partnera: tanec v paru 0.8 m celem, ostatni spolecny pocatek
        is_dance = bool(re.match(r"^Party_Duo_Standing_Dancing_", f))
        entry["posunPartner"] = {"x": 0, "y": 0.8 if is_dance else 0, "z": 0, "yaw": 180 if is_dance else 0}

    vysledek_list.append(entry)

print(f"Zpracovano {len(vysledek_list)} animaci, {paired_count} paru.")

# Ulozit JSON
print(f"Ukladam {OUT_JSON}...")
with open(OUT_JSON, "w", encoding="utf-8") as f:
    json.dump({"total": len(vysledek_list), "anims": vysledek_list, "rekvizity": list(vsechny_rekvizity.values()), "nabytek": furniture_raw}, f, ensure_ascii=False, indent=2)

# Ulozit Lua modul animace_data.lua
print(f"Generuji {OUT_LUA}...")
lua_lines = [
    "-- animace_data.lua - VYGENEROVANO automaticky z KCD2 dat a katalogu",
    "-- Obsahuje metadata pro KCD:MP server a rychle vyhledavani animaci.",
    "local AnimaceData = {}",
    "",
    "AnimaceData.total = " + str(len(vysledek_list)),
    "AnimaceData.by_key = {}",
    "AnimaceData.by_fragment = {}",
    "",
    "local raw = "
]

# Serializace do Lua tabulky
def to_lua(val):
    if val is None: return "nil"
    if isinstance(val, bool): return "true" if val else "false"
    if isinstance(val, (int, float)): return str(val)
    if isinstance(val, str):
        # Escape string
        s = val.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{s}"'
    if isinstance(val, list):
        items = [to_lua(x) for x in val]
        return "{" + ", ".join(items) + "}"
    if isinstance(val, dict):
        items = []
        for k, v in val.items():
            if re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*$", k):
                items.append(f"{k} = {to_lua(v)}")
            else:
                items.append(f'[{to_lua(k)}] = {to_lua(v)}')
        return "{" + ", ".join(items) + "}"
    return "nil"

# Aby nebyl animace_data.lua giganticky monolit, ulozime prehledne indexovany lookup
# Ulozime kompaktni zaznamy
lua_records = []
for e in vysledek_list:
    item = {
        "k": e["klic"],
        "f": e["fragment"],
        "t": e["tags"],
        "c": e["clip"],
        "d": e["duration"],
        "o": e["oneShot"],
        "b": e["fullBody"],
        "m": e["male"],
        "w": e["female"],
        "p": e["priznaky"],
    }
    if e.get("sequence"): item["sq"] = e["sequence"]
    if e.get("phase"): item["ph"] = e["phase"]
    if e.get("postoj"): item["po"] = e["postoj"]
    if e.get("props"): item["pr"] = e["props"]
    if e.get("dvojice"): item["dv"] = e["dvojice"]
    if e.get("posunPartner"): item["pp"] = e["posunPartner"]
    lua_records.append(item)

# Zapis v davkach pro efektivni parsovani v Lua
lua_lines.append("{")
for rec in lua_records:
    lua_lines.append("  " + to_lua(rec) + ",")
lua_lines.append("}")
lua_lines.append("")
lua_lines.append("""
for _, item in ipairs(raw) do
    AnimaceData.by_key[item.k] = item
    if not AnimaceData.by_fragment[item.f] then
        AnimaceData.by_fragment[item.f] = {}
    end
    table.insert(AnimaceData.by_fragment[item.f], item)
end

function AnimaceData.get(klic)
    return AnimaceData.by_key[klic]
end

function AnimaceData.getByFragment(fragment)
    return AnimaceData.by_fragment[fragment] or {}
end

return AnimaceData
""")

with open(OUT_LUA, "w", encoding="utf-8") as f:
    f.write("\n".join(lua_lines))

print("Hotovo! Data byla uspesne vygenerovana.")
