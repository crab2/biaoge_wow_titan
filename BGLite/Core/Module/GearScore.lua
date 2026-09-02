if BG.IsBlackListPlayer then return end
local AddonName, ns = ...

local L = ns.L
local LibBG = ns.LibBG
local RGB = ns.RGB
local Maxb = ns.Maxb
local GetItemID = ns.GetItemID

local player = BG.playerName
local realmID = BG.realmID
local GetItemInfoInstant = _G.GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)

local function ItemTypeID(link)
    if not link then return end
    if GetItemInfoInstant then
        local _, _, _, _, _, classID = GetItemInfoInstant(link)
        if classID then return classID end
    end
    return select(12, GetItemInfo(link))
end

local CR_DEFENSE_SKILL = _G.CR_DEFENSE_SKILL or 2
local CR_DODGE = _G.CR_DODGE or 3
local CR_PARRY = _G.CR_PARRY or 4
local CR_BLOCK = _G.CR_BLOCK or 5
local CR_HIT_MELEE = _G.CR_HIT_MELEE or 6
local CR_HIT_RANGED = _G.CR_HIT_RANGED or 7
local CR_HIT_SPELL = _G.CR_HIT_SPELL or 8
local CR_CRIT_MELEE = _G.CR_CRIT_MELEE or 9
local CR_CRIT_RANGED = _G.CR_CRIT_RANGED or 10
local CR_CRIT_SPELL = _G.CR_CRIT_SPELL or 11
local CR_HASTE_MELEE = _G.CR_HASTE_MELEE or 18
local CR_HASTE_RANGED = _G.CR_HASTE_RANGED or 19
local CR_HASTE_SPELL = _G.CR_HASTE_SPELL or 20
local CR_EXPERTISE = _G.CR_EXPERTISE or 24
local CR_ARMOR_PENETRATION = _G.CR_ARMOR_PENETRATION or 25

local BIAS1 = 1.45
local BIAS2 = 1.18
local ILVL_W = 0.15
local SOCKET_GEM = 16

local DEFAULT_CAPS = {
    hitMelee = 263,
    hitMeleeDW = 886,
    hitSpell = 368,
    hitSpell17 = 446,
    expertise = 214,
    defense = 140,
    arp = 1400, -- WotLK 80: ~100% armor penetration
}

local STAT_KEYS = {
    STR = true, AGI = true, STA = true, INT = true, SPI = true,
    AP = true, RAP = true, SP = true, HEAL = true,
    HIT = true, HIT_PHYSICAL = true, HIT_SPELL = true,
    CRIT = true, CRIT_PHYSICAL = true, CRIT_SPELL = true,
    HASTE = true, HASTE_PHYSICAL = true, HASTE_SPELL = true,
    ARPEN = true, SPELLPEN = true, EXPERTISE = true, DEFENSE = true,
    DODGE = true, PARRY = true, BLOCK = true, BLOCKVALUE = true,
    ARMOR = true, DPS = true, MP5 = true, SOCKET = true,
}

local WEIGHTS = {
    MELEE = {
        STR = 1.00, AGI = 1.00, STA = 0.05, INT = 0, SPI = 0,
        AP = 0.45, SP = 0, HEAL = 0, HIT = 1.60, HIT_SPELL = 0,
        CRIT = 0.70, HASTE = 0.70, ARPEN = 0.70, EXPERTISE = 1.60, DEFENSE = 0,
        DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVALUE = 0,
        ARMOR = 0, DPS = 3.50, MP5 = 0, SOCKET = 1,
    },
    RANGED = {
        STR = 0.10, AGI = 1.00, STA = 0.05, INT = 0, SPI = 0,
        AP = 0.45, SP = 0, HEAL = 0, HIT = 1.60, HIT_SPELL = 0,
        CRIT = 0.70, HASTE = 0.70, ARPEN = 0.70, EXPERTISE = 0, DEFENSE = 0,
        DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVALUE = 0,
        ARMOR = 0, DPS = 3.20, MP5 = 0, SOCKET = 1,
    },
    CASTER = {
        STR = 0, AGI = 0, STA = 0.05, INT = 0.55, SPI = 0.10,
        AP = 0, SP = 1.00, HEAL = 0, HIT = 1.60, HIT_SPELL = 1.60,
        CRIT = 0.70, HASTE = 0.70, ARPEN = 0, EXPERTISE = 0, DEFENSE = 0,
        DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVALUE = 0,
        ARMOR = 0, DPS = 0, MP5 = 0.05, SOCKET = 1,
    },
    HEAL = {
        STR = 0, AGI = 0, STA = 0.08, INT = 0.70, SPI = 0.90,
        AP = 0, SP = 1.00, HEAL = 1.00, HIT = 0, HIT_SPELL = 0,
        CRIT = 0.45, HASTE = 0.75, ARPEN = 0, EXPERTISE = 0, DEFENSE = 0,
        DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVALUE = 0,
        ARMOR = 0, DPS = 0, MP5 = 0.50, SOCKET = 1,
    },
    TANK = {
        STR = 0.35, AGI = 0.40, STA = 1.00, INT = 0, SPI = 0,
        AP = 0.10, SP = 0, HEAL = 0, HIT = 1.10, HIT_SPELL = 0,
        CRIT = 0.15, HASTE = 0.25, ARPEN = 0, EXPERTISE = 1.10, DEFENSE = 2.00,
        DODGE = 0.80, PARRY = 0.80, BLOCK = 0.50, BLOCKVALUE = 0.20,
        ARMOR = 0.04, DPS = 0.40, MP5 = 0, SOCKET = 1,
    },
}

-- iTank-style EP keys → scoring keys. Specific hit/crit/haste variants applied last.
local EP_TO_SCORE = {
    str = "STR", agi = "AGI", sta = "STA", int = "INT", spi = "SPI",
    ap = "AP", rap = "AP", sp = "SP", heal = "HEAL", mp5 = "MP5",
    armor = "ARMOR", dps = "DPS",
    hitRating = "HIT", critRating = "CRIT", hasteRating = "HASTE",
    expertiseRating = "EXPERTISE", arpRating = "ARPEN",
    dodge = "DODGE", parry = "PARRY", block = "BLOCK",
    blockValue = "BLOCKVALUE", defense = "DEFENSE",
    spellHitRating = "HIT_SPELL", spellCritRating = "CRIT", spellHasteRating = "HASTE",
    rangedHitRating = "HIT", rangedCritChance = "CRIT", rangedHasteRating = "HASTE",
}

local EP_APPLY_ORDER = {
    "str", "agi", "sta", "int", "spi",
    "ap", "sp", "heal", "mp5", "armor", "dps",
    "hitRating", "critRating", "hasteRating",
    "expertiseRating", "arpRating",
    "dodge", "parry", "block", "blockValue", "defense",
    "rap",
    "spellHitRating", "spellCritRating", "spellHasteRating",
    "rangedHitRating", "rangedCritChance", "rangedHasteRating",
}

-- Per-talent default EP. Shape follows each spec's stat mix (hit vs haste etc.).
-- Starting points for personal upgrade value, not a raid-wide BiS list.
-- Green ratings (hit/crit/haste/arp/ap/sp) often outvalue white primaries —
-- keep the sim/MYGear EP numbers. Weapon DPS is omitted so a slightly faster
-- weapon does not bury a cheaper piece with better stats. Hit / expertise /
-- defense / arp stay high because the cap already makes overflow worthless.
local SPEC_EP = {
    WARRIOR = {
        [1] = { -- 武器
            DPS = {
                str = 2.314, agi = 1.659, ap = 1.000, hitRating = 2.000, critRating = 1.975,
                hasteRating = 1.121, arpRating = 2.574, expertiseRating = 1.508, armor = 0.027, dps = 13.233,
            },
        },
        [2] = { -- 狂怒
            DPS = {
                str = 2.550, agi = 1.872, ap = 1.000, hitRating = 1.250, critRating = 2.221,
                hasteRating = 1.890, arpRating = 2.560, expertiseRating = 1.460, armor = 0.027, dps = 6.624,
            },
        },
        [3] = { -- 防护
            TANK = {
                str = 1.555, agi = 1.271, sta = 2.336, ap = 0.320, hitRating = 1.432, critRating = 0.925,
                hasteRating = 0.431, arpRating = 0.155, expertiseRating = 1.440, armor = 0.174,
                defense = 3.805, block = 1.320, blockValue = 1.373, dodge = 2.056, parry = 2.049, dps = 6.081,
            },
        },
    },
    PALADIN = {
        [1] = { -- 神圣
            HEAL = {
                int = 1.844, spi = 0.337, sp = 2.000, heal = 2.000, spellCritRating = 1.010,
                spellHasteRating = 1.200, mp5 = 0.500,
            },
        },
        [2] = { -- 防护
            TANK = {
                str = 1.100, agi = 0.620, sta = 1.200, sp = 0.130, ap = 0.260, hitRating = 1.790,
                critRating = 0.300, hasteRating = 0.170, arpRating = 0.040, expertiseRating = 0.690,
                armor = 0.070, defense = 2.540, block = 0.520, blockValue = 0.280, dodge = 0.460,
                parry = 0.610, dps = 3.330,
            },
        },
        [3] = { -- 惩戒
            DPS = {
                str = 2.530, agi = 1.530, int = 0.150, sp = 0.320, mp5 = 0.050, hitRating = 2.070,
                critRating = 1.770, hasteRating = 1.560, ap = 1.000, arpRating = 0.760,
                expertiseRating = 1.800, dps = 8.030,
            },
        },
    },
    HUNTER = {
        [1] = { -- 野兽控制
            DPS = {
                agi = 1.903, int = 1.100, rap = 1.000, ap = 1.000, rangedHitRating = 2.000,
                rangedCritChance = 1.312, rangedHasteRating = 1.038, arpRating = 1.556, dps = 5.221,
            },
        },
        [2] = { -- 射击
            DPS = {
                agi = 2.650, sta = 0.500, int = 1.100, rap = 1.000, ap = 1.000, rangedHitRating = 2.500,
                rangedCritChance = 1.500, rangedHasteRating = 1.390, arpRating = 1.320, dps = 6.320,
            },
        },
        [3] = { -- 生存
            DPS = {
                agi = 2.805, sta = 0.462, int = 1.100, rap = 1.000, ap = 1.000, rangedHitRating = 2.934,
                rangedCritChance = 1.627, rangedHasteRating = 0.885, arpRating = 1.232, dps = 5.070,
            },
        },
    },
    ROGUE = {
        [1] = { -- 刺杀
            DPS = {
                str = 1.100, agi = 1.900, ap = 1.000, hitRating = 1.910, critRating = 1.568,
                hasteRating = 1.480, arpRating = 0.950, expertiseRating = 2.375, dps = 3.176,
            },
        },
        [2] = { -- 战斗
            DPS = {
                str = 1.100, agi = 1.000, ap = 1.000, hitRating = 2.940, critRating = 1.410,
                hasteRating = 1.229, arpRating = 1.299, expertiseRating = 1.000, dps = 3.997,
            },
        },
        [3] = { -- 敏锐
            DPS = {
                str = 1.100, agi = 2.020, ap = 1.000, hitRating = 1.610, critRating = 1.210,
                hasteRating = 1.380, arpRating = 1.299, expertiseRating = 2.400, dps = 3.997,
            },
        },
    },
    PRIEST = {
        [1] = { -- 戒律
            HEAL = {
                int = 1.644, spi = 0.337, sp = 2.000, heal = 2.000, mp5 = 0.500,
                spellCritRating = 0.900, spellHasteRating = 1.200,
            },
        },
        [2] = { -- 神圣
            HEAL = {
                int = 1.644, spi = 0.337, sp = 2.000, heal = 2.000, mp5 = 0.500,
                spellCritRating = 0.900, spellHasteRating = 1.200,
            },
        },
        [3] = { -- 暗影
            DPS = {
                int = 0.212, spi = 0.565, sp = 1.000, spellHitRating = 0.636,
                spellCritRating = 0.684, spellHasteRating = 0.425,
            },
        },
    },
    DEATHKNIGHT = {
        [1] = { -- 鲜血
            TANK = {
                str = 0.830, agi = 0.600, sta = 1.400, ap = 0.060, hitRating = 0.670, critRating = 0.280,
                hasteRating = 0.210, arpRating = 0.190, expertiseRating = 0.670, armor = 0.050,
                defense = 1.500, dodge = 0.700, parry = 0.580, dps = 3.100,
            },
            DPS = {
                str = 2.900, agi = 0.948, ap = 1.000, hitRating = 2.807, critRating = 2.157,
                hasteRating = 2.084, arpRating = 2.301, expertiseRating = 2.915, armor = 0.028, dps = 9.869,
            },
        },
        [2] = { -- 冰霜
            DPS = {
                str = 2.797, agi = 1.267, ap = 1.000, hitRating = 2.051, critRating = 1.470,
                hasteRating = 1.460, arpRating = 2.061, expertiseRating = 1.107, armor = 0.030, dps = 6.574,
            },
        },
        [3] = { -- 邪恶
            DPS = {
                str = 2.890, agi = 0.745, ap = 1.000, hitRating = 1.874, critRating = 1.662,
                hasteRating = 2.000, arpRating = 0.853, expertiseRating = 1.273, armor = 0.010, dps = 3.181,
            },
        },
    },
    SHAMAN = {
        [1] = { -- 元素
            DPS = {
                int = 0.990, sp = 1.000, mp5 = 0.987, spellHitRating = 0.896,
                spellCritRating = 0.745, spellHasteRating = 0.868,
            },
        },
        [2] = { -- 增强
            DPS = {
                str = 1.100, agi = 1.613, int = 1.535, sp = 1.111, ap = 1.000, hitRating = 1.496,
                critRating = 1.295, hasteRating = 0.613, arpRating = 0.990, expertiseRating = 2.290, dps = 7.372,
            },
        },
        [3] = { -- 恢复
            HEAL = {
                int = 1.644, spi = 0.337, sp = 2.000, heal = 2.000, mp5 = 0.500,
                spellCritRating = 1.610, spellHasteRating = 2.200,
            },
        },
    },
    MAGE = {
        [1] = { -- 奥术
            DPS = {
                int = 0.132, spi = 0.294, sp = 1.000, spellHitRating = 0.907,
                spellCritRating = 0.442, spellHasteRating = 0.888,
            },
        },
        [2] = { -- 火焰
            DPS = {
                int = 0.132, spi = 0.294, sp = 1.000, spellHitRating = 0.907,
                spellCritRating = 0.442, spellHasteRating = 0.888,
            },
        },
        [3] = { -- 冰霜
            DPS = {
                int = 0.132, spi = 0.294, sp = 1.000, spellHitRating = 0.907,
                spellCritRating = 0.442, spellHasteRating = 0.888,
            },
        },
    },
    WARLOCK = {
        [1] = { -- 痛苦
            DPS = {
                sta = 0.010, int = 0.331, spi = 0.549, sp = 1.000, spellHitRating = 0.930,
                spellCritRating = 0.583, spellHasteRating = 1.047,
            },
        },
        [2] = { -- 恶魔学识
            DPS = {
                sta = 0.010, int = 0.331, spi = 0.549, sp = 1.000, spellHitRating = 0.930,
                spellCritRating = 0.583, spellHasteRating = 1.047,
            },
        },
        [3] = { -- 毁灭
            DPS = {
                int = 0.280, spi = 0.650, sp = 1.000, spellHitRating = 1.280,
                spellCritRating = 0.570, spellHasteRating = 0.510,
            },
        },
    },
    DRUID = {
        [1] = { -- 平衡
            DPS = {
                int = 0.530, spi = 0.337, sp = 1.000, spellHitRating = 1.860,
                spellCritRating = 1.270, spellHasteRating = 0.611,
            },
        },
        [2] = { -- 野性：猫输出 / 熊坦克
            DPS = {
                str = 2.379, agi = 2.522, ap = 1.000, hitRating = 2.083, critRating = 2.037,
                hasteRating = 1.767, arpRating = 2.980, expertiseRating = 2.361, dps = 16.800,
            },
            TANK = {
                sta = 2.637, agi = 1.196, ap = 1.000, critRating = 0.388, hasteRating = 0.901,
                arpRating = 0.863, expertiseRating = 2.505, armor = 1.201, parry = 0.842,
                dodge = 0.842, defense = -1.000, dps = 16.516,
            },
        },
        [3] = { -- 恢复
            HEAL = {
                int = 1.644, spi = 0.337, sp = 2.000, heal = 2.000, spellCritRating = 0.803,
                spellHasteRating = 1.111,
            },
        },
    },
}

local TANK_EP = {
    sta = 1.00, defense = 2.00, dodge = 0.80, parry = 0.80,
    expertiseRating = 1.10, hitRating = 1.10, agi = 0.40, str = 0.35,
    block = 0.50, hasteRating = 0.25, blockValue = 0.20, armor = 0.04,
    ap = 0.10, critRating = 0.15,
}

local HEAL_EP = {
    sp = 1.00, heal = 1.00, spi = 0.90, spellHasteRating = 0.75,
    int = 0.70, mp5 = 0.50, spellCritRating = 0.45, sta = 0.08,
}

local PAWN_TO_EP = {
    Strength = "str", Agility = "agi", Intellect = "int", Spirit = "spi", Stamina = "sta",
    Ap = "ap", RAP = "rap", Rap = "rap", SpellDamage = "sp", SpellPower = "sp",
    Healing = "heal", SpellHealing = "heal",
    HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating",
    ExpertiseRating = "expertiseRating", ArmorPenetration = "arpRating",
    Armor = "armor", Mp5 = "mp5", MP5 = "mp5",
    DodgeRating = "dodge", ParryRating = "parry", DefenseRating = "defense",
    BlockRating = "block", BlockValue = "blockValue",
    SpellHitRating = "spellHitRating", SpellCritRating = "spellCritRating",
    SpellHasteRating = "spellHasteRating",
    Dps = "dps", DPS = "dps",
}

local PAWN_CLASS_STAT = {
    WARRIOR = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
    PALADIN = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
    DEATHKNIGHT = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
    ROGUE = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
    HUNTER = { HitRating = "rangedHitRating", CritRating = "rangedCritChance", HasteRating = "rangedHasteRating" },
    MAGE = { HitRating = "spellHitRating", CritRating = "spellCritRating", HasteRating = "spellHasteRating" },
    WARLOCK = { HitRating = "spellHitRating", CritRating = "spellCritRating", HasteRating = "spellHasteRating" },
    PRIEST = { HitRating = "spellHitRating", CritRating = "spellCritRating", HasteRating = "spellHasteRating" },
    DRUID = {
        [1] = { HitRating = "spellHitRating", CritRating = "spellCritRating", HasteRating = "spellHasteRating" },
        [2] = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
        default = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
    },
    SHAMAN = {
        [1] = { HitRating = "spellHitRating", CritRating = "spellCritRating", HasteRating = "spellHasteRating" },
        [2] = { HitRating = "hitRating", CritRating = "critRating", HasteRating = "hasteRating" },
        default = { HitRating = "spellHitRating", CritRating = "spellCritRating", HasteRating = "spellHasteRating" },
    },
}

-- armor subclassID (typeID 4): 1 cloth, 2 leather, 3 mail, 4 plate
local CLASS_ARMOR = {
    WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
    HUNTER = 3, SHAMAN = 3,
    ROGUE = 2, DRUID = 2,
    MAGE = 1, PRIEST = 1, WARLOCK = 1,
}

-- weapon subclassID (typeID 2)
local CLASS_WEAPON = {
    WARRIOR = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [16] = true, [18] = true },
    PALADIN = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    HUNTER = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [16] = true, [18] = true },
    ROGUE = { [0] = true, [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true, [16] = true, [18] = true },
    PRIEST = { [4] = true, [10] = true, [15] = true, [19] = true },
    DEATHKNIGHT = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    SHAMAN = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
    MAGE = { [7] = true, [10] = true, [15] = true, [19] = true },
    WARLOCK = { [7] = true, [10] = true, [15] = true, [19] = true },
    DRUID = { [4] = true, [5] = true, [6] = true, [10] = true, [13] = true, [15] = true },
}

local IGNORE_ARMOR_LOC = {
    INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true, INVTYPE_HOLDABLE = true, INVTYPE_SHIELD = true,
    INVTYPE_RELIC = true, INVTYPE_TABARD = true, INVTYPE_BODY = true,
}

local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_TABARD = { 19 },
}

local function RangedSlots()
    if BG.verOver4 then
        return { 16 }
    end
    return { 18 }
end

local function SlotsForLoc(equipLoc)
    if equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
        or equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_RELIC" then
        return RangedSlots()
    end
    return EQUIP_SLOTS[equipLoc]
end

-- GetItemStats on Titan/Classic may use either ITEM_MOD_X or ITEM_MOD_X_SHORT.
local STAT_MAP = {
    ITEM_MOD_STRENGTH = "STR",
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY = "AGI",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA = "STA",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT = "INT",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT = "SPI",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_HIT_RATING = "HIT",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_MELEE_RATING = "HIT_PHYSICAL",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT_PHYSICAL",
    ITEM_MOD_HIT_RANGED_RATING = "HIT_PHYSICAL",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT_PHYSICAL",
    ITEM_MOD_HIT_SPELL_RATING = "HIT_SPELL",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT_SPELL",
    ITEM_MOD_CRIT_RATING = "CRIT",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_MELEE_RATING = "CRIT_PHYSICAL",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT_PHYSICAL",
    ITEM_MOD_CRIT_RANGED_RATING = "CRIT_PHYSICAL",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT_PHYSICAL",
    ITEM_MOD_CRIT_SPELL_RATING = "CRIT_SPELL",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT_SPELL",
    ITEM_MOD_HASTE_RATING = "HASTE",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_MELEE_RATING = "HASTE_PHYSICAL",
    ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE_PHYSICAL",
    ITEM_MOD_HASTE_RANGED_RATING = "HASTE_PHYSICAL",
    ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE_PHYSICAL",
    ITEM_MOD_HASTE_SPELL_RATING = "HASTE_SPELL",
    ITEM_MOD_HASTE_SPELL_RATING_SHORT = "HASTE_SPELL",
    ITEM_MOD_EXPERTISE_RATING = "EXPERTISE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
    ITEM_MOD_DEFENSE_SKILL_RATING = "DEFENSE",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE",
    ITEM_MOD_DODGE_RATING = "DODGE",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING = "PARRY",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING = "BLOCK",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE = "BLOCKVALUE",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_ARMOR_PENETRATION_RATING = "ARPEN",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARPEN",
    ITEM_MOD_SPELL_PENETRATION = "SPELLPEN",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "SPELLPEN",
    ITEM_MOD_SPELL_POWER = "SP",
    ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_SPELL_DAMAGE_DONE = "SP",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
    ITEM_MOD_SPELL_HEALING_DONE = "HEAL",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_ATTACK_POWER = "AP",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER = "RAP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_FERAL_ATTACK_POWER = "FERAL_AP",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "FERAL_AP",
    ITEM_MOD_POWER_REGEN0 = "MP5",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_MANA_REGENERATION = "MP5",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_DAMAGE_PER_SECOND = "DPS",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    ITEM_MOD_ARMOR = "ARMOR",
    ITEM_MOD_ARMOR_SHORT = "ARMOR",
    RESISTANCE0_NAME = "ARMOR",
    ARMOR = "ARMOR",
    EMPTY_SOCKET_RED = "SOCKET",
    EMPTY_SOCKET_YELLOW = "SOCKET",
    EMPTY_SOCKET_BLUE = "SOCKET",
    EMPTY_SOCKET_META = "SOCKET",
    EMPTY_SOCKET_PRISMATIC = "SOCKET",
    EMPTY_SOCKET_NO_COLOR = "SOCKET",
}

local WHITE_STAT = {
    STR = true, AGI = true, STA = true, INT = true, SPI = true, ARMOR = true,
}

local function CopyWeights(src)
    local t = {}
    for k, v in pairs(src) do
        t[k] = v
    end
    return t
end

local function CombatRating(id)
    if not GetCombatRating or not id then return 0 end
    return GetCombatRating(id) or 0
end

local SPELL_HIT_PER_PCT = (DEFAULT_CAPS.hitSpell17 or 446) / 17
local MELEE_HIT_PER_PCT = (DEFAULT_CAPS.hitMelee or 263) / 8

-- WotLK talent IDs that grant hit. value = { spell = perRank, melee = perRank, ranged = perRank }
local HIT_TALENT_IDS = {
    [1005] = { spell = 1 },            -- Warlock Suppression
    [463]  = { spell = 1 },            -- Priest Shadow Focus
    [181]  = { melee = 1, ranged = 1 }, -- Rogue Precision
    [1649] = { spell = 1 },            -- Shaman Elemental Precision
    [1783] = { spell = 2 },            -- Druid Balance of Power
    [1310] = { melee = 1, ranged = 1 }, -- Hunter Surefooted
    [1581] = { melee = 5 },            -- Warrior Dual Wield Specialization (1 rank)
}

local HIT_TALENT_NAMES = {
    WARLOCK = {
        ["镇压"] = { spell = 1 }, ["鎮壓"] = { spell = 1 }, ["Suppression"] = { spell = 1 },
    },
    MAGE = {
        ["精确"] = { spell = 1 }, ["精確"] = { spell = 1 }, ["Precision"] = { spell = 1 },
    },
    PRIEST = {
        ["暗影集中"] = { spell = 1 }, ["暗影專注"] = { spell = 1 }, ["Shadow Focus"] = { spell = 1 },
    },
    DRUID = {
        ["能量平衡"] = { spell = 2 }, ["Balance of Power"] = { spell = 2 },
    },
    SHAMAN = {
        ["元素精准"] = { spell = 1 }, ["元素精準"] = { spell = 1 }, ["Elemental Precision"] = { spell = 1 },
    },
    PALADIN = {
        ["开明审判"] = { spell = 2, melee = 2 }, ["開明審判"] = { spell = 2, melee = 2 },
        ["Enlightened Judgements"] = { spell = 2, melee = 2 },
    },
    HUNTER = {
        ["专注瞄准"] = { melee = 1, ranged = 1 }, ["專注瞄準"] = { melee = 1, ranged = 1 },
        ["Focused Aim"] = { melee = 1, ranged = 1 },
        ["稳固"] = { melee = 1, ranged = 1 }, ["穩固"] = { melee = 1, ranged = 1 },
        ["Surefooted"] = { melee = 1, ranged = 1 },
    },
    ROGUE = {
        ["精确"] = { melee = 1 }, ["精確"] = { melee = 1 }, ["Precision"] = { melee = 1 },
    },
    DEATHKNIGHT = {
        ["冰冷神经"] = { melee = 1 }, ["冰冷神經"] = { melee = 1 },
        ["Nerves of Cold Steel"] = { melee = 1 },
        ["恶毒"] = { spell = 1 }, ["惡毒"] = { spell = 1 }, ["Virulence"] = { spell = 1 },
    },
    WARRIOR = {
        ["双武器专精"] = { melee = 1 }, ["雙武器專精"] = { melee = 1 },
        ["Dual Wield Specialization"] = { melee = 1 },
    },
}

local talentTip
local function TalentTip()
    if not talentTip then
        talentTip = CreateFrame("GameTooltip", "BGGearScoreTalentTip", UIParent, "GameTooltipTemplate")
        talentTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return talentTip
end

local function TalentTipText()
    local tip = TalentTip()
    local parts = {}
    local n = tip:NumLines() or 0
    for i = 1, n do
        local fs = _G["BGGearScoreTalentTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and t ~= "" then
            tinsert(parts, t)
        end
    end
    return table.concat(parts, " ")
end

local function SetTalentTip(tab, index, group)
    local tip = TalentTip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    if group then
        local ok = pcall(tip.SetTalent, tip, tab, index, false, false, group)
        if ok then return true end
    end
    return pcall(tip.SetTalent, tip, tab, index)
end

-- Returns spellPct, physPct, genericPct from a talent description.
local function ParseHitFromText(text)
    if type(text) ~= "string" or text == "" then
        return 0, 0, 0
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("被.-击中.-%d+[%%％]", "")
    text = text:gsub("被.-擊中.-%d+[%%％]", "")
    text = text:gsub("[Cc]hance you'll be hit by spells by %d+%%", "")
    text = text:gsub("you'll be hit by spells by %d+%%", "")
    text = text:gsub("[Cc]hance to be hit.-%d+%%", "")

    local function firstNum(...)
        for i = 1, select("#", ...) do
            local n = tonumber(select(i, ...))
            if n then return n end
        end
        return 0
    end

    local spell = firstNum(
        text:match("法术命中.-(%d+)[%%％]"),
        text:match("法術命中.-(%d+)[%%％]"),
        text:match("法术的命中.-(%d+)[%%％]"),
        text:match("法術的命中.-(%d+)[%%％]"),
        text:match("[Hh]it with spells by (%d+)%%"),
        text:match("[Hh]it with all spells by (%d+)%%"),
        text:match("[Hh]it with your spells by (%d+)%%"),
        text:match("[Hh]it with Shadow spells by (%d+)%%"),
        text:match("[Hh]it with Fire, Frost and Nature spells by (%d+)%%")
    )
    if spell > 0 then
        return spell, 0, 0
    end

    local lower = text:lower()
    local isPhys = text:find("武器", 1, true) or text:find("近战", 1, true) or text:find("近戰", 1, true)
        or text:find("毒药", 1, true) or text:find("毒藥", 1, true)
        or lower:find("weapon", 1, true) or lower:find("melee", 1, true) or lower:find("poison", 1, true)
    if isPhys then
        local phys = firstNum(
            text:match("命中.-(%d+)[%%％]"),
            text:match("[Cc]hance to hit with.-(%d+)%%"),
            text:match("[Hh]it with.-(%d+)%%")
        )
        return 0, phys, 0
    end

    local generic = firstNum(
        text:match("命中几率提高(%d+)[%%％]"),
        text:match("命中机率提高(%d+)[%%％]"),
        text:match("命中機率提高(%d+)[%%％]"),
        text:match("命中率提高(%d+)[%%％]"),
        text:match("[Ii]ncreases your chance to hit by (%d+)%%"),
        text:match("[Cc]hance to hit by (%d+)%%"),
        text:match("[Hh]it chance by (%d+)%%")
    )
    return 0, 0, generic
end

local function AddHitSpec(dst, spec, rank)
    if not spec or not rank or rank <= 0 then return end
    dst.spell = dst.spell + (spec.spell or 0) * rank
    dst.melee = dst.melee + (spec.melee or 0) * rank
    dst.ranged = dst.ranged + (spec.ranged or 0) * rank
end

local function TalentLinkID(tab, index, group)
    if not GetTalentLink then return end
    local link
    if group then
        local ok, v = pcall(GetTalentLink, tab, index, false, false, group)
        if ok then link = v end
    end
    if not link then
        local ok, v = pcall(GetTalentLink, tab, index)
        if ok then link = v end
    end
    if type(link) == "string" then
        return tonumber(link:match("talent:(%d+)"))
    end
end

local function PctToHitRating(pct, cr, perPct)
    if not pct or pct == 0 then return 0 end
    if GetCombatRatingBonus then
        local rating = CombatRating(cr)
        local bonus = GetCombatRatingBonus(cr)
        if rating and rating > 0 and bonus and bonus > 0 then
            return pct * rating / bonus
        end
    end
    return pct * perPct
end

local function ScanPlayerHit()
    local meleePct, rangedPct, spellPct, talentMelee, talentRanged, talentSpell, racialPct = 0, 0, 0, 0, 0, 0, 0
    if BG.verOver4 and (GetHitModifier or GetSpellHitModifier) then
        if GetHitModifier then
            meleePct = GetHitModifier() or 0
            rangedPct = meleePct
        end
        if GetSpellHitModifier then
            spellPct = GetSpellHitModifier() or 0
        end
        talentMelee, talentRanged, talentSpell = meleePct, rangedPct, spellPct
    elseif GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        local class = select(2, UnitClass("player"))
        local group = GetActiveTalentGroup and GetActiveTalentGroup() or nil
        local names = HIT_TALENT_NAMES[class]
        local acc = { spell = 0, melee = 0, ranged = 0 }
        local nTabs = GetNumTalentTabs() or 3
        for tab = 1, nTabs do
            local nTalents = GetNumTalents(tab) or 0
            for index = 1, nTalents do
                local name, rank
                local ok, n1, _, _, _, r1 = pcall(GetTalentInfo, tab, index, false, false, group)
                if ok then
                    name, rank = n1, r1
                else
                    ok, n1, _, _, _, r1 = pcall(GetTalentInfo, tab, index)
                    if ok then
                        name, rank = n1, r1
                    end
                end
                rank = tonumber(rank) or 0
                if rank > 0 then
                    local parsed
                    if SetTalentTip(tab, index, group) then
                        local sp, ph, ge = ParseHitFromText(TalentTipText())
                        if sp > 0 or ph > 0 or ge > 0 then
                            acc.spell = acc.spell + sp + ge
                            acc.melee = acc.melee + ph + ge
                            acc.ranged = acc.ranged + ph + ge
                            parsed = true
                        end
                    end
                    if not parsed then
                        local id = TalentLinkID(tab, index, group)
                        local spec = (id and HIT_TALENT_IDS[id]) or (name and names and names[name])
                        if spec then
                            AddHitSpec(acc, spec, rank)
                        end
                    end
                end
            end
        end
        talentSpell, talentMelee, talentRanged = acc.spell, acc.melee, acc.ranged
        spellPct, meleePct, rangedPct = acc.spell, acc.melee, acc.ranged
    end
    -- Cata+ GetHitModifier already includes Heroic Presence.
    if not BG.verOver4 and select(2, UnitRace("player")) == "Draenei" then
        racialPct = 1
        meleePct = meleePct + 1
        rangedPct = rangedPct + 1
        spellPct = spellPct + 1
    end
    return {
        meleePct = meleePct,
        rangedPct = rangedPct,
        spellPct = spellPct,
        talentMeleePct = talentMelee,
        talentRangedPct = talentRanged,
        talentSpellPct = talentSpell,
        racialPct = racialPct,
        meleeRating = PctToHitRating(meleePct, CR_HIT_MELEE, MELEE_HIT_PER_PCT),
        rangedRating = PctToHitRating(rangedPct, CR_HIT_RANGED, MELEE_HIT_PER_PCT),
        spellRating = PctToHitRating(spellPct, CR_HIT_SPELL, SPELL_HIT_PER_PCT),
    }
end

local function RoundHit(n)
    if not n then return 0 end
    return math.floor(n + 0.5)
end

local function GetClassFile()
    return select(2, UnitClass("player"))
end

local function GetClassName()
    return UnitClass("player")
end

-- WotLK talent tab 1-3: role + damage school. specType is never picked by hand.
-- altRoles: same tree can play another duty (Feral tank/cat, Blood DK DPS).
local CLASS_TALENTS = {
    WARRIOR = {
        { role = "DPS", specType = "MELEE" },
        { role = "DPS", specType = "MELEE" },
        { role = "TANK", specType = "MELEE" },
    },
    PALADIN = {
        { role = "HEAL", specType = "CASTER" },
        { role = "TANK", specType = "MELEE" },
        { role = "DPS", specType = "MELEE" },
    },
    HUNTER = {
        { role = "DPS", specType = "RANGED" },
        { role = "DPS", specType = "RANGED" },
        { role = "DPS", specType = "RANGED" },
    },
    ROGUE = {
        { role = "DPS", specType = "MELEE" },
        { role = "DPS", specType = "MELEE" },
        { role = "DPS", specType = "MELEE" },
    },
    PRIEST = {
        { role = "HEAL", specType = "CASTER" },
        { role = "HEAL", specType = "CASTER" },
        { role = "DPS", specType = "CASTER" },
    },
    DEATHKNIGHT = {
        { role = "TANK", specType = "MELEE", altRoles = { "DPS" } },
        { role = "DPS", specType = "MELEE" },
        { role = "DPS", specType = "MELEE" },
    },
    SHAMAN = {
        { role = "DPS", specType = "CASTER" },
        { role = "DPS", specType = "MELEE" },
        { role = "HEAL", specType = "CASTER" },
    },
    MAGE = {
        { role = "DPS", specType = "CASTER" },
        { role = "DPS", specType = "CASTER" },
        { role = "DPS", specType = "CASTER" },
    },
    WARLOCK = {
        { role = "DPS", specType = "CASTER" },
        { role = "DPS", specType = "CASTER" },
        { role = "DPS", specType = "CASTER" },
    },
    DRUID = {
        { role = "DPS", specType = "CASTER" },
        { role = "DPS", specType = "MELEE", altRoles = { "TANK" } },
        { role = "HEAL", specType = "CASTER" },
    },
}

local TALENT_NAME_FALLBACK
do
    local loc = GetLocale and GetLocale() or "zhCN"
    if loc == "zhTW" then
        TALENT_NAME_FALLBACK = {
            WARRIOR = { "武器", "狂怒", "防護" },
            PALADIN = { "神聖", "防護", "懲戒" },
            HUNTER = { "野獸控制", "射擊", "生存" },
            ROGUE = { "刺殺", "戰鬥", "敏銳" },
            PRIEST = { "戒律", "神聖", "暗影" },
            DEATHKNIGHT = { "鮮血", "冰霜", "邪惡" },
            SHAMAN = { "元素", "增強", "恢復" },
            MAGE = { "奧術", "火焰", "冰霜" },
            WARLOCK = { "痛苦", "惡魔學識", "毀滅" },
            DRUID = { "平衡", "野性", "恢復" },
        }
    elseif loc == "enUS" or loc == "enGB" then
        TALENT_NAME_FALLBACK = {
            WARRIOR = { "Arms", "Fury", "Protection" },
            PALADIN = { "Holy", "Protection", "Retribution" },
            HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
            ROGUE = { "Assassination", "Combat", "Subtlety" },
            PRIEST = { "Discipline", "Holy", "Shadow" },
            DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
            SHAMAN = { "Elemental", "Enhancement", "Restoration" },
            MAGE = { "Arcane", "Fire", "Frost" },
            WARLOCK = { "Affliction", "Demonology", "Destruction" },
            DRUID = { "Balance", "Feral", "Restoration" },
        }
    else
        TALENT_NAME_FALLBACK = {
            WARRIOR = { "武器", "狂怒", "防护" },
            PALADIN = { "神圣", "防护", "惩戒" },
            HUNTER = { "野兽控制", "射击", "生存" },
            ROGUE = { "刺杀", "战斗", "敏锐" },
            PRIEST = { "戒律", "神圣", "暗影" },
            DEATHKNIGHT = { "鲜血", "冰霜", "邪恶" },
            SHAMAN = { "元素", "增强", "恢复" },
            MAGE = { "奥术", "火焰", "冰霜" },
            WARLOCK = { "痛苦", "恶魔学识", "毁灭" },
            DRUID = { "平衡", "野性", "恢复" },
        }
    end
end

local TALENT_ICON_FALLBACK = {
    WARRIOR = {
        "Interface\\Icons\\Ability_Warrior_SavageBlow",
        "Interface\\Icons\\Ability_Warrior_InnerRage",
        "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    },
    PALADIN = {
        "Interface\\Icons\\Spell_Holy_HolyBolt",
        "Interface\\Icons\\Spell_Holy_DevotionAura",
        "Interface\\Icons\\Spell_Holy_AuraOfLight",
    },
    HUNTER = {
        "Interface\\Icons\\Ability_Hunter_BeastTaming",
        "Interface\\Icons\\Ability_Marksmanship",
        "Interface\\Icons\\Ability_Hunter_SwiftStrike",
    },
    ROGUE = {
        "Interface\\Icons\\Ability_Rogue_Eviscerate",
        "Interface\\Icons\\Ability_BackStab",
        "Interface\\Icons\\Ability_Stealth",
    },
    PRIEST = {
        "Interface\\Icons\\Spell_Holy_WordFortitude",
        "Interface\\Icons\\Spell_Holy_HolyBolt",
        "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    },
    DEATHKNIGHT = {
        "Interface\\Icons\\Spell_Deathknight_BloodPresence",
        "Interface\\Icons\\Spell_Deathknight_FrostPresence",
        "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
    },
    SHAMAN = {
        "Interface\\Icons\\Spell_Nature_Lightning",
        "Interface\\Icons\\Spell_Nature_LightningShield",
        "Interface\\Icons\\Spell_Nature_MagicImmunity",
    },
    MAGE = {
        "Interface\\Icons\\Spell_Holy_MagicalSentry",
        "Interface\\Icons\\Spell_Fire_FireBolt02",
        "Interface\\Icons\\Spell_Frost_FrostBolt02",
    },
    WARLOCK = {
        "Interface\\Icons\\Spell_Shadow_DeathCoil",
        "Interface\\Icons\\Spell_Shadow_Metamorphosis",
        "Interface\\Icons\\Spell_Shadow_RainOfFire",
    },
    DRUID = {
        "Interface\\Icons\\Spell_Nature_StarFall",
        "Interface\\Icons\\Ability_Racial_BearForm",
        "Interface\\Icons\\Spell_Nature_HealingTouch",
    },
}

local function SpecDef(class, tab)
    class = class or GetClassFile()
    local list = CLASS_TALENTS[class]
    if not list then
        return { role = "DPS", specType = "MELEE" }
    end
    tab = tonumber(tab) or 1
    return list[tab] or list[1]
end

local function SpecSupportsRole(def, role)
    if not def or not role then return false end
    if def.role == role then return true end
    if def.altRoles then
        for _, r in ipairs(def.altRoles) do
            if r == role then return true end
        end
    end
    return false
end

local function ClassRoles(class)
    class = class or GetClassFile()
    local list = CLASS_TALENTS[class]
    local seen, out = {}, {}
    local function add(role)
        if role and not seen[role] then
            seen[role] = true
            tinsert(out, role)
        end
    end
    if not list then
        add("TANK")
        add("HEAL")
        add("DPS")
        return out
    end
    for _, def in ipairs(list) do
        add(def.role)
        if def.altRoles then
            for _, r in ipairs(def.altRoles) do
                add(r)
            end
        end
    end
    local order = { TANK = 1, HEAL = 2, DPS = 3 }
    table.sort(out, function(a, b)
        return (order[a] or 9) < (order[b] or 9)
    end)
    return out
end

local function RoleAllowedForClass(class, role)
    for _, r in ipairs(ClassRoles(class)) do
        if r == role then return true end
    end
    return false
end

local function DefaultTabForRole(class, role)
    local list = CLASS_TALENTS[class or GetClassFile()]
    if not list then return 1 end
    for i, def in ipairs(list) do
        if def.role == role then return i end
    end
    for i, def in ipairs(list) do
        if SpecSupportsRole(def, role) then return i end
    end
    return 1
end

local function DetectTalentTab()
    local spec = BiaoGe.playerInfo and BiaoGe.playerInfo[realmID]
        and BiaoGe.playerInfo[realmID][player] and BiaoGe.playerInfo[realmID][player].talent
    spec = tonumber(spec)
    if spec and spec >= 1 and spec <= 3 then
        return spec
    end
    local maxPoints, mainTree = -1, 1
    if GetTalentTabInfo then
        local group = GetActiveTalentGroup and GetActiveTalentGroup() or nil
        for i = 1, 3 do
            local ok, name, icon, spent, background, preview
            if group then
                ok, name, icon, spent, background, preview = pcall(GetTalentTabInfo, i, false, false, group)
                if not ok then
                    ok, name, icon, spent, background, preview = pcall(GetTalentTabInfo, i, nil, nil, group)
                end
            else
                ok, name, icon, spent, background, preview = pcall(GetTalentTabInfo, i)
            end
            local points = tonumber(spent) or 0
            local extra = tonumber(preview) or 0
            if extra > points then
                points = extra
            end
            if points > maxPoints then
                maxPoints = points
                mainTree = i
            end
        end
    end
    return mainTree
end

local function TalentTabRaw(tab)
    if not GetTalentTabInfo then return end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or nil
    local ok, a, b, c, d, e
    if group then
        ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab, false, false, group)
        if not ok or a == nil then
            ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab, nil, nil, group)
        end
    end
    if not ok or a == nil then
        ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab)
    end
    if not ok then return end
    return a, b, c, d, e
end

local function IsTalentTexture(v)
    if type(v) == "number" then
        return v > 0
    end
    if type(v) == "string" and v ~= "" then
        return v:find("[\\/]") or v:find("^Interface") or v:find("INV_")
            or v:find("Spell_") or v:find("Ability_") or v:find("Achievement_")
    end
    return false
end

local function TalentTabName(class, tab)
    class = class or GetClassFile()
    tab = tonumber(tab) or 1
    local a, b = TalentTabRaw(tab)
    if type(a) == "string" and a ~= "" then
        return a
    end
    if type(b) == "string" and b ~= "" and not IsTalentTexture(b) then
        return b
    end
    local fb = TALENT_NAME_FALLBACK[class]
    return (fb and fb[tab]) or (L["天赋"] .. tab)
end

local function TalentTabIcon(class, tab)
    class = class or GetClassFile()
    tab = tonumber(tab) or 1
    local a, b, c, d = TalentTabRaw(tab)
    if IsTalentTexture(b) then
        return b
    end
    if IsTalentTexture(d) then
        return d
    end
    if IsTalentTexture(c) then
        return c
    end
    local fb = TALENT_ICON_FALLBACK[class]
    return fb and fb[tab]
end

local function RoleLabel(role)
    if role == "TANK" then return L["坦克"] end
    if role == "HEAL" then return L["治疗"] end
    return L["输出"]
end

local function GuessProfile(class, specIndex)
    class = class or GetClassFile()
    specIndex = tonumber(specIndex) or DetectTalentTab()
    local def = SpecDef(class, specIndex)
    return def.role, def.specType, def.role == "TANK", specIndex
end

local function PrimaryFor(class, role, specType)
    class = class or GetClassFile()
    if role == "HEAL" then
        return "INT"
    end
    if specType == "CASTER" then
        return "INT"
    end
    if class == "WARRIOR" or class == "PALADIN" or class == "DEATHKNIGHT" then
        return "STR"
    end
    if class == "SHAMAN" and specType == "MELEE" then
        return "STR"
    end
    if class == "DRUID" and role == "TANK" then
        return "AGI"
    end
    if specType == "RANGED" or class == "ROGUE" or class == "HUNTER" or class == "DRUID" then
        return "AGI"
    end
    return "STR"
end

local function DefaultBias(role, specType)
    if role == "TANK" then return "STA", "DODGE" end
    if role == "HEAL" then return "SP", "HASTE" end
    if specType == "CASTER" then return "SP", "HASTE" end
    if specType == "RANGED" then return "ARPEN", "CRIT" end
    return "ARPEN", "HASTE"
end

function BG.GearScore_BiasOptions(role, specType, primary)
    local list
    if role == "TANK" then
        list = { "STA", "DODGE", "PARRY", "HASTE" }
    elseif role == "HEAL" then
        list = { "SP", "HASTE", "CRIT", "SPI" }
    elseif specType == "CASTER" then
        list = { "SP", "HASTE", "CRIT", "INT" }
    elseif specType == "RANGED" then
        list = { "ARPEN", "HASTE", "CRIT", "AGI" }
    else
        list = { "ARPEN", "HASTE", "CRIT", primary or "STR" }
    end
    local labels = {
        STA = L["耐力"], DODGE = L["躲闪"], PARRY = L["招架"], HASTE = L["急速"],
        SP = L["法强"], CRIT = L["暴击"], SPI = L["精神"], INT = L["智力"],
        ARPEN = L["破甲"], AGI = L["敏捷"], STR = L["力量"],
    }
    local out = {}
    for _, key in ipairs(list) do
        tinsert(out, { key = key, label = labels[key] or key })
    end
    return out
end

local function NormalizeProfile(db)
    local class = GetClassFile()
    local tab = tonumber(db.talentTab) or DetectTalentTab()
    if tab < 1 or tab > 3 then
        tab = 1
    end
    db.talentTab = tab
    local def = SpecDef(class, tab)
    db.specType = def.specType
    if not RoleAllowedForClass(class, db.role) then
        db.role = def.role
        db.isMT = db.role == "TANK"
    elseif not SpecSupportsRole(def, db.role) and not db.roleLocked then
        db.role = def.role
        db.isMT = db.role == "TANK"
    end
    if db.role ~= "TANK" then
        db.isMT = false
    elseif db.isMT == nil then
        db.isMT = true
    end
    return db
end

local function GetDB()
    -- This profile is local-only: it drives suggestions for this character
    -- and is never included in raid addon messages or ranking data.
    BiaoGe.GearScore = BiaoGe.GearScore or {}
    BiaoGe.GearScore[realmID] = BiaoGe.GearScore[realmID] or {}
    local db = BiaoGe.GearScore[realmID][player]
    if not db then
        local tab = DetectTalentTab()
        local role, specType, isMT = GuessProfile(nil, tab)
        local bias1, bias2 = DefaultBias(role, specType)
        db = {
            role = role,
            specType = specType,
            talentTab = tab,
            isMT = isMT and true or false,
            -- iTank's default is the physical/yellow hit cap (8%).
            -- The 27% dual-wield cap is opt-in because it is only relevant
            -- when the player explicitly wants to value white swings.
            dualWieldHit = false,
            dualWieldHitSet = false,
            spellHit17 = false,
            bias1 = bias1,
            bias2 = bias2,
            userSet = false,
            talentLocked = false,
            roleLocked = false,
        }
        BiaoGe.GearScore[realmID][player] = db
    end
    -- Profiles created before the dual-wield cap was made opt-in inherited
    -- `true` for every rogue. Treat that value as the old default once, while
    -- preserving the setting after the user explicitly changes the checkbox.
    if db.dualWieldHitSet == nil then
        db.dualWieldHit = false
        db.dualWieldHitSet = false
    end
    if not db.talentTab then
        db.talentTab = DetectTalentTab()
    end
    return db
end

function BG.GearScore_GetDB()
    return GetDB()
end

local function GetMainTree()
    local gs = BiaoGe.GearScore
    local db = gs and gs[realmID] and gs[realmID][player]
    if db and db.talentLocked then
        local tab = tonumber(db.talentTab)
        if tab and tab >= 1 and tab <= 3 then
            return tab
        end
    end
    return DetectTalentTab()
end

local applyProfileChange
local specIconButtons = {}

local function PaintSpecIcon(bt, selected)
    if not bt then return end
    if selected then
        bt:SetBackdropBorderColor(0, 1, 0, 1)
        if bt.icon then
            bt.icon:SetDesaturated(false)
            bt.icon:SetAlpha(1)
        end
    else
        bt:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
        if bt.icon then
            bt.icon:SetDesaturated(true)
            bt.icon:SetAlpha(0.55)
        end
    end
end

local function RefreshSpecButtons()
    local db = GetDB()
    local class = GetClassFile()
    local cur = tonumber(db.talentTab) or GetMainTree()
    for _, bt in ipairs(specIconButtons) do
        if bt.icon then
            bt.icon:SetTexture(TalentTabIcon(class, bt.tab) or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        PaintSpecIcon(bt, bt.tab == cur)
    end
    if BG.GearScorePrefButton then
        local on = BG.GearPrefMainFrame and BG.GearPrefMainFrame:IsShown()
        BG.GearScorePrefButton:SetBackdropBorderColor(on and 1 or 0.12, on and 0.82 or 0.12, on and 0 or 0.12, 1)
    end
end
BG.GearScore_RefreshSpecBar = RefreshSpecButtons

local function CreateSpecIconButton(parent, tab, size)
    local bt = CreateFrame("Button", nil, parent, "BackdropTemplate")
    bt:SetSize(size, size)
    bt:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeSize = 1,
    })
    bt:SetBackdropColor(0, 0, 0, 0.7)
    bt:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
    local icon = bt:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(TalentTabIcon(GetClassFile(), tab) or "Interface\\Icons\\INV_Misc_QuestionMark")
    bt.icon = icon
    bt.tab = tab
    local hl = bt:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 1, 1, 0.18)
    bt:SetScript("OnEnter", function(self)
        local class = GetClassFile()
        local name = TalentTabName(class, tab)
        local def = SpecDef(class, tab)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, 0)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddLine(RoleLabel(def.role), 1, 0.82, 0)
        GameTooltip:AddLine(L["点击后按该天赋计算升级分。"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    bt:SetScript("OnLeave", GameTooltip_Hide)
    bt:SetScript("OnClick", function()
        BG.GearScore_SetTalentTab(tab)
    end)
    tinsert(specIconButtons, bt)
    return bt
end

function BG.GearScore_SetTalentTab(tab, silent)
    tab = tonumber(tab)
    if not tab or tab < 1 or tab > 3 then
        return
    end
    local db = GetDB()
    local class = GetClassFile()
    db.talentTab = tab
    db.talentLocked = true
    db.userSet = true
    db.roleLocked = false
    local def = SpecDef(class, tab)
    db.specType = def.specType
    db.role = def.role
    db.isMT = def.role == "TANK"
    if applyProfileChange then
        applyProfileChange(true, silent)
    else
        NormalizeProfile(db)
        RefreshSpecButtons()
        if not silent then
            BG.GearScore_OnSettingChanged()
            BG.PlaySound(1)
        end
    end
end

function BG.GearScore_SpecBarUI()
    if BG.GearScoreSpecBar then
        RefreshSpecButtons()
        return
    end
    -- 表格页底部按钮行：清空表格与通报按钮之间、底部模块页签正上方
    local parent = BG.FBMainFrame
    if not parent then
        return
    end

    local ICON, GAP, PREF_GAP = 26, 3, 8
    local barW = ICON * 4 + GAP * 2 + PREF_GAP
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(barW, 28)
    -- 与底部「表格」tab 左对齐（tab 锚在 MainFrame BOTTOM -185），y 与清空/通报按钮同一行
    bar:SetPoint("BOTTOMLEFT", BG.MainFrame, "BOTTOM", -185, 38)
    bar:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 5)
    BG.GearScoreSpecBar = bar

    for tab = 1, 3 do
        local bt = CreateSpecIconButton(bar, tab, ICON)
        bt:SetPoint("LEFT", (tab - 1) * (ICON + GAP), 0)
    end

    local pref = CreateFrame("Button", nil, bar, "BackdropTemplate")
    pref:SetSize(ICON, ICON)
    pref:SetPoint("LEFT", 3 * ICON + 2 * GAP + PREF_GAP, 0)
    pref:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeSize = 1,
    })
    pref:SetBackdropColor(0, 0, 0, 0.7)
    pref:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
    local picon = pref:CreateTexture(nil, "ARTWORK")
    picon:SetPoint("TOPLEFT", 1, -1)
    picon:SetPoint("BOTTOMRIGHT", -1, 1)
    picon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    picon:SetTexture("Interface\\Icons\\Trade_Engineering")
    pref.icon = picon
    local phl = pref:CreateTexture(nil, "HIGHLIGHT")
    phl:SetPoint("TOPLEFT", 1, -1)
    phl:SetPoint("BOTTOMRIGHT", -1, 1)
    phl:SetColorTexture(1, 1, 1, 0.18)
    pref:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, 0)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["装备偏好"], 1, 1, 1)
        GameTooltip:AddLine(L["打开装备偏好，调整属性价值和命中门槛。"], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    pref:SetScript("OnLeave", GameTooltip_Hide)
    pref:SetScript("OnClick", function()
        if BG.ClickTabButton and BG.GearPrefMainFrameTabNum then
            BG.ClickTabButton(BG.GearPrefMainFrameTabNum)
        end
        BG.PlaySound(1)
        RefreshSpecButtons()
    end)
    BG.GearScorePrefButton = pref

    if BG.GearPrefMainFrame then
        BG.GearPrefMainFrame:HookScript("OnShow", RefreshSpecButtons)
        BG.GearPrefMainFrame:HookScript("OnHide", RefreshSpecButtons)
    end
    RefreshSpecButtons()
end

local function FormatWeight(n)
    n = tonumber(n)
    if not n then return "0" end
    if math.abs(n - math.floor(n + 0.00001)) < 0.00001 then
        return tostring(math.floor(n + 0.00001))
    end
    local s = string.format("%.4f", n):gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function EPLabel(key)
    local labels = {
        str = L["力量"],
        agi = L["敏捷"],
        sta = L["耐力"],
        int = L["智力"],
        spi = L["精神"],
        ap = L["攻强"],
        rap = L["远程攻强"],
        sp = L["法伤"],
        heal = L["治疗强度"],
        mp5 = L["每5秒回蓝"],
        armor = L["护甲"],
        dps = L["武器DPS"],
        hitRating = L["物理命中等级"],
        critRating = L["物理暴击等级"],
        hasteRating = L["物理急速等级"],
        expertiseRating = L["精准等级"],
        arpRating = L["破甲等级"],
        spellHitRating = L["法术命中等级"],
        spellCritRating = L["法术暴击等级"],
        spellHasteRating = L["法术急速等级"],
        rangedHitRating = L["远程命中等级"],
        rangedCritChance = L["远程暴击"],
        rangedHasteRating = L["远程急速等级"],
        AP = L["攻强"], RAP = L["远程攻强"], SP = L["法伤"], HEAL = L["治疗强度"],
        HIT = L["命中"], HIT_PHYSICAL = L["物理命中等级"], HIT_SPELL = L["法术命中等级"],
        CRIT = L["暴击"], CRIT_PHYSICAL = L["物理暴击等级"], CRIT_SPELL = L["法术暴击等级"],
        HASTE = L["急速"], HASTE_PHYSICAL = L["物理急速等级"], HASTE_SPELL = L["法术急速等级"],
        ARPEN = L["破甲等级"], SPELLPEN = L["法术穿透"], EXPERTISE = L["精准等级"],
        DEFENSE = L["防御"], DODGE = L["躲闪"], PARRY = L["招架"],
        BLOCK = L["格挡"], BLOCKVALUE = L["格挡值"], DPS = L["武器DPS"],
        dodge = L["躲闪"],
        parry = L["招架"],
        block = L["格挡"],
        blockValue = L["格挡值"],
        defense = L["防御"],
    }
    return labels[key] or key
end

local function GetWeightProfileKey(db)
    db = db or GetDB()
    local tab = tonumber(db.talentTab) or GetMainTree() or 1
    return (db.role or "DPS") .. ":" .. tostring(tab)
end

local function LookupSpecEP(class, tab, role)
    local classW = SPEC_EP[class]
    if not classW then
        return nil
    end
    tab = tonumber(tab) or 1
    role = role or "DPS"
    local tabW = classW[tab]
    if tabW then
        local w = tabW[role] or tabW.DPS or tabW.TANK or tabW.HEAL
        if w then
            return w
        end
    end
    for i = 1, 3 do
        local tw = classW[i]
        if tw and tw[role] then
            return tw[role]
        end
    end
end

-- Keep sim/MYGear EP as-is. Green ratings (hit/crit/haste/arp/ap/sp) often
-- outvalue white primaries; do not softmax them down. Weapon DPS is still
-- omitted so a slightly faster weapon does not bury a cheaper piece.
local function ValueEP(src)
    if not src then
        return nil
    end
    local t = CopyWeights(src)
    t.dps = nil
    if t.defense and t.defense < 0 then
        t.defense = 0
    end
    return t
end

local function GetDefaultEP(db)
    db = db or GetDB()
    local class = GetClassFile()
    local tab = tonumber(db.talentTab) or GetMainTree() or 1
    local role = db.role or "DPS"
    local w = LookupSpecEP(class, tab, role)
    if w then
        return ValueEP(w)
    end
    if role == "TANK" then
        return CopyWeights(TANK_EP)
    end
    if role == "HEAL" then
        return CopyWeights(HEAL_EP)
    end
end

local function GetEffectiveEPWeights(db)
    db = db or GetDB()
    local defaults = GetDefaultEP(db)
    if not defaults then
        return nil, false
    end
    local key = GetWeightProfileKey(db)
    local custom = db.epWeights and db.epWeights[key]
    if type(custom) ~= "table" then
        return defaults, false
    end
    local merged = CopyWeights(defaults)
    for k, v in pairs(custom) do
        if tonumber(v) then
            merged[k] = tonumber(v)
        end
    end
    return merged, true
end

local function SetEPWeight(statKey, value)
    local db = GetDB()
    local pk = GetWeightProfileKey(db)
    db.epWeights = db.epWeights or {}
    db.epWeights[pk] = db.epWeights[pk] or {}
    db.epWeights[pk][statKey] = value
    db.userSet = true
end

local function ResetEPWeight(statKey)
    local db = GetDB()
    local pk = GetWeightProfileKey(db)
    if db.epWeights and db.epWeights[pk] then
        db.epWeights[pk][statKey] = nil
        if not next(db.epWeights[pk]) then
            db.epWeights[pk] = nil
        end
    end
    db.userSet = true
end

local function ResetAllEPWeights()
    local db = GetDB()
    local pk = GetWeightProfileKey(db)
    if db.epWeights then
        db.epWeights[pk] = nil
    end
    db.userSet = true
end

local function PawnSubMap(class, spec, db)
    db = db or GetDB()
    if db.role == "HEAL" or db.specType == "CASTER" then
        return {
            HitRating = "spellHitRating",
            CritRating = "spellCritRating",
            HasteRating = "spellHasteRating",
        }
    end
    if db.specType == "RANGED" then
        return {
            HitRating = "rangedHitRating",
            CritRating = "rangedCritChance",
            HasteRating = "rangedHasteRating",
        }
    end
    local classMap = PAWN_CLASS_STAT[class]
    if type(classMap) ~= "table" then
        return nil
    end
    if classMap[spec] then
        return classMap[spec]
    end
    if classMap.default then
        return classMap.default
    end
    if classMap.HitRating then
        return classMap
    end
end

local function ParsePawnEP(rawText, db)
    db = db or GetDB()
    if type(rawText) ~= "string" or rawText == "" then
        return {}
    end
    local parsedClass = string.match(rawText, "Class=([%w%s]+)")
    local classMap = {
        MAGE = "MAGE", WARLOCK = "WARLOCK", PRIEST = "PRIEST", DRUID = "DRUID",
        SHAMAN = "SHAMAN", HUNTER = "HUNTER", ROGUE = "ROGUE", WARRIOR = "WARRIOR",
        PALADIN = "PALADIN", DEATHKNIGHT = "DEATHKNIGHT", MONK = "MONK",
    }
    if parsedClass then
        parsedClass = string.upper(parsedClass)
        parsedClass = string.gsub(parsedClass, "%s+", "")
        if parsedClass == "DEATHKNIGHT" or parsedClass == "DEATH KNIGHT" then
            parsedClass = "DEATHKNIGHT"
        end
    end
    local matchedClass = (parsedClass and (classMap[parsedClass] or parsedClass)) or GetClassFile()
    local spec = tonumber(db.talentTab) or GetMainTree()
    local specSubMap = PawnSubMap(matchedClass, spec, db)
    local imported = {}
    for k, v in string.gmatch(rawText, "([%w_]+)%s*=%s*([%d%.%-]+)") do
        if k ~= "Class" and k ~= "v1" then
            local epKey
            if specSubMap and specSubMap[k] then
                epKey = specSubMap[k]
            elseif PAWN_TO_EP[k] then
                epKey = PAWN_TO_EP[k]
            end
            local num = tonumber(v)
            if epKey and num then
                imported[epKey] = num
            end
        end
    end
    return imported
end

local function GetCaps(db)
    db = db or GetDB()
    local c = db.caps or {}
    local hitMelee = tonumber(c.hitMelee) or DEFAULT_CAPS.hitMelee
    local hitSpell = tonumber(c.hitSpell) or DEFAULT_CAPS.hitSpell
    if db.dualWieldHit then
        hitMelee = tonumber(c.hitMeleeDW) or DEFAULT_CAPS.hitMeleeDW
    end
    if db.spellHit17 then
        hitSpell = tonumber(c.hitSpell17) or DEFAULT_CAPS.hitSpell17
    end
    return {
        hitMelee = hitMelee,
        hitSpell = hitSpell,
        expertise = tonumber(c.expertise) or DEFAULT_CAPS.expertise,
        defense = tonumber(c.defense) or DEFAULT_CAPS.defense,
        arp = tonumber(c.arp) or DEFAULT_CAPS.arp,
    }
end

function BG.GearScore_DefaultCaps()
    return {
        hitMelee = DEFAULT_CAPS.hitMelee,
        hitSpell = DEFAULT_CAPS.hitSpell,
        expertise = DEFAULT_CAPS.expertise,
        defense = DEFAULT_CAPS.defense,
        arp = DEFAULT_CAPS.arp,
    }
end

local ApplyProfileWeightRules
local function BuildWeights(db)
    db = db or GetDB()
    local class = GetClassFile()
    local primary = PrimaryFor(class, db.role, db.specType)
    local base
    if db.role == "TANK" then
        base = WEIGHTS.TANK
    elseif db.role == "HEAL" then
        base = WEIGHTS.HEAL
    elseif db.specType == "CASTER" then
        base = WEIGHTS.CASTER
    elseif db.specType == "RANGED" then
        base = WEIGHTS.RANGED
    else
        base = WEIGHTS.MELEE
    end
    local w = CopyWeights(base)
    local ep = GetEffectiveEPWeights(db)
    if ep then
        for _, epKey in ipairs(EP_APPLY_ORDER) do
            local scoreKey = EP_TO_SCORE[epKey]
            if scoreKey and ep[epKey] ~= nil then
                w[scoreKey] = ep[epKey]
            end
        end
        if db.role == "HEAL" or db.specType == "CASTER" then
            local hitW = ep.spellHitRating or ep.hitRating
            if hitW then
                w.HIT = hitW
                w.HIT_SPELL = hitW
            end
        end
        if db.role == "TANK" and not db.isMT then
            w.DEFENSE = math.min(w.DEFENSE or 0, 0.15)
        end
    else
        for _, k in ipairs({ "STR", "AGI", "INT" }) do
            if k ~= primary then
                if w[k] and w[k] >= 0.5 then
                    w[k] = 0.05
                end
            end
        end
        if db.role == "HEAL" then
            w.SPI = math.max(w.SPI or 0, 0.90)
        end
        if db.role == "TANK" and not db.isMT then
            w.DEFENSE = 0.15
        end
        local function bump(key, mul)
            if key and w[key] then
                w[key] = w[key] * mul
            end
        end
        bump(db.bias1, BIAS1)
        if db.bias2 and db.bias2 ~= "NONE" and db.bias2 ~= db.bias1 then
            bump(db.bias2, BIAS2)
        end
    end
    w._primary = primary
    if ApplyProfileWeightRules then
        ApplyProfileWeightRules(w, db)
    end
    return w
end

local playerSnap = {
    ratings = { hitMelee = 0, hitRanged = 0, hitSpell = 0, expertise = 0, defense = 0, arp = 0 },
    talentHit = {
        meleePct = 0, rangedPct = 0, spellPct = 0,
        talentMeleePct = 0, talentRangedPct = 0, talentSpellPct = 0,
        racialPct = 0, meleeRating = 0, rangedRating = 0, spellRating = 0,
    },
    equipped = {}, -- slot -> { itemID, link, stats, ilvl, equipLoc }
}

local itemStatCache = {}

local function AddStat(stats, key, n)
    if not key or not n then return end
    n = tonumber(n)
    if not n then return end
    stats[key] = (stats[key] or 0) + n
end

local function MapStatKey(raw)
    if not raw then return end
    if STAT_MAP[raw] then return STAT_MAP[raw] end
    if type(raw) == "string" then
        local noShort = raw:gsub("_SHORT$", "")
        if noShort ~= raw and STAT_MAP[noShort] then
            return STAT_MAP[noShort]
        end
        if raw:find("SOCKET_BONUS", 1, true) then
            return nil
        end
    end
    local found
    local family = {
        HIT = "HIT", HIT_PHYSICAL = "HIT", HIT_SPELL = "HIT",
        CRIT = "CRIT", CRIT_PHYSICAL = "CRIT", CRIT_SPELL = "CRIT",
        HASTE = "HASTE", HASTE_PHYSICAL = "HASTE", HASTE_SPELL = "HASTE",
        AP = "AP", RAP = "AP",
    }
    for tokenName, key in pairs(STAT_MAP) do
        local loc = _G[tokenName]
        if loc and loc == raw then
            if not found then
                found = key
            elseif found ~= key then
                if family[found] and family[found] == family[key] then
                    return family[key]
                end
                return nil
            end
        end
    end
    return found
end

local function ParseGetItemStats(link)
    local stats = {}
    if not GetItemStats then return stats, false end
    local ok, raw = pcall(GetItemStats, link)
    if not ok or type(raw) ~= "table" then return stats, false end
    for k, v in pairs(raw) do
        local key = MapStatKey(k)
        if key then
            AddStat(stats, key, v)
        end
    end
    return stats, true
end

local tooltipMatchers
local tooltipSkipSocketBonus
local tooltipSkipOnUse

local function EscapePat(s)
    return (s:gsub("([%(%)%.%+%-%*%?%[%^%$%%])", "%%%1"))
end

-- Convert Blizzard ITEM_MOD_* format strings into Lua patterns.
-- White: "%c%s 力量" → "+20 力量"
-- Green: "使你的命中等级提高%s点。" (often prefixed by 装备：)
local function GlobalToPattern(globalKey)
    local str = _G[globalKey]
    if type(str) ~= "string" or str == "" then return end
    local hasPlus = str:find("%%c", 1, true)
    str = str:gsub("%%c", ""):gsub("%%s", "\0"):gsub("%%d", "\0")
    str = EscapePat(str)
    str = str:gsub("\0", "(%%d+)")
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if not str:find("%(%%d%+%)") then
        return
    end
    if hasPlus then
        str = "%+?%s*" .. str
    end
    return str
end

-- "%c%s" / "%d" with no stat name would match "456点护甲" as spirit/int.
local function PatternHasStatName(pat)
    if type(pat) ~= "string" or pat == "" then
        return false
    end
    local plain = pat:gsub("%%.", ""):gsub("%b()", "")
    plain = plain:gsub("[%^%$%*%+%-%?%[%]%.]", "")
    plain = plain:gsub("%s+", "")
    return plain ~= ""
end

local function AddMatcher(list, key, pat)
    if type(pat) == "string" and pat ~= "" and PatternHasStatName(pat) then
        tinsert(list, { key = key, pat = pat })
    end
end

-- "456点护甲" / "+456 Armor". Do not treat 护甲穿透 as armor.
local function LineArmorValue(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    if text:find("穿透", 1, true) or text:find("破甲", 1, true)
        or text:find("Penetration", 1, true) then
        return
    end
    local n = text:match("^%+?%s*(%d+)%s*点%s*护甲")
        or text:match("^%+?%s*(%d+)%s*点%s*護甲")
        or text:match("^%+?%s*(%d+)%s+Armor%s*$")
        or text:match("^%+?%s*(%d+)%s+Armor%s")
    if n then
        return n
    end
    local armorWord = _G.ARMOR
    if type(armorWord) == "string" and armorWord ~= "" and not armorWord:find("%%", 1, true) then
        n = text:match("^%+?%s*(%d+)%s*点?%s*" .. EscapePat(armorWord) .. "%s*$")
        if n then
            return n
        end
    end
    local tmpl = _G.ARMOR_TEMPLATE
    if type(tmpl) == "string" and tmpl:find("%%d", 1, true) then
        local pat = "^%+?%s*" .. tmpl:gsub("%%d", "(%%d+)"):gsub("%%s", ".-")
        n = text:match(pat)
        if n then
            return n
        end
    end
end

local STAT_GLOBAL_ROWS = {
    { "STR", "ITEM_MOD_STRENGTH" },
    { "AGI", "ITEM_MOD_AGILITY" },
    { "STA", "ITEM_MOD_STAMINA" },
    { "INT", "ITEM_MOD_INTELLECT" },
    { "SPI", "ITEM_MOD_SPIRIT" },
    { "HIT", "ITEM_MOD_HIT_RATING" },
    { "HIT_PHYSICAL", "ITEM_MOD_HIT_MELEE_RATING" },
    { "HIT_PHYSICAL", "ITEM_MOD_HIT_RANGED_RATING" },
    { "HIT_SPELL", "ITEM_MOD_HIT_SPELL_RATING" },
    { "CRIT", "ITEM_MOD_CRIT_RATING" },
    { "CRIT_PHYSICAL", "ITEM_MOD_CRIT_MELEE_RATING" },
    { "CRIT_PHYSICAL", "ITEM_MOD_CRIT_RANGED_RATING" },
    { "CRIT_SPELL", "ITEM_MOD_CRIT_SPELL_RATING" },
    { "HASTE", "ITEM_MOD_HASTE_RATING" },
    { "HASTE_PHYSICAL", "ITEM_MOD_HASTE_MELEE_RATING" },
    { "HASTE_PHYSICAL", "ITEM_MOD_HASTE_RANGED_RATING" },
    { "HASTE_SPELL", "ITEM_MOD_HASTE_SPELL_RATING" },
    { "EXPERTISE", "ITEM_MOD_EXPERTISE_RATING" },
    { "DEFENSE", "ITEM_MOD_DEFENSE_SKILL_RATING" },
    { "DODGE", "ITEM_MOD_DODGE_RATING" },
    { "PARRY", "ITEM_MOD_PARRY_RATING" },
    { "BLOCK", "ITEM_MOD_BLOCK_RATING" },
    { "BLOCKVALUE", "ITEM_MOD_BLOCK_VALUE" },
    { "ARPEN", "ITEM_MOD_ARMOR_PENETRATION_RATING" },
    { "SPELLPEN", "ITEM_MOD_SPELL_PENETRATION" },
    { "SP", "ITEM_MOD_SPELL_POWER" },
    { "SP", "ITEM_MOD_SPELL_DAMAGE_DONE" },
    { "HEAL", "ITEM_MOD_SPELL_HEALING_DONE" },
    { "AP", "ITEM_MOD_ATTACK_POWER" },
    { "RAP", "ITEM_MOD_RANGED_ATTACK_POWER" },
    { "FERAL_AP", "ITEM_MOD_FERAL_ATTACK_POWER" },
    { "MP5", "ITEM_MOD_MANA_REGENERATION" },
    { "MP5", "ITEM_MOD_POWER_REGEN0" },
}

-- Longer stems first so 护甲穿透 is not eaten by 护甲, 远程攻击强度 not by 攻击强度.
local EXTRA_STEMS = {
    { "ARPEN", { "护甲穿透等级", "护甲穿透", "破甲等级", "破甲", "Armor Penetration" } },
    { "SPELLPEN", { "法术穿透等级", "法术穿透", "Spell Penetration" } },
    { "HIT_SPELL", { "法术命中等级", "法术命中", "Spell Hit" } },
    { "HIT_PHYSICAL", { "物理命中等级", "近战命中等级", "远程命中等级", "Melee Hit", "Ranged Hit" } },
    { "RAP", { "远程攻击强度", "Ranged Attack Power" } },
    { "AP", { "攻击强度", "Attack Power" } },
    { "SP", { "法术强度", "法术伤害", "Spell Power" } },
    { "HEAL", { "治疗效果", "治疗强度" } },
    { "HIT", { "命中等级", "命中" } },
    { "CRIT_SPELL", { "法术暴击等级", "法术爆击等级", "Spell Crit Rating", "Spell Critical Strike" } },
    { "CRIT_PHYSICAL", { "物理暴击等级", "近战暴击等级", "远程暴击等级", "Melee Crit", "Ranged Crit" } },
    { "CRIT", { "暴击等级", "爆击等级", "暴击", "爆击", "Crit Rating", "Critical Strike" } },
    { "HASTE_SPELL", { "法术急速等级", "Spell Haste" } },
    { "HASTE_PHYSICAL", { "物理急速等级", "近战急速等级", "远程急速等级", "Melee Haste", "Ranged Haste" } },
    { "HASTE", { "急速等级", "急速", "Haste Rating" } },
    { "EXPERTISE", { "精准等级", "精准", "Expertise" } },
    { "DEFENSE", { "防御等级", "Defense Rating" } },
    { "DODGE", { "躲闪等级", "闪躲等级", "Dodge Rating" } },
    { "PARRY", { "招架等级", "Parry Rating" } },
    { "BLOCKVALUE", { "格挡值", "Block Value" } },
    { "BLOCK", { "格挡等级", "Block Rating" } },
    { "MP5", { "每5秒恢复", "每5秒回复", "mana per 5" } },
    { "STR", { "力量", "Strength" } },
    { "AGI", { "敏捷", "Agility" } },
    { "STA", { "耐力", "Stamina" } },
    { "INT", { "智力", "Intellect" } },
    { "SPI", { "精神", "Spirit" } },
}

local function BuildTooltipMatchers()
    tooltipMatchers = {}
    for _, row in ipairs(STAT_GLOBAL_ROWS) do
        AddMatcher(tooltipMatchers, row[1], GlobalToPattern(row[2]))
        AddMatcher(tooltipMatchers, row[1], GlobalToPattern(row[2] .. "_SHORT"))
        local shortName = _G[row[2] .. "_SHORT"]
        if type(shortName) == "string" and shortName ~= "" then
            local esc = EscapePat(shortName)
            AddMatcher(tooltipMatchers, row[1], "^%+(%d+)%s*" .. esc)
            AddMatcher(tooltipMatchers, row[1], esc .. ".-提高(%d+)")
            AddMatcher(tooltipMatchers, row[1], "提高.-" .. esc .. ".-(%d+)")
            AddMatcher(tooltipMatchers, row[1], "[Ii]ncreases.-" .. esc .. ".-(%d+)")
            AddMatcher(tooltipMatchers, row[1], "[Ii]mproves.-" .. esc .. ".-(%d+)")
        end
    end
    for _, row in ipairs(EXTRA_STEMS) do
        for _, stem in ipairs(row[2]) do
            local esc = EscapePat(stem)
            AddMatcher(tooltipMatchers, row[1], "^%+(%d+)%s*" .. esc)
            AddMatcher(tooltipMatchers, row[1], esc .. ".-提高(%d+)")
            AddMatcher(tooltipMatchers, row[1], "提高.-" .. esc .. ".-(%d+)")
        end
    end
    table.sort(tooltipMatchers, function(a, b)
        return #a.pat > #b.pat
    end)
    local sockBonus = ITEM_SOCKET_BONUS
    if type(sockBonus) == "string" then
        tooltipSkipSocketBonus = sockBonus:gsub("%%s.*", "")
    end
    tooltipSkipOnUse = ITEM_SPELL_TRIGGER_ONUSE
end

local function TooltipLineSkipped(text)
    if tooltipSkipOnUse and tooltipSkipOnUse ~= "" and text:find(tooltipSkipOnUse, 1, true) then
        return true
    end
    if text:find("使用：", 1, true) or text:find("Use:", 1, true) then
        return true
    end
    -- proc / on-hit, not static green stats
    if text:find("有一定几率", 1, true) or text:find("有几率", 1, true)
        or text:find("有一定幾率", 1, true) or text:find("有幾率", 1, true)
        or text:find("a chance", 1, true) or text:find("A chance", 1, true)
        or text:find("Chance on", 1, true) or text:find("chance on", 1, true)
        or text:find("触发", 1, true) then
        return true
    end
    if tooltipSkipSocketBonus and tooltipSkipSocketBonus ~= "" and text:find(tooltipSkipSocketBonus, 1, true) then
        return true
    end
    if text:find("镶孔奖励", 1, true) or text:find("Socket Bonus", 1, true) then
        return true
    end
    -- feral AP on weapons is green text; only druids should score it
    if GetClassFile() ~= "DRUID" then
        if text:find("猎豹", 1, true) or text:find("枭兽", 1, true) or text:find("梟獸", 1, true)
            or text:find("Feral", 1, true) or text:find("cat form", 1, true)
            or text:find("bear form", 1, true) then
            return true
        end
    end
end

local function ParseTooltipStats(item)
    if not tooltipMatchers then BuildTooltipMatchers() end
    local stats = {}
    if not BG.Tooltip_SetItemByID then return stats, false end
    local ok = pcall(BG.Tooltip_SetItemByID, item)
    if not ok or not BiaoGeTooltip or (BiaoGeTooltip:NumLines() or 0) <= 1 then
        return stats, false
    end
    for i = 2, BiaoGeTooltip:NumLines() do
        local fs = _G["BiaoGeTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text ~= "" then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if not TooltipLineSkipped(text) then
                local matched
                local armor = LineArmorValue(text)
                if armor then
                    AddStat(stats, "ARMOR", armor)
                    matched = true
                else
                    for _, row in ipairs(tooltipMatchers) do
                        local n = text:match(row.pat)
                        if n then
                            AddStat(stats, row.key, n)
                            matched = true
                            break
                        end
                    end
                    if not matched then
                        local plus, name = text:match("^%+(%d+)%s*(.+)$")
                        if plus and name then
                            local armorName = (name:find("护甲", 1, true) or name:find("護甲", 1, true)
                                or name:find("Armor", 1, true))
                                and not (name:find("穿透", 1, true) or name:find("破甲", 1, true)
                                    or name:find("Penetration", 1, true))
                            if armorName then
                                AddStat(stats, "ARMOR", plus)
                                matched = true
                            else
                                for _, row in ipairs(EXTRA_STEMS) do
                                    for _, stem in ipairs(row[2]) do
                                        if name:find(stem, 1, true) then
                                            AddStat(stats, row[1], plus)
                                            matched = true
                                            break
                                        end
                                    end
                                    if matched then break end
                                end
                            end
                        end
                    end
                end
                local dps = text:match("每秒伤害.-([%d%.]+)") or text:match("([%d%.]+).-[Dd]amage per second")
                if dps then
                    AddStat(stats, "DPS", dps)
                end
                for _, sockKey in ipairs({ "EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_META", "EMPTY_SOCKET_PRISMATIC", "EMPTY_SOCKET_NO_COLOR" }) do
                    local sockText = _G[sockKey]
                    if sockText and text:find(sockText, 1, true) then
                        AddStat(stats, "SOCKET", 1)
                        break
                    end
                end
            end
        end
    end
    return stats, true
end

-- Fill gaps without double-counting: keep the larger value per stat.
local function MergeFill(dst, src)
    for k, v in pairs(src) do
        v = tonumber(v)
        if v then
            local cur = tonumber(dst[k]) or 0
            if math.abs(v) > math.abs(cur) then
                dst[k] = v
            end
        end
    end
    return dst
end

-- Titan can expose the same rating as a generic GetItemStats key and a
-- school-specific tooltip line. Prefer the specific source instead of scoring
-- both copies.
local function PreferSpecificSchool(dst, src)
    local families = {
        { "HIT", { "HIT_PHYSICAL", "HIT_SPELL" } },
        { "CRIT", { "CRIT_PHYSICAL", "CRIT_SPELL" } },
        { "HASTE", { "HASTE_PHYSICAL", "HASTE_SPELL" } },
        { "AP", { "RAP" } },
    }
    for _, family in ipairs(families) do
        local generic, specifics = family[1], family[2]
        local dstSpecificTotal, srcSpecificTotal = 0, 0
        for _, specific in ipairs(specifics) do
            dstSpecificTotal = dstSpecificTotal + (tonumber(dst[specific]) or 0)
            srcSpecificTotal = srcSpecificTotal + (tonumber(src[specific]) or 0)
        end
        if tonumber(dst[generic]) and srcSpecificTotal > 0
            and math.abs(tonumber(dst[generic]) - srcSpecificTotal) < 0.01 then
            dst[generic] = nil
        end
        if tonumber(src[generic]) and dstSpecificTotal > 0
            and math.abs(tonumber(src[generic]) - dstSpecificTotal) < 0.01 then
            src[generic] = nil
        end
        for _, specific in ipairs(specifics) do
            local a = tonumber(dst[generic])
            local b = tonumber(src[specific])
            if a and b and math.abs(a - b) < 0.01 then
                dst[generic] = nil
            end
            a = tonumber(src[generic])
            b = tonumber(dst[specific])
            if a and b and math.abs(a - b) < 0.01 then
                src[generic] = nil
            end
        end
    end
end

-- Tank white armor (hundreds) must not stay mapped as intellect/spirit.
local function SanitizeTankWhiteStats(stats)
    local tank = (tonumber(stats.DEFENSE) or 0) + (tonumber(stats.DODGE) or 0)
        + (tonumber(stats.PARRY) or 0) + (tonumber(stats.BLOCK) or 0)
    local armor = tonumber(stats.ARMOR) or 0
    local spi = tonumber(stats.SPI) or 0
    local intv = tonumber(stats.INT) or 0
    local str = tonumber(stats.STR) or 0
    local function dropDup(primary, amount)
        if amount <= 0 then
            return
        end
        if armor > 0 and math.abs(amount - armor) < 0.5 then
            stats[primary] = nil
        elseif armor == 0 and amount >= 200 then
            stats.ARMOR = amount
            armor = amount
            stats[primary] = nil
        elseif tank > 0 and amount >= 200 then
            stats[primary] = nil
        end
    end
    dropDup("SPI", spi)
    if tank > 0 or str > 0 then
        dropDup("INT", intv)
    end
    return stats
end

local function FinalizeStats(stats)
    if stats.FERAL_AP and stats.FERAL_AP ~= 0 then
        if GetClassFile() == "DRUID" then
            AddStat(stats, "AP", stats.FERAL_AP)
        end
        stats.FERAL_AP = nil
    end
    return SanitizeTankWhiteStats(stats)
end

local function ItemStatCacheKey(itemID, link)
    if type(link) == "string" then
        local itemString = link:match("item:[^|%s]+")
        if itemString then
            return itemString
        end
    end
    return itemID and ("item:" .. tostring(itemID)) or nil
end

local function ParseItemStats(itemID, link)
    if not itemID then return {} end
    local cacheKey = ItemStatCacheKey(itemID, link)
    if cacheKey and itemStatCache[cacheKey] then
        return itemStatCache[cacheKey], true
    end
    -- GetItemStats often returns only white primaries on Titan. Always scan
    -- the tooltip for green Equip: lines (hit/crit/haste/arp/ap/sp).
    local stats = ParseGetItemStats(link or itemID)
    local extra, tooltipReady = ParseTooltipStats(link or itemID)
    PreferSpecificSchool(stats, extra)
    MergeFill(stats, extra)
    FinalizeStats(stats)
    -- Titan frequently returns white stats before green tooltip lines exist.
    -- Do not make that incomplete result permanent.
    if tooltipReady and cacheKey then
        itemStatCache[cacheKey] = stats
    end
    return stats, tooltipReady
end

local function ItemHasProc(itemID, link)
    if not BiaoGeTooltip then return end
    BG.Tooltip_SetItemByID(link or itemID)
    local trigger = ITEM_SPELL_TRIGGER_ONEQUIP or "装备"
    local chance = ITEM_SPELL_TRIGGER_ONPROC or "几率"
    for i = 2, BiaoGeTooltip:NumLines() do
        local fs = _G["BiaoGeTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            if text:find("几率", 1, true) or text:find("chance", 1, true) or text:find("Chance", 1, true)
                or text:find("触发", 1, true) or text:find("proc", 1, true) then
                return true
            end
        end
    end
end

local classAllowedPat
local function ItemClassOK(itemID, link)
    if not ITEM_CLASSES_ALLOWED then return true end
    classAllowedPat = classAllowedPat or ITEM_CLASSES_ALLOWED:gsub("%%s", "(.+)")
    BG.Tooltip_SetItemByID(link or itemID)
    local my = GetClassName()
    for i = 2, BiaoGeTooltip:NumLines() do
        local fs = _G["BiaoGeTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            local classes = text:match(classAllowedPat)
            if classes then
                return classes:find(my, 1, true) and true or false
            end
        end
    end
    return true
end

local function UniqueEquipped(itemID, slots)
    if not itemID or not slots then return end
    for _, slot in ipairs(slots) do
        if GetInventoryItemID("player", slot) == itemID then
            return true
        end
    end
end

local function ItemIsUniqueEquip(itemID)
    if not itemID or not BiaoGeTooltip then return end
    BG.Tooltip_SetItemByID(itemID)
    local uniqueEq = ITEM_UNIQUE_EQUIPPABLE
    local unique = ITEM_UNIQUE
    for i = 2, BiaoGeTooltip:NumLines() do
        local fs = _G["BiaoGeTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            if uniqueEq and text:find(uniqueEq, 1, true) then
                return true
            end
            if unique and unique ~= uniqueEq and text == unique then
                return true
            end
        end
    end
end

local function TooltipRequirementOK(itemID, link)
    if not BiaoGeTooltip then
        return true
    end
    BG.Tooltip_SetItemByID(link or itemID)
    for i = 2, BiaoGeTooltip:NumLines() do
        local fs = _G["BiaoGeTooltipTextLeft" .. i]
        if fs then
            local r, g, b = fs:GetTextColor()
            if r and r > 0.9 and g and g < 0.2 and b and b < 0.2 then
                local text = fs:GetText()
                if text and text ~= "" then
                    if (ITEM_UNIQUE_EQUIPPABLE and text:find(ITEM_UNIQUE_EQUIPPABLE, 1, true))
                        or (ITEM_UNIQUE and text == ITEM_UNIQUE)
                        or (ITEM_SPELL_KNOWN and text:find(ITEM_SPELL_KNOWN, 1, true))
                    then
                        -- 唯一/已学会不视为“装备用不了”
                    else
                        return false
                    end
                end
            end
        end
    end
    return true
end

local function ArmorOK(class, typeID, subclassID, equipLoc)
    if typeID ~= 4 then return true end
    if IGNORE_ARMOR_LOC[equipLoc] then return true end
    if equipLoc and (equipLoc:find("WEAPON") or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
        or equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_SHIELD"
        or equipLoc == "INVTYPE_RELIC") then
        return true
    end
    local want = CLASS_ARMOR[class]
    if not want then return true end
    if subclassID == 0 then return true end -- misc
    return subclassID == want
end

local DUAL_WIELD_CLASS = {
    WARRIOR = true,
    HUNTER = true,
    ROGUE = true,
    DEATHKNIGHT = true,
}

local function CanUseOffHandWeapon(class, specType)
    if DUAL_WIELD_CLASS[class] then return true end
    return class == "SHAMAN" and specType == "MELEE"
end

local function WeaponOK(class, typeID, subclassID, equipLoc, role, specType)
    if typeID ~= 2 then
        if equipLoc == "INVTYPE_HOLDABLE" then
            return role == "HEAL" or specType == "CASTER"
        end
        if equipLoc == "INVTYPE_SHIELD" then
            return class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" or class == "DEATHKNIGHT"
        end
        return true
    end
    local allow = CLASS_WEAPON[class]
    if not allow then return true end
    if equipLoc == "INVTYPE_WEAPONOFFHAND" and not CanUseOffHandWeapon(class, specType) then
        return false
    end
    return allow[subclassID] and true or false
end

local TANK_ONLY_STATS = {
    DEFENSE = true, DODGE = true, PARRY = true, BLOCK = true, BLOCKVALUE = true,
}

local PHYSICAL_ONLY_STATS = {
    AP = true, RAP = true, HIT_PHYSICAL = true, CRIT_PHYSICAL = true,
    HASTE_PHYSICAL = true, ARPEN = true, EXPERTISE = true, DPS = true,
}

local SPELL_ONLY_STATS = {
    SP = true, HEAL = true, HIT_SPELL = true, CRIT_SPELL = true,
    HASTE_SPELL = true, SPELLPEN = true,
}

local function IsPhysicalProfile(db)
    return db.role == "TANK" or (db.role ~= "HEAL" and (db.specType == "MELEE" or db.specType == "RANGED"))
end

local function IsCasterProfile(db)
    return db.role == "HEAL" or db.specType == "CASTER"
end

local function StatAllowed(key, db)
    if not key or not db then return false end
    local class = GetClassFile()
    if TANK_ONLY_STATS[key] then
        if db.role ~= "TANK" then return false end
        if class == "DRUID" and (key == "DEFENSE" or key == "PARRY" or key == "BLOCK" or key == "BLOCKVALUE") then
            return false
        end
        if class == "DEATHKNIGHT" and (key == "BLOCK" or key == "BLOCKVALUE") then
            return false
        end
        return true
    end
    if PHYSICAL_ONLY_STATS[key] then
        if not IsPhysicalProfile(db) then return false end
        if key == "RAP" then
            return db.specType == "RANGED"
        end
        if key == "EXPERTISE" then
            return db.role == "TANK" or db.specType == "MELEE"
        end
        return true
    end
    if SPELL_ONLY_STATS[key] then
        if not IsCasterProfile(db) then return false end
        if key == "HEAL" then
            return db.role == "HEAL"
        end
        if key == "HIT_SPELL" or key == "SPELLPEN" then
            return db.role ~= "HEAL" and db.specType == "CASTER"
        end
        return true
    end
    if key == "HIT" then
        return db.role ~= "HEAL"
    end
    return true
end

ApplyProfileWeightRules = function(w, db)
    for _, key in ipairs({
        "AP", "SP", "HEAL", "HIT", "CRIT", "HASTE", "ARPEN", "EXPERTISE",
        "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVALUE", "DPS",
    }) do
        if not StatAllowed(key, db) then
            w[key] = 0
        end
    end
    if db.role == "HEAL" then
        w.HIT = 0
        w.EXPERTISE = 0
        w.ARPEN = 0
    elseif IsCasterProfile(db) then
        w.AP = 0
        w.EXPERTISE = 0
        w.ARPEN = 0
        w.DPS = 0
    elseif IsPhysicalProfile(db) then
        w.SP = 0
        w.HEAL = 0
    end
end

local function ScoreKeyForStat(key, db)
    if not StatAllowed(key, db) then return nil end
    if key == "RAP" then return "AP" end
    if key == "HIT_PHYSICAL" then return "HIT" end
    if key == "CRIT_PHYSICAL" or key == "CRIT_SPELL" then return "CRIT" end
    if key == "HASTE_PHYSICAL" or key == "HASTE_SPELL" then return "HASTE" end
    return key
end

local function EPWeightAllowed(epKey, db)
    local specific = {
        rap = "RAP",
        spellHitRating = "HIT_SPELL",
        spellCritRating = "CRIT_SPELL",
        spellHasteRating = "HASTE_SPELL",
        rangedHitRating = "HIT_PHYSICAL",
        rangedCritChance = "CRIT_PHYSICAL",
        rangedHasteRating = "HASTE_PHYSICAL",
    }
    local statKey = specific[epKey] or EP_TO_SCORE[epKey]
    return not statKey or StatAllowed(statKey, db)
end

local NEUTRAL_USEFUL_STATS = {
    STA = true,
    ARMOR = true,
    HIT = true,
    CRIT = true,
    HASTE = true,
    SOCKET = true,
}

local function HasUsefulNativeStat(stats, w, db)
    local hasUseful, hasSchoolUseful, hasKnown = false, false, false
    local forbidden = {}
    for key, value in pairs(stats or {}) do
        value = tonumber(value) or 0
        if value > 0 and STAT_KEYS[key] and key ~= "SOCKET" then
            hasKnown = true
            local scoreKey = ScoreKeyForStat(key, db)
            if not scoreKey then
                tinsert(forbidden, key)
            elseif (tonumber(w[scoreKey]) or 0) > 0 then
                -- Stamina and base armor alone must not make a wrong-school DPS/heal item valid.
                if db.role == "TANK" or (key ~= "STA" and key ~= "ARMOR") then
                    hasUseful = true
                    if not NEUTRAL_USEFUL_STATS[key] then
                        hasSchoolUseful = true
                    end
                end
            end
        end
    end
    -- Generic hit/crit/haste can benefit multiple schools, but must not rescue
    -- an item that otherwise advertises only forbidden physical/spell stats.
    if #forbidden > 0 and not hasSchoolUseful then
        hasUseful = false
    end
    return hasUseful, forbidden, hasKnown
end

-- Rings/necks/trinkets have no armor restriction. Require at least one native
-- positive-weight stat and never let an explicitly forbidden school add score.
local function WrongStatSchool(stats, db, w)
    local hasUseful, forbidden, hasKnown = HasUsefulNativeStat(stats, w, db)
    return hasKnown and not hasUseful, forbidden, hasUseful
end

local function CappedScore(amount, current, cap, highW)
    amount = amount or 0
    if amount == 0 or not highW or highW == 0 then
        return 0, 0, 0
    end
    current = current or 0
    cap = cap or 0
    local room = math.max(0, cap - current)
    local useful = math.min(amount, room)
    local waste = amount - useful
    return useful * highW, useful, waste
end

local function AddPart(parts, key, amount)
    if WHITE_STAT[key] then
        parts.white = parts.white + amount
    else
        parts.green = parts.green + amount
    end
    parts.score = parts.score + amount
end

local function StatAmount(stats, keys)
    local amount = 0
    for i = 1, #keys do
        amount = amount + (tonumber(stats and stats[keys[i]]) or 0)
    end
    return amount
end

local function ScoreStats(stats, w, db, ilvl, notes, ratings, includeBudget)
    db = db or GetDB()
    notes = notes or {}
    local caps = GetCaps(db)
    local r = ratings or playerSnap.ratings
    local parts = { score = 0, white = 0, green = 0 }
    local hitAmt = 0
    if db.role == "HEAL" then
        -- Healers do not use any hit stat.
    elseif db.specType == "CASTER" then
        hitAmt = (stats.HIT or 0) + (stats.HIT_SPELL or 0)
        local s, useful, waste = CappedScore(hitAmt, r.hitSpell, caps.hitSpell, w.HIT)
        AddPart(parts, "HIT", s)
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "hitcap")
        elseif waste and waste > 0 then
            tinsert(notes, "hitpartial")
        end
    else
        local hitCur = db.specType == "RANGED" and r.hitRanged or r.hitMelee
        hitAmt = StatAmount(stats, { "HIT", "HIT_PHYSICAL" })
        local s, useful, waste = CappedScore(hitAmt, hitCur, caps.hitMelee, w.HIT)
        AddPart(parts, "HIT", s)
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "hitcap")
        elseif waste and waste > 0 then
            tinsert(notes, "hitpartial")
        end
    end
    if (db.specType == "MELEE" or db.role == "TANK") and StatAllowed("EXPERTISE", db) then
        local s, useful, waste = CappedScore(stats.EXPERTISE, r.expertise, caps.expertise, w.EXPERTISE)
        AddPart(parts, "EXPERTISE", s)
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "expcap")
        elseif waste and waste > 0 then
            tinsert(notes, "exppartial")
        end
    end
    if db.role == "TANK" and db.isMT and StatAllowed("DEFENSE", db) then
        local s, useful, waste = CappedScore(stats.DEFENSE, r.defense, caps.defense, w.DEFENSE)
        AddPart(parts, "DEFENSE", s)
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "defcap")
        elseif waste and waste > 0 then
            tinsert(notes, "defpartial")
        end
    elseif stats.DEFENSE and StatAllowed("DEFENSE", db) then
        AddPart(parts, "DEFENSE", (stats.DEFENSE or 0) * (w.DEFENSE or 0))
    end
    if (db.specType == "MELEE" or db.specType == "RANGED" or db.role == "TANK") and (w.ARPEN or 0) > 0 then
        local s, useful, waste = CappedScore(stats.ARPEN, r.arp, caps.arp, w.ARPEN)
        AddPart(parts, "ARPEN", s)
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "arpcap")
        elseif waste and waste > 0 then
            tinsert(notes, "arppartial")
        end
    end

    local skip = {
        HIT = true, HIT_PHYSICAL = true, HIT_SPELL = true,
        EXPERTISE = true, DEFENSE = true, SOCKET = true,
    }
    if (db.specType == "MELEE" or db.specType == "RANGED" or db.role == "TANK") and (w.ARPEN or 0) > 0 then
        skip.ARPEN = true
    end
    for k, v in pairs(stats) do
        if not skip[k] and STAT_KEYS[k] then
            local scoreKey = ScoreKeyForStat(k, db)
            if scoreKey then
                AddPart(parts, scoreKey, v * (w[scoreKey] or 0))
            end
        end
    end
    if includeBudget ~= false and stats.SOCKET and stats.SOCKET > 0 then
        local p = w[w._primary or "STR"] or 1
        AddPart(parts, "SOCKET", stats.SOCKET * SOCKET_GEM * p)
    end
    if includeBudget ~= false and ilvl then
        parts.score = parts.score + ilvl * ILVL_W
    end
    return parts.score, parts.white, parts.green
end

function BG.GearScore_RefreshPlayer()
    local r = playerSnap.ratings
    local ok, th = pcall(ScanPlayerHit)
    if not ok or type(th) ~= "table" then
        th = {
            meleePct = 0, rangedPct = 0, spellPct = 0,
            talentMeleePct = 0, talentRangedPct = 0, talentSpellPct = 0,
            racialPct = 0, meleeRating = 0, rangedRating = 0, spellRating = 0,
        }
    end
    playerSnap.talentHit = th
    r.hitMelee = CombatRating(CR_HIT_MELEE) + RoundHit(th.meleeRating)
    r.hitRanged = CombatRating(CR_HIT_RANGED) + RoundHit(th.rangedRating)
    r.hitSpell = CombatRating(CR_HIT_SPELL) + RoundHit(th.spellRating)
    r.expertise = CombatRating(CR_EXPERTISE)
    r.defense = CombatRating(CR_DEFENSE_SKILL)
    r.arp = CombatRating(CR_ARMOR_PENETRATION)
    wipe(playerSnap.equipped)
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        local id = GetInventoryItemID("player", slot)
        if link and id then
            local _, _, _, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
            local stats, ready = ParseItemStats(id, link)
            playerSnap.equipped[slot] = {
                itemID = id,
                link = link,
                stats = stats,
                ready = ready and ilvl ~= nil and equipLoc and equipLoc ~= "",
                ilvl = ilvl,
                equipLoc = equipLoc,
            }
        end
    end
end

function BG.GearScore_GetSnapshot()
    return playerSnap
end

local function CloneRatings(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = tonumber(v) or 0
    end
    return out
end

local function RatingAmount(stats, ratingKey)
    if ratingKey == "hitSpell" then
        return StatAmount(stats, { "HIT", "HIT_SPELL" })
    elseif ratingKey == "hitMelee" or ratingKey == "hitRanged" then
        return StatAmount(stats, { "HIT", "HIT_PHYSICAL" })
    elseif ratingKey == "expertise" then
        return tonumber(stats and stats.EXPERTISE) or 0
    elseif ratingKey == "defense" then
        return tonumber(stats and stats.DEFENSE) or 0
    elseif ratingKey == "arp" then
        return tonumber(stats and stats.ARPEN) or 0
    end
    return 0
end

local function RatingsForReplacement(removed, candidateStats)
    local current = playerSnap.ratings
    local baseline = CloneRatings(current)
    local after = CloneRatings(current)
    for _, ratingKey in ipairs({ "hitSpell", "hitMelee", "hitRanged", "expertise", "defense", "arp" }) do
        local removedAmount = 0
        for _, eq in ipairs(removed) do
            removedAmount = removedAmount + RatingAmount(eq.stats, ratingKey)
        end
        baseline[ratingKey] = math.max(0, (tonumber(current[ratingKey]) or 0) - removedAmount)
        after[ratingKey] = baseline[ratingKey] + RatingAmount(candidateStats, ratingKey)
    end
    return baseline, after
end

local function AddStats(dst, src)
    for key, value in pairs(src or {}) do
        value = tonumber(value)
        if value and STAT_KEYS[key] then
            dst[key] = (dst[key] or 0) + value
        end
    end
end

local function ItemBudgetScore(stats, ilvl, w, db)
    local useful = HasUsefulNativeStat(stats, w, db)
    if not useful then return 0 end
    local score = (tonumber(ilvl) or 0) * ILVL_W
    local sockets = tonumber(stats and stats.SOCKET) or 0
    if sockets > 0 then
        score = score + sockets * SOCKET_GEM * (w[w._primary or "STR"] or 1)
    end
    return score
end

local function ReplacementUpgrade(candidate, removed, w, db, notes, candidateUseful)
    local baseline, after = RatingsForReplacement(removed, candidate.stats)
    local oldStats = {}
    local oldBudget = 0
    for _, eq in ipairs(removed) do
        AddStats(oldStats, eq.stats)
        oldBudget = oldBudget + ItemBudgetScore(eq.stats, eq.ilvl, w, db)
    end
    local oldScore = ScoreStats(oldStats, w, db, nil, {}, baseline, false) + oldBudget
    local newScore, newWhite, newGreen = ScoreStats(
        candidate.stats, w, db, candidate.ilvl, notes, baseline, candidateUseful)
    return newScore - oldScore, after, oldScore, newScore, newWhite, newGreen
end

local function ReplacementPlans(equipLoc, itemID, db)
    local slots = SlotsForLoc(equipLoc)
    if not slots then
        return nil, "slot"
    end
    if UniqueEquipped(itemID, slots) and ItemIsUniqueEquip(itemID) then
        return nil, "unique"
    end
    if equipLoc == "INVTYPE_2HWEAPON" then
        return { { slots = { 16, 17 } } }
    end
    if #slots == 2 then
        if equipLoc == "INVTYPE_WEAPON" then
            local main = playerSnap.equipped[16]
            if main and main.equipLoc == "INVTYPE_2HWEAPON" then
                return { { slots = { 16 } } }
            end
            if not CanUseOffHandWeapon(GetClassFile(), db.specType) then
                return { { slots = { 16 } } }
            end
        end
        return { { slots = { slots[1] } }, { slots = { slots[2] } } }
    end
    return { { slots = { slots[1] } } }
end

local function EquippedForPlan(plan)
    local removed = {}
    for _, slot in ipairs(plan.slots) do
        local eq = playerSnap.equipped[slot]
        if eq then
            if not eq.ready then
                return nil
            end
            tinsert(removed, eq)
        end
    end
    return removed
end

local function ExchangeProducts(itemID)
    if not itemID or not BG.Loot or not BG.FBtable then return end
    if type(itemID) == "string" then
        itemID = GetItemID(itemID) or tonumber(itemID)
    else
        itemID = tonumber(itemID) or itemID
    end
    if not itemID then return end
    local products = {}
    local seen = {}
    local function AddProducts(list)
        if type(list) ~= "table" then return end
        local indexed = {}
        for index = 1, #list do
            indexed[index] = true
            local productID = tonumber(list[index]) or list[index]
            if productID and not seen[productID] then
                seen[productID] = true
                tinsert(products, productID)
            end
        end
        -- Also accept sparse/keyed exchange tables used by older custom data.
        for index, productID in pairs(list) do
            if not indexed[index] then
                productID = tonumber(productID) or productID
                if productID and not seen[productID] then
                    seen[productID] = true
                    tinsert(products, productID)
                end
            end
        end
    end
    for _, FB in ipairs(BG.FBtable) do
        local ex = BG.Loot[FB] and BG.Loot[FB].ExchangeItems
        local list = ex and ex[itemID]
        AddProducts(list)
    end
    if #products > 0 then
        return products
    end
end

-- Kept public so the table/tooltip UI can distinguish an exchange token from
-- an ordinary non-gear item before applying its normal gear-only filter.
BG.GearScore_GetExchangeProducts = ExchangeProducts
function BG.GearScore_IsExchangeItem(itemID)
    return ExchangeProducts(itemID) ~= nil
end

local function IsLegendaryItem(quality, link, itemLink)
    if quality == 5 then
        return true
    end
    if type(itemLink) == "string"
        and itemLink:lower():find("|cffff8000", 1, true) then
        return true
    end
    if type(link) == "string"
        and link:lower():find("|cffff8000", 1, true) then
        return true
    end
    return false
end

-- Orange equipment-upgrade materials are transferable tokens, not gear that
-- the current character must be able to equip. Keep them highlighted in
-- auctions when their exchange table identifies them, or when a newly added
-- token is known to be unequippable and is not pickup-bound.
function BG.GearScore_IsOrangeWeaponUpgradeItem(itemID, link)
    if type(itemID) ~= "number" then
        itemID = GetItemID(itemID or link)
    end
    if not itemID then
        return false
    end

    local _, itemLink, quality, _, _, _, _, _, equipLoc, _, _, _, _, bindType = GetItemInfo(link or itemID)
    if not IsLegendaryItem(quality, link, itemLink) then
        return false
    end

    local products = ExchangeProducts(itemID)
    -- The source item's exchange table is authoritative. Product metadata is
    -- often not cached yet when an auction frame is first created, so do not
    -- make the result depend on the exchanged products being loaded.
    if products and #products > 0 then
        return true
    end

    -- Keep newly introduced materials working before their exchange mapping is
    -- added to the loot database. An ordinary legendary weapon or armor has an
    -- equip location, while transferable upgrade tokens do not.
    local instantEquipLoc = GetItemInfoInstant and select(4, GetItemInfoInstant(link or itemID))
    local itemEquipLoc = equipLoc or instantEquipLoc
    if not itemEquipLoc or itemEquipLoc == "" then
        -- Some versions classify upgrade tokens as weapons despite leaving
        -- them unequippable. Their empty equip location is sufficient to
        -- distinguish them from a real legendary weapon or armor.
        return bindType ~= 1
    end
    return false
end

BG.GearScore_IsOrangeUpgradeItem = BG.GearScore_IsOrangeWeaponUpgradeItem

local function Round1(n)
    if not n then return 0 end
    return math.floor(n + 0.5)
end

local function EvalOne(itemID, link, db, w)
    local result = {
        suitable = true,
        reason = nil,
        upgrade = 0,
        newScore = 0,
        oldScore = 0,
        oldLink = nil,
        oldLink2 = nil,
        notes = {},
        itemID = itemID,
        link = link,
    }
    local name, itemLink, quality, ilvl, _, _, _, _, equipLoc, _, _, typeID, subclassID = GetItemInfo(link or itemID)
    if (not typeID or not subclassID or not equipLoc) and GetItemInfoInstant then
        local instantID, _, _, loc, _, tID, subID = GetItemInfoInstant(link or itemID)
        itemID = itemID or instantID
        equipLoc = equipLoc or loc
        typeID = typeID or tID
        subclassID = subclassID or subID
    end
    result.ilvl = ilvl
    result.equipLoc = equipLoc
    result.typeID = typeID

    if typeID and typeID ~= 2 and typeID ~= 4 then
        if not ItemClassOK(itemID, itemLink or link) then
            result.suitable = false
            result.reason = "class"
            return result
        end
        result.suitable = false
        result.reason = "notgear"
        return result
    end
    if not name or ilvl == nil or not typeID or not equipLoc or equipLoc == "" or subclassID == nil then
        result.suitable = false
        result.reason = "loading"
        return result
    end

    local class = GetClassFile()
    if not ItemClassOK(itemID, itemLink or link) then
        result.suitable = false
        result.reason = "class"
        return result
    end
    if not ArmorOK(class, typeID, subclassID, equipLoc) then
        result.suitable = false
        result.reason = "armor"
        return result
    end
    if not WeaponOK(class, typeID, subclassID, equipLoc, db.role, db.specType) then
        result.suitable = false
        result.reason = "weapon"
        return result
    end
    if not TooltipRequirementOK(itemID, itemLink or link) then
        result.suitable = false
        result.reason = "class"
        return result
    end

    local stats, statsReady = ParseItemStats(itemID, itemLink or link)
    result.stats = stats
    if not statsReady then
        result.suitable = false
        result.reason = "loading"
        return result
    end

    local hasProc = (equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_FINGER")
        and ItemHasProc(itemID, itemLink or link)
    local wrongStats, forbidden, hasUseful = WrongStatSchool(stats, db, w)
    result.wasteStats = forbidden
    if wrongStats or (not hasUseful and not hasProc) then
        result.suitable = false
        result.reason = "stats"
        result.upgrade = 0
        return result
    end
    if hasProc then
        tinsert(result.notes, "proc")
    end

    local plans, planReason = ReplacementPlans(equipLoc, itemID, db)
    if planReason == "unique" then
        result.reason = "unique"
        result.upgrade = 0
        return result
    end
    if not plans then
        result.suitable = false
        result.reason = planReason or "slot"
        return result
    end

    local candidate = { stats = stats, ilvl = ilvl, link = itemLink or link, itemID = itemID }
    local best
    for _, plan in ipairs(plans) do
        local removed = EquippedForPlan(plan)
        if not removed then
            result.suitable = false
            result.reason = "loading"
            return result
        end
        local planNotes = {}
        if hasProc then tinsert(planNotes, "proc") end
        local upgrade, ratingsAfter, oldScore, replacementScore, newWhite, newGreen =
            ReplacementUpgrade(candidate, removed, w, db, planNotes, hasUseful)
        if not best or upgrade > best.upgrade then
            best = {
                upgrade = upgrade,
                oldScore = oldScore,
                newScore = replacementScore,
                removed = removed,
                notes = planNotes,
                ratingsAfter = ratingsAfter,
                newWhite = newWhite,
                newGreen = newGreen,
            }
        end
    end
    if not best then
        result.suitable = false
        result.reason = "slot"
        return result
    end
    result.upgrade = best.upgrade
    result.oldScore = best.oldScore
    result.newScore = best.newScore
    result.oldLink = best.removed[1] and best.removed[1].link or nil
    result.oldLink2 = best.removed[2] and best.removed[2].link or nil
    result.notes = best.notes
    result.ratingsAfter = best.ratingsAfter
    result.newWhite = best.newWhite or 0
    result.newGreen = best.newGreen or 0
    return result
end

local function SafeEvalOne(itemID, link, db, w)
    local ok, r = pcall(EvalOne, itemID, link, db, w)
    if ok then
        return r
    end
end

function BG.GearScore_Eval(link)
    if not link then return end
    if BG.GearScore_IsOrangeWeaponUpgradeItem then
        local itemID = type(link) == "number" and link or GetItemID(link)
        if BG.GearScore_IsOrangeWeaponUpgradeItem(itemID, link) then
            return
        end
    end
    local db = GetDB()
    local w = BuildWeights(db)
    local itemID
    if type(link) == "number" then
        itemID = link
    else
        itemID = GetItemID(link)
        if not itemID and GetItemInfoInstant then
            itemID = GetItemInfoInstant(link)
        end
    end
    if not itemID then
        return
    end

    if not next(playerSnap.equipped) and not playerSnap.scanned then
        BG.GearScore_RefreshPlayer()
        playerSnap.scanned = true
    end

    local products = ExchangeProducts(itemID)
    if products and #products > 0 then
        local best
        for _, pid in ipairs(products) do
            local r = SafeEvalOne(pid, pid, db, w)
            if r and r.suitable then
                if not best or r.upgrade > best.upgrade then
                    best = r
                    best.tokenItemID = pid
                    best.tokenFrom = itemID
                end
            end
        end
        if best then
            return best
        end
        local fail = SafeEvalOne(itemID, link, db, w)
        if not fail then
            return
        end
        fail.suitable = false
        fail.reason = fail.reason or "class"
        return fail
    end
    return SafeEvalOne(itemID, link, db, w)
end

local GRAY_R, GRAY_G, GRAY_B = 0.62, 0.62, 0.62

local function StripColorCodes(s)
    if type(s) ~= "string" then
        return s
    end
    return s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
end

local ITEM_LIST_UNUSABLE_REASON = {
    class = true,
    weapon = true,
}

local function ItemListAppearance(link, legacyFiltered)
    local ev = BG.GearScore_Eval(link)
    if ev and ev.suitable == false then
        if ITEM_LIST_UNUSABLE_REASON[ev.reason] then
            return "unusable"
        elseif ev.reason == "armor" then
            local _, _, _, _, _, _, subclassID = GetItemInfoInstant(link)
            local maxArmor = CLASS_ARMOR[GetClassFile()]
            if maxArmor and subclassID and subclassID > maxArmor then
                return "unusable"
            end
            return "offspec"
        elseif ev.reason == "stats" then
            return "offspec"
        end
    end
    if legacyFiltered then
        return "offspec"
    end
end

local function PaintItemListFont(fs, originalText, grayscale)
    if not fs then return end
    if originalText ~= nil then
        fs:SetText(grayscale and StripColorCodes(originalText) or originalText)
    end
    if grayscale then
        fs:SetTextColor(GRAY_R, GRAY_G, GRAY_B)
    else
        fs:SetTextColor(1, 1, 1)
    end
end

function BG.GearScore_UpdateItemListButton(bt, link, legacyFiltered)
    if not bt or not bt.frame then return end
    link = link or bt.link
    if not link then return end

    if bt._gsItemText == nil and bt.item then
        bt._gsItemText = bt.item:GetText() or ""
    end
    if legacyFiltered ~= nil then
        bt._gsLegacyFiltered = legacyFiltered and true or false
    end
    local appearance = ItemListAppearance(link, bt._gsLegacyFiltered)
    bt.gearScoreAppearance = appearance

    if appearance == "unusable" then
        bt.frame:SetAlpha(1)
        if bt.icon then
            bt.icon:SetDesaturated(true)
            bt.icon:SetVertexColor(0.72, 0.72, 0.72)
        end
        if bt.iconFrame then
            bt.iconFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        PaintItemListFont(bt.item, bt._gsItemText, true)
        if bt.iconFrame and bt.iconFrame.level then
            bt.iconFrame.level:SetTextColor(GRAY_R, GRAY_G, GRAY_B)
        end
        return
    end

    if bt.icon then
        bt.icon:SetDesaturated(false)
        bt.icon:SetVertexColor(1, 1, 1)
    end
    if bt.iconFrame and bt.qualityColor then
        bt.iconFrame:SetBackdropBorderColor(unpack(bt.qualityColor))
    end
    PaintItemListFont(bt.item, bt._gsItemText, false)
    if bt.iconFrame and bt.iconFrame.level and bt.qualityColor then
        bt.iconFrame.level:SetTextColor(unpack(bt.qualityColor))
    end
    bt.frame:SetAlpha(appearance == "offspec" and 0.4 or 1)
end

-- 名称后只显示升级分；自己不能用时竞价窗改黑白，不挂叉叉
local function ShowNameBadge(ev)
    if not ev or not ev.suitable then
        return false
    end
    return true
end

local function PaintAuctionFont(fs, unusable)
    if not fs then
        return
    end
    if fs._gsOrig == nil then
        fs._gsOrig = fs:GetText() or ""
    end
    if unusable then
        fs:SetText(StripColorCodes(fs._gsOrig))
        fs:SetTextColor(GRAY_R, GRAY_G, GRAY_B)
    else
        fs:SetText(fs._gsOrig)
    end
end

local function IsMeAuction(bidFrame)
    if BGA and BGA.aura_env and BGA.aura_env.IsMe then
        return BGA.aura_env.IsMe(bidFrame)
    end
    return bidFrame.player and bidFrame.player == BG.playerName
end

local function ApplyAuctionUnusableLook(bidFrame, unusable)
    unusable = unusable and true or false
    local orangeWeaponUpgrade = bidFrame.orangeWeaponUpgrade
    bidFrame.unusable = unusable
    local itemFrame = bidFrame.itemFrame
    if itemFrame then
        local iconFrame = itemFrame.iconFrame
        if iconFrame then
            if iconFrame.tex then
                iconFrame.tex:SetDesaturated(unusable)
                if unusable then
                    iconFrame.tex:SetVertexColor(0.75, 0.75, 0.75)
                else
                    iconFrame.tex:SetVertexColor(1, 1, 1)
                end
            end
            if not bidFrame.IsSmallWindow then
                if unusable then
                    iconFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                elseif iconFrame.color then
                    iconFrame:SetBackdropBorderColor(unpack(iconFrame.color))
                end
            end
        end
        PaintAuctionFont(itemFrame.itemNameText, unusable)
        PaintAuctionFont(itemFrame.itemTypeText, unusable)
        if itemFrame.levelText then
            if unusable then
                itemFrame.levelText:SetTextColor(GRAY_R, GRAY_G, GRAY_B)
            elseif iconFrame and iconFrame.color then
                itemFrame.levelText:SetTextColor(unpack(iconFrame.color))
            end
        end
        if itemFrame.bindTypeText then
            if unusable then
                itemFrame.bindTypeText:SetTextColor(GRAY_R, GRAY_G, GRAY_B)
            else
                itemFrame.bindTypeText:SetTextColor(0, 1, 0)
            end
        end
    end
    if (unusable or bidFrame.filterByScheme) and not orangeWeaponUpgrade then
        bidFrame.filter = true
        if BGA and BGA.aura_env and BGA.aura_env.SetFrameColor and not IsMeAuction(bidFrame) then
            BGA.aura_env.SetFrameColor(bidFrame, 2)
        end
    else
        bidFrame.filter = nil
        if BGA and BGA.aura_env and BGA.aura_env.SetFrameColor and not IsMeAuction(bidFrame) then
            BGA.aura_env.SetFrameColor(bidFrame, 0)
        end
    end
end

function BG.GearScore_Format(link, long)
    local r = BG.GearScore_Eval(link)
    if not r then
        return "", 0.5, 0.5, 0.5, r
    end
    if not r.suitable then
        return "", 1, 0.35, 0.35, r
    end
    if r.reason == "unique" then
        return "=", 1, 0.85, 0.2, r
    end
    local u = Round1(r.upgrade)
    if u > 0 then
        return "+" .. u, 0.2, 1, 0.3, r
    elseif u < 0 then
        return tostring(u), 0.85, 0.85, 0.85, r
    else
        return "+0", 1, 0.92, 0.25, r
    end
end

local function BadgeColors(ev)
    if not ev or not ev.suitable then
        return 0.42, 0.07, 0.07, 0.95
    end
    if ev.reason == "unique" then
        return 0.38, 0.28, 0.04, 0.95
    end
    local u = Round1(ev.upgrade or 0)
    if u > 0 then
        return 0.02, 0.48, 0.1, 0.95
    elseif u < 0 then
        return 0.16, 0.16, 0.16, 0.95
    end
    return 0.38, 0.3, 0.04, 0.95
end

function BG.GearScore_AddTooltip(tooltip, link)
    -- Gear scores remain available to tables and auction windows, but item
    -- tooltips intentionally stay compact so comparison panels do not widen.
end

local function FSWidth(fs)
    if not fs or not fs.GetStringWidth then return 0 end
    return fs:GetStringWidth() or 0
end

local measureFS
local function MeasureShownName(text, fontSize)
    if type(text) ~= "string" or text == "" then return 0 end
    local name = text:match("|h%[(.-)%]|h") or text:match("%[(.-)%]")
    if not name then
        name = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    end
    if name == "" then return 0 end
    if not measureFS then
        measureFS = UIParent:CreateFontString()
        measureFS:Hide()
    end
    measureFS:SetFont(BIAOGE_TEXT_FONT, fontSize or 14, "OUTLINE")
    measureFS:SetText(name)
    return measureFS:GetStringWidth() or 0
end

local function SizeScoreBadge(badge, text, r, g, b, br, bgc, bb, ba, fontSize, height)
    badge.text:SetFont(BIAOGE_TEXT_FONT, fontSize, "OUTLINE")
    badge.text:SetText(text)
    badge.text:SetTextColor(r, g, b)
    badge:SetBackdropColor(br, bgc, bb, ba)
    badge:SetSize(math.max(FSWidth(badge.text) + 8, 22), height)
end

function BG.ScoreText(bt, link)
    if not bt then return end
    if not bt.scoreFrame then
        local f = CreateFrame("Frame", nil, bt, "BackdropTemplate")
        f:EnableMouse(false)
        f:SetFrameLevel((bt:GetFrameLevel() or 0) + 12)
        f:SetSize(28, 14)
        f:SetBackdrop({
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
        })
        f:SetBackdropBorderColor(0, 0, 0, 0)
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetFont(BIAOGE_TEXT_FONT, 11, "OUTLINE")
        f.text:SetPoint("CENTER", 0, 0)
        bt.scoreFrame = f
    end
    if BiaoGe.options.gearScore ~= 1 or BiaoGe.options.gearScoreTable ~= 1 then
        bt.scoreFrame:Hide()
        return
    end
    local text = link or (bt.GetText and bt:GetText()) or ""
    local itemID = GetItemID(text)
    if not (text:find("item:") and itemID) then
        bt.scoreFrame:Hide()
        return
    end
    if BG.GearScore_IsOrangeWeaponUpgradeItem
        and BG.GearScore_IsOrangeWeaponUpgradeItem(itemID, text) then
        bt.scoreFrame:Hide()
        return
    end
    local isExchangeItem = BG.GearScore_IsExchangeItem
        and BG.GearScore_IsExchangeItem(itemID)
    local typeID = ItemTypeID(text)
    if typeID and typeID ~= 2 and typeID ~= 4 and not isExchangeItem then
        bt.scoreFrame:Hide()
        return
    end
    local short, r, g, b, ev = BG.GearScore_Format(text)
    if not ShowNameBadge(ev) or not short or short == "" then
        bt.scoreFrame:Hide()
        return
    end
    local br, bg, bb, ba = BadgeColors(ev)
    SizeScoreBadge(bt.scoreFrame, short, r, g, b, br, bg, bb, ba, 11, 14)

    -- 贴在装备名称后面，不要贴在右侧装等旁边
    local rightReserve = 22
    if bt.levelText and bt.levelText:IsShown() then
        rightReserve = math.max(rightReserve, FSWidth(bt.levelText.text) + 8)
    end
    if bt.bindingTex and bt.bindingTex:IsVisible() then
        rightReserve = rightReserve + 14
    end
    local boxW = bt:GetWidth() or 0
    local badgeW = bt.scoreFrame:GetWidth() or 22
    local fontSize = (BiaoGe.options and BiaoGe.options.editFontSize) or 14
    local nameW = MeasureShownName(text, fontSize)
    local leftInset = 0
    if bt.GetTextInsets then
        leftInset = select(1, bt:GetTextInsets()) or 0
    end
    if boxW > 0 and nameW > boxW then
        nameW = boxW
    end
    local x = leftInset + nameW + 3
    local maxX = boxW - rightReserve - badgeW
    if maxX < 2 then maxX = 2 end
    if x > maxX then x = maxX end
    if x < 2 then x = 2 end
    bt.scoreFrame:SetFrameLevel((bt:GetFrameLevel() or 0) + 12)
    bt.scoreFrame:ClearAllPoints()
    bt.scoreFrame:SetPoint("LEFT", x, 0)
    bt.scoreFrame:Show()
end

function BG.UpdateAllGearScore()
    local FB = BG.FB1
    if FB and BG.Frame and BG.Frame[FB] and Maxb[FB] then
        for b = 1, Maxb[FB] do
            for i = 1, BG.GetMaxi(FB, b) do
                local bt = BG.Frame[FB]["boss" .. b]["zhuangbei" .. i]
                if bt then
                    BG.ScoreText(bt)
                end
            end
        end
    end
    if BGA and BGA.Frames then
        for _, f in ipairs(BGA.Frames) do
            BG.GearScore_UpdateAuctionFrame(f)
        end
    end
    if BG.auctionLogFrame and BG.auctionLogFrame.buttons then
        for _, bt in ipairs(BG.auctionLogFrame.buttons) do
            BG.GearScore_UpdateItemListButton(bt)
        end
    end
    if BG.GearScore_RefreshOptionsStatus then
        BG.GearScore_RefreshOptionsStatus()
    end
end

local function SetAuctionTextWidths(bidFrame, nameExtra, typeExtra)
    local f = bidFrame.itemFrame
    local nameFS = f and f.itemNameText
    local typeFS = f and f.itemTypeText
    if not (f and nameFS) then return end
    local base = (f:GetWidth() or 0) - (f:GetHeight() or 0)
    local nameW = base - (nameExtra or 50)
    if nameW > 40 then
        nameFS:SetWidth(nameW)
    end
    if typeFS then
        local typeW = base - (typeExtra or 50)
        if typeW > 40 then
            typeFS:SetWidth(typeW)
        end
        if typeFS.SetWordWrap then
            typeFS:SetWordWrap(false)
        end
    end
end

function BG.GearScore_UpdateAuctionFrame(bidFrame)
    if not bidFrame then return end
    if not bidFrame.scoreHolder then
        local parent = bidFrame.itemFrame or bidFrame
        local badge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        badge:EnableMouse(false)
        badge:SetBackdrop({
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
        })
        badge:SetBackdropBorderColor(0, 0, 0, 0)
        local fs = badge:CreateFontString(nil, "OVERLAY")
        fs:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
        fs:SetPoint("CENTER", 0, 0)
        badge.text = fs
        bidFrame.scoreHolder = badge
        bidFrame.scoreText = fs
    end
    local badge = bidFrame.scoreHolder
    local parent = badge:GetParent()
    badge:SetFrameLevel((parent:GetFrameLevel() or 0) + 25)

    local link = bidFrame.link or (bidFrame.itemFrame and bidFrame.itemFrame.link)
    local orangeWeaponUpgrade = BG.GearScore_IsOrangeWeaponUpgradeItem
        and BG.GearScore_IsOrangeWeaponUpgradeItem(bidFrame.itemID, link)
    bidFrame.orangeWeaponUpgrade = orangeWeaponUpgrade and true or false
    local evLook = not orangeWeaponUpgrade and link and BG.GearScore_Eval(link)
    ApplyAuctionUnusableLook(bidFrame, evLook and evLook.suitable == false
        and evLook.reason ~= "notgear" and evLook.reason ~= "loading"
        and not orangeWeaponUpgrade)

    if orangeWeaponUpgrade then
        badge:Hide()
        SetAuctionTextWidths(bidFrame, 50, 50)
        return
    end

    if BiaoGe.options.gearScore ~= 1 or BiaoGe.options.gearScoreAuction ~= 1 then
        badge:Hide()
        SetAuctionTextWidths(bidFrame, 50, 50)
        return
    end
    if not link then
        badge:Hide()
        SetAuctionTextWidths(bidFrame, 50, 50)
        return
    end
    local text, r, g, b, ev = BG.GearScore_Format(link)
    if not ShowNameBadge(ev) or not text or text == "" then
        badge:Hide()
        SetAuctionTextWidths(bidFrame, 50, 50)
        return
    end
    local br, bgc, bb, ba = BadgeColors(ev)
    local isSmall = bidFrame.IsSmallWindow
    if badge.caption then
        badge.caption:Hide()
    end
    badge.text:ClearAllPoints()
    badge.text:SetPoint("CENTER", 0, 0)
    SizeScoreBadge(badge, text, r, g, b, br, bgc, bb, ba, isSmall and 12 or 13, isSmall and 16 or 18)

    local nameFS = bidFrame.itemFrame and bidFrame.itemFrame.itemNameText
    local remain = bidFrame.remainingTime
    local remainW = 36
    if remain then
        remainW = math.max(FSWidth(remain), 28) + 8
    end
    local badgeW = badge:GetWidth() or 28
    if isSmall then
        SetAuctionTextWidths(bidFrame, 110 + badgeW, 50)
    else
        -- 类型行只给剩余时间留位，分数贴在物品名后面，避免盖住「匕首」
        SetAuctionTextWidths(bidFrame, remainW + badgeW + 8, remainW)
    end

    badge:ClearAllPoints()
    if nameFS then
        local nw = FSWidth(nameFS)
        local cap = nameFS.GetWidth and nameFS:GetWidth() or nw
        if cap and cap > 0 and nw > cap then
            nw = cap
        end
        if bidFrame.itemFrame.nameHaveTex and bidFrame.itemFrame.nameHaveTex:IsShown() then
            nw = nw + 16
        end
        if nw < 8 and not bidFrame._gsNameRetry then
            bidFrame._gsNameRetry = true
            BG.After(0, function()
                bidFrame._gsNameRetry = nil
                BG.GearScore_UpdateAuctionFrame(bidFrame)
            end)
        end
        badge:SetPoint("LEFT", nameFS, "LEFT", nw + 4, 0)
    elseif isSmall and bidFrame.currentMoneyFrame then
        badge:SetPoint("RIGHT", bidFrame.currentMoneyFrame, "LEFT", -6, 0)
    else
        badge:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    end
    badge:Show()
end

local dirty
local function QueueRefresh()
    dirty = true
end

function BG.GearScore_OnSettingChanged()
    itemStatCache = {}
    playerSnap.scanned = false
    BG.GearScore_RefreshPlayer()
    playerSnap.scanned = true
    BG.UpdateAllGearScore()
end

local function ApplyGuessIfNeeded()
    local db = GetDB()
    local oldRole, oldSpec = db.role, db.specType
    if not db.talentLocked then
        db.talentTab = DetectTalentTab()
    end
    local class = GetClassFile()
    local def = SpecDef(class, db.talentTab)
    db.specType = def.specType
    local keepRole = db.roleLocked or (db.userSet and RoleAllowedForClass(class, db.role))
    if keepRole and RoleAllowedForClass(class, db.role) then
        if db.role ~= "TANK" then
            db.isMT = false
        elseif db.isMT == nil then
            db.isMT = true
        end
    else
        db.role = def.role
        db.isMT = db.role == "TANK"
    end
    NormalizeProfile(db)
    if not db.userSet and (db.role ~= oldRole or db.specType ~= oldSpec) then
        db.bias1, db.bias2 = DefaultBias(db.role, db.specType)
    end
end

BG.Init(function()
    player = BG.playerName or GetUnitName("player", true) or player
    realmID = BG.realmID or GetRealmID()
    if BiaoGe.options.gearScore == nil then BiaoGe.options.gearScore = 1 end
    if BiaoGe.options.gearScoreTable == nil then BiaoGe.options.gearScoreTable = 1 end
    if BiaoGe.options.gearScoreAuction == nil then BiaoGe.options.gearScoreAuction = 1 end
    GetDB()
    ApplyGuessIfNeeded()
    if BG.GearScore_PrefTabUI then
        BG.GearScore_PrefTabUI()
    end
    if BG.GearScore_SpecBarUI then
        BG.GearScore_SpecBarUI()
    end
end)

BG.Init2(function()
    ApplyGuessIfNeeded()
    if BG.GearScore_SpecBarUI then
        BG.GearScore_SpecBarUI()
    end
    if BG.GearScore_RefreshSpecBar then
        BG.GearScore_RefreshSpecBar()
    end
    BG.After(1.2, function()
        ApplyGuessIfNeeded()
        BG.GearScore_RefreshPlayer()
        playerSnap.scanned = true
        BG.UpdateAllGearScore()
        if BG.GearScore_RefreshProfileUI then
            BG.GearScore_RefreshProfileUI()
        end
        if BG.GearScore_RefreshSpecBar then
            BG.GearScore_RefreshSpecBar()
        end
    end)
end)

BG.RegisterEvent({
    "GET_ITEM_INFO_RECEIVED",
    "PLAYER_EQUIPMENT_CHANGED",
    "COMBAT_RATING_UPDATE",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "CHARACTER_POINTS_CHANGED",
}, function(_, event)
    if event == "GET_ITEM_INFO_RECEIVED" then
        itemStatCache = {}
    end
    if event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
        ApplyGuessIfNeeded()
        if BG.GearScore_RefreshSpecBar then
            BG.GearScore_RefreshSpecBar()
        end
        if BG.GearPrefMainFrame and BG.GearPrefMainFrame:IsVisible() then
            if BG.GearScore_RefreshProfileUI then
                BG.GearScore_RefreshProfileUI()
            end
            if BG.GearScore_RefreshWeightsPanel then
                BG.GearScore_RefreshWeightsPanel()
            end
        end
    end
    if event ~= "PLAYER_REGEN_ENABLED" and InCombatLockdown() then
        dirty = true
        return
    end
    QueueRefresh()
end)

C_Timer.NewTicker(0.8, function()
    if not dirty then return end
    if InCombatLockdown() then return end
    dirty = false
    BG.GearScore_RefreshPlayer()
    playerSnap.scanned = true
    BG.UpdateAllGearScore()
end)

local function PlayerSP()
    if not GetSpellBonusDamage then return 0 end
    local best = 0
    for i = 2, 7 do
        local v = GetSpellBonusDamage(i) or 0
        if v > best then best = v end
    end
    return best
end

local function ReadEPStat(key)
    local r = playerSnap.ratings or {}
    if key == "str" then
        return (UnitStat("player", 1)) or 0
    elseif key == "agi" then
        return (UnitStat("player", 2)) or 0
    elseif key == "sta" then
        return (UnitStat("player", 3)) or 0
    elseif key == "int" then
        return (UnitStat("player", 4)) or 0
    elseif key == "spi" then
        return (UnitStat("player", 5)) or 0
    elseif key == "ap" then
        local b, p, n = UnitAttackPower("player")
        return (b or 0) + (p or 0) + (n or 0)
    elseif key == "rap" then
        local b, p, n = UnitRangedAttackPower("player")
        return (b or 0) + (p or 0) + (n or 0)
    elseif key == "sp" then
        return PlayerSP()
    elseif key == "heal" then
        return GetSpellBonusHealing and GetSpellBonusHealing() or 0
    elseif key == "mp5" then
        if GetManaRegen then
            return (GetManaRegen() or 0) * 5
        end
        return 0
    elseif key == "armor" then
        return (UnitArmor("player")) or 0
    elseif key == "hitRating" then
        return r.hitMelee or CombatRating(CR_HIT_MELEE)
    elseif key == "rangedHitRating" then
        return r.hitRanged or CombatRating(CR_HIT_RANGED)
    elseif key == "spellHitRating" then
        return r.hitSpell or CombatRating(CR_HIT_SPELL)
    elseif key == "critRating" then
        return CombatRating(CR_CRIT_MELEE)
    elseif key == "spellCritRating" then
        return CombatRating(CR_CRIT_SPELL)
    elseif key == "rangedCritChance" then
        if GetRangedCritChance then
            return GetRangedCritChance() or 0
        end
        return CombatRating(CR_CRIT_RANGED)
    elseif key == "hasteRating" then
        return CombatRating(CR_HASTE_MELEE)
    elseif key == "spellHasteRating" then
        return CombatRating(CR_HASTE_SPELL)
    elseif key == "rangedHasteRating" then
        return CombatRating(CR_HASTE_RANGED)
    elseif key == "expertiseRating" then
        return r.expertise or CombatRating(CR_EXPERTISE)
    elseif key == "arpRating" then
        return CombatRating(CR_ARMOR_PENETRATION)
    elseif key == "dodge" then
        return CombatRating(CR_DODGE)
    elseif key == "parry" then
        return CombatRating(CR_PARRY)
    elseif key == "block" then
        return CombatRating(CR_BLOCK)
    elseif key == "blockValue" then
        return GetShieldBlock and GetShieldBlock() or 0
    elseif key == "defense" then
        return r.defense or CombatRating(CR_DEFENSE_SKILL)
    end
    return 0
end

-- 人物属性 / 装备偏好面板
function BG.GearScore_OptionsUI(parent)
    local db = GetDB()
    local width = 15
    local y = -10
    local lineWidth = 700

    local function Header(text, yy)
        local t = parent:CreateFontString()
        t:SetFont(BIAOGE_TEXT_FONT, 15, "OUTLINE")
        t:SetPoint("TOPLEFT", width, yy)
        t:SetText(BG.STC_g1(text))
        return t
    end

    local function CreateLine(yy)
        local l = parent:CreateLine()
        l:SetColorTexture(RGB("808080", 1))
        l:SetStartPoint("TOPLEFT", 5, yy)
        l:SetEndPoint("TOPLEFT", lineWidth, yy)
        l:SetThickness(1.5)
        return l
    end

    local function CreateCheckButton(name, text, x, yy, ontext, callback)
        local bt = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
        bt:SetSize(30, 30)
        bt:SetPoint("TOPLEFT", parent, x, yy)
        bt.Text:SetFont(BIAOGE_TEXT_FONT, 15, "OUTLINE")
        bt.Text:SetText(text)
        bt.Text:SetWordWrap(false)
        bt.Text:SetWidth(min(bt.Text:GetStringWidth() + 20, 500))
        bt:SetHitRectInsets(0, -bt.Text:GetWidth(), 0, 0)
        bt.name = name
        bt.ontext = ontext
        bt.callback = callback
        BG.options["button" .. name] = bt
        BG.options[name .. "reset"] = BG.options[name .. "reset"] or 1
        bt:SetChecked(BiaoGe.options[name] == 1)
        bt:SetScript("OnClick", function(self)
            BiaoGe.options[self.name] = self:GetChecked() and 1 or 0
            if self.callback then
                self.callback()
            end
            BG.PlaySound(1)
        end)
        bt:SetScript("OnEnter", function(self)
            if not self.ontext then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, 0)
            GameTooltip:ClearLines()
            if type(self.ontext) == "table" then
                for i, tipText in ipairs(self.ontext) do
                    if i == 1 then
                        GameTooltip:AddLine(tipText, 1, 1, 1, true)
                    else
                        GameTooltip:AddLine(tipText, 1, 0.82, 0, true)
                    end
                end
                GameTooltip:Show()
            else
                GameTooltip:SetText(self.ontext)
            end
        end)
        bt:SetScript("OnLeave", GameTooltip_Hide)
        bt:SetScript("OnShow", function(self)
            self:SetChecked(BiaoGe.options[self.name] == 1)
        end)
        return bt
    end

    local fEnable = CreateCheckButton("gearScore", L["启用自身装备评分"], 15, y, {
        L["启用自身装备评分"],
        L["分数只针对你自己，对比的是你当前穿的装备。白字只是一部分，绿字（命中/暴击/急速/破甲/攻强/法强）经常更值钱。缺命中时命中装分高，达标后别人会去抢别的属性。"],
    }, BG.GearScore_OnSettingChanged)
    y = y - 30

    local fTable = CreateCheckButton("gearScoreTable", L["在表格装备格显示升级分"], 15, y, {
        L["在表格装备格显示升级分"],
        L["在装备名称后面显示相对你当前同部位的升级分，例如 +23。"],
    }, BG.GearScore_OnSettingChanged)
    y = y - 30

    local fAuc = CreateCheckButton("gearScoreAuction", L["在拍卖竞价窗显示升级分"], 15, y, {
        L["在拍卖竞价窗显示升级分"],
        L["团长开拍时，竞价窗物品名称后面显示你的推荐升级分。"],
    }, BG.GearScore_OnSettingChanged)
    y = y - 28

    local tip = parent:CreateFontString()
    tip:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    tip:SetPoint("TOPLEFT", width, y)
    tip:SetWidth(520)
    tip:SetJustifyH("LEFT")
    tip:SetTextColor(0.7, 0.7, 0.7)
    tip:SetText(L["分数只针对你自己，对比的是你当前穿的装备。白字只是一部分，绿字（命中/暴击/急速/破甲/攻强/法强）经常更值钱。缺命中时命中装分高，达标后别人会去抢别的属性。"])
    y = y - 40

    CreateLine(y + 8)
    y = y - 8
    Header(L["属性"], y)
    y = y - 22

    local statusLine = parent:CreateFontString()
    statusLine:SetFont(BIAOGE_TEXT_FONT, 14, "OUTLINE")
    statusLine:SetPoint("TOPLEFT", width, y)
    statusLine:SetJustifyH("LEFT")
    y = y - 20

    local hitLine = parent:CreateFontString()
    hitLine:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    hitLine:SetPoint("TOPLEFT", width, y)
    y = y - 18
    local expLine = parent:CreateFontString()
    expLine:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    expLine:SetPoint("TOPLEFT", width, y)
    y = y - 18
    local defLine = parent:CreateFontString()
    defLine:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    defLine:SetPoint("TOPLEFT", width, y)
    y = y - 22

    local attrScoreLine = parent:CreateFontString()
    attrScoreLine:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    attrScoreLine:SetPoint("TOPLEFT", width, y)
    attrScoreLine:SetJustifyH("LEFT")
    y = y - 20

    local attrDetailLine = parent:CreateFontString()
    attrDetailLine:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    attrDetailLine:SetPoint("TOPLEFT", width, y)
    attrDetailLine:SetWidth(700)
    attrDetailLine:SetJustifyH("LEFT")
    attrDetailLine:SetSpacing(3)
    y = y - 96

    local function CapColor(cur, cap, needed)
        if not needed then
            return "|cff808080"
        end
        if cur >= cap then
            return "|cff00ff00"
        end
        return "|cffffff00"
    end

    local function RefreshStatus()
        db = GetDB()
        local class = GetClassFile()
        local primary = PrimaryFor(class, db.role, db.specType)
        local primaryName = ({ STR = L["力量"], AGI = L["敏捷"], INT = L["智力"] })[primary] or primary
        local ilvl = 0
        if GetAverageItemLevel then
            ilvl = select(2, GetAverageItemLevel()) or 0
        end
        local className = GetClassName()
        local color = select(4, GetClassColor(class))
        local talentName = TalentTabName(class, db.talentTab or GetMainTree())
        statusLine:SetText(format("|c%s%s|r  %s  %s   %s %s   %s %.0f",
            color or "ffffffff", className, RoleLabel(db.role), talentName,
            L["主属性"], primaryName, L["装等"], ilvl))

        local caps = GetCaps(db)
        local r = playerSnap.ratings
        local th = playerSnap.talentHit or {}
        local function HitNote(talentPct)
            local parts = {}
            talentPct = talentPct or 0
            if talentPct > 0 then
                tinsert(parts, format("%s+%d%%", L["天赋"], talentPct))
            end
            if (th.racialPct or 0) > 0 then
                tinsert(parts, format("%s+%d%%", L["种族"], th.racialPct))
            end
            if #parts == 0 then
                return ""
            end
            return "  |cff00ff00" .. table.concat(parts, " ") .. "|r"
        end
        local hitCur, hitCap
        if db.role == "HEAL" then
            hitLine:SetText(L["命中"] .. "：|cff808080" .. L["不需要"] .. "|r")
        elseif db.specType == "CASTER" then
            hitCur, hitCap = r.hitSpell, caps.hitSpell
            hitLine:SetText(format("%s：%s%d / %d|r  %s%s", L["命中"], CapColor(hitCur, hitCap, true), hitCur, hitCap,
                hitCur >= hitCap and L["达标"] or L["未达标"], HitNote(th.talentSpellPct)))
        else
            hitCur = db.specType == "RANGED" and r.hitRanged or r.hitMelee
            hitCap = caps.hitMelee
            local tPct = db.specType == "RANGED" and th.talentRangedPct or th.talentMeleePct
            hitLine:SetText(format("%s：%s%d / %d|r  %s%s", L["命中"], CapColor(hitCur, hitCap, true), hitCur, hitCap,
                hitCur >= hitCap and L["达标"] or L["未达标"], HitNote(tPct)))
        end
        if db.specType == "MELEE" or db.role == "TANK" then
            expLine:SetText(format("%s：%s%d / %d|r  %s", L["精准"], CapColor(r.expertise, caps.expertise, true),
                r.expertise, caps.expertise, r.expertise >= caps.expertise and L["达标"] or L["未达标"]))
        else
            expLine:SetText(L["精准"] .. "：|cff808080" .. L["不需要"] .. "|r")
        end
        if db.role == "TANK" and db.isMT then
            defLine:SetText(format("%s：%s%d / %d|r  %s", L["防御"], CapColor(r.defense, caps.defense, true),
                r.defense, caps.defense, r.defense >= caps.defense and L["达标"] or L["未达标"]))
        else
            defLine:SetText(L["防御"] .. "：|cff808080" .. L["不需要"] .. "|r")
        end

        local ep, isCustom = GetEffectiveEPWeights(db)
        if ep then
            local ranked = {}
            local score = 0
            for k, v in pairs(ep) do
                if EPWeightAllowed(k, db) then
                    local wgt = tonumber(v) or 0
                    local cur = ReadEPStat(k) or 0
                    score = score + cur * wgt
                    tinsert(ranked, { key = k, value = wgt, cur = cur })
                end
            end
            table.sort(ranked, function(a, b)
                if a.value == b.value then
                    return a.key < b.key
                end
                return a.value > b.value
            end)
            local tag = isCustom and L["自定义"] or L["默认"]
            attrScoreLine:SetText(format("%s：|cff00ff00%.0f|r    %s", L["属性评分"], score, tag))
            local cols, lines, col = {}, {}, 0
            for _, row in ipairs(ranked) do
                col = col + 1
                tinsert(cols, format("%s |cffffffff%.0f|r", EPLabel(row.key), row.cur))
                if col == 3 then
                    tinsert(lines, table.concat(cols, "    "))
                    cols, col = {}, 0
                end
            end
            if #cols > 0 then
                tinsert(lines, table.concat(cols, "    "))
            end
            attrDetailLine:SetText(table.concat(lines, "\n"))
        else
            attrScoreLine:SetText(L["当前职业暂无属性权重数据。"])
            attrDetailLine:SetText("")
        end
    end
    BG.GearScore_RefreshOptionsStatus = RefreshStatus

    CreateLine(y + 8)
    y = y - 8

    local RefreshWeightsPanel

    local function AfterRoleChange(resetBias, silent)
        db = GetDB()
        NormalizeProfile(db)
        if not silent then
            db.userSet = true
        end
        if resetBias then
            db.bias1, db.bias2 = DefaultBias(db.role, db.specType)
        end
        RefreshSpecButtons()
        if BG.GearScoreMTCheck then
            BG.GearScoreMTCheck:SetShown(db.role == "TANK")
            BG.GearScoreMTCheck:SetChecked(db.isMT)
        end
        if BG.GearScoreDWCheck then
            BG.GearScoreDWCheck:SetShown(db.role == "TANK" or db.specType == "MELEE")
        end
        if BG.GearScoreSpellHitCheck then
            BG.GearScoreSpellHitCheck:SetShown(db.specType == "CASTER" and db.role ~= "HEAL")
        end
        RefreshStatus()
        if RefreshWeightsPanel then
            RefreshWeightsPanel()
        end
        if not silent then
            BG.GearScore_OnSettingChanged()
            BG.PlaySound(1)
        end
    end
    applyProfileChange = AfterRoleChange
    BG.GearScore_RefreshProfileUI = function()
        AfterRoleChange(false, true)
    end

    local function MakeProfileCheck(label, tip, checked, onClick)
        local bt = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
        bt:SetSize(30, 30)
        bt:SetPoint("TOPLEFT", parent, 15, y)
        bt.Text:SetFont(BIAOGE_TEXT_FONT, 15, "OUTLINE")
        bt.Text:SetText(label)
        bt.Text:SetWordWrap(false)
        bt:SetHitRectInsets(0, -bt.Text:GetWidth(), 0, 0)
        bt:SetChecked(checked)
        bt:SetScript("OnClick", onClick)
        bt:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, 0)
            GameTooltip:ClearLines()
            GameTooltip:AddLine(label, 1, 1, 1, true)
            GameTooltip:AddLine(tip, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        bt:SetScript("OnLeave", GameTooltip_Hide)
        return bt
    end

    local mt = MakeProfileCheck(L["主坦"], L["勾选后把防御当作硬门槛。副坦可以取消。"], db.isMT, function(self)
        db.isMT = self:GetChecked() and true or false
        db.userSet = true
        AfterRoleChange(false)
    end)
    BG.GearScoreMTCheck = mt
    y = y - 28

    local dw = MakeProfileCheck(L["双持命中帽"], L["近战双持把命中门槛从 8% 改为 27%。"], db.dualWieldHit, function(self)
        db.dualWieldHit = self:GetChecked() and true or false
        db.dualWieldHitSet = true
        db.userSet = true
        AfterRoleChange(false)
    end)
    BG.GearScoreDWCheck = dw
    y = y - 28

    local spellHit = MakeProfileCheck(L["法术命中按17%"], L["不勾选时按 14%（团队命中减益）。天赋和种族提供的命中会自动计入。"], db.spellHit17, function(self)
        db.spellHit17 = self:GetChecked() and true or false
        db.userSet = true
        AfterRoleChange(false)
    end)
    BG.GearScoreSpellHitCheck = spellHit
    y = y - 30

    CreateLine(y + 8)
    y = y - 8
    Header(L["门槛"], y)
    y = y - 24

    local function CapEdit(label, key, x)
        local t = parent:CreateFontString()
        t:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
        t:SetPoint("TOPLEFT", x, y)
        t:SetText(label)
        local edit = CreateFrame("EditBox", nil, parent, BG.editTemplate)
        edit:SetSize(55, 20)
        edit:SetPoint("LEFT", t, "RIGHT", 6, 0)
        edit:SetAutoFocus(false)
        edit:SetNumeric(true)
        edit:SetMaxLetters(4)
        BG.SetEditBaseClass(edit)
        local caps = db.caps or {}
        edit:SetText(tostring(caps[key] or DEFAULT_CAPS[key] or ""))
        edit:SetScript("OnEditFocusLost", function(self)
            db.caps = db.caps or {}
            local n = tonumber(self:GetText())
            if n and n > 0 then
                db.caps[key] = n
            else
                db.caps[key] = nil
                self:SetText(tostring(DEFAULT_CAPS[key]))
            end
            db.userSet = true
            RefreshStatus()
            BG.GearScore_OnSettingChanged()
        end)
        edit:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        return edit
    end
    CapEdit(L["近战命中"], "hitMelee", 15)
    CapEdit(L["法术命中"], "hitSpell", 220)
    y = y - 28
    CapEdit(L["精准"], "expertise", 15)
    CapEdit(L["防御"], "defense", 220)
    y = y - 36

    local reset = BG.CreateButton(parent)
    reset:SetSize(120, 24)
    reset:SetPoint("TOPLEFT", width, y)
    reset:SetText(L["恢复默认门槛"])
    reset:SetScript("OnClick", function()
        db.caps = nil
        db.userSet = true
        RefreshStatus()
        BG.GearScore_OnSettingChanged()
        BG.PlaySound(1)
    end)
    y = y - 40

    CreateLine(y + 8)
    y = y - 8
    Header(L["属性价值"], y)
    y = y - 22

    local weightTip = parent:CreateFontString()
    weightTip:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    weightTip:SetPoint("TOPLEFT", width, y)
    weightTip:SetWidth(700)
    weightTip:SetJustifyH("LEFT")
    weightTip:SetTextColor(1, 0.82, 0)
    weightTip:SetText(L["默认按天赋给出属性价值，绿字（命中/暴击/急速/破甲/攻强/法强）按模拟器权重计，往往比白字更值钱。可按自己的配装习惯改。"])
    y = y - 24

    local weightBox = CreateFrame("Frame", nil, parent)
    weightBox:SetPoint("TOPLEFT", parent, "TOPLEFT", width, y)
    weightBox:SetSize(720, 40)
    weightBox.controls = {}
    local weightBoxTop = y

    local function SmallBtn(p, text, bw)
        local bt = BG.CreateButton(p)
        bt:SetSize(bw or 55, 22)
        bt:SetText(text)
        local fs = bt:GetFontString()
        if fs then
            fs:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
        end
        return bt
    end

    local function Track(ctrl)
        tinsert(weightBox.controls, ctrl)
        return ctrl
    end

    local function UpdatePrefHeight(boxH)
        weightBox:SetHeight(boxH)
        parent.prefContentHeight = math.abs(weightBoxTop) + boxH + 50
        parent:SetHeight(math.max(parent.prefContentHeight, 400))
    end

    RefreshWeightsPanel = function()
        for _, c in ipairs(weightBox.controls) do
            c:Hide()
            c:SetParent(nil)
        end
        wipe(weightBox.controls)

        local defaults = GetDefaultEP(db)
        local weights = GetEffectiveEPWeights(db)
        if not defaults or not weights then
            local noData = weightBox:CreateFontString()
            noData:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
            noData:SetPoint("TOPLEFT", 0, 0)
            noData:SetText(L["当前职业暂无属性权重数据。"])
            Track(noData)
            UpdatePrefHeight(30)
            return
        end

        local statKeys, seen = {}, {}
        for k, v in pairs(defaults) do
            if EPWeightAllowed(k, db) then
                tinsert(statKeys, { key = k, value = tonumber(weights[k] or v) or 0 })
                seen[k] = true
            end
        end
        for k, v in pairs(weights) do
            if not seen[k] and EPWeightAllowed(k, db) then
                tinsert(statKeys, { key = k, value = tonumber(v) or 0 })
            end
        end
        table.sort(statKeys, function(a, b)
            if a.value == b.value then
                return a.key < b.key
            end
            return a.value > b.value
        end)

        local LABEL_W, INPUT_W, BTN_W, LINE_H = 130, 70, 55, 30
        local yOff = 0
        for _, statItem in ipairs(statKeys) do
            local k = statItem.key
            local defaultValue = defaults[k]
            local currentValue = weights[k]

            local fsLabel = weightBox:CreateFontString()
            fsLabel:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
            fsLabel:SetPoint("TOPLEFT", 0, yOff)
            fsLabel:SetWidth(LABEL_W)
            fsLabel:SetJustifyH("RIGHT")
            fsLabel:SetText(EPLabel(k) .. "：")
            Track(fsLabel)

            local editBox = CreateFrame("EditBox", nil, weightBox, BG.editTemplate)
            editBox:SetSize(INPUT_W, 20)
            editBox:SetPoint("LEFT", fsLabel, "RIGHT", 8, 0)
            editBox:SetAutoFocus(false)
            editBox:SetMaxLetters(10)
            BG.SetEditBaseClass(editBox)
            editBox:SetText(FormatWeight(currentValue))
            Track(editBox)

            local function SaveWeight()
                local value = tonumber(editBox:GetText())
                if value then
                    SetEPWeight(k, value)
                    editBox:SetText(FormatWeight(value))
                    RefreshStatus()
                    BG.GearScore_OnSettingChanged()
                    BG.PlaySound(1)
                else
                    local cur = GetEffectiveEPWeights(db)
                    editBox:SetText(FormatWeight(cur and cur[k]))
                end
                editBox:ClearFocus()
            end

            local btnConfirm = SmallBtn(weightBox, L["确认"], BTN_W)
            btnConfirm:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
            btnConfirm:SetScript("OnClick", SaveWeight)
            Track(btnConfirm)
            editBox:SetScript("OnEnterPressed", SaveWeight)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            local btnDefault = SmallBtn(weightBox, L["默认"], BTN_W)
            btnDefault:SetPoint("LEFT", btnConfirm, "RIGHT", 6, 0)
            btnDefault:SetScript("OnClick", function()
                ResetEPWeight(k)
                editBox:SetText(FormatWeight(defaultValue))
                RefreshStatus()
                BG.GearScore_OnSettingChanged()
                BG.PlaySound(1)
            end)
            Track(btnDefault)

            yOff = yOff - LINE_H
        end

        local btnResetAll = SmallBtn(weightBox, L["重置所有为默认"], 140)
        btnResetAll:SetPoint("TOPLEFT", LABEL_W + 8, yOff)
        btnResetAll:SetScript("OnClick", function()
            ResetAllEPWeights()
            RefreshWeightsPanel()
            RefreshStatus()
            BG.GearScore_OnSettingChanged()
            BG.PlaySound(1)
        end)
        Track(btnResetAll)
        yOff = yOff - 36

        local importTitle = weightBox:CreateFontString()
        importTitle:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
        importTitle:SetPoint("TOPLEFT", 0, yOff)
        importTitle:SetJustifyH("LEFT")
        importTitle:SetTextColor(1, 0.82, 0)
        importTitle:SetText(L["导入WOWSimsCN的EP权重数据"])
        Track(importTitle)
        yOff = yOff - 22

        local importHelp = weightBox:CreateFontString()
        importHelp:SetFont(BIAOGE_TEXT_FONT, 12, "OUTLINE")
        importHelp:SetPoint("TOPLEFT", 0, yOff)
        importHelp:SetWidth(700)
        importHelp:SetHeight(124)
        importHelp:SetJustifyH("LEFT")
        importHelp:SetJustifyV("TOP")
        importHelp:SetSpacing(2)
        importHelp:SetWordWrap(true)
        importHelp:SetTextColor(0.75, 0.75, 0.75)
        importHelp:SetText(L["WOWSimsCN EP导入说明"])
        Track(importHelp)
        yOff = yOff - 132

        local importBG = CreateFrame("Frame", nil, weightBox, BackdropTemplateMixin and "BackdropTemplate" or nil)
        importBG:SetPoint("TOPLEFT", 0, yOff)
        importBG:SetSize(520, 90)
        if importBG.SetBackdrop then
            importBG:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeSize = 1,
            })
            importBG:SetBackdropColor(0, 0, 0, 0.45)
            importBG:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        Track(importBG)

        local importEdit = CreateFrame("EditBox", nil, importBG)
        importEdit:SetPoint("TOPLEFT", 6, -6)
        importEdit:SetPoint("BOTTOMRIGHT", -6, 6)
        importEdit:SetMultiLine(true)
        importEdit:SetAutoFocus(false)
        importEdit:EnableMouse(true)
        importEdit:SetFont(BIAOGE_TEXT_FONT, 13, "")
        importEdit:SetJustifyH("LEFT")
        importEdit:SetJustifyV("TOP")
        importEdit:SetTextInsets(0, 0, 0, 0)
        importEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        importEdit:SetScript("OnMouseDown", function(self) self:SetFocus() end)
        importEdit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        importEdit:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
        Track(importEdit)
        yOff = yOff - 100

        local importMsg = weightBox:CreateFontString()
        importMsg:SetFont(BIAOGE_TEXT_FONT, 12, "OUTLINE")
        importMsg:SetPoint("TOPLEFT", 0, yOff - 28)
        importMsg:SetJustifyH("LEFT")
        importMsg:SetText("")
        Track(importMsg)

        local btnImport = SmallBtn(weightBox, L["导入"], 80)
        btnImport:SetPoint("TOPLEFT", LABEL_W + 8, yOff)
        btnImport:SetScript("OnClick", function()
            local rawText = importEdit:GetText() or ""
            local imported = ParsePawnEP(rawText, db)
            local n = 0
            for k, v in pairs(imported) do
                SetEPWeight(k, v)
                n = n + 1
            end
            if n > 0 then
                RefreshWeightsPanel()
                RefreshStatus()
                BG.GearScore_OnSettingChanged()
            else
                importMsg:SetTextColor(1, 0.35, 0.35)
                importMsg:SetText(L["没有识别到有效的EP权重"])
            end
            BG.PlaySound(1)
        end)
        Track(btnImport)

        local btnClear = SmallBtn(weightBox, L["清除"], 80)
        btnClear:SetPoint("LEFT", btnImport, "RIGHT", 8, 0)
        btnClear:SetScript("OnClick", function()
            importEdit:SetText("")
            importEdit:ClearFocus()
            importMsg:SetText("")
            BG.PlaySound(1)
        end)
        Track(btnClear)

        local btnRestore = SmallBtn(weightBox, L["恢复默认"], 100)
        btnRestore:SetPoint("LEFT", btnClear, "RIGHT", 8, 0)
        btnRestore:SetScript("OnClick", function()
            ResetAllEPWeights()
            RefreshWeightsPanel()
            RefreshStatus()
            BG.GearScore_OnSettingChanged()
            BG.PlaySound(1)
        end)
        Track(btnRestore)

        yOff = yOff - 48
        UpdatePrefHeight(math.abs(yOff) + 20)
    end
    BG.GearScore_RefreshWeightsPanel = RefreshWeightsPanel

    AfterRoleChange(false, true)
    RefreshStatus()
    RefreshWeightsPanel()
    parent:HookScript("OnShow", function()
        ApplyGuessIfNeeded()
        BG.GearScore_RefreshPlayer()
        AfterRoleChange(false, true)
    end)
    if not parent.prefContentHeight then
        parent.prefContentHeight = math.abs(weightBoxTop) + 400
    end
end

function BG.GearScore_PrefTabUI()
    local mainFrame = BG.GearPrefMainFrame
    if not mainFrame or mainFrame.prefBuilt then
        return
    end
    mainFrame.prefBuilt = true

    local scroll = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", BG.MainFrame, 20, -35)
    scroll:SetPoint("BOTTOMRIGHT", BG.MainFrame, -40, 80)
    scroll:EnableMouse(true)
    scroll.ScrollBar.scrollStep = BG.scrollStep
    BG.CreateSrollBarBackdrop(scroll.ScrollBar)
    BG.HookScrollBarShowOrHide(scroll)
    mainFrame.scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(760, 620)
    child:EnableMouse(true)
    scroll:SetScrollChild(child)
    mainFrame.child = child

    BG.GearScore_OptionsUI(child)
    if child.prefContentHeight and child.prefContentHeight > 100 then
        child:SetHeight(child.prefContentHeight)
    end
end
