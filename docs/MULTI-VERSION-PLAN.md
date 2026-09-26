# 多版本 / 多加载器方案

本文回答一个问题：把 TFC Food Port 编译到 **1.20.1 至今的所有热门版本、所有加载器**，实际需要做什么。

结论先说：**这不是一次改动，而是一个独立工程**。下面是具体的阻塞点、可以复用的部分、以及建议的推进顺序。

---

## 1. 现实边界

### 1.1 数据源（TFC）只在两个版本存在

本仓库的全部内容（食物、作物、贴图、配方数值）来自 TerraFirmaCraft。已核实当前使用的 jar：

```
META-INF/neoforge.mods.toml
  modLoader    = "javafml"
  modId        = "tfc"
  license      = "EUPL-1.2"
  minecraft    versionRange = [1.21.1]
  neoforge     versionRange = [21.1.234,)
```

也就是说：

| MC 版本 | TFC 是否存在 | 本模组如何取得数据 |
| :--- | :--- | :--- |
| 1.20.1 | 存在（**Forge** 版，另一份 jar） | 需要**重新提取**一份 TFC 1.20.1 数据 |
| 1.21.1 | 存在（**NeoForge** 版，即当前这份） | 直接复用 |
| 1.21.2 及以后 | **不存在** | 只能从 1.21.1 数据搬运（26.1.2 就是这么做的） |

1.21.1 → 26.1.2 的搬运已经完成且验证通过。**再往前做新版本，数据侧是"照搬 + 适配"，成本主要在 API；往前做 1.20.1，则要额外重新提取一份 TFC 数据。**

### 1.2 三个加载器是三套 API

| | NeoForge | Forge | Fabric |
| :--- | :--- | :--- | :--- |
| 入口 | `@Mod` 构造注入 | `@Mod` | `ModInitializer` |
| 注册 | `DeferredRegister` | `DeferredRegister`（Forge 包） | `Registry.register(...)` 直接调用 |
| 事件 | `IEventBus` / `@EventBusSubscriber` | `MinecraftForge.EVENT_BUS` | `ServerLifecycleEvents` 等回调 |
| 流体 | 26.x 是 `ResourceHandler<FluidResource>`；更早是 `IFluidHandler` | `IFluidHandler`（Forge） | **Transfer API**（`FluidStorage`，又一套） |
| 数据包条件 | `neoforge:conditions` / `neoforge:mod_loaded` | `forge:conditions` / `forge:mod_loaded` | `fabric:load_conditions` / `fabric:all_mods_loaded` |
| 元数据 | `neoforge.mods.toml` | `mods.toml` | `fabric.mod.json` |

**Fabric 不是"适配"，是另写一遍。** 尤其是大桶的流体存储：26.x 的那套 `ResourceHandler` / `FluidStacksResourceHandler` 在 Fabric 上完全不存在，必须用 `FluidStorage` 重写。

### 1.3 Java 版本随版本变

| MC | Java |
| :--- | :--- |
| 1.20.1 | 17 |
| 1.21.1 | 21 |
| 26.1.2 | 25（当前） |

---

## 2. 本仓库的版本耦合面（已实测统计）

### 2.1 Java：20 个文件，15 个版本敏感

| 文件 | 版本敏感点 |
| :--- | :--- |
| `TFCFoodPort.java` | `Identifier`（26.x 改名，旧为 `ResourceLocation`） |
| `BarrelBlock.java` | 流体能力 |
| `BarrelBlockEntity.java` | **26.x transfer API**、能力、`ValueInput/ValueOutput` 序列化 |
| `TFCCapabilities.java` | **26.x transfer API**、能力 |
| `TFCBlocks.java` | `DeferredRegister` + 原版方块 |
| `TFCItems.java` / `TFCCreativeTabs.java` / `TFCComponents.java` | `DeferredRegister`、数据组件 |
| `FoodValues.java` | **食物双组件（1.21.2 拆分）** |
| `TFCLeavesBlock.java` / `TFCBerryBushBlock.java` / `TFCPalmFruitBlock.java` | 数据包 codec |
| `Berry.java` | `TreeGrower`、`ResourceKey` |
| `TFCFoodPortGameTests.java` | 几乎全部 + Gametest API |
| **`TFCCropBlock.java`** | 无 |
| **`Crop.java`** | 无 |
| **`Mooncake.java`** | 无（只用 `Holder<MobEffect>`、`MobEffects`） |
| **`PlantableFruitItem.java`** | 无 |
| **`WaterConvertibleItem.java`** | 无 |

**好消息**：`Food` / `Crop` / `Mooncake` / `Berry` 这几个"数据枚举"基本是纯数据（`Food.java` 里对 `FoodProperties` 的引用只在 javadoc 里）。**数值表、作物阶段数、月饼口味与效果、树的形状参数都是跨版本可复用的**，不需要为每个版本重写。

### 2.2 资源：跨版本可复用与必须分版本的部分

| 资源 | 数量 | 跨版本 |
| :--- | :--- | :--- |
| 贴图 `textures/**` | 428 | ✅ **完全可复用** |
| 方块状态 `blockstates/**` | 56 | ✅ 基本可复用 |
| 方块模型 `models/block/**` | — | ✅ 基本可复用 |
| **物品模型定义 `assets/<ns>/items/**`** | **210** | ❌ **1.21.4 才引入这一层**，1.20.1 / 1.21.1 必须删掉，改为在 `models/item/` 内解析 |
| **配方 `recipe/**` | **272** | ❌ 格式 + 条件键 + 第三方字段名都随版本变 |
| 战利品表 `loot_table/**` | 59 | ⚠️ 部分函数是 1.20.5+（如 `copy_components`） |

**配方的三层版本差异**（这是最费时的部分）：

1. **原版材料写法**：1.21.2 起是字符串（`"minecraft:melon"`），之前是对象（`{"item": "..."}` / `{"tag": "..."}`）
2. **条件键**：`neoforge:conditions` / `forge:conditions` / `fabric:load_conditions` 三者互不相通
3. **第三方字段名**：农夫乐事自己的配方格式在 1.20.1 与 1.21.2 之间变过；森罗物语是较新的模组，**是否支持旧版本需要核实**

---

## 3. 目标矩阵

"热门版本"按整合包基座取，实务上通常只要这几个：

| MC | NeoForge | Forge | Fabric |
| :--- | :--- | :--- | :--- |
| 1.20.1 | — | ★ 必做 | ★ 必做 |
| 1.21.1 | ★ 必做 | ★ | ★ |
| 1.21.4 / 1.21.5 | ○ | — | ○ |
| 26.1.2 | ✅ **已完成** | — | — |

★ = 整合包基座，优先；○ = 次要；— = 该加载器在此版本没有实际生态（Forge 事实上停在 1.21.1）

合计约 **8~10 个目标**，每个都需要：Gradle 配置 + 注册层 + 资源格式转换 + 实机试玩。

---

## 4. 建议的架构

单一源码树无法同时满足 8~10 个目标。建议改为 **Gradle 多模块**：

```
settings.gradle
  :common                    <- 纯数据与平台无关逻辑
                                 Food / Crop / Mooncake / Berry 枚举
                                 数值表、掉落规则表、配方"意图"
                                 生成脚本产出的中间数据（tsv）
  :neoforge:26.1.2           <- 当前这份（已完成）
  :neoforge:1.21.1
  :fabric:1.21.1
  :forge:1.20.1
  ...
```

`common` 里放**数据**，不放 API 调用：枚举、数值、每个配方的"意图"（输入 → 输出 → 用哪类机器）。各平台模块负责把"意图"翻成该版本的落地形式（注册、JSON、能力）。

生成脚本也要相应改造：目前 `gen-recipes.ps1` 直接把 26.1.2 的 JSON 写进 `src/main/resources`。多版本后应改为**先产出与格式无关的配方表**，再由每个平台模块渲染成对应格式。

---

## 5. 建议顺序

按"性价比 / 风险"排序，每一步都是可发布、可验证的独立增量：

1. **NeoForge 1.21.1**（推荐从这里开始）
   - 与现有代码差异最小：同一份 TFC 数据、同一加载器、同样有 `IFluidHandler`（比 26.x 的 transfer API 更常见）
   - 主要工作：食物退回单组件 `FoodProperties`（1.21.2 之前的形态）、注册 API 的旧写法、配方 JSON 退回对象写法、删掉 210 个 `items/` 定义
   - 这是**验证"多模块架构是否成立"的最低成本试金石**

2. **Forge 1.20.1**
   - 额外工作：重新提取一份 TFC 1.20.1 数据（贴图路径可能不同）；Forge 能力体系；Java 17

3. **Fabric 1.21.1**
   - 最大的一块：注册、事件、流体存储全部重写；`fabric:load_conditions`
   - 需要核实农夫乐事 / 森罗物语的 Fabric 版本及其配方格式

4. 1.21.4 / 1.21.5 与其余版本按需追加

---

## 6. 需要你决定的事

不同起点的做法差别很大，所以我需要一个方向再动手：

- 若从 **NeoForge 1.21.1** 开始：可以先把 `common` 模块抽出来，风险低，且能验证架构
- 若从 **Fabric** 开始：需要**先设计平台抽象层**，改动面大得多，但一次解决加载器维度
- 若只想要 **1.20.1（整合包最主流）**：那就只做 Forge 1.20.1，不引入多模块，最快但后续每加一个版本都要重来

另外请确认：是否允许**改动现有 26.1.2 的结构**（拆成多模块）？这会影响已发布的 `v1.0.0`，我倾向于新开分支或在模块化时保持 26.1.2 的产物完全一致。
