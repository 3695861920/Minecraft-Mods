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

## 资源层的差异（工作量比 Java 大）

| 资源 | 数量 | 1.21.1 要做的事 |
| :--- | :--- | :--- |
| `assets/<ns>/items/**` 物品模型定义 | **210** | **全部删除** —— 这一层 1.21.4 才引入；1.21.1 直接从 `models/item/**` 解析 |
| 配方 JSON | **272** | 材料从字符串退回对象：`{"item": "..."}` / `{"tag": "..."}` |
| 配方条件 | 152 个带条件 | `neoforge:conditions` 在 1.21.1 **同样是这个键**（NeoForge 自 1.20.2 起沿用），无需改 |
| `kaleidoscope_cookery` 配方 | 31 | **需要核实森罗物语是否支持 1.21.1**；若不支持应加 `mod_loaded` 之外的版本条件或整段不生成 |
| 农夫乐事配方字段 | 45 | 1.21.1 的 FD 是 1.2.7，`farmersdelight:cooking` / `cutting` 的字段名需对照其 jar |
| 贴图 / 方块模型 / blockstates | 428 / — / 56 | ✅ 可复用 |

### 生成脚本需要的改造

`tools/targets.ps1` 已经能按目标选模块，但生成器本身**写死了 26.1.2 的格式**：

- `gen-item-definitions.ps1` 要能整体跳过（1.21.1 不需要定义层）
- `gen-recipes.ps1` 要能输出对象式材料（一个 `Recipe-Ingredient-Format` 开关）
- `gen-plants.ps1` 的树叶物品定义同理要跳过

建议在 `targets.ps1` 里为每个目标加一行能力表：

```powershell
$TFC_TARGET_CAPS = @{
    'neoforge-26.1.2' = @{ itemDefinitions = $true;  ingredientStyle = 'string' }
    'neoforge-1.21.1' = @{ itemDefinitions = $false; ingredientStyle = 'object' }
}
```

这样生成脚本问能力，而不是问版本号 —— 加 1.21.4 之类中间版本时不用再改判断逻辑。

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

1. 改 `Mooncake` 的 5 个 `MobEffects` 常量名
2. 读 `TFCBlocks` / `TFCItems` 的**完整**编译错误，定性 `registerBlock` / `registerItem` 的第三个参数
3. 去掉 `TFCLeavesBlock` 构造器的 float
4. 修 `TFCBerryBushBlock.getCloneItemStack`、`TFCPalmFruitBlock`
5. 移植 24 个游戏测试并删掉 `build.gradle` 的 exclude
6. 生成脚本加**能力表**（`itemDefinitions` / `ingredientStyle`），让 1.21.1 不生成 210 个物品定义、配方材料出对象式
7. 重新 include，本地 **+ CI 双绿**后再提交，然后才推到 GitHub

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

