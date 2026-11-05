# 移植自 S/gameCore/serviceUtils/soundLibrary.as
# 原版 142 个soundLibrary_s*.as 只是嵌入 mp3 的壳类：类名 -> data/symbols.json 的 characterId -> assets/library/sound/<id>.mp3。
class_name SoundLibrary
extends RefCounted

static var inst: SoundLibrary

const SYMBOLS_PATH := "res://data/symbols.json"
const SYMBOL_PREFIX := "gameCore.serviceUtils.soundLibrary_"
const RESOURCES_PATH := "res://data/resources.json"

const CLICK1 := "click1"
const CLICK := "click"
const ROVER := "rover"
const CLICKFAIL := "clickfail"
const MENU_MUSIC := "menuMusic"
const SPEC_FLASH1 := "specFlash1"
const SPEC_FLASH2 := "specFlash2"
const ARCHER_PULL1 := "archerPull1"
const ARCHER_PULL2 := "archerPull2"
const ARCHER_PULL3 := "archerPull3"
const ARCHER_SHOOT1 := "archerShoot1"
const ARCHER_SHOOT2 := "archerShoot2"
const ARCHER_SHOOT3 := "archerShoot3"
const ARCHER_SHOOT := "archerShoot"
const ARCHER_PULL := "archerPull"
const CROSSB_SHOOT1 := "crossbShoot1"
const CROSSB_SHOOT2 := "crossbShoot2"
const CROSSB_SHOOT3 := "crossbShoot3"
const CROSSB_SHOOT := "crossbShoot"
const MAGE_BLUE_STRIKE1 := "mageBlueStrike1"
const MAGE_BLUE_STRIKE2 := "mageBlueStrike2"
const MAGE_BLUE_STRIKE3 := "mageBlueStrike3"
const MAGE_RED_STRIKE3 := "mageRedStrike3"
const MAGE_RED_STRIKE2 := "mageRedStrike2"
const MAGE_RED_STRIKE1 := "mageRedStrike1"
const MAGE_BLACK_STRIKE1 := "mageBlackStrike1"
const MAGE_BLACK_STRIKE2 := "mageBlackStrike2"
const MAGE_BLACK_STRIKE3 := "mageBlackStrike3"
const MAGE_BLACK_STRIKE := "mageBlackStrike"
const MAGE_BLUE_STRIKE := "mageBlueStrike"
const MAGE_RED_STRIKE := "mageRedStrike"
const MAGE_STRIKE := "mageStrike"
const SWORD_SWOOSH := "swordSwoosh"
const SWORD_SWOOSH1 := "swordSwoosh1"
const SWORD_SWOOSH2 := "swordSwoosh2"
const SWORD_SWOOSH3 := "swordSwoosh3"
const SWORD_SWOOSH4 := "swordSwoosh4"
const SWORD_SWOOSH5 := "swordSwoosh5"
const SWORD_SWOOSH6 := "swordSwoosh6"
const SWORD_SWOOSH7 := "swordSwoosh7"
const SWORDMASTER_CIRCLE := "swordmasterCircle"
const HEAVY_SWORD := "heavySword"
const HEAVY_SWORD1 := "heavySword1"
const HEAVY_SWORD2 := "heavySword2"
const HEAVY_SWORD3 := "heavySword3"
const AXE := "axe"
const AXE1 := "axe1"
const AXE2 := "axe2"
const AXE3 := "axe3"
const SWORDMASTER_PARRY := "swordmasterParry"
const IMPACT := "impact"
const IMPACT_ARMOR := "impactArmor"
const IMPACT_ARMOR1 := "impactArmor1"
const IMPACT_ARMOR2 := "impactArmor2"
const IMPACT_ARMOR3 := "impactArmor3"
const IMPACT_HANDS := "impactHands"
const IMPACT_HANDS1 := "impactHands1"
const IMPACT_HANDS2 := "impactHands2"
const IMPACT_HANDS3 := "impactHands3"
const IMPACT_FLESH := "impactFlesh"
const IMPACT_FLESH1 := "impactFlesh1"
const IMPACT_FLESH2 := "impactFlesh2"
const IMPACT_FLESH3 := "impactFlesh3"
const IMPACT_FLESH4 := "impactFlesh4"
const IMPACT_FLESH5 := "impactFlesh5"
const ARROW_IMPACT := "arrowImpact"
const ARROW_IMPACT1 := "arrowImpact1"
const ARROW_IMPACT2 := "arrowImpact2"
const ARROW_IMPACT3 := "arrowImpact3"
const ARROW_IMPACT4 := "arrowImpact4"
const ARROW_IMPACT5 := "arrowImpact5"
const ARROW_IMPACT6 := "arrowImpact6"
const ARROW_IMPACT7 := "arrowImpact7"
const BATTLE_MUSIC := "battleMusic"
const ICE_BREAK := "iceBreak"
const ICE_MAKE := "iceMake"
const CREATURE_ATTACK := "creatureAttack"
const CREATURE_ATTACK1 := "creatureAttack1"
const CREATURE_ATTACK2 := "creatureAttack2"
const CREATURE_ATTACK3 := "creatureAttack3"
const HEAL := "heal"
const HEAL1 := "heal1"
const HEAL2 := "heal2"
const HEAL3 := "heal3"
const HEAL4 := "heal4"
const KAMIKAZE := "kamikaze"
const NEW_WAVE := "newWave"
const HEAL_CAST := "healCast"
const HEAL_CAST1 := "healCast1"
const HEAL_CAST2 := "healCast2"
const HEAL_CAST3 := "healCast3"
const MAN_VOICE := "manVoice"
const MAN_VOICE7 := "manVoice7"
const MAN_VOICE6 := "manVoice6"
const MAN_VOICE5 := "manVoice5"
const MAN_VOICE4 := "manVoice4"
const MAN_VOICE3 := "manVoice3"
const MAN_VOICE2 := "manVoice2"
const MAN_VOICE1 := "manVoice1"
const STRONG_HEAL := "strongHeal"
const BACKSTAB := "backstab"
const CRITICAL := "critical"
const MAGIC_SHIELD := "magicShield"
const METHEOR_FALLS := "metheorFalls"
const STUNNED := "stunned"
const BLOCK := "block"
const BLOCK1 := "block1"
const BLOCK2 := "block2"
const WIN_MUSIC := "winMusic"
const LOSS_MUSIC := "lossMusic"
const MAP_MUSIC := "mapMusic"
const IFACE_WINDOW := "ifaceWindow"
const IFACE_PAPER_SMALL := "ifacePaperSmall"
const MAGE_CAST1 := "mageCast1"
const MAGE_CAST2 := "mageCast2"
const OGRE_PUNCH := "ogrePunch"
const BIG_CREATURE_ATTACK1 := "bigCreatureAttack1"
const BIG_CREATURE_ATTACK2 := "bigCreatureAttack2"
const BIG_CREATURE_ATTACK := "bigCreatureAttack"
const OGRE_DEAD := "ogreDead"
const MAN_DIED := "manDied"
const MAN_DIED1 := "manDied1"
const MAN_DIED2 := "manDied2"
const MAN_DIED3 := "manDied3"
const UNIT_KILLED := "unitKilled"
const FLAG_MOVE_NORMAL := "flagMoveNormal"
const FLAG_MOVE_VOICE := "flagMoveVoice"
const FLAG_HEAL := "flagHeal"
const FLAG_ATTACK := "flagAttack"
const ARROW_SWARM := "arrowSwarm"
const RESSURECT := "ressurect"
const ARROW_GROUND := "arrowGround"
const ARROW_GROUND1 := "arrowGround1"
const ARROW_GROUND2 := "arrowGround2"
const ARROW_GROUND3 := "arrowGround3"
const ARROW_GROUND4 := "arrowGround4"
const ARROW_GROUND5 := "arrowGround5"
const ARROW_GROUND6 := "arrowGround6"
const ARROW_GROUND7 := "arrowGround7"
const ARROW_GROUND8 := "arrowGround8"
const SUMMON := "summon"
const GAME_START := "gameStart"
const MAP_FLAG_CLICK := "mapFlagClick"
const MAP_FLAG_ROVER := "mapFlagRover"
const HIRE := "hire"
const HAS_UPGRADE := "hasUpgrade"
const HEAL_CAST_FRIENDS := "healCastFriends"
const HEAL_CAST_PRIEST := "healCastFriends1"
const HEAL_CAST_CLERIC := "healCastFriends2"
const HEAL_CAST_MONK := "healCastFriends3"
const BTN_DENY := "btnDeny"
const UPG_CLICK1 := "upgClick1"
const UPG_CLICK2 := "upgClick2"
const UPG_CLICK3 := "upgClick3"
const MAGE_CAST_NEW1 := "mageCastNew3"
const BREAK_ARMOR := "breakArm"
const HIDESPY := "hideSpy"
const SUPPRESS := "supress"
const SLOW := "slow"
const POISON := "poison"
const TAUNT := "taunt"
const WEAKSPOT := "weakSpot"
const PAPER_MOVE_NEW := "paperMove"
const MONSTERS := "monsters"
const MONSTER1 := "monsters1"
const MONSTER2 := "monsters2"
const MONSTER3 := "monsters3"
const MONSTER4 := "monsters4"
const MONSTER5 := "monsters5"
const SELECTION := "selection"
const ZOMBIE_WEAKNESS := "zweakns"
const BONEBREAK := "zBoneBroken"

# lib 键 -> 壳类名（去掉 soundLibrary_ 前缀）。顺序、重复项照 init() 原样保留。
# 原版疑点：MAGE_BLACK_STRIKE3 指向 sMageBlackStrike2（sMageBlackStrike3 从未被引用）。
const LIB_CLASSES := {
	MAGE_CAST1: "sMageCast1",
	MAGE_CAST2: "sMageCast2",
	MAGE_CAST_NEW1: "sMageCastNew1",
	POISON: "sPoison",
	TAUNT: "sTaunt",
	SELECTION: "sSelection",
	BONEBREAK: "sBoneBreaked",
	IFACE_PAPER_SMALL: "sPaperSmall",
	CLICK1: "sClick1",
	ROVER: "sRover",
	CLICKFAIL: "sFail",
	MENU_MUSIC: "sMenuMusic",
	BATTLE_MUSIC: "sBattleMusic",
	MAP_MUSIC: "sMapMusic",
	BTN_DENY: "sBtnDeny",
	GAME_START: "sGameStartClicked",
	MAP_FLAG_CLICK: "sMapFlagClicked",
	MAP_FLAG_ROVER: "sMapFlagHover",
	HIRE: "sHire",
	HAS_UPGRADE: "sHasUpgrade",
	HEAL_CAST_PRIEST: "sHealFriendPriest",
	HEAL_CAST_CLERIC: "sHealFriendCleric",
	HEAL_CAST_MONK: "sHealFriendMonk",
	UPG_CLICK1: "sUpgClick1",
	UPG_CLICK2: "sUpgClick2",
	UPG_CLICK3: "sUpgClick3",
	BREAK_ARMOR: "sBreakArmor",
	HIDESPY: "sHideSpy",
	SUPPRESS: "sSlow",
	WEAKSPOT: "sWeakSpot",
	ZOMBIE_WEAKNESS: "sZWeakness",
	SLOW: "sRealSlow",
	PAPER_MOVE_NEW: "sPaperMoveNew",
	MONSTER1: "sMonster1",
	MONSTER2: "sMonster2",
	MONSTER3: "sMonster3",
	MONSTER4: "sMonster4",
	MONSTER5: "sMonster5",
	SPEC_FLASH1: "sFlash1",
	SPEC_FLASH2: "sFlash2",
	ARCHER_PULL1: "sBowPull1",
	ARCHER_PULL2: "sBowPull2",
	ARCHER_PULL3: "sBowPull3",
	ARCHER_SHOOT1: "sBowShoot1",
	ARCHER_SHOOT2: "sBowShoot2",
	ARCHER_SHOOT3: "sBowShoot3",
	CROSSB_SHOOT1: "sCrossbowShoot1",
	CROSSB_SHOOT2: "sCrossbowShoot2",
	CROSSB_SHOOT3: "sCrossbowShoot3",
	MAGE_BLACK_STRIKE1: "sMageBlackStrike1",
	MAGE_BLACK_STRIKE2: "sMageBlackStrike2",
	MAGE_BLACK_STRIKE3: "sMageBlackStrike2",
	MAGE_RED_STRIKE1: "sMageRedStrike1",
	MAGE_RED_STRIKE2: "sMageRedStrike2",
	MAGE_RED_STRIKE3: "sMageRedStrike3",
	MAGE_BLUE_STRIKE1: "sMageBlueStrike1",
	MAGE_BLUE_STRIKE2: "sMageBlueStrike2",
	MAGE_BLUE_STRIKE3: "sMageBlueStrike3",
	AXE1: "sAxe1",
	AXE2: "sAxe2",
	AXE3: "sAxe3",
	SWORD_SWOOSH1: "sSwordSwoosh1",
	SWORD_SWOOSH2: "sSwordSwoosh2",
	SWORD_SWOOSH3: "sSwordSwoosh3",
	SWORD_SWOOSH4: "sSwordSwoosh4",
	SWORD_SWOOSH5: "sSwordSwoosh5",
	SWORD_SWOOSH6: "sSwordSwoosh6",
	SWORD_SWOOSH7: "sSwordSwoosh7",
	HEAVY_SWORD1: "sHeavySword1",
	HEAVY_SWORD2: "sHeavySword2",
	HEAVY_SWORD3: "sHeavySword3",
	SWORDMASTER_CIRCLE: "sCircleStrike",
	SWORDMASTER_PARRY: "sParry",
	IMPACT_ARMOR1: "sArmorHit1",
	IMPACT_ARMOR2: "sArmorHit2",
	IMPACT_ARMOR3: "sArmorHit3",
	IMPACT_HANDS1: "sHitHands1",
	IMPACT_HANDS2: "sHitHands2",
	IMPACT_HANDS3: "sHitHands3",
	IMPACT_FLESH1: "sHitFlesh1",
	IMPACT_FLESH2: "sHitFlesh2",
	IMPACT_FLESH3: "sHitFlesh3",
	IMPACT_FLESH4: "sHitFlesh4",
	IMPACT_FLESH5: "sHitFlesh5",
	ARROW_IMPACT1: "sArrowImpact1",
	ARROW_IMPACT2: "sArrowImpact2",
	ARROW_IMPACT3: "sArrowImpact3",
	ARROW_IMPACT4: "sArrowImpact4",
	ARROW_IMPACT5: "sArrowImpact5",
	ARROW_IMPACT6: "sArrowImpact6",
	ARROW_IMPACT7: "sArrowImpact7",
	ICE_MAKE: "sIceMake",
	ICE_BREAK: "sIceBreak",
	ARROW_GROUND1: "sArrowToGround1",
	ARROW_GROUND2: "sArrowToGround2",
	ARROW_GROUND3: "sArrowToGround3",
	ARROW_GROUND4: "sArrowToGround4",
	ARROW_GROUND5: "sArrowToGround5",
	ARROW_GROUND6: "sArrowToGround6",
	ARROW_GROUND7: "sArrowToGround7",
	ARROW_GROUND8: "sArrowToGround8",
	SUMMON: "sSummon",
	CREATURE_ATTACK1: "sCreatureHit1",
	CREATURE_ATTACK2: "sCreatureHit2",
	CREATURE_ATTACK3: "sCreatureHit3",
	BIG_CREATURE_ATTACK1: "sCreatureBigHit1",
	BIG_CREATURE_ATTACK2: "sCreatureBigHit2",
	UNIT_KILLED: "sUnitKilledDrum",
	FLAG_MOVE_NORMAL: "sFlagMoveRegular",
	FLAG_MOVE_VOICE: "sFlagMoveVoice",
	FLAG_HEAL: "sFlagFocusHeal",
	FLAG_ATTACK: "sFlagAttack",
	HEAL_CAST1: "sHealCast1",
	HEAL_CAST2: "sHealCast2",
	HEAL_CAST3: "sHealCast3",
	KAMIKAZE: "sKamikadze",
	NEW_WAVE: "sNewWave",
	MAN_VOICE1: "sManVoice1",
	MAN_VOICE2: "sManVoice2",
	MAN_VOICE3: "sManVoice3",
	MAN_VOICE4: "sManVoice4",
	MAN_VOICE5: "sManVoice5",
	MAN_VOICE6: "sManVoice6",
	MAN_VOICE7: "sManVoice7",
	MAN_DIED1: "sManDied1",
	MAN_DIED2: "sManDied2",
	MAN_DIED3: "sManDied3",
	ARROW_SWARM: "sArrowSwarm",
	RESSURECT: "sResurrect",
	STRONG_HEAL: "sStrongHeal",
	BACKSTAB: "sBackStab",
	CRITICAL: "sCritical",
	MAGIC_SHIELD: "sMagicShield",
	METHEOR_FALLS: "sMetheor",
	STUNNED: "sStun",
	BLOCK1: "sBlock1",
	BLOCK2: "sBlock2",
	WIN_MUSIC: "sWinMusic",
	LOSS_MUSIC: "sLosMusic",
	IFACE_WINDOW: "sMoveIface",
	OGRE_PUNCH: "sOgrePunch",
	OGRE_DEAD: "sOgreDead",
}

# soundObj：同类随机选择的候选列表。注意原版 ARROW_GROUND 不含 4 和 8。
const SOUND_OBJ := {
	"ARROW_GROUND": [ARROW_GROUND1, ARROW_GROUND2, ARROW_GROUND3, ARROW_GROUND5, ARROW_GROUND6, ARROW_GROUND7],
	"BLOCK": [BLOCK1, BLOCK2],
	"MONSTERS": [MONSTER1, MONSTER2, MONSTER3, MONSTER4, MONSTER5],
	"MAN_VOICE": [MAN_VOICE1, MAN_VOICE2, MAN_VOICE3, MAN_VOICE4, MAN_VOICE5, MAN_VOICE6, MAN_VOICE7],
	"MAN_DIED": [MAN_DIED1, MAN_DIED2, MAN_DIED3],
	"HEAL_CAST": [HEAL_CAST1, HEAL_CAST2, HEAL_CAST3],
	"CREATURE_ATTACK": [CREATURE_ATTACK1, CREATURE_ATTACK2, CREATURE_ATTACK3],
	"BIG_CREATURE_ATTACK": [BIG_CREATURE_ATTACK1, BIG_CREATURE_ATTACK2],
	"ARROW_IMPACT": [ARROW_IMPACT1, ARROW_IMPACT2, ARROW_IMPACT3, ARROW_IMPACT4, ARROW_IMPACT5, ARROW_IMPACT6, ARROW_IMPACT7],
	"IMPACT_FLESH": [IMPACT_FLESH1, IMPACT_FLESH2, IMPACT_FLESH3, IMPACT_FLESH4, IMPACT_FLESH5],
	"IMPACT_HANDS": [IMPACT_HANDS1, IMPACT_HANDS2, IMPACT_HANDS3],
	"IMPACT_ARMOR": [IMPACT_ARMOR1, IMPACT_ARMOR2, IMPACT_ARMOR3],
	"ARCHER_PULL": [ARCHER_PULL1, ARCHER_PULL2, ARCHER_PULL3],
	"ARCHER_SHOOT": [ARCHER_SHOOT1, ARCHER_SHOOT2, ARCHER_SHOOT3],
	"CROSSB_SHOOT": [CROSSB_SHOOT1, CROSSB_SHOOT2, CROSSB_SHOOT3],
	"MAGE_BLUE_STRIKE": [MAGE_BLUE_STRIKE1, MAGE_BLUE_STRIKE2, MAGE_BLUE_STRIKE3],
	"MAGE_RED_STRIKE": [MAGE_RED_STRIKE1, MAGE_RED_STRIKE2, MAGE_RED_STRIKE3],
	"MAGE_BLACK_STRIKE": [MAGE_BLACK_STRIKE1, MAGE_BLACK_STRIKE2, MAGE_BLACK_STRIKE3],
	"AXE": [AXE1, AXE2, AXE3],
	"HEAVY_SWORD": [HEAVY_SWORD1, HEAVY_SWORD2, HEAVY_SWORD3],
	"SWORD_SWOOSH": [SWORD_SWOOSH1, SWORD_SWOOSH2, SWORD_SWOOSH3, SWORD_SWOOSH4, SWORD_SWOOSH5, SWORD_SWOOSH6, SWORD_SWOOSH7],
}

# 对应原版 private var lib:Object 与 a:Array（a 在未匹配的 getSoundFromStack 调用间保留旧值）。
var lib: Dictionary = {}
var a: Array = []
var sound_obj: Dictionary = SOUND_OBJ

static var _symbols: Dictionary = {}
static var _paths: Dictionary = {}  # characterId -> mp3 路径（来自 data/resources.json 的 paths，文件名带 id 前缀）


# 壳类名（如 "sClick1"）-> characterId，取自 data/symbols.json。
static func symbol_id(class_name_: String) -> int:
	if _symbols.is_empty():
		var f := FileAccess.open(SYMBOLS_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_symbols = parsed
	return int(_symbols.get(SYMBOL_PREFIX + class_name_, -1))


# 壳类名 -> mp3 路径（assets/library/sound/<characterId>_<类名>....mp3）；找不到返回空串。
static func mp3_path(class_name_: String) -> String:
	var id := symbol_id(class_name_)
	if id < 0:
		return ""
	if _paths.is_empty():
		var f := FileAccess.open(RESOURCES_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for record in parsed.get("resources", []):
					if str(record.get("type", "")) != "sound":
						continue
					for path in record.get("paths", []):
						if str(path).ends_with(".mp3"):
							_paths[int(record.id)] = "res://" + str(path)
							break
	return _paths.get(id, "")


# 原版 init()：对每个 lib 键 new 一个嵌入声音。
func init() -> void:
	inst = self
	lib = {}
	for key in LIB_CLASSES:
		var path := mp3_path(LIB_CLASSES[key])
		lib[key] = load(path) if path != "" and ResourceLoader.exists(path) else null


# 反编译破损：switch 末尾带 §§goto，且 BIG_CREATURE_ATTACK 分支只有 `this.a;` 而没有赋值，
# 随后落入 ARROW_IMPACT 分支。无 P-code 可核对，按反编译结果保留：
# BIG_CREATURE_ATTACK 实际使用 ARROW_IMPACT 的候选列表（记入 docs/verification.md 待查）。
# 未匹配的键不改写 a，沿用上一次的值。随机数：Utility.randRange(0, n-1) -> floor(rand*n)。
func get_sound_from_stack(param1: String) -> AudioStream:
	match param1:
		MONSTERS: a = sound_obj["MONSTERS"]
		ARROW_GROUND: a = sound_obj["ARROW_GROUND"]
		BLOCK: a = sound_obj["BLOCK"]
		MAN_VOICE: a = sound_obj["MAN_VOICE"]
		MAN_DIED: a = sound_obj["MAN_DIED"]
		HEAL_CAST: a = sound_obj["HEAL_CAST"]
		CREATURE_ATTACK: a = sound_obj["CREATURE_ATTACK"]
		BIG_CREATURE_ATTACK: a = sound_obj["ARROW_IMPACT"]
		ARROW_IMPACT: a = sound_obj["ARROW_IMPACT"]
		IMPACT_FLESH: a = sound_obj["IMPACT_FLESH"]
		IMPACT_HANDS: a = sound_obj["IMPACT_HANDS"]
		IMPACT_ARMOR: a = sound_obj["IMPACT_ARMOR"]
		ARCHER_PULL: a = sound_obj["ARCHER_PULL"]
		ARCHER_SHOOT: a = sound_obj["ARCHER_SHOOT"]
		CROSSB_SHOOT: a = sound_obj["CROSSB_SHOOT"]
		MAGE_BLUE_STRIKE: a = sound_obj["MAGE_BLUE_STRIKE"]
		MAGE_RED_STRIKE: a = sound_obj["MAGE_RED_STRIKE"]
		MAGE_BLACK_STRIKE: a = sound_obj["MAGE_BLACK_STRIKE"]
		AXE: a = sound_obj["AXE"]
		HEAVY_SWORD: a = sound_obj["HEAVY_SWORD"]
		SWORD_SWOOSH: a = sound_obj["SWORD_SWOOSH"]
	if a.is_empty():
		push_error("SoundLibrary.get_sound_from_stack: no group for '%s'" % param1)
		return null
	var _loc2_: int = RWRandom.rand_range(0, a.size() - 1)
	return lib.get(a[_loc2_])


func get_sound(param1: String) -> AudioStream:
	return lib.get(param1)
