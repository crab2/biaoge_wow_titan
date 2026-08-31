if BG.IsBlackListPlayer then return end
local AddonName, ns = ...

local L = ns.L
local LibBG = ns.LibBG
local Maxb = ns.Maxb
local GetItemID = ns.GetItemID

local player = BG.playerName
local realmID = BG.realmID

local CR_DEFENSE_SKILL = _G.CR_DEFENSE_SKILL or 2
local CR_HIT_MELEE = _G.CR_HIT_MELEE or 6
local CR_HIT_RANGED = _G.CR_HIT_RANGED or 7
local CR_HIT_SPELL = _G.CR_HIT_SPELL or 8
local CR_EXPERTISE = _G.CR_EXPERTISE or 24

local BIAS1 = 1.45
local BIAS2 = 1.18
local WASTE = 0.05
local ILVL_W = 0.15
local SOCKET_GEM = 16

local DEFAULT_CAPS = {
    hitMelee = 263,
    hitMeleeDW = 886,
    hitSpell = 368,
    hitSpell17 = 446,
    expertise = 214,
    defense = 140,
}

local STAT_KEYS = {
    STR = true, AGI = true, STA = true, INT = true, SPI = true,
    AP = true, SP = true, HEAL = true, HIT = true, HIT_SPELL = true,
    CRIT = true, HASTE = true, ARPEN = true, EXPERTISE = true, DEFENSE = true,
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
        AP = 0, SP = 1.00, HEAL = 0.15, HIT = 1.60, HIT_SPELL = 1.60,
        CRIT = 0.70, HASTE = 0.70, ARPEN = 0, EXPERTISE = 0, DEFENSE = 0,
        DODGE = 0, PARRY = 0, BLOCK = 0, BLOCKVALUE = 0,
        ARMOR = 0, DPS = 0, MP5 = 0.05, SOCKET = 1,
    },
    HEAL = {
        STR = 0, AGI = 0, STA = 0.08, INT = 0.70, SPI = 0.90,
        AP = 0, SP = 1.00, HEAL = 1.00, HIT = 0.05, HIT_SPELL = 0.05,
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

local STAT_MAP = {
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT_SPELL",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_SPELL_RATING_SHORT = "HASTE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARPEN",
    ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    RESISTANCE0_NAME = "ARMOR",
    EMPTY_SOCKET_RED = "SOCKET",
    EMPTY_SOCKET_YELLOW = "SOCKET",
    EMPTY_SOCKET_BLUE = "SOCKET",
    EMPTY_SOCKET_META = "SOCKET",
    EMPTY_SOCKET_PRISMATIC = "SOCKET",
    EMPTY_SOCKET_NO_COLOR = "SOCKET",
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

local function GetClassFile()
    return select(2, UnitClass("player"))
end

local function GetClassName()
    return UnitClass("player")
end

local function GuessProfile(class, specIndex)
    class = class or GetClassFile()
    specIndex = specIndex or (BiaoGe.playerInfo and BiaoGe.playerInfo[realmID]
        and BiaoGe.playerInfo[realmID][player] and BiaoGe.playerInfo[realmID][player].talent)
    local role, specType, isMT = "DPS", "MELEE", false
    if class == "MAGE" or class == "WARLOCK" then
        specType = "CASTER"
    elseif class == "HUNTER" then
        specType = "RANGED"
    elseif class == "PRIEST" then
        if specIndex == 3 then
            specType = "CASTER"
        else
            role, specType = "HEAL", "CASTER"
        end
    elseif class == "PALADIN" then
        if specIndex == 1 then
            role, specType = "HEAL", "CASTER"
        elseif specIndex == 2 then
            role, specType, isMT = "TANK", "MELEE", true
        else
            specType = "MELEE"
        end
    elseif class == "WARRIOR" then
        if specIndex == 3 then
            role, specType, isMT = "TANK", "MELEE", true
        else
            specType = "MELEE"
        end
    elseif class == "DEATHKNIGHT" then
        if specIndex == 1 then
            role, specType, isMT = "TANK", "MELEE", true
        else
            specType = "MELEE"
        end
    elseif class == "SHAMAN" then
        if specIndex == 1 then
            specType = "CASTER"
        elseif specIndex == 3 then
            role, specType = "HEAL", "CASTER"
        else
            specType = "MELEE"
        end
    elseif class == "DRUID" then
        if specIndex == 1 then
            specType = "CASTER"
        elseif specIndex == 3 then
            role, specType = "HEAL", "CASTER"
        else
            specType = "MELEE"
        end
    elseif class == "ROGUE" then
        specType = "MELEE"
    end
    return role, specType, isMT
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

local function GetDB()
    BiaoGe.GearScore = BiaoGe.GearScore or {}
    BiaoGe.GearScore[realmID] = BiaoGe.GearScore[realmID] or {}
    local db = BiaoGe.GearScore[realmID][player]
    if not db then
        local role, specType, isMT = GuessProfile()
        local bias1, bias2 = DefaultBias(role, specType)
        db = {
            role = role,
            specType = specType,
            isMT = isMT and true or false,
            dualWieldHit = false,
            spellHit17 = false,
            bias1 = bias1,
            bias2 = bias2,
            userSet = false,
        }
        BiaoGe.GearScore[realmID][player] = db
    end
    return db
end

function BG.GearScore_GetDB()
    return GetDB()
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
    }
end

function BG.GearScore_DefaultCaps()
    return {
        hitMelee = DEFAULT_CAPS.hitMelee,
        hitSpell = DEFAULT_CAPS.hitSpell,
        expertise = DEFAULT_CAPS.expertise,
        defense = DEFAULT_CAPS.defense,
    }
end

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
    w._primary = primary
    return w
end

local playerSnap = {
    ratings = { hitMelee = 0, hitRanged = 0, hitSpell = 0, expertise = 0, defense = 0 },
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
    local token = raw
    if _G[raw] and STAT_MAP[raw] then
        return STAT_MAP[raw]
    end
    -- localized short as key
    for tokenName, key in pairs(STAT_MAP) do
        local loc = _G[tokenName]
        if loc and loc == raw then
            return key
        end
    end
    return nil
end

local function ParseGetItemStats(link)
    local stats = {}
    if not GetItemStats then return stats end
    local ok, raw = pcall(GetItemStats, link)
    if not ok or type(raw) ~= "table" then return stats end
    for k, v in pairs(raw) do
        local key = MapStatKey(k)
        if key then
            AddStat(stats, key, v)
        end
    end
    return stats
end

local function ShortPat(globalName)
    local s = _G[globalName]
    if type(s) ~= "string" or s == "" then return end
    return s
end

local tooltipStatNames
local function BuildTooltipNames()
    tooltipStatNames = {}
    local pairs_ = {
        { "STR", "ITEM_MOD_STRENGTH_SHORT" },
        { "AGI", "ITEM_MOD_AGILITY_SHORT" },
        { "STA", "ITEM_MOD_STAMINA_SHORT" },
        { "INT", "ITEM_MOD_INTELLECT_SHORT" },
        { "SPI", "ITEM_MOD_SPIRIT_SHORT" },
        { "HIT", "ITEM_MOD_HIT_RATING_SHORT" },
        { "HIT_SPELL", "ITEM_MOD_HIT_SPELL_RATING_SHORT" },
        { "CRIT", "ITEM_MOD_CRIT_RATING_SHORT" },
        { "HASTE", "ITEM_MOD_HASTE_RATING_SHORT" },
        { "EXPERTISE", "ITEM_MOD_EXPERTISE_RATING_SHORT" },
        { "DEFENSE", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
        { "DODGE", "ITEM_MOD_DODGE_RATING_SHORT" },
        { "PARRY", "ITEM_MOD_PARRY_RATING_SHORT" },
        { "BLOCK", "ITEM_MOD_BLOCK_RATING_SHORT" },
        { "ARPEN", "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
        { "SP", "ITEM_MOD_SPELL_POWER_SHORT" },
        { "HEAL", "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
        { "AP", "ITEM_MOD_ATTACK_POWER_SHORT" },
    }
    for _, row in ipairs(pairs_) do
        local loc = ShortPat(row[2])
        if loc then
            tinsert(tooltipStatNames, { key = row[1], name = loc })
        end
    end
    -- extra Chinese/English stems in case globals differ on Titan
    tinsert(tooltipStatNames, { key = "SP", name = L["法强"] })
    tinsert(tooltipStatNames, { key = "ARPEN", name = L["破甲"] })
    tinsert(tooltipStatNames, { key = "HASTE", name = L["急速"] })
    tinsert(tooltipStatNames, { key = "CRIT", name = L["暴击"] })
    tinsert(tooltipStatNames, { key = "HIT", name = L["命中"] })
    tinsert(tooltipStatNames, { key = "EXPERTISE", name = L["精准"] })
    tinsert(tooltipStatNames, { key = "DEFENSE", name = L["防御"] })
    tinsert(tooltipStatNames, { key = "MP5", name = "每5秒" })
end

local function ParseTooltipStats(item)
    if not tooltipStatNames then BuildTooltipNames() end
    local stats = {}
    if not BG.Tooltip_SetItemByID then return stats end
    BG.Tooltip_SetItemByID(item)
    if not BiaoGeTooltip then return stats end
    for i = 2, BiaoGeTooltip:NumLines() do
        local fs = _G["BiaoGeTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text ~= "" then
            local plus, name = text:match("^%+(%d+)%s*(.+)$")
            if plus and name then
                name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                for _, row in ipairs(tooltipStatNames) do
                    if name:find(row.name, 1, true) then
                        AddStat(stats, row.key, plus)
                        break
                    end
                end
            else
                local n = text:match("(%d+)")
                if n then
                    for _, row in ipairs(tooltipStatNames) do
                        if text:find(row.name, 1, true) and (text:find("提高", 1, true) or text:find("improves", 1, true) or text:find("Increases", 1, true) or text:find("increases", 1, true) or text:find("Equip:", 1, true) or text:find("装备", 1, true)) then
                            AddStat(stats, row.key, n)
                            break
                        end
                    end
                end
            end
            local armor = text:match("^(%d+)%s*" .. (ARMOR or "护甲"))
            if armor then
                AddStat(stats, "ARMOR", armor)
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
    return stats
end

local function MergeStats(a, b)
    for k, v in pairs(b) do
        AddStat(a, k, v)
    end
    return a
end

local function HasUsefulStats(stats)
    for k, v in pairs(stats) do
        if k ~= "SOCKET" and v and v ~= 0 then
            return true
        end
    end
end

local function ParseItemStats(itemID, link)
    if not itemID then return {} end
    if itemStatCache[itemID] then
        return itemStatCache[itemID]
    end
    local stats = ParseGetItemStats(link or itemID)
    if not HasUsefulStats(stats) then
        stats = MergeStats(stats, ParseTooltipStats(link or itemID))
    else
        -- fill DPS/armor/sockets if GetItemStats skipped them
        local extra = ParseTooltipStats(link or itemID)
        if extra.DPS and not stats.DPS then stats.DPS = extra.DPS end
        if extra.ARMOR and not stats.ARMOR then stats.ARMOR = extra.ARMOR end
        if extra.SOCKET and not stats.SOCKET then stats.SOCKET = extra.SOCKET end
    end
    itemStatCache[itemID] = stats
    return stats
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
    return allow[subclassID] and true or false
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
    return useful * highW + waste * highW * WASTE, useful, waste
end

local function ScoreStats(stats, w, db, ilvl, notes)
    db = db or GetDB()
    local caps = GetCaps(db)
    local r = playerSnap.ratings
    local score = 0
    local hitAmt = 0
    if db.role == "HEAL" or db.specType == "CASTER" then
        hitAmt = (stats.HIT or 0) + (stats.HIT_SPELL or 0)
        local s, useful, waste = CappedScore(hitAmt, r.hitSpell, caps.hitSpell, w.HIT)
        score = score + s
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "hitcap")
        elseif waste and waste > 0 then
            tinsert(notes, "hitpartial")
        end
    else
        local hitCur = db.specType == "RANGED" and r.hitRanged or r.hitMelee
        local s, useful, waste = CappedScore(stats.HIT, hitCur, caps.hitMelee, w.HIT)
        score = score + s
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "hitcap")
        elseif waste and waste > 0 then
            tinsert(notes, "hitpartial")
        end
    end
    if db.specType == "MELEE" or db.role == "TANK" then
        local s, useful, waste = CappedScore(stats.EXPERTISE, r.expertise, caps.expertise, w.EXPERTISE)
        score = score + s
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "expcap")
        elseif waste and waste > 0 then
            tinsert(notes, "exppartial")
        end
    end
    if db.role == "TANK" and db.isMT then
        local s, useful, waste = CappedScore(stats.DEFENSE, r.defense, caps.defense, w.DEFENSE)
        score = score + s
        if waste and waste > 0 and useful == 0 then
            tinsert(notes, "defcap")
        elseif waste and waste > 0 then
            tinsert(notes, "defpartial")
        end
    elseif stats.DEFENSE then
        score = score + (stats.DEFENSE or 0) * (w.DEFENSE or 0)
    end

    local skip = { HIT = true, HIT_SPELL = true, EXPERTISE = true, DEFENSE = true, SOCKET = true }
    for k, v in pairs(stats) do
        if not skip[k] and STAT_KEYS[k] then
            score = score + v * (w[k] or 0)
        end
    end
    if stats.SOCKET and stats.SOCKET > 0 then
        local p = w[w._primary or "STR"] or 1
        score = score + stats.SOCKET * SOCKET_GEM * p
    end
    if ilvl then
        score = score + ilvl * ILVL_W
    end
    return score
end

local function ScoreLink(link, itemID, w, db, notes)
    local name, itemLink, quality, ilvl, _, _, _, _, equipLoc, _, _, typeID = GetItemInfo(link or itemID)
    local stats = ParseItemStats(itemID, itemLink or link)
    return ScoreStats(stats, w, db, ilvl, notes or {}), stats, ilvl, equipLoc, typeID, itemLink or link
end

function BG.GearScore_RefreshPlayer()
    local r = playerSnap.ratings
    r.hitMelee = CombatRating(CR_HIT_MELEE)
    r.hitRanged = CombatRating(CR_HIT_RANGED)
    r.hitSpell = CombatRating(CR_HIT_SPELL)
    r.expertise = CombatRating(CR_EXPERTISE)
    r.defense = CombatRating(CR_DEFENSE_SKILL)
    wipe(playerSnap.equipped)
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        local id = GetInventoryItemID("player", slot)
        if link and id then
            local _, _, _, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
            playerSnap.equipped[slot] = {
                itemID = id,
                link = link,
                stats = ParseItemStats(id, link),
                ilvl = ilvl,
                equipLoc = equipLoc,
            }
        end
    end
end

function BG.GearScore_GetSnapshot()
    return playerSnap
end

local function ScoreSlot(slot, w, db)
    local eq = playerSnap.equipped[slot]
    if not eq then return 0, nil end
    return ScoreStats(eq.stats, w, db, eq.ilvl, {}), eq.link
end

local function CompareScore(equipLoc, w, db, itemID)
    local slots = SlotsForLoc(equipLoc)
    if not slots then
        return 0, nil
    end
    if UniqueEquipped(itemID, slots) and ItemIsUniqueEquip(itemID) then
        local s, link = ScoreSlot(slots[1], w, db)
        if #slots == 2 then
            local s2, link2 = ScoreSlot(slots[2], w, db)
            if GetInventoryItemID("player", slots[2]) == itemID then
                return s2, link2, "unique"
            end
        end
        if GetInventoryItemID("player", slots[1]) == itemID then
            return s, link, "unique"
        end
    end
    if equipLoc == "INVTYPE_2HWEAPON" then
        local s1, l1 = ScoreSlot(16, w, db)
        local s2, l2 = ScoreSlot(17, w, db)
        return s1 + s2, l1, nil, l2
    end
    if #slots == 2 then
        local s1, l1 = ScoreSlot(slots[1], w, db)
        local s2, l2 = ScoreSlot(slots[2], w, db)
        if s1 <= s2 then
            return s1, l1
        end
        return s2, l2
    end
    return ScoreSlot(slots[1], w, db)
end

local function ExchangeProducts(itemID)
    if not itemID or not BG.Loot or not BG.FBtable then return end
    for _, FB in ipairs(BG.FBtable) do
        local ex = BG.Loot[FB] and BG.Loot[FB].ExchangeItems
        if ex and ex[itemID] then
            return ex[itemID]
        end
    end
end

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
    if not typeID then
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
        result.suitable = false
        result.reason = "notgear"
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

    local notes = result.notes
    local newScore, stats = ScoreLink(itemLink or link, itemID, w, db, notes)
    result.newScore = newScore
    result.stats = stats
    if (equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_FINGER") and ItemHasProc(itemID, itemLink or link) then
        tinsert(notes, "proc")
    end

    local oldScore, oldLink, uniqueReason, oldLink2 = CompareScore(equipLoc, w, db, itemID)
    result.oldScore = oldScore or 0
    result.oldLink = oldLink
    result.oldLink2 = oldLink2
    if uniqueReason == "unique" then
        result.reason = "unique"
        result.upgrade = 0
        return result
    end
    result.upgrade = newScore - (oldScore or 0)
    return result
end

function BG.GearScore_Eval(link)
    if not link then return end
    local db = GetDB()
    local w = BuildWeights(db)
    local itemID
    if type(link) == "number" then
        itemID = link
    else
        itemID = GetItemID(link) or GetItemInfoInstant(link)
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
            local r = EvalOne(pid, pid, db, w)
            if r.suitable then
                if not best or r.newScore > best.newScore then
                    best = r
                    best.tokenItemID = pid
                    best.tokenFrom = itemID
                end
            end
        end
        if best then
            return best
        end
        local fail = EvalOne(itemID, link, db, w)
        fail.suitable = false
        fail.reason = fail.reason or "class"
        return fail
    end
    return EvalOne(itemID, link, db, w)
end

function BG.GearScore_Format(link, long)
    local r = BG.GearScore_Eval(link)
    if not r then
        return "", 0.5, 0.5, 0.5, r
    end
    if not r.suitable then
        return "×", 0.45, 0.45, 0.45, r
    end
    if r.reason == "unique" then
        return "=", 0.6, 0.6, 0.6, r
    end
    local u = Round1(r.upgrade)
    if u > 0 then
        local t = "+" .. u
        if long then t = L["推荐"] .. " " .. t end
        return t, 0, 1, 0, r
    elseif u < 0 then
        local t = tostring(u)
        if long then t = L["推荐"] .. " " .. t end
        return t, 0.7, 0.7, 0.7, r
    else
        return "=", 0.55, 0.55, 0.55, r
    end
end

local REASON_TEXT = {
    armor = L["不适合你的护甲类型"],
    weapon = L["不适合你的武器类型"],
    class = L["职业限定不含你"],
    unique = L["已装备唯一"],
    notgear = L["不是装备"],
}

local NOTE_TEXT = {
    hitcap = L["命中已达标，额外命中几乎不计"],
    hitpartial = L["命中仅缺口部分计入"],
    expcap = L["精准已达标，额外精准几乎不计"],
    exppartial = L["精准仅缺口部分计入"],
    defcap = L["防御已达标，额外防御几乎不计"],
    defpartial = L["防御仅缺口部分计入"],
    proc = L["特效未计入"],
}

function BG.GearScore_AddTooltip(tooltip, link)
    if not tooltip or not link then return end
    if BiaoGe.options.gearScore ~= 1 then return end
    local itemID = GetItemID(link) or GetItemInfoInstant(link)
    if not itemID then return end
    local _, _, _, _, _, _, _, _, _, _, _, typeID = GetItemInfo(link)
    if typeID ~= 2 and typeID ~= 4 then return end

    local text, r, g, b, ev = BG.GearScore_Format(link, true)
    tooltip:AddLine(" ")
    tooltip:AddLine(L["< BGLite 自身评分 >"], 0, 0.75, 1)
    if not ev then return end
    if not ev.suitable then
        tooltip:AddLine(REASON_TEXT[ev.reason] or L["不适合"], 1, 0.2, 0.2)
        tooltip:Show()
        return
    end
    if ev.reason == "unique" then
        tooltip:AddLine(L["已装备唯一"], 1, 0.82, 0)
        tooltip:Show()
        return
    end
    tooltip:AddDoubleLine(L["推荐"], text, 1, 0.82, 0, r, g, b)
    local newS = Round1(ev.newScore)
    local oldS = Round1(ev.oldScore)
    if ev.oldLink then
        tooltip:AddDoubleLine(format(L["掉落 %s"], newS), format(L["当前 %s"], oldS), 1, 1, 1, 0.7, 0.7, 0.7)
    else
        tooltip:AddDoubleLine(format(L["掉落 %s"], newS), L["当前栏位空"], 1, 1, 1, 0.7, 0.7, 0.7)
    end
    if ev.tokenItemID and ev.tokenItemID ~= ev.itemID then
        local n = GetItemInfo(ev.tokenItemID)
        if n then
            tooltip:AddLine(format(L["兑换为：%s"], n), 0.5, 0.8, 1)
        end
    end
    local db = GetDB()
    local labels = {
        STA = L["耐力"], DODGE = L["躲闪"], PARRY = L["招架"], HASTE = L["急速"],
        SP = L["法强"], CRIT = L["暴击"], SPI = L["精神"], INT = L["智力"],
        ARPEN = L["破甲"], AGI = L["敏捷"], STR = L["力量"],
    }
    if db.bias1 then
        tooltip:AddLine(format(L["主堆%s已加权"], labels[db.bias1] or db.bias1), 0.6, 0.6, 0.6)
    end
    for _, note in ipairs(ev.notes) do
        if NOTE_TEXT[note] then
            tooltip:AddLine(NOTE_TEXT[note], 0.6, 0.6, 0.6)
        end
    end
    tooltip:Show()
end

function BG.ScoreText(bt, link)
    if not bt then return end
    if not bt.scoreFrame then
        local f = CreateFrame("Frame", nil, bt)
        f:SetPoint("RIGHT", -20, 0)
        f.text = f:CreateFontString()
        f.text:SetFont(BIAOGE_TEXT_FONT, 11, "OUTLINE")
        f.text:SetPoint("RIGHT", 0, 0)
        f:SetSize(32, 20)
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
    local _, _, _, _, _, _, _, _, _, _, _, typeID = GetItemInfo(text)
    if typeID ~= 2 and typeID ~= 4 then
        local _, _, _, _, _, tID = GetItemInfoInstant(text)
        typeID = tID
    end
    if typeID ~= 2 and typeID ~= 4 then
        bt.scoreFrame:Hide()
        return
    end
    local short, r, g, b = BG.GearScore_Format(text)
    if short == "" then
        bt.scoreFrame:Hide()
        return
    end
    bt.scoreFrame.text:SetText(short)
    bt.scoreFrame.text:SetTextColor(r, g, b)
    local x = -20
    if bt.bindingTex and bt.bindingTex:IsVisible() then
        x = -28
    end
    bt.scoreFrame:ClearAllPoints()
    bt.scoreFrame:SetPoint("RIGHT", x, 0)
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
    if BG.GearScore_RefreshOptionsStatus then
        BG.GearScore_RefreshOptionsStatus()
    end
end

function BG.GearScore_UpdateAuctionFrame(bidFrame)
    if not bidFrame then return end
    if not bidFrame.scoreText then
        local parent = bidFrame.itemFrame or bidFrame
        local fs = parent:CreateFontString()
        fs:SetFont(BIAOGE_TEXT_FONT, 12, "OUTLINE")
        fs:SetJustifyH("LEFT")
        bidFrame.scoreText = fs
    end
    if BiaoGe.options.gearScore ~= 1 or BiaoGe.options.gearScoreAuction ~= 1 then
        bidFrame.scoreText:SetText("")
        return
    end
    local link = bidFrame.link or (bidFrame.itemFrame and bidFrame.itemFrame.link)
    if not link then
        bidFrame.scoreText:SetText("")
        return
    end
    local long = not bidFrame.IsSmallWindow
    local text, r, g, b = BG.GearScore_Format(link, long)
    bidFrame.scoreText:SetText(text)
    bidFrame.scoreText:SetTextColor(r, g, b)
    bidFrame.scoreText:ClearAllPoints()
    if bidFrame.IsSmallWindow then
        bidFrame.scoreText:SetFont(BIAOGE_TEXT_FONT, 11, "OUTLINE")
        if bidFrame.currentMoneyFrame then
            bidFrame.scoreText:SetPoint("RIGHT", bidFrame.currentMoneyFrame, "LEFT", -6, 0)
        else
            bidFrame.scoreText:SetPoint("RIGHT", bidFrame, "RIGHT", -50, 0)
        end
    else
        bidFrame.scoreText:SetFont(BIAOGE_TEXT_FONT, 12, "OUTLINE")
        local nameFS = bidFrame.itemFrame and bidFrame.itemFrame.itemNameText
        if nameFS then
            bidFrame.scoreText:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -1)
        else
            bidFrame.scoreText:SetPoint("TOPLEFT", bidFrame.itemFrame, "TOPLEFT", 40, -18)
        end
    end
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
    if db.userSet then return end
    local role, specType, isMT = GuessProfile()
    db.role, db.specType, db.isMT = role, specType, isMT and true or false
    db.bias1, db.bias2 = DefaultBias(role, specType)
end

BG.Init(function()
    player = BG.playerName or GetUnitName("player", true) or player
    realmID = BG.realmID or GetRealmID()
    if BiaoGe.options.gearScore == nil then BiaoGe.options.gearScore = 1 end
    if BiaoGe.options.gearScoreTable == nil then BiaoGe.options.gearScoreTable = 1 end
    if BiaoGe.options.gearScoreAuction == nil then BiaoGe.options.gearScoreAuction = 1 end
    GetDB()
end)

BG.Init2(function()
    ApplyGuessIfNeeded()
    BG.After(1.2, function()
        BG.GearScore_RefreshPlayer()
        playerSnap.scanned = true
        BG.UpdateAllGearScore()
    end)
end)

BG.RegisterEvent({
    "PLAYER_EQUIPMENT_CHANGED",
    "COMBAT_RATING_UPDATE",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_TALENT_UPDATE",
}, function(_, event)
    if event == "PLAYER_TALENT_UPDATE" then
        ApplyGuessIfNeeded()
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

-- Options tab widgets
function BG.GearScore_OptionsUI(parent)
    local db = GetDB()
    local width = 15
    local y = -10

    local function Header(text, yy)
        local t = parent:CreateFontString()
        t:SetFont(BIAOGE_TEXT_FONT, 15, "OUTLINE")
        t:SetPoint("TOPLEFT", width, yy)
        t:SetText(BG.STC_g1(text))
        return t
    end

    local name = "gearScore"
    BG.options[name .. "reset"] = 1
    local fEnable = ns.O.CreateCheckButton(name, L["启用自身装备评分"], parent, 15, y, {
        L["启用自身装备评分"],
        L["分数只针对你自己，不会同步给团队。命中/精准/防御达标后，超出部分几乎不计分。同职业选择不同偏向，会推荐不同装备。"],
    }, true, { BG.GearScore_OnSettingChanged })
    BG.options["button" .. name] = fEnable
    y = y - 30

    local name2 = "gearScoreTable"
    BG.options[name2 .. "reset"] = 1
    local fTable = ns.O.CreateCheckButton(name2, L["在表格装备格显示升级分"], parent, 15, y, {
        L["在表格装备格显示升级分"],
        L["在装备名右侧显示相对你当前同部位的升级分，例如 +23。"],
    }, true, { BG.GearScore_OnSettingChanged })
    BG.options["button" .. name2] = fTable
    y = y - 30

    local name3 = "gearScoreAuction"
    BG.options[name3 .. "reset"] = 1
    local fAuc = ns.O.CreateCheckButton(name3, L["在拍卖竞价窗显示升级分"], parent, 15, y, {
        L["在拍卖竞价窗显示升级分"],
        L["团长开拍时，竞价窗物品名下显示你的推荐升级分。"],
    }, true, { BG.GearScore_OnSettingChanged })
    BG.options["button" .. name3] = fAuc
    y = y - 28

    local tip = parent:CreateFontString()
    tip:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
    tip:SetPoint("TOPLEFT", width, y)
    tip:SetWidth(520)
    tip:SetJustifyH("LEFT")
    tip:SetTextColor(0.7, 0.7, 0.7)
    tip:SetText(L["分数只针对你自己，不会同步给团队。命中/精准/防御达标后，超出部分几乎不计分。同职业选择不同偏向，会推荐不同装备。"])
    y = y - 40

    ns.O.CreateLine(parent, y + 8)
    y = y - 8
    Header(L["自身状态"], y)
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
    y = y - 26

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
        statusLine:SetText(format("|c%s%s|r  %s %s   %s %.0f", color or "ffffffff", className, L["主属性"], primaryName, L["装等"], ilvl))

        local caps = GetCaps(db)
        local r = playerSnap.ratings
        local hitCur, hitCap, hitNeed
        if db.role == "HEAL" then
            hitLine:SetText(L["命中"] .. "：|cff808080" .. L["不需要"] .. "|r")
        elseif db.specType == "CASTER" then
            hitCur, hitCap, hitNeed = r.hitSpell, caps.hitSpell, true
            hitLine:SetText(format("%s：%s%d / %d|r  %s", L["命中"], CapColor(hitCur, hitCap, true), hitCur, hitCap,
                hitCur >= hitCap and L["达标"] or L["未达标"]))
        else
            hitCur = db.specType == "RANGED" and r.hitRanged or r.hitMelee
            hitCap = caps.hitMelee
            hitLine:SetText(format("%s：%s%d / %d|r  %s", L["命中"], CapColor(hitCur, hitCap, true), hitCur, hitCap,
                hitCur >= hitCap and L["达标"] or L["未达标"]))
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
    end
    BG.GearScore_RefreshOptionsStatus = RefreshStatus

    ns.O.CreateLine(parent, y + 8)
    y = y - 8
    Header(L["职责"], y)
    y = y - 26

    local roleButtons = {}
    local specButtons = {}
    local function PaintButtons(list, cur, field)
        for _, bt in ipairs(list) do
            if bt.key == cur then
                bt:GetFontString():SetTextColor(0, 1, 0)
            else
                bt:GetFontString():SetTextColor(1, 0.82, 0)
            end
        end
    end

    local dropBias1, dropBias2
    local function RefreshBiasDrops()
        db = GetDB()
        local opts = BG.GearScore_BiasOptions(db.role, db.specType, PrimaryFor(GetClassFile(), db.role, db.specType))
        local function labelOf(key, allowNone)
            if allowNone and (not key or key == "NONE") then
                return L["无"]
            end
            for _, o in ipairs(opts) do
                if o.key == key then return o.label end
            end
            return key or ""
        end
        if dropBias1 then
            LibBG:UIDropDownMenu_SetText(dropBias1, labelOf(db.bias1))
        end
        if dropBias2 then
            LibBG:UIDropDownMenu_SetText(dropBias2, labelOf(db.bias2, true))
        end
    end

    local function AfterRoleChange(resetBias, silent)
        db = GetDB()
        if not silent then
            db.userSet = true
        end
        if resetBias then
            db.bias1, db.bias2 = DefaultBias(db.role, db.specType)
        end
        PaintButtons(roleButtons, db.role)
        PaintButtons(specButtons, db.specType)
        if BG.GearScoreMTCheck then
            BG.GearScoreMTCheck:SetShown(db.role == "TANK")
            BG.GearScoreMTCheck:SetChecked(db.isMT)
        end
        if BG.GearScoreSpecRow then
            BG.GearScoreSpecRow:SetShown(db.role == "DPS")
        end
        if BG.GearScoreDWCheck then
            BG.GearScoreDWCheck:SetShown(db.role == "TANK" or db.specType == "MELEE")
        end
        RefreshBiasDrops()
        RefreshStatus()
        if not silent then
            BG.GearScore_OnSettingChanged()
            BG.PlaySound(1)
        end
    end

    local roles = {
        { key = "TANK", text = L["坦克"] },
        { key = "HEAL", text = L["治疗"] },
        { key = "DPS", text = L["输出"] },
    }
    for i, v in ipairs(roles) do
        local bt = BG.CreateButton(parent)
        bt:SetSize(70, 24)
        bt:SetPoint("TOPLEFT", width + (i - 1) * 80, y)
        bt:SetText(v.text)
        bt.key = v.key
        bt:SetScript("OnClick", function()
            db.role = v.key
            if v.key == "HEAL" then
                db.specType = "CASTER"
            elseif v.key == "TANK" then
                db.specType = "MELEE"
            end
            AfterRoleChange(true)
        end)
        tinsert(roleButtons, bt)
    end
    y = y - 32

    local specRow = CreateFrame("Frame", nil, parent)
    specRow:SetSize(400, 28)
    specRow:SetPoint("TOPLEFT", width, y)
    BG.GearScoreSpecRow = specRow
    local specs = {
        { key = "MELEE", text = L["近战"] },
        { key = "RANGED", text = L["远程物理"] },
        { key = "CASTER", text = L["法系"] },
    }
    for i, v in ipairs(specs) do
        local bt = BG.CreateButton(specRow)
        bt:SetSize(80, 24)
        bt:SetPoint("LEFT", (i - 1) * 90, 0)
        bt:SetText(v.text)
        bt.key = v.key
        bt:SetScript("OnClick", function()
            db.specType = v.key
            AfterRoleChange(true)
        end)
        tinsert(specButtons, bt)
    end
    y = y - 32

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
        db.userSet = true
        AfterRoleChange(false)
    end)
    BG.GearScoreDWCheck = dw
    y = y - 28

    MakeProfileCheck(L["法术命中按17%"], L["不勾选时按 14%（常见天赋减 3%）。"], db.spellHit17, function(self)
        db.spellHit17 = self:GetChecked() and true or false
        db.userSet = true
        AfterRoleChange(false)
    end)
    y = y - 30

    ns.O.CreateLine(parent, y + 8)
    y = y - 8
    Header(L["偏向"], y)
    y = y - 28

    local function MakeBiasDrop(which, x)
        local drop = LibBG:Create_UIDropDownMenu(nil, parent)
        drop:SetPoint("TOPLEFT", x, y)
        LibBG:UIDropDownMenu_SetWidth(drop, 110)
        LibBG:UIDropDownMenu_SetAnchor(drop, 0, 0, "TOP", drop, "BOTTOM")
        BG.dropDownToggle(drop)
        local title = drop:CreateFontString()
        title:SetPoint("BOTTOM", drop, "TOP", 0, 4)
        title:SetFont(BIAOGE_TEXT_FONT, 13, "OUTLINE")
        title:SetText(which == 1 and L["主偏向"] or L["次偏向"])
        LibBG:UIDropDownMenu_Initialize(drop, function()
            db = GetDB()
            local opts = BG.GearScore_BiasOptions(db.role, db.specType, PrimaryFor(GetClassFile(), db.role, db.specType))
            if which == 2 then
                local info = LibBG:UIDropDownMenu_CreateInfo()
                info.text = L["无"]
                info.func = function()
                    db.bias2 = "NONE"
                    db.userSet = true
                    LibBG:UIDropDownMenu_SetText(drop, L["无"])
                    BG.GearScore_OnSettingChanged()
                    BG.PlaySound(1)
                end
                info.checked = not db.bias2 or db.bias2 == "NONE"
                LibBG:UIDropDownMenu_AddButton(info)
            end
            for _, o in ipairs(opts) do
                local info = LibBG:UIDropDownMenu_CreateInfo()
                info.text = o.label
                info.func = function()
                    if which == 1 then
                        db.bias1 = o.key
                        if db.bias2 == o.key then db.bias2 = "NONE" end
                    else
                        db.bias2 = o.key
                    end
                    db.userSet = true
                    LibBG:UIDropDownMenu_SetText(drop, o.label)
                    RefreshBiasDrops()
                    BG.GearScore_OnSettingChanged()
                    BG.PlaySound(1)
                end
                info.checked = (which == 1 and db.bias1 == o.key) or (which == 2 and db.bias2 == o.key)
                LibBG:UIDropDownMenu_AddButton(info)
            end
        end)
        return drop
    end
    dropBias1 = MakeBiasDrop(1, 0)
    dropBias2 = MakeBiasDrop(2, 180)
    y = y - 50

    ns.O.CreateLine(parent, y + 8)
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

    AfterRoleChange(false, true)
    RefreshStatus()
    parent:HookScript("OnShow", function()
        BG.GearScore_RefreshPlayer()
        AfterRoleChange(false, true)
    end)
end
