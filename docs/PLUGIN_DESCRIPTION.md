# bg次bis版 插件描述文件

本文档提供插件发布页可直接使用的三段 Markdown 文案。插件详情和更新公告均采用纯 Markdown 格式，可直接复制到支持 Markdown 的编辑器。

## 插件介绍（80字）

> bg次bis版 为泰坦时光服金团提供个人装备动态评分：结合你的天赋、属性、装等与绿字权重计算升级分，优先推荐真正适合、性价比高的装备，不盲追 BIS，更理性省金。

## 插件详情

### bg次bis版｜泰坦时光服金团表格

**bg次bis版** 是面向魔兽世界泰坦时光服的团队金团管理插件。它把“装备评估、掉落、开拍、成交、记账、对账、分账、交易”集中在一张可操作的表格里，帮助团长减少手工记录和重复沟通。

### 个人装备动态评分

插件不使用对所有人都一样的固定 GearScore，也不把“装等最高”直接等同于“最值得买”。它会读取你的职业、当前天赋、职责、已穿装备和实时属性，结合装备白字、绿字、插槽与装等，计算这件装备替换当前装备后的**个人升级分**。

- **按人计算：**同一件装备对近战、法系、治疗和坦克的分数不同；还会根据当前角色的属性缺口动态调整结果。
- **绿字优先看价值：**命中、精准、防御、破甲等门槛属性只计算未达标的有效缺口，达标后的溢出部分不再抬高分数；暴击、急速、攻强、法强等绿字按当前天赋权重计分。
- **装等只是组成部分：**装等会加分，但不会压过真正适合你的属性；插槽也会按主属性价值计入。
- **比较真实替换收益：**戒指、饰品、单手和双手武器会枚举可替换栏位，计算“换上之后比现在多多少”，而不是拿一件孤立的高分装备硬套所有人。
- **为性价比服务：**升级分用于判断“值不值得加价”。它帮助你识别便宜但提升扎实的装备，避免为了所谓 BIS 为低边际收益装备支付过高金价。

#### 装备分数公式（Lua 风格）

```lua
local function EffectiveAmount(stat, amount, profile, current)
  local cap = CapFor(stat, profile)
  if cap then
    return math.min(amount, math.max(0, cap - CurrentRating(stat, current)))
  end
  return amount
end

local function StatScore(stat, amount, profile, current)
  if not IsAllowedStat(stat, profile) then
    return 0
  end
  local key = NormalizeStat(stat)
  local value = EffectiveAmount(key, amount, profile, current)
  return value * (profile.weights[key] or 0)
end

local function GearScore(item, profile, current)
  local white, green = 0, 0
  for stat, amount in pairs(item.stats or {}) do
    local part = StatScore(stat, amount, profile, current)
    if IsWhiteStat(NormalizeStat(stat)) then
      white = white + part
    else
      green = green + part
    end
  end

  local socket = (item.emptySockets or 0) * 16
      * (profile.weights[profile.primary] or 1)
  local ilvl = (item.itemLevel or 0) * 0.15
  return {
    total = white + green + socket + ilvl,
    white = white, green = green, socket = socket, ilvl = ilvl,
  }
end

local function UpgradeScore(candidate, equipped, profile, current)
  local baseline = RemoveEquippedStats(current, equipped)
  local newScore = GearScore(candidate, profile, baseline).total
  local oldScore = 0
  for _, oldItem in ipairs(equipped) do
    oldScore = oldScore + GearScore(oldItem, profile, baseline).total
  end
  return newScore - oldScore
end
```

其中 `profile.weights` 优先使用当前角色的自定义 EP，其次使用职业/天赋默认权重，再使用通用回退权重；不适合当前属性学派的属性权重为 0。界面显示的“+N”就是 `UpgradeScore` 四舍五入后的结果，正数代表值得考虑，负数代表换上后反而不划算。该分数是个人升级参考，不是全团统一排名，也不是永久有效的 BIS 证明。

### 核心功能

- **掉落自动入表：**监听团本掉落，按当前 Boss 自动归类，支持品质筛选、黑白名单和可堆叠物品数量记录。
- **内嵌团队拍卖：**团长或物品分配者可通过 Alt+点击装备开拍，设置起拍价、时长和重置阈值；团队成员在拍卖窗内出价，结束后自动播报成交或流拍。
- **账单与工资计算：**记录买家、成交价和欠款，自动汇总总收入、补贴支出、净收入、分钱人数及人均工资，并支持抹零设置。
- **交易与欠款辅助：**交易时显示拍卖成交信息，辅助放置装备和填写金额；欠款可单独标记，便于后续追踪。
- **团队通报与对账：**可向团队通报账单、流拍、消费和欠款，并接收团队表格数据进行金额核对。
- **工资发放辅助：**保留交易记录和邮件记录，支持批量整理工资发放信息，减少结算阶段的重复操作。

### 快速开始

1. 将插件目录放入 `Interface\AddOns\BGLite`，在角色选择界面启用 bg次bis版。
2. 进入团队后使用 `/bglite`、`/gbg` 或 `/biaoge` 打开主表格。
3. 团长或物品分配者使用 Alt+点击表格中的装备开始拍卖；团员安装插件后即可在拍卖窗内出价。
4. 拍卖结束后检查买家、金额和欠款标记，再使用表格中的通报、对账和交易工具完成结算。

### 适用范围

目标客户端为魔兽世界经典怀旧服泰坦时光服（`_classic_titan_`，Interface 38002），默认副本为熔火之心。数据保存在本地 SavedVariables，不会自动上传账本或角色资料。

### 使用须知

- 请勿与原版 BiaoGe 同时启用。两个插件共用全局表和 `BiaoGe` 存档，可能造成界面覆盖或账本交叉污染。
- 内嵌拍卖需要团队成员加载 bg次bis版，才能完整接收拍卖消息并参与出价。
- 插件以团长实际操作为最终结算依据；语音、口头出价和游戏外转账不属于自动记账范围。

## 更新公告

### v2.4.0｜泰坦时光服金团流程稳定版

本次更新围绕泰坦时光服的金团主流程和个人装备性价比评估整理插件体验，让团长可以在同一张表格中完成从拾取装备到发放工资的日常操作。

### 本次更新

- 适配泰坦时光服客户端（Interface 38002），内置泰坦副本、Boss 和掉落数据。
- 加入个人装备动态评分：按职业、天赋、职责、当前属性、绿字权重和装等计算替换升级分。
- 命中、精准、防御、破甲等门槛属性按当前缺口计分，达标后的溢出属性不再误导加价决策。
- 在表格和拍卖窗显示升级分及白字/绿字构成；物品 Tooltip 保持紧凑，不追加 bg次bis版自身评分，帮助玩家优先选择高性价比装备，不必盲目追求 BIS。
- 整合掉落自动入表、内嵌拍卖、成交记录、账单汇总、欠款标记和工资计算。
- 完善团队账单、流拍、消费和欠款通报，以及团队数据接收和金额对账。
- 补齐交易记录、邮件记录和工资发放辅助流程，降低结算阶段的手工操作量。
- 清理不必要的外部挂载和过度角色数据采集，保留本地账本和团队内通信所需的数据。

### 升级提示

升级前建议备份 SavedVariables。请确认已关闭原版 BiaoGe，避免两个插件同时加载造成存档冲突。已有 `BiaoGe` 账本会继续沿用当前存档名称。

### 已知事项

部分泰坦副本掉落数据仍在持续完善，奥杜尔及少数世界 Boss 的物品可能需要团长手动调整到杂项或指定行；这不会影响手工记账、拍卖和工资汇总流程。
