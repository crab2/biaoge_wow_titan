# bg次bis版（泰坦时光服金团表格）

魔兽世界 **泰坦时光服**（`_classic_titan_`，Interface `38002`）用的金团插件：团本掉落后团长拍卖记账、对账、通报、分工资。

本仓库从游戏目录拷贝了现成的「纯净版」基础工程，作为后续开发起点。

## 来源

- 游戏内插件目录：`D:\World of Warcraft\_classic_titan_\Interface\AddOns\BGLite`
- 拷贝时间：2026-08-27
- 基础版本：`2.4.0`（TOC 标题：`<bg次bis版> bg次bis版纯净版`）
- 原作血统：金团表格 **BiaoGe** 的 Lite / 纯净裁剪版（作者标记 `CQZS (Lite)`）

## 文档

详细架构、数据模型、业务闭环、模块清单、裁剪对照、已知缺口，见：

- [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md) — **项目上下文（下一阶段开发必读）**

## 游戏内加载

开发时改本仓库，再同步回游戏插件目录：

```
D:\World of Warcraft\_classic_titan_\Interface\AddOns\BGLite
```

命令：

| 命令 | 作用 |
|---|---|
| `/bglite` `/gbg` `/biaoge` | 开关主表格 |
| `/bgo` | 打开设置 |
| `/bgm` | 解锁通知框位置 |

按键绑定：游戏设置里「打开/关闭表格」（`BIAOGE`）。

**不要与原版 `BiaoGe` 同时启用。** 两者共用全局表 `BG` 和存档 `BiaoGe`，后加载者会覆盖前者，导致功能失灵和账本交叉污染。

## 当前能力一句话

掉落自动入表 → ALT 开拍（内嵌拍卖窗，不再依赖外部 WA）→ 出价/倒计时/流拍 → 拍卖记录写账 → 交易自动记账 → 总收入/支出/人均工资 → 团队通报账单 / 流拍 / 消费 / 欠款。
