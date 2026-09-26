# 1.21.1 移植笔记

从 26.1.2 模块移植到 NeoForge 21.1.251 时，**已从反编译源码核实**的 API 差异。

核实方法：`gradlew :versions:neoforge-1.21.1:createMinecraftArtifacts` 会生成完整参考源码（5364 个源文件），
从 `~/.gradle/caches/neoformruntime/intermediate_results/decompile_*.jar` 读取。**不要凭记忆写** —— 下面每一条
都是查出来的，因为猜错的代价是一次完整的编译往返。

---

## 食物（这是最大的一处）

26.1.2 起食物拆成**两个数据组件**，1.21.1 是**一个**。

### 1.21.1

```java
// net/minecraft/world/food/FoodProperties.java
public record FoodProperties(
    int nutrition, float saturation, boolean canAlwaysEat, float eatSeconds,
    Optional<ItemStack> usingConvertsTo, List<FoodProperties.PossibleEffect> effects)
{
    public static class Builder {
        public FoodProperties.Builder nutrition(int);
        public FoodProperties.Builder saturationModifier(float);
        public FoodProperties.Builder alwaysEdible();
        public FoodProperties.Builder fast();                       // 0.8s 进食
        public FoodProperties.Builder effect(MobEffectInstance, float probability);
        public FoodProperties.Builder usingConvertsTo(ItemLike);    // 碗/瓶子返还，在这里！
        public FoodProperties build();
    }
    public record PossibleEffect(MobEffectInstance effect, float probability) { ... }
}
```

- `Item.Properties.food(FoodProperties)` —— **单参数**
- **没有** `Consumable` / `Consumables` / `ApplyStatusEffectsConsumeEffect`
- 状态效果走 `Builder.effect(...)`，**概率为 float**
- 碗返还走 `Builder.usingConvertsTo(...)`
- 饱和度由 `FoodConstants.saturationByModifier(nutrition, saturationModifier)` 算出

### 26.1.2（现状，供对照）

```java
properties.food(FoodValues.properties(food), FoodValues.consumable());
// 效果在 Consumable 上：Consumables.defaultFood().onConsume(new ApplyStatusEffectsConsumeEffect(effects, 1.0F))
// 碗返还：properties.usingConvertsTo(Items.BOWL)  <- Item.Properties 上
```

### 结论

`FoodValues` 要改成返回**单个** `FoodProperties`，把效果与 `usingConvertsTo` 都塞进去；
`TFCItems` 里 `properties.food(props, consumable)` → `properties.food(props)`，
并把 `usingConvertsTo` 从 `Item.Properties` 移到 `FoodProperties.Builder`。

---

## 方块交互：**返回类型不同**（关键）

第一版这节写的是「没变」——**错了**，已由编译器推翻。真正的问题在于我当时只读了 `BlockBehaviour` 里
**public** 的重载，就以为 protected 的签名也一样。protected 的那两个在 1.21.1 就是：

```java
// net/minecraft/world/level/block/state/BlockBehaviour.java
protected ItemInteractionResult useItemOn(ItemStack, BlockState, Level, BlockPos, Player, InteractionHand, BlockHitResult);
protected InteractionResult useWithoutItem(BlockState, Level, BlockPos, Player, BlockHitResult);
```

写错返回类型时报的是
`useItemOn(...) in TFCCropBlock cannot override useItemOn(...) in BlockBehaviour`
——**不是**一个显眼的类型不匹配，很容易被误读成「签名对不上」。

### `InteractionResult` 在 1.21.1 是枚举

```java
SUCCESS, SUCCESS_NO_ITEM_USED, CONSUME, CONSUME_PARTIAL, PASS, FAIL
```

26.1.2 用的两个常量**不存在**，映射如下：

| 26.1.2 | 1.21.1 `ItemInteractionResult` | 1.21.1 `InteractionResult` |
| :--- | :--- | :--- |
| `TRY_WITH_EMPTY_HAND` | `PASS_TO_DEFAULT_BLOCK_INTERACTION` | `PASS` |
| `SUCCESS` | `SUCCESS` | `SUCCESS` |
| `SUCCESS_SERVER` | `SUCCESS` | `SUCCESS` |

`ItemInteractionResult` 常量：`SUCCESS, CONSUME, CONSUME_PARTIAL, PASS_TO_DEFAULT_BLOCK_INTERACTION, SKIP_DEFAULT_BLOCK_INTERACTION, FAIL`

（注意 `ItemInteractionResult` 里**没有** `TRY_WITH_EMPTY_HAND`，别把两个枚举的常量混着用。）

---

## 其它已核实的差异

| 项 | 1.21.1 | 26.1.2 | 状态 |
| :--- | :--- | :--- | :--- |
| 属性拼写 | **`noCollission()`** | `noCollision()` | ✅ 已改 `TFCBlocks` |
| 浆果丛基类 | **`BushBlock`** | `VegetationBlock` | ✅ 已改 `TFCBerryBushBlock` |
| 植被标签 | **`BlockTags.DIRT`** | `BlockTags.SUPPORTS_VEGETATION` | ✅ 已改 |
| 物品描述前缀 | **`Item.Properties` 上不存在** | `useItemDescriptionPrefix()` / `useBlockDescriptionPrefix()` | ✅ 已删 |
| 标识符 | `ResourceLocation` | `Identifier` | ✅ 全量替换 |
| 方块实体序列化 | `(CompoundTag, HolderLookup.Provider)` | `(ValueInput)` / `(ValueOutput)` | ✅ 已改 `BarrelBlockEntity` |
| 流体 | `IFluidHandler` + `FluidTank` | `ResourceHandler<FluidResource>` + `FluidStacksResourceHandler` | ✅ 已改 |
| 物品流体能力 | `Capabilities.FluidHandler.ITEM` + `stack.getCapability(...)` | `Capabilities.Fluid.ITEM` + `ItemAccess.forStack(...)` | ✅ 已改 |
| 流体交互 | `FluidUtil.interactWithFluidHandler(player, hand, level, pos, side)` | 带事务的版本 | ✅ 已改 |
| 组件输入 | `applyImplicitComponents(DataComponentInput)` | 同名 | ✅ 已改 |
| 配方管理器 | `level.getRecipeManager()` | `level.recipeAccess()` | ⏳ 游戏测试里要改 |
| **`LeavesBlock` 构造器** | **单参 `LeavesBlock(Properties)`** | `LeavesBlock(float, Properties)` | ⏳ `TFCLeavesBlock` 里 `super(0.01F, props)` 的 float 要去掉 |
| **`MobEffects` 常量名** | `MOVEMENT_SPEED` / `JUMP` / `DIG_SPEED` / `DAMAGE_RESISTANCE` / `DAMAGE_BOOST` | `SPEED` / `JUMP_BOOST` / `HASTE` / `RESISTANCE` / `STRENGTH` | ⏳ `Mooncake` 里 5 处 |
| **`getCloneItemStack`** | 签名不同 | `(LevelReader, BlockPos, BlockState, boolean)` | ⏳ `TFCBerryBushBlock:165` |
| **`TFCPalmFruitBlock`** | `cannot find symbol` + `List` 类型不兼容 | — | ⏳ 待逐条看错误 |
| **`DeferredRegister` 注册方法** | 见下 | — | ⏳ 待核 |

### `DeferredRegister`（1.21.1）

```java
public <B extends Block> DeferredBlock<B> registerBlock(String, Function<BlockBehaviour.Properties, ? extends B>, BlockBehaviour.Properties);
```

`registerBlock` / `registerItem` / `registerSimpleBlockItem` 都在。`TFCBlocks`（7 处）与 `TFCItems`（2 处）报的
`no suitable method found for register...` 需要看**完整错误文本**才能定性。最可能的原因：1.21.1 的第三个参数是
`BlockBehaviour.Properties` 实体，而 26.1.2 接受 Supplier，本项目传的是 `TFCBlocks::bushProperties`（无参方法引用）。

**存在且可用**（已核实）：`LeavesBlock`、`SaplingBlock`、`CropBlock`、`CocoaBlock`、`TreeGrower`。
`LeavesBlock` 在 1.21.1 **没有** `spawnFallingLeavesParticle` 这个抽象方法 —— 覆写已删。

---

## 资源层

好消息是**比我原先写的工作量小**。以下每一条都是查出来的，不是推断的。

### 不需要改的

| 资源 | 证据 |
| :--- | :--- |
| **配方目录名** | 1.21.1 也是 `data/<ns>/recipe/`（**单数**）。`RecipeManager` 的构造器是 `super(GSON, Registries.elementsDirPath(Registries.RECIPE))`，而 `elementsDirPath` 就是 `location().getPath()`，即 `"recipe"`；`RECIPE = createRegistryKey("recipe")` |
| **配方类型字符串** | 完全相同。直接读 1.21.1 的 `RecipeSerializer` 注册：`crafting_shaped` / `crafting_shapeless` / `smelting` / `blasting` / `smoking` / `campfire_cooking` / `stonecutting` / `smithing_transform` |
| **配方结果写法** | 同样是 `{"count": n, "id": "..."}` |
| **加载条件** | 同样是 `neoforge:conditions` |
| **标签** | `data/<ns>/tags/item/**` 不变 |
| **贴图 / 方块模型 / blockstates** | 428 / — / 56，可复用 |

### 必须改的

| 资源 | 数量 | 改法 |
| :--- | :--- | :--- |
| `assets/<ns>/items/**` 物品模型定义 | **210** | **不生成** —— 这一层 1.21.4 才有；`gen-item-definitions.ps1` 在目标没有该能力时直接返回，并清掉可能的残留 |
| 配方材料 | 272 | 改成对象：`{"item": "..."}` / `{"tag": "..."}` |

材料这一条的证据是 `Ingredient.codec()`：1.21.1 是 `Codec.either(Value 列表, 单个 Value)`，而 `Value` 是带 `item` 或 `tag` 键的**对象**。**没有字符串分支** —— 光秃秃的 `"minecraft:melon"` 会被拒绝。这也解释了为什么那个 `#` 前缀在对象式里要变成键名。

### 生成脚本：改成问能力，而不是问版本号

`tools/targets.ps1` 现在带一张能力表，生成脚本问它而不是判断版本：

```powershell
$TFC_TARGET_CAPS = @{
    'neoforge-26.1.2' = @{ itemDefinitions = $true;  ingredientStyle = 'string'; farmModRecipes = $true }
    'neoforge-1.21.1' = @{ itemDefinitions = $false; ingredientStyle = 'object'; farmModRecipes = $false }
}
```

`gen-recipes.ps1` 里的 `Ing()` / `IngList()` 是**唯一**知道两种材料语法存在的地方，所以以后加版本不用动十二个配方构造函数。

### 尚未核实、因此拒绝生成的部分

`farmModRecipes = $false` 表示「这个目标的第三方模组配方格式还没对照过」。
`Assert-FarmModRecipes` 会**直接报错退出**，而不是写出看似合理、实际加载不了的配方：

- `farmersdelight:cutting` 的 `result: [{"item": {...}}]` 形状
- `farmersdelight:cooking` 的 `container` 写法
- `neoforge:compound` 这个材料类型在 NeoForge 21.1 里是否存在
- `kaleidoscope_cookery:millstone` / `chopping_board` / `pot` 三个格式（还有森罗物语是否支持 1.21.1）

要解锁就是拿到这些模组**对应 1.21.1 的 jar**，照它们的配方文件改，然后把 `farmModRecipes` 置为 `$true`。
在做完之前，1.21.1 的 `gen-recipes.ps1` 是**跑不完的**，所以 1.21.1 模块的资源还没生成。

**注意**：`gen-recipes.ps1` 会在开头清空整个配方目录，再开始写。也就是说一次失败的运行会留下一个空目录。
这是原有设计，不是这次引入的，但因为它现在会被守卫主动打断，值得记一笔。

### `check-target-caps.ps1`

新增了一个一秒跑完的检查：能力表里每个目标都有条目、未知目标会被拒绝、两种材料语法各渲染正确、每个渲染结果都能被 `ConvertFrom-Json` 解析。
理由很实际：配方生成器会一次性重写 272 个文件，而错的语法**产出的是合法 JSON** —— 只是游戏不会加载它。
在这里一秒发现，比在游戏里花一晚上发现划算。

---

## 一个容易误判的坑：行尾

`core.autocrlf=true`，而生成脚本用 PowerShell 的 here-string 写文件，得到的是 CRLF。
结果：重新生成之后 `git status` 会把这 29 个文件报告为已修改，**但 `git diff` 是空的**，因为内容其实一样。

判断依据不要用 `git status`，用对象哈希：

```powershell
git hash-object -- <file>      # 与下面相同 = 内容真的没变
git rev-parse HEAD:<file>
```

这次就是靠这个确认「重构没有改变 26.1.2 的产物」。真正被改坏的只有两处，而且是 `git diff` 抓出来的，不是 `git status`：
FD 的 `container` 被我从 ItemStack 误改成材料，以及月饼生胚配方的缩进丢了。

---

## 游戏测试：**框架完全不同**，不是改名

1.21.1 是**注解式 + 反射发现**：

```java
@GameTestHolder("tfc_food_port")            // 类注解，框架扫描后注册
public final class TFCFoodPortGameTests {
    @GameTest(template = "empty")           // 方法注解
    public static void someTest(GameTestHelper helper) { ... }
}
```

26.1.2 用的 `Registries.TEST_FUNCTION`、`FunctionGameTestInstance`、`TestData`、`TestEnvironmentDefinition`
这些类在 1.21.1 **都不存在**。所以 24 个测试要改的是注册**模型**，另外每个测试体里的
`DataComponents.FOOD` / `CONSUMABLE`（双组件）、`level.recipeAccess()`、`Identifier`、`TagValueInput`、
`ResourceHandler` 也都要改。

为了让主代码能独立编译，`versions/neoforge-1.21.1/build.gradle` 里暂时加了一行：

```groovy
sourceSets.main.java { exclude 'com/tfc_food_port/gametest/**' }
```

**测试移植完成后必须在同一个提交里删掉这行**，否则「编译通过」是假的。

---

## 已经做完的部分

- `versions/neoforge-1.21.1/build.gradle` —— 目标定为 MC 1.21.1 / NeoForge **21.1.251** / Java 21，
  已成功解析依赖并生成了完整反编译参考源码（`createMinecraftArtifacts` 通过，9 分 15 秒）
- `versions/neoforge-1.21.1/src/main/templates/META-INF/neoforge.mods.toml` —— 元数据模板已就位
- 主代码 15 个文件已按上表改完，**还剩 6 处编译错误**（表中 ⏳ 各条），因此模块**仍不 include**
- `settings.gradle` 中该模块**故意保持注释状态**：根项目会构建所有已 include 的模块，把一个编译不过的模块挂上去
  会让已完成的 26.1.2 发布流程变红。等它编译通过的**同一个提交**里再加回来
- 已验证该改动没有影响已完成的目标：`./gradlew build` 通过，
  26.1.2 jar 指纹仍为 `ac5c3599071391c453a78d5e79fede9f0ad8677bac5512ad87388fd0909d4434`（1534 个条目）

## 下一步（按顺序）

1. **拿到农夫乐事与森罗物语对应 1.21.1 的 jar**，对照它们自己的配方文件，把 `farmModRecipes` 置为 `$true`。
   在此之前 1.21.1 的资源生成跑不完，这是当前最前面的阻塞项。
2. 给 1.21.1 生成资源（`TFC_TARGET=neoforge-1.21.1` 跑全套生成脚本）
3. 移植 24 个游戏测试（`@GameTestHolder` + `@GameTest`），并删掉 `build.gradle` 里的 exclude 行
4. 把 1.21.1 从 `-Penable1211` 转成默认 include，本地 **+ CI 双绿**后再提交、推送

## 本地环境

- JDK 17 / 21 / 25 都在 `C:\Program Files\Zulu\`，1.21.1 目标用 21
- `gradle.properties` 里 `org.gradle.java.installations.auto-download=false`，所以**必须**用已装的 JDK
- `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv6Addresses=true`（用户环境变量）是访问 maven.neoforged.net 的必要条件

---

## 已更正（第一版笔记的错误）

| 第一版说 | 事实 |
| :--- | :--- |
| 「方块交互没变，签名不用改」 | **返回类型不同**：`useItemOn` 必须返回 `ItemInteractionResult`。当时只读了 public 重载就下了结论 |
| 没提 `InteractionResult` 是枚举 | 是枚举，且**没有** `TRY_WITH_EMPTY_HAND` / `SUCCESS_SERVER` |
| 没提 `LeavesBlock` 构造器 | 1.21.1 是**单参**构造器 |
| 没提 `MobEffects` 改名 | 用到的 5 个效果常量名字不同 |
| 没提 Gametest 框架 | 是**完全不同的注册模型**，不是改名 |

教训：**public 的重载不等于 protected 的可覆盖签名**。下结论前要么去读 protected 定义，要么直接编译 ——
这一次是编译器赢，代价是一轮完整构建。

