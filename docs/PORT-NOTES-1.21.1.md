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

## 方块交互：**没变**

好消息，26.1.2 与 1.21.1 一致：

```java
// net/minecraft/world/level/block/state/BlockBehaviour.java
protected ItemInteractionResult useItemOn(ItemStack, BlockState, Level, BlockPos, Player, InteractionHand, BlockHitResult);
protected InteractionResult useWithoutItem(BlockState, Level, BlockPos, Player, BlockHitResult);
// 加上旧的 public 重载，两者在 1.21.1 就已并存
public ItemInteractionResult useItemOn(ItemStack, Level, Player, InteractionHand, BlockHitResult);
public InteractionResult useWithoutItem(Level, Player, BlockHitResult);
```

所以 `TFCCropBlock`（已用 `useItemOn`）、`BarrelBlock`、`TFCBerryBushBlock` 的**交互签名不用改**。

---

## 其它已核实的差异

| 项 | 1.21.1 | 26.1.2 | 处理 |
| :--- | :--- | :--- | :--- |
| 属性拼写 | **`noCollission()`** | `noCollision()` | 改 `TFCBlocks` |
| 浆果丛基类 | **`BushBlock`** | `VegetationBlock` | 改 `TFCBerryBushBlock` |
| 物品描述前缀 | **`Item.Properties` 上不存在** | `useItemDescriptionPrefix()` / `useBlockDescriptionPrefix()` | 删掉这些调用 |
| 标识符 | `ResourceLocation` | `Identifier` | 全量替换 |
| 方块实体序列化 | `load(CompoundTag)` / `saveAdditional(CompoundTag)` | `ValueInput` / `ValueOutput` | 改 `BarrelBlockEntity` |
| 流体 | `IFluidHandler` + `FluidTank` | `ResourceHandler<FluidResource>` + `FluidStacksResourceHandler` | 改 `BarrelBlockEntity` / `TFCCapabilities` |
| 配方管理器 | `level.getRecipeManager()` | `level.recipeAccess()` | 改游戏测试 |

**存在且可用**（已核实）：`LeavesBlock`、`SaplingBlock`、`CropBlock`、`CocoaBlock`、`TreeGrower`。
`LeavesBlock` 在 1.21.1 **没有** `spawnFallingLeavesParticle` 这个抽象方法 —— `TFCLeavesBlock` 要删掉那个覆写。

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

## 已经做完的部分

- `versions/neoforge-1.21.1/build.gradle` —— 目标定为 MC 1.21.1 / NeoForge **21.1.251** / Java 21，
  已成功解析依赖并生成了完整反编译参考源码（`createMinecraftArtifacts` 通过，9 分 15 秒）
- `versions/neoforge-1.21.1/src/main/templates/META-INF/neoforge.mods.toml` —— 元数据模板已就位
- 20 个 Java 源文件已复制过去，**尚未改 API**
- `settings.gradle` **暂不 include 该模块**：根项目会构建所有已 include 的模块，把一个编译不过的模块挂上去
  会让已完成的 26.1.2 发布流程变红。等它编译通过的同一个提交里再加。

## 本地环境

- JDK 17 / 21 / 25 都在 `C:\Program Files\Zulu\`，1.21.1 目标用 21
- `gradle.properties` 里 `org.gradle.java.installations.auto-download=false`，所以**必须**用已装的 JDK
- `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv6Addresses=true`（用户环境变量）是访问 maven.neoforged.net 的必要条件
