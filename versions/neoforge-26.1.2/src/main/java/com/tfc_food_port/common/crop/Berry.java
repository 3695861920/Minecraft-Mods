package com.tfc_food_port.common.crop;

import com.tfc_food_port.TFCFoodPort;
import com.tfc_food_port.common.food.Food;
import com.tfc_food_port.registry.TFCItems;
import java.util.Locale;
import java.util.Optional;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.util.StringRepresentable;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.grower.TreeGrower;
import net.minecraft.world.level.levelgen.feature.ConfiguredFeature;
import org.jetbrains.annotations.Nullable;

/**
 * The harvestable plants of this port: TFC's eleven wild berries plus its nine tree fruits.
 *
 * There are two kinds:
 * <ul>
 *     <li><b>Berries</b> grow on a low bush. The berry item is its own seed - right clicking a suitable block with
 *     the berry plants the bush, and a bush has no separate item form.</li>
 *     <li><b>Tree fruits</b> grow on a small tree. The trunk is a vanilla oak log (as requested) and only the leaves
 *     are custom, so breaking the leaves is what yields the fruit. Each fruit has a sapling, and the fruit itself is
 *     also plantable.</li>
 * </ul>
 *
 * Growth stages map onto TFC's own art:
 * <ul>
 *     <li>berries: {@code dry_<name>_bush}, {@code <name>_bush}, {@code flowering_<name>_bush}, {@code fruiting_<name>_bush}</li>
 *     <li>tree fruits: {@code <name>_sapling} for the sapling and {@code <name>_leaves} for the leaves</li>
 * </ul>
 */
public enum Berry implements StringRepresentable
{
    // TFC wild berries - grow on a bush, the berry is the seed
    BLACKBERRY(Food.BLACKBERRY, Group.FOREST),
    RASPBERRY(Food.RASPBERRY, Group.FOREST),
    BLUEBERRY(Food.BLUEBERRY, Group.FOREST),
    ELDERBERRY(Food.ELDERBERRY, Group.FOREST),
    GOOSEBERRY(Food.GOOSEBERRY, Group.FOREST),
    BUNCHBERRY(Food.BUNCHBERRY, Group.FOREST),
    STRAWBERRY(Food.STRAWBERRY, Group.PLAINS),
    SNOWBERRY(Food.SNOWBERRY, Group.TAIGA),
    CLOUDBERRY(Food.CLOUDBERRY, Group.TAIGA),
    WINTERGREEN_BERRY(Food.WINTERGREEN_BERRY, Group.TAIGA),
    CRANBERRY(Food.CRANBERRY, Group.TAIGA),

    // TFC tree fruits - grow on an oak-trunked tree with custom leaves, and have a sapling
    BANANA(Food.BANANA, Group.JUNGLE),
    ORANGE(Food.ORANGE, Group.JUNGLE),
    LEMON(Food.LEMON, Group.JUNGLE),
    PEACH(Food.PEACH, Group.JUNGLE),
    CHERRY(Food.CHERRY, Group.FOREST),
    OLIVE(Food.OLIVE, Group.FOREST),
    GREEN_APPLE(Food.GREEN_APPLE, Group.FOREST),
    RED_APPLE(Food.RED_APPLE, Group.FOREST),
    PLUM(Food.PLUM, Group.FOREST);

    /**
     * Which vanilla biome group the plant generates in.
     *
     * These are only used for readability now: the generated biome modifiers add every plant to
     * {@code #minecraft:is_overworld}, so bushes and trees appear in all overworld biomes.
     */
    public enum Group
    {
        TAIGA,
        FOREST,
        PLAINS,
        JUNGLE
    }

    private final String name;
    private final Food food;
    private final Group group;
    private final boolean treeFruit;
    private final TreeGrower treeGrower;

    Berry(Food food, Group group)
    {
        this.name = name().toLowerCase(Locale.ROOT);
        this.food = food;
        this.group = group;
        this.treeFruit = isTreeFruitName(this.name);

        // A TreeGrower records itself in a static name->grower map in its constructor, which is what the
        // SaplingBlock codec resolves against, so a custom grower can be created here and used by a vanilla
        // SaplingBlock. Only tree fruits get one.
        this.treeGrower = treeFruit
            ? new TreeGrower(this.name, Optional.empty(), Optional.of(treeFeatureKey(this.name)), Optional.empty())
            : null;
    }

    private static boolean isTreeFruitName(String name)
    {
        return switch (name)
        {
            case "banana", "orange", "lemon", "peach", "cherry", "olive", "green_apple", "red_apple", "plum" -> true;
            default -> false;
        };
    }

    private static ResourceKey<ConfiguredFeature<?, ?>> treeFeatureKey(String name)
    {
        return ResourceKey.create(Registries.CONFIGURED_FEATURE, TFCFoodPort.id(name + "_tree"));
    }

    @Override
    public String getSerializedName()
    {
        return name;
    }

    /** {@code true} for TFC's tree fruits, which grow on a tree instead of a bush. */
    public boolean isTreeFruit()
    {
        return treeFruit;
    }

    /** The food this plant harvests. */
    public Food food()
    {
        return food;
    }

    /** The harvested item, which is also the seed for berries and tree fruits alike. */
    public Item product()
    {
        return TFCItems.get(food).get();
    }

    /** Registry path of the bush block, i.e. {@code plant/<name>_bush}. Berries only. */
    public String bushPath()
    {
        return "plant/" + name + "_bush";
    }

    /** Registry path of the sapling block, i.e. {@code plant/<name>_sapling}. Tree fruits only. */
    public String saplingPath()
    {
        return "plant/" + name + "_sapling";
    }

    /** Registry path of the leaves block, i.e. {@code plant/<name>_leaves}. Tree fruits only. */
    public String leavesPath()
    {
        return "plant/" + name + "_leaves";
    }

    /**
     * Bananas are special: the fruit grows stuck to the side of the trunk like cocoa, so there is an extra block.
     *
     * TFC grows bananas on a palm-like plant, and a palm's fruit really does hang off the trunk rather than the
     * leaves, so this keeps that behaviour.
     */
    public boolean hasTrunkFruit()
    {
        return this == BANANA;
    }

    /** Registry path of the trunk-hugging fruit block, i.e. {@code plant/<name>_bunch}. Banana only. */
    public String trunkFruitPath()
    {
        return "plant/" + name + "_bunch";
    }

    /** The configured feature that grows this tree. Tree fruits only. */
    public ResourceKey<ConfiguredFeature<?, ?>> treeFeature()
    {
        return treeFeatureKey(name);
    }

    /** The tree grower for this fruit's sapling. Tree fruits only. */
    public TreeGrower treeGrower()
    {
        if (treeGrower == null)
        {
            throw new IllegalStateException(name + " is a berry, not a tree fruit, so it has no TreeGrower");
        }
        return treeGrower;
    }

    /** Finds the plant that harvests the given food, or {@code null} for foods that are not grown here. */
    @Nullable
    public static Berry byFood(Food food)
    {
        for (final Berry berry : values())
        {
            if (berry.food == food)
            {
                return berry;
            }
        }
        return null;
    }

    /** All tree fruits, for iterating the sapling and leaves registrations. */
    public static java.util.List<Berry> treeFruits()
    {
        return java.util.Arrays.stream(values()).filter(Berry::isTreeFruit).toList();
    }

    /** All bush berries, for iterating the bush registrations. */
    public static java.util.List<Berry> bushBerries()
    {
        return java.util.Arrays.stream(values()).filter(b -> !b.isTreeFruit()).toList();
    }
}
