# bg次bis版 项目上下文

> 给下一阶段开发用的工程说明书。基于 2026-08-27 从游戏目录拷入本仓库的 `bg次bis版 2.4.0` 源码通读整理。
>
> 源路径：`D:\World of Warcraft\_classic_titan_\Interface\AddOns\BGLite`
> 工作副本：`D:\workplace-xq\biaoge_wow_titan\BGLite`

---

## 1. 项目定位

### 1.1 要做什么

面向 **魔兽世界泰坦时光服** 的团队金团插件。核心场景：

1. 团本 Boss 出装备后，**物品分配者 / 团长** 开拍
2. 成交价、买家、欠款写入当前副本表格
3. 汇总总收入、补贴支出、分钱人数，算出人均工资
4. 把账单 / 流拍 / 消费排名 / 欠款通报到团队
5. 交易、邮件辅助收款和发工资

说明书原文把本版本定位为「国服运营安全清理后的纯净过渡版，不再新增功能」。这是**基础工程的官方口径**，不是我们后续产品的上限。用户目标是：**在此基础上继续开发，功能不限于拍卖记账分工资。**

### 1.2 血统与约束

| 项 | 事实 |
|---|---|
| 前身 | 金团表格 `BiaoGe`（完整版，功能远多于当前） |
| 当前形态 | `bg次bis版` 纯净裁剪 + 2026-08-24/25 部分功能回补 |
| TOC 名 | `bg次bis版`（插件 ID 仍为 `BGLite`） |
| 存档名 | **`BiaoGe`**（与原版同名，账号级 SavedVariables） |
| 全局表 | **`BG = {}`**（与原版同名，硬重置） |
| 共存 | **禁止与原版 BiaoGe 同时启用**；启动后 `PLAYER_ENTERING_WORLD` 检测并弹窗，不自动禁用对方 |
| 硬核服 | `C_GameRules.IsHardcoreActive()` 为真时多数模块直接 `return`（暴雪 UI 控件数量限制） |

后续改名、改存档键、改全局表，都要当成破坏性迁移来设计。现阶段继续沿用 `BiaoGe` 存档，才能读玩家已有账本。

### 1.3 目标客户端

判定在 `Core/DB/Init.lua`：

```text
interface = select(4, GetBuildInfo())
IsWLK     = 30000 ≤ interface < 40000
IsTitan   = IsWLK 且 interface ≥ 38000
```

TOC 显式包含 **`38002`**。泰坦时光服走这条分支：

- `BG.IsTitan = true`
- `BG.onlyOneHard = true`（无 10/25、普通/英雄切换，掉落只用 `"N"`）
- 默认当前副本 `BG.FB1 = "MCtitan"`
- 满级 `80`

同一份源码仍保留 Vanilla / SoD / TBC / WLK80 / CTM / MoP / Retail 的副本表和掉落库。对泰坦服而言，那些分支在运行时不会 `AddDB`，但文件仍会加载（尤其是各版本 `DB_Loot_*.lua` 和超大的 `LibRecipes-3.0.lua`）。

---

## 2. 仓库结构

```text
biaoge_wow_titan/
├── README.md
├── docs/PROJECT_CONTEXT.md     ← 本文件
└── BGLite/                     ← 游戏可直接加载的插件根
    ├── BGLite.toc
    ├── Bindings.xml            ← 不进 TOC，WoW 自动读
    ├── Templates.xml           ← 输入框模板
    ├── Core/
    │   ├── DB/                 ← 版本探测、存档初始化、副本/Boss/掉落
    │   ├── FBUI/               ← 表格格子生成
    │   ├── TongBao/            ← 账单/流拍/消费/欠款通报
    │   ├── Module/             ← 拍卖、拾取、交易、对账…
    │   ├── BiaoGe.lua          ← 主窗口、Tab、斜杠命令
    │   ├── Options.lua         ← 游戏设置面板
    │   ├── function1.lua       ← 通用工具
    │   └── function2.lua       ← UI 工具 + Lite 空壳
    ├── Locales/                ← zhCN / zhTW / enUS
    ├── Libs/                   ← LibStub / AceComm / DropDown / Glow / DBIcon…
    └── Media/                  ← 图标、Boss 模型图、语音包
```

Lua/XML 约 75 个业务文件，合计约 **3.4 万行业务 Lua**（不含 Libs）。最大单文件：

| 文件 | 约行数 | 角色 |
|---|---|---|
| `Locales/zhCN.lua` | 2883 | 文案 |
| `Core/Options.lua` | 2660 | 设置页 |
| `Core/function2.lua` | 2505 | 工具 + 空壳 |
| `Core/Module/Trade.lua` | 2820 | 交易记账 |
| `Core/BiaoGe.lua` | 1885 | 主界面 |
| `Core/Module/Loot.lua` | 1682 | 掉落入表 |
| `Core/Module/Auction.lua` | 1568 | 开拍 UI |
| `Core/DB/DB.lua` | 1404 | 存档/副本布局 |
| `Core/DB/DB_Loot_Titan.lua` | 1442 | 泰坦掉落 |

`Libs/LibRecipes-3.0.lua` 约 1 万行，Lite 里装备库 UI 已删，这份配方库基本闲置。

---

## 3. 加载顺序与生命周期

### 3.1 TOC 顺序（决定初始化依赖）

```text
Locales → Templates.xml → Libs/embeds.xml → Core/DB/DB.xml
→ function1.lua → function2.lua → Core/FBUI/FBUI.xml
→ Receive.lua → DuiZhang.lua
→ TongBao/*（账单/流拍/消费/欠款/频道）
→ BiaoGe.lua
→ ClearBiaoGe / Loot / AuctionMSG / Auction / AuctionLog
→ AuctionWA / AuctionWAEvent
→ Trade / TradeHistory / MailHistory / SendMail
→ QuickAccounting / ItemTooltip / ItemLib / hooks
→ minimap.lua → Options.lua
```

**磁盘上有、但不进 TOC、运行时不加载：**

- `Core/Module/History.lua`
- `Core/FBUI/HistoryUIfunction.lua`

历史表格、保存当前表、分享当前表的 UI 因此全部失效。`BG.SaveBiaoGe` 只定义在未加载的 `History.lua` 里。

### 3.2 生命周期钩子（`Init.lua`）

| 钩子 | 事件 | 用途 |
|---|---|---|
| `BG.Init(fn)` | `ADDON_LOADED` 且 addon=`BGLite` | 建存档、建主 UI |
| `BG.Init2(fn)` | 首次 `PLAYER_ENTERING_WORLD` | 进世界后逻辑（共存检测、预加载掉落） |
| `BG.Init3(fn)` | `PLAYER_LOGIN` | 登录时 |
| `BG.RegisterEvent(event\|tbl, fn)` | 任意；`COMBAT_LOG` 会展开 | 统一事件总线，内部 `securecall` |

几乎所有模块顶部都有：

```lua
if BG.IsBlackListPlayer then return end
```

硬核服会让整模块变成空文件。

### 3.3 命名空间习惯

```lua
local AddonName, ns = ...
BG = BG or {}          -- 全局，被 Init.lua 先建
ns.L                   -- 本地化
ns.LibBG               -- 下拉菜单库 BiaoGe-LibUIDropDownMenu-4.0
ns.Maxb / ns.Maxi / ns.Maxt / ns.BossNum
```

拍卖运行时另有全局 **`BGA`**（`BGA.Frames`、`BGA.aura_env`），这是从 WeakAuras 内嵌进来的拍卖窗，协议前缀仍叫 `BiaoGeAuction`。

---

## 4. 架构总览

```text
┌─────────────────────────────────────────────────────────────┐
│  输入                                                      │
│  掉落聊天 / 拾取窗 / 背包 ALT / 聊天链接 ALT / 交易窗 / 邮件 │
└──────────────┬──────────────────────────────────────────────┘
               ▼
┌─────────────────────────────────────────────────────────────┐
│  当前表格 BiaoGe[FB].bossN                                  │
│  列：装备 zhuangbei  买家 maijia  金额 jine  欠款 qiankuan  │
│  段：Boss1..N → 杂项 → 罚款 → 支出 → 总览/工资              │
└──────────────┬──────────────────────────────────────────────┘
               │
     ┌─────────┼─────────┬──────────────┐
     ▼         ▼         ▼              ▼
  拍卖窗WA   拍卖记录   对账/接收     通报 TongBao
  (BGA)     auctionLog  duizhang      账单/流拍/消费/欠款
     │         │
     └────┬────┘
          ▼
  交易自动记账 / 批量邮寄工资
          ▼
  总收入 − 总支出 = 净收入
  人均工资 = 净收入 / 分钱人数（可抹零）
```

没有服务端、没有 AceDB。状态几乎全部在 SavedVariables `BiaoGe` + 运行时 `BG.*`。团内同步靠 `C_ChatInfo.SendAddonMessage`（**不用 AceComm 封装**，尽管库已嵌入）。

---

## 5. 当前表格数据模型

### 5.1 格子几何

每个副本 `FB` 有一套独立 UI 和独立存档。`AddDB(FB, width, height, maxt, maxb, bossNumTbl, …)` 决定：

- `Maxt[FB]`：列数（通常 3，NAXX 类 4）
- `Maxb[FB]`：**罚款段的下标**（真实 Boss 数 + 杂项）
- `Maxi[FB][b]`：每个 Boss 段的行数
- 末尾再追加：支出行数（默认 8/20）、总览 5 行

`DB_BossName.lua` 的 `Addother()` 在真实 Boss 后追加固定四段：

| 段 | 下标 | 默认名 | 行数 |
|---|---|---|---|
| 真实 Boss | `1 … Maxb-2` | 各 Boss | `Maxi[FB][b]` |
| 杂项 | `Maxb-1` | 杂项 | 同上，可滚动 |
| 罚款 | `Maxb` | 罚款 | `BG.Maxi`（40） |
| 支出 | `Maxb+1` | 支出 | 20，绿色 |
| 总览+工资 | `Maxb+2` | 总览 / 工资 | **固定 5 行** |

工资 5 行写死：

1. `总收入` ← 所有 Boss+杂项+罚款金额之和（`BG.GetTotalIncome`）
2. `总支出` ← 支出段之和（`BG.GetTotalExpenditure`）
3. `净收入` = 总收入 − 总支出
4. `分钱人数`（**唯一可手改**）
5. `人均工资` ← `净收入 / 人数`；`BiaoGe.options.moLing==1` 时 `math.modf` 抹零，否则两位小数

支出默认预填：`T补贴` / `N补贴` / `DPS补贴`（WLK 另加 `放鱼补贴`）。名称里写 `12%` 会按总收入自动算金额（选项 `zhichuPercent`）；写 `8人` 会提示人均。

### 5.2 一行的存档字段

路径：`BiaoGe[FB]["boss"..b][<字段>..i]`

| 字段 | 含义 |
|---|---|
| `zhuangbei{i}` | 装备链接或支出名称 |
| `maijia{i}` | 买家名 |
| `jine{i}` | 金额 |
| `qiankuan{i}` | 欠款金额（有值则显示欠款钮） |
| `guanzhu{i}` | 关注标记 |
| `loot{i}` | 拾取日志 `{time, player, class, count, itemID}` 数组 |
| `itemLevel{i}` / `bindOnEquip{i}` | 装等 / 装绑 |
| `class{i}` `level{i}` `realm{i}` `color{i}` | 买家身份（现采） |

已停止采集并一次性迁移删除的行级字段：`guild{i}` `raceID{i}` `guid{i}` `factionGroup{i}`（guid 是账号级唯一标识，不应长期留在账本）。

每个副本还有：

```text
BiaoGe[FB].tradeTbl      -- 打包交易：一组格子引用
BiaoGe[FB].auctionLog    -- 自动拍卖记录
BiaoGe[FB].raidRoster    -- { time, realm, roster = {name...} } 击杀时快照
BiaoGe[FB].leaderInfo    -- 团长信息（Lite 已不再采集付费 AI 数据）
```

### 5.3 根级 SavedVariables（常用）

```text
BiaoGe = {
  FB, lastFrame, NotifyChannel, font,
  options = { scale, alpha, autoLoot, autoTrade, autoAuction*, …, SearchHistory },
  point = { 各可拖动框 GetPoint },
  duizhang = { 对账快照… },
  Auction = { gen, mod, duration, resetThreshold, money, fastMoney, aotoSendLate },
  Hope[realmID][player][FB],          -- 心愿；UI 已空，结构仍初始化
  playerInfo[realmID][player],
  tradeHistory, mailHistory, sendMail,
  History, HistoryList,               -- Lite 零读写，禁止自动清空（防误删原版账本）
  [FB] = { boss1.., tradeTbl, auctionLog, raidRoster }
}
```

`BiaoGe.GearScore[realmID][player]` 和
`BiaoGe.FilterClassItemDB[realmID][player]` 仅用于当前客户端的装备建议与
职业过滤，不参与团队/平台排名，也不会通过插件消息自动上传。设置页的
「重置配置」是用户主动操作，会整体清空 `BiaoGe` 并重载；删除角色数据
`BG.DeletePlayerData` 同时覆盖这两个本机域。后续字段变更须使用
`BG.Once(name, dt, fn)` 做兼容迁移，不能在登录时静默删除用户账本。

小地图按钮用 `LibDBIcon:Register(AddonName, plugin, BiaoGe)`，**把整个存档根当 db**，`minimapPos` / `hide` / `lock` 会写在 `BiaoGe` 根上。

`BG.Once(name, dt, fn)` 用 `BiaoGe.options.SearchHistory[name..dt]=true` 做一次性迁移脚本开关。

---

## 6. 泰坦时光服副本清单

默认当前本：`MCtitan`。难度只有 N。

| FB 代码 | 阶段 | instanceID | 人数 | 内容 |
|---|---|---|---|---|
| `Worldtitan` | — | **-100**（伪地图） | 40 | 世界 Boss：蓝龙 / 卡扎克 / 末日行者 / 末日领主卡扎克 / 四绿龙 |
| `MCtitan` | P1 | 409 | 25 | 熔火之心 |
| `SSCtitan` | P2 | 548 + **550 风暴要塞** 占 boss7–10 | 25 | 「毒蛇风暴」双本 |
| `NAXXtitan` | P3 | 533 + OS 615 + EOE 616 | — | 纳克萨玛斯 + 黑曜石圣殿 + 永恒之眼 |
| `TOCtitan` | P4 | **309 祖格** + **649 十字军** boss11–15 | 25 | 「P4双本」 |
| `SWtitan` | P5 | **568 祖阿曼** + **580 太阳井** boss8–13 | 25 | 「P5双本」 |
| `ULDtitan` | P6 | 603 | 25 | 奥杜尔 |

Boss 名、颜色、杂项/罚款/支出/总览追加：`Core/DB/DB_BossName.lua` 的 Titan 段。

EncounterID：`Core/DB/DB_EncounterID.lua`。击杀后用 `BG.GetBossIndexByBossID` 把掉落记到对应格子；45 秒内再进战斗仍记该 Boss，超时回杂项。

掉落表：`Core/DB/DB_Loot_Titan.lua`（文件头 `if not BG.IsTitan then return end`）。

```text
BG.Loot[FB].N["boss"..n] = { itemID, ... }
BG.Loot[FB].N["boss"..n.."other"]  -- 兑换成品等
BG.Loot[FB].ExchangeItems[兑换物ID] = { 成品ID... }
BG.Loot[FB].N.Quest / Currency / Faction / Profession / WorldBoss / Team / Shop
```

黑白名单：`DB_Loot_BlackWhiteList.lua` Titan 分支。

- `blacklist`：不记账
- `whitelist`：强制记账
- `zaXiangItems`：强制进杂项
- `stackItems` / `noStackItems`：堆叠策略
- `itemToBoss`：把隐藏 Boss / 限时宝箱物品钉到指定行（TOCtitan / SWtitan）

**已知掉落缺口：**

- `ULDtitan`：**格子、Boss 名、EncounterID 都有，掉落表完全没有**。自动拾取无法按表归位，只能进杂项或靠白名单。
- `Worldtitan` boss5–8（四绿龙）掉落数组是 `{}`。
- `Worldtitan` boss9 也是空数组。

图标资源已有对应目录：`Media/icon/MCtitan` `SSCtitan` `NAXXtitan` `SWtitan` `TKtitan` `ZAMtitan` `ZUGtitan` 等。

---

## 7. 核心业务闭环

### 7.1 掉落入表（`Loot.lua`）

1. `CHAT_MSG_LOOT` 解析系统拾取句（自己/他人、多件、额外掷骰）
2. 过滤：品质 ≥ `BG.lootQuality[FB]`（泰坦默认 4 史诗）、黑白名单、交易/商店/任务 0.5 秒内自己获得的不记
3. 当前 Boss 格由 `ENCOUNTER_START/END` 决定；失败或超时写入杂项 `Maxb[FB]-1`
4. 空格子写入 `zhuangbei{i}`，屏幕上方 `BG.FrameLootMsg` 飘字
5. 可堆叠物品：已有同 ID 则改成 `链接xN`

团长/分配者还可：拾取窗一键分配给自己（橙片/任务物除外）、部分祖格区域自动降分配品质。

### 7.2 开拍（`Auction.lua` + `AuctionWA*.lua`）

仅 **团长或物品分配者**（`BG.IsML`）。

入口：

- ALT + 点击表格装备 / 背包 / 聊天链接 / 拾取格
- 拍卖记录「开始拍卖」「一键重拍」
- 选项 `autoAuctionStart==1` 才响应 ALT（可用 `notAlt` 强制）

起拍窗可改：起拍价、时长（默认 40 秒）、数量 1–9、第二代重置阈值（默认 20 秒，不能低于 10）。

并发上限 **10** 件。多件间隔 1 秒发 addon 消息。

协议两代：

| 代 | 前缀 | 分隔 | 载荷 |
|---|---|---|---|
| Gen1 | `BiaoGeAuction` | `,` | `StartAuction,{GetTime()},{itemID},{money},{duration},,{mod},{link}` |
| Gen2 | `BiaoGeAuction1..10` 轮询 | `^` | 同上 + `resetThreshold`；另有 Pause/Resume |

两代消息都由 `Auction.lua:BG.SendStartAuctionMsg` 发出，接收路径统一为
`AuctionWAEvent.lua` 的 `CHAT_MSG_ADDON`：Gen1 使用 `BiaoGeAuction`，Gen2
使用并轮询 `BiaoGeAuction1..10`。字段顺序固定为：`opcode, auctionID,
itemID, money, duration, player, mod, link[, resetThreshold]`；Gen1 的
`player` 是空字段，Gen1 不携带重置阈值并使用默认 20 秒。接收端会校验
数值字段、拒绝未知/匿名模式，并对无效消息静默丢弃；重复 `auctionID`
由拍卖窗去重。这样一代旧客户端、二代新客户端及混合团队均能继续收到
拍卖开始消息。

`BiaoGe.Auction.mod` 只保留 **`normal`**。`roll` / `anonymous` 启动时强制改回；收到匿名 `StartAuction` **静默丢弃**。

全团 `AuctionWAEvent` 收到后建竞拍窗（最多 20 扇）。团长喊 `RAID_WARNING`：`{rt1}拍卖开始{rt1} {link} 起拍价：{money}`。

### 7.3 出价与结束

团员在窗里加价，addon 消息 `SendMyMoney^{auctionID}^{money}`。

- 最小加价档 `wa.MiniMoneyTbl`（当前价越高，加价步长越大）
- 按钮 CD 1 秒
- 剩余 ≤ 重置阈值且有人出价 → 计时拉回阈值（Gen2）
- 剩余 ≤ 3 秒出价会自曝「卡秒」并播 `tooLate`
- **`remaining <= -0.5` 才结算**（防卡秒）
- 自动出价：锁心理价，被超后延迟再加一档（泰坦默认延迟约 1.5s）

结束由**各客户端本地**判定，团长负责喊话：

- 成功：`{rt6}拍卖成功{rt6} {link} {买家} {金额}`
- 流拍：`{rt7}流拍{rt7} {link}`
- 取消：`CancelAuction` → `{rt7}拍卖取消{rt7}`

然后 `BG.AuctionWAEnd(endType, …)` 写入 `BiaoGe[FB].auctionLog`。

口头出价**不进协议**，只进 `AuctionMSG` 聊天记录框。成交价以拍卖窗最高价为准。

### 7.4 写账的三条路径

1. **自动账单**（`AuctionLog.lua` `CreateBillByAuctionLog`）：非 ML 且 `autoCreateBill==1` 时，拍卖结束后把成功记录填进表格空买家格。也可按按钮「生成表格账单」（会先清空已有买家/金额再回填）。
2. **团长自购弹窗** `BG.SaveRLAuction`：自己拍到自己的装，选「记账」或「记为欠款」。
3. **快速记账**（`QuickAccounting.lua`）：**非 ML** 右键聊天物品链接，选买家和金额。

成交后交易窗可按拍卖记录自动放装备、填金额、标欠款（`autoAuctionMoney` 等选项）。退货可广播 `BiaoGe2 RefundAuctionToFailed^…` 把成功记录改回流拍。

### 7.5 分工资与通报（`TongBao/`）

主表右下按钮链：`账单 | 流拍 | 消费 | 欠款 | 频道▼`

统一经 `BG.SendMsgToRaid`：每 0.3 秒发 2 条，频道 `BiaoGe.NotifyChannel`（RAID/GUILD/SAY/YELL）。连续 5 次聊天限流则停发。Boss 战时不发。

| 按钮 | 内容 |
|---|---|
| 账单 | 按 Boss 列出装备+买家+金额；罚款合计；支出；总览；人数；人均；**小队工资 = 人均 × 5** |
| 流拍 | 有装备、买家空、金额空 |
| 消费 | 按买家汇总金额，降序 |
| 欠款 | 按人汇总 `qiankuan`；可选把欠款者挪到 7/8 队 |

账单在 RAID 频道时，2 秒后额外发 addon：`BiaoGe` / `DuiZhang-{买家}-{itemID 金额,}`，给队友对账识别打包交易。

### 7.6 对账（`DuiZhang.lua`）

监听团队频道里的金团表格 / RaidLedger / 大脚账单，以及上述 addon 包，存进 `BiaoGe.duizhang[]`。底部「对账」Tab：我的金额 vs 对方金额。可「复制对方账单」覆盖当前金额（对方若也是 bg次bis版 还会带买家）。

默认保留 24 小时（选项 `duiZhangTime`）。

### 7.7 交易与邮寄

- `Trade.lua`：打开交易预览、自动把拍卖成交装备放上去、成交后写表格或记罚款/退货。团内广播 `tradeTo-<name>` / `tradeEnd` 提示「团长正在交易」。
- `TradeHistory.lua`：独立交易流水，默认保留 7 天。**底部 Tab 已隐藏**（2026-08-25），逻辑仍在。
- `MailHistory.lua`：收发件记录。底部 Tab **可见**。
- `SendMail.lua`：邮箱「批量」页按模板给全团发工资。泰坦发送间隔 **1.5 秒**（其它版本 0.5 秒），规避 20 人/小时限制。选项 `enableSendMail`，改完需重载。

---

## 8. 模块清单

### 8.1 已加载、承担业务

| 模块 | 路径 | 职责 |
|---|---|---|
| 启动/版本 | `Core/DB/Init.lua` | `BG` 表、版本旗标、Init 钩子 |
| 前缀/Tooltip | `Core/DB/Init2.lua` | 注册 `BiaoGe`/`BiaoGe2`/`BiaoGeWorldBoss`；绑定名 |
| 存档/副本布局 | `Core/DB/DB.lua` | SavedVariables 初始化、FB 几何、声音表 |
| Boss 名 | `DB_BossName.lua` | 每段标题和颜色 |
| Encounter | `DB_EncounterID.lua` | 击杀→格子 |
| 泰坦掉落 | `DB_Loot_Titan.lua` | 只在 `IsTitan` 时执行 |
| 黑白名单 | `DB_Loot_BlackWhiteList.lua` | 拾取过滤 |
| 格子生成 | `FBUI/CreateFBUI.lua` + `FBUIfunction.lua` | 装备/买家/金额/底色/工资公式 |
| 对账格子 | `DuiZhangUIfunction.lua` | 只读对比列 |
| 接收格子 | `ReceiveUIfunction.lua` | 别人分享的只读表 |
| Boss 模型 | `Model.lua` | 选项 `model` |
| 主窗 | `BiaoGe.lua` | Tab、副本条、倒数、斜杠 |
| 设置 | `Options.lua` | 表格 / 自动拍卖 / 其他功能 三页 |
| 清空 | `ClearBiaoGe.lua` | 左下清空；进本自动清 |
| 拾取 | `Loot.lua` | 自动入表、一键分配 |
| 拍卖聊天框 | `AuctionMSG.lua` | 过滤团队聊天留出价 |
| 开拍 | `Auction.lua` | 起拍 UI、发协议、版本条 |
| 拍卖账本 | `AuctionLog.lua` | 成功/流拍/未拍/生成账单 |
| 拍卖窗 | `AuctionWA.lua` + `AuctionWAEvent.lua` | 内嵌竞拍运行时 |
| 交易 | `Trade.lua` | 自动记账 |
| 交易流水 | `TradeHistory.lua` | 独立历史（Tab 隐藏） |
| 邮件流水 | `MailHistory.lua` | 独立历史 |
| 批量邮寄 | `SendMail.lua` | 发工资 |
| 快速记账 | `QuickAccounting.lua` | 团员右键聊天链接 |
| 物品提示 | `ItemTooltip.lua` | 兑换装对照 |
| 掉落预热 | `ItemLib.lua` | **只预加载 Titan itemID，无 UI** |
| tooltip 钩 | `hooks.lua` | 欠款/罚款、背包已拍状态 |
| 小地图 | `minimap.lua` | LDB 图标 |
| 接收分享 | `Receive.lua` | 前缀 `BiaoGeReceive1..10` |
| 对账逻辑 | `DuiZhang.lua` | 解析频道账单 |
| 通报 | `TongBao/*` | 见 7.5 |

### 8.2 空壳 / 故意短路（防旧调用崩）

`function2.lua` 开头 `Lite stubs for deleted modules`：

- `BG.ItemLibUI` / `RoleOverviewUI` / `FilterClassItemUI` → 空
- `BG.IsHope` → 恒 `false`
- `BG.IsSetBestPriceKeyDown` / `BG.UpdateEditBorderColor` → 空（原付费模块 BGV）
- `BG.SetFBCD` **被改写成开关主表格**（原版是角色总览 / 副本 CD）
- `BG.ItemLibMainFrame:IsShown()` 恒 false

注意：`LootFilterClassItem`、`UpdateAllFilter` 在 stub 之后**又有真实实现**，后定义覆盖前定义。`UpdateMoLingButton` 在 `BiaoGe.lua` 里再次定义，覆盖 stub。

### 8.3 未加载（文件在磁盘）

| 文件 | 原职责 | 现状 |
|---|---|---|
| `Core/Module/History.lua` | 历史表格列表、保存、分享、`SaveBiaoGe` | 不进 TOC |
| `Core/FBUI/HistoryUIfunction.lua` | 历史只读格子 | 不进 FBUI.xml |

存档键 `BiaoGe.History` / `HistoryList` 仍可能从原版遗留；Lite **禁止自动清空**，以免误删。

### 8.4 明确删除、不再恢复的原版能力（注释与 Options 列出）

- 角色总览、站位图、装备库 UI、InfoBar（在线人数）
- 查询记录 / 一键指定 / 一键举报 / 贸易局 / 血月 / 商品总览
- 匿名拍卖、Roll 点模式、内嵌 WeakAuras 导出字符串
- 第三方付费 BGV：最佳价格、CP 货币记账、输入框边框着色
- 模块禁用按钮 UI（只留空表 `disabledModules`）
- 玩家黑名单、战网角色查询
- 跨插件读 `BiaoGeAccounts` 历史成交价

Locale 里仍残留对应字符串，属于死文案。

---

## 9. 插件通信一览

全部 `C_ChatInfo.SendAddonMessage`，RAID / GUILD / WHISPER。

| 前缀 | 用途 |
|---|---|
| `BiaoGe` | 版本 `MyVer-` / `VersionCheck`；交易 `tradeTo` / `tradeEnd`；对账 `DuiZhang-`；重拍 `ReAuction^` |
| `BiaoGe2` | 提醒拍卖 `RemindAuction^`；退货 `RefundAuctionToFailed^` |
| `BiaoGeAuction` | Gen1 拍卖 |
| `BiaoGeAuction1..10` | Gen2 拍卖（轮询抗聊天限流） |
| `BiaoGeReceive` + `1..10` | 分享表格（压缩 + Base64，包在 `!BIAOGE! … !END!`） |
| `BiaoGeWorldBoss` | **只注册，Lite 无消费者** |

聊天可见标记：

- `{rt1}拍卖开始{rt1}`
- `{rt6}拍卖成功{rt6}`
- `{rt7}流拍{rt7}` / `{rt7}拍卖取消{rt7}`
- 密语交易通报前缀：`bg次bis版: `（原版是 `BiaoGe: `）

团员插件版本：`BG.raidBiaoGeVersion[name]`。部分请求要求对方 ≥ v2.0.0 / v2.0.7。拍卖窗本身要求全团安装本插件（或旧流程的拍卖 WA）；Lite 已去掉「密语发送 WA 字符串」入口。

**已知协议空洞：** `GetAuctioning` 只发不收，中途进团看不到进行中的拍卖。

---

## 10. 命令、按键、设置页

### 10.1 斜杠

| 命令 | 作用 |
|---|---|
| `/bglite` `/gbg` `/biaoge` | 开关 `BG.MainFrame` |
| `/bgo` | 打开设置并关闭主窗 |
| `/bgm` | `BG.Move()` 解锁通知框 |

Locale 残留 `/bgre` `/bgmap` `/BGR` 等，**代码未注册**。

### 10.2 按键

`Bindings.xml` 只声明 `BIAOGE`（开关主表）。原版 `RoleOverview` 故意不声明。`Init2.lua` 仍有 `BINDING_NAME_RoleOverview` 字符串，无对应 Binding。

小地图：左键开关主表，右键设置，中键等同 `SetFBCD`（现在也是开关主表）。

### 10.3 主窗口 Tab

| 编号 | 文案 | 状态 |
|---|---|---|
| 1 | 表格 | 默认 |
| 4 | 对账 | 2026-08-24 恢复入口 |
| 101 | 交易记录 | **创建后 Hide，并从锚点链摘掉** |
| 102 | 邮件记录 | 可见 |

顶部是副本切换条 `BG.ButtonMCtitan` 等。泰坦 `onlyOneHard`，难度下拉不出现。

操作习惯（说明书）：

- 右键输入框清空（5 秒内可点「撤销删除」）
- ALT+装备：ML 开拍，团员关注
- 右键聊天装备：ML 自动倒数，团员快速记账
- Shift+链接插入聊天或格子

### 10.4 设置页 keys（开发时不要随便改名）

**表格页：** `scale` `alpha` `bg` `editFontSize` `font` `mainIcon*` `autoLoot` `lootTime` `lootFontSize` `autolootNotice` `autolootRemind` `autoTrade` `tradeTime` `tradeFontSize` `tradeNotice` `tradePreview` `isTrading` `NDuiOpenBag` `auctionHigh` `auctionHighTime` `HighOnterItem` `auctionChat` `auctionChatHoldNew` `countDown*` `fastCount*` `guoqiRemind*` `autoQingKong` `retainExpenses*` `QingKongPeople` `MaxPlayers*` `buttonSound` `tipsSound` `Sound` `autoAdd0` `duiZhangTime` `zhichuPercent` `NumFrame` `model` `ignore` `mouseFK` `miniMap` `addonsOutTime`；主界面勾选 `moLing`。

**自动拍卖页：** `autoAuctionScale` `autoAuctionFrameLevel`；存 `BiaoGe.Auction.*`；勾选 `autoAuctionStart/Put/Money/QianKuan/SetMoney/SureClick/LogLink/HappySay/AutoEndTips/Fold/Up` `autoCreateBill` `autoShowTradeCopyMoney` `aotoSendLate`（拼写即少一个 u）`auctionMoveByShift`。泰坦不显示 `autoAuctionHappySay`。

**其他功能：** `joinorleavePlayercolor` `allLootToMe` `autoAllLootToMe` `autoSetLootNum`（泰坦）`showCurrencyCount` `ERR_CHAT_THROTTLED` `enableSendMail` `tradeSuccessSound` `tradeFalseSound` `tradeMSG*`。

「重置配置」会 `BiaoGe = nil` 再 Reload，**整份存档清空**。

---

## 11. UI 与格子交互（改表格时必看）

格子在 `FBUIfunction.lua` 创建，引用存在 `BG.Frame[FB]["boss"..b]["zhuangbei"..i]` 等。

- 装备格宽 140，支出/总览格宽 235；买家/金额各 90
- 改装备文本会同步对账格、写存档、刷新过滤/关注/装等图标
- 改金额会刷新工资三格
- 底色三层：悬停 / 焦点 / 团长正在拍卖的高亮（`BG.FrameDs[FB..1|2|3]`）
- 打包交易悬停显示「打包交易」绿框（`tradeTbl`）
- `BG.PairFBItem(fn)` 遍历当前表所有格子，通报和对账都靠它

主窗口：`BG.MainFrame`，可拖动，右下角缩放写入 `options.scale`（0.5–1.5）。边框/标题条用玩家职业色。

---

## 12. 本地化

加载：`zhCN.lua` → `zhTW.lua` → `enUS.lua`。

`zhCN.lua` 先建 `ns.L` 元表（缺键返回 key），非 zhTW/enUS 客户端填 `ns.instructionsText`，再列出全部中文 key（值 `true`）。其它语言把中文 key 映射成译文。

新功能文案：**先在 `Locales/zhCN.lua` 加 key**，三语都要补，否则英文客户端会直接显示中文句子。

说明书强调「纯净版不再新增功能」——若产品方向改为继续增强，说明书和标题 `bg次bis版-biaoge纯净版` 需要一起改，避免玩家误解。

---

## 13. 媒体与语音

- 图标：`Media/icon/icon.tga`（小地图 / TOC IconTexture）
- Boss 模型图：`Media/icon/<副本>/bN.png` `mN.png`
- 语音包：`Media/sound/AI/*.mp3`，作者 ID `"AI"`，可被带 `X-BiaoGe-Voice` 元数据的外部插件扩展
- 常用音效 ID：`paimai` `qingkong` `biaogefull` `qiankuan` `tradeSuccess` `tradeFalse` `auctionError` `tooLate` `auctionTopPrice` `autoAuctionAutoEndTips` …

选项 `tipsSound` 总闸，`Sound` 选作者。

---

## 14. 已知问题、缺口、开发风险

### 14.1 功能缺口（相对「金团日常够用」）

1. **历史表格未加载** — 不能保存/回看往期账本。文件还在，接回 TOC + FBUI.xml 并恢复按钮即可，但要处理与原版共用存档。
2. **ULDtitan 无掉落表** — P6 奥杜尔自动入表会大量进杂项。
3. **四绿龙掉落为空** — 世界 Boss 页后四个 Boss。
4. **中途进团看不到进行中的拍卖** — `GetAuctioning` 无应答。
5. **交易记录 Tab 被摘掉** — 流水还在记，只是没入口。
6. **装备库 / 心愿 / 职业过滤 UI 已删** — 过滤函数还在，没有配置界面；`IsHope` 恒 false，心愿高亮不会亮。
7. **分享表格按钮随 History 一起没了** — `Receive.lua` 仍能收别人发来的表。

### 14.2 工程风险

1. **全局 `BG` + 存档 `BiaoGe` 与原版冲突** — 任何「改名插件」都要做存档迁移。
2. **无测试框架** — 没有单元测试；改协议必须双开或组队验证。
3. **`securecall` 吞错** — `Init`/`RegisterEvent` 里的异常可能静默失败。
4. **拼写债务当 API 用了** — `StartAucitonFrame`、`aotoSendLate`、`serachEdit`、`Auciton`。改名会丢存档/选项。
5. **`function2.lua` stub 与后文真实现叠在一起** — 改过滤/装备库时先分清哪段会被覆盖。
6. **多版本掉落库全量加载** — 泰坦客户端仍解析 Vanilla/WLK/CTM/MoP/Retail 的 `DB_Loot_*.lua`（文件头有版本 `return`，解析成本仍在）。`LibRecipes-3.0.lua` 极大且 Lite 无消费者。
7. **注释里的 `docs/07` `docs/09`** — 指向某次裁剪设计文档，**本仓库没有这些文件**。
8. **暴雪插件限制** — 硬核服已放弃；经典服 addon 消息长度、聊天限流、每小时邮件人数都已在代码里打补丁，新功能不要绕过。

### 14.3 安全/合规（纯净版已经做过的）

- 去掉内嵌 WA 长字符串（著作权不清）
- 去掉 guid 等过度采集
- 去掉付费模块挂载点
- 匿名拍卖关闭
- 密语品牌改为 `bg次bis版:`

后续加「上传账单到网站」「自动举报」一类能力，需要单独过合规，不要直接从原版拷回来。

### 14.4 拍卖协议回归测试矩阵

提交前至少用双客户端或模拟 `CHAT_MSG_ADDON` 事件覆盖以下组合：

| 发送方 | 接收方 | 核验点 |
|---|---|---|
| Gen1 | Gen1 / Gen2 | `BiaoGeAuction`、逗号字段、空 `player`、默认 20 秒阈值 |
| Gen2 | Gen1 / Gen2 | `BiaoGeAuction1..10` 轮询、`^` 字段、重置阈值 |
| 任一 | 任一 | 重复 `auctionID` 只创建一个窗口 |
| 任一 | 任一 | 缺字段、非数字金额/时长、负数和未知模式静默丢弃 |

每组还应验证单件、多件（1 秒间隔）、重拍和暂停/恢复；不同版本组合
不得因为一条异常消息阻断后续正常拍卖。

---

## 15. 开发约定（建议下一阶段遵守）

1. **先在本仓库改，再同步到** `Interface\AddOns\BGLite`，避免游戏目录和 git 分叉。
2. 新模块按 TOC 现有风格追加，文件头保留 `if BG.IsBlackListPlayer then return end`。
3. 存档只扩展，不改已有键名；破坏性迁移用 `BG.Once(name, yymmdd, fn)`。
4. 团内协议优先走已有前缀；新 opcode 加在 `BiaoGe2` 或新前缀，并做版本号门槛。
5. 泰坦专属逻辑用 `if BG.IsTitan then`，不要改坏其它版本分支（即便暂时不发布那些版本）。
6. UI 改动后至少验证：开表、切副本、ALT 开拍、成交写账、清空、通报、重载后数据还在。
7. 不要与原版 BiaoGe 同时加载来「对照」——会把存档写乱。对照请用备份的 `WTF/Account/.../SavedVariables/BiaoGe.lua`。

---

## 16. 下一阶段可以从哪里下手

按「金团主路径是否完整」排序，而不是按代码量：

| 优先级 | 事项 | 说明 |
|---|---|---|
| P0 产品 | 确认产品名、是否继续叫「纯净版」、说明书口径 | 现在文案与「继续开发」矛盾 |
| P0 数据 | 补 `ULDtitan` 掉落 + 绿龙掉落 | 否则 P6 / 世界 Boss 自动记账不可用 |
| P1 主路径 | 决定是否接回历史表格 | 文件现成，差 TOC 和入口按钮 |
| P1 主路径 | 中途进团同步进行中的拍卖 | 补 `GetAuctioning` 应答 |
| P1 UX | 交易记录 Tab 是否恢复 | 逻辑已在 |
| P2 聚焦 | 泰坦专用加载：跳过非 Titan 掉落库、删/懒加载 LibRecipes | 减内存、减维护面 |
| P2 体验 | 装备库 / 心愿是否要做泰坦精简版 | 现有 ItemLib 只预热缓存 |
| P3 | 与原版存档冲突的长期方案 | 改 SavedVariables 名或检测后只读迁移 |

主路径（掉落 → 拍卖 → 记账 → 分钱 → 通报 → 交易/邮寄）**已经打通**，不是从零做金团插件。下一阶段是：补泰坦数据、接回被裁但团长仍需要的能力、把「纯净维护版」转成「泰坦金团正式产品」。
