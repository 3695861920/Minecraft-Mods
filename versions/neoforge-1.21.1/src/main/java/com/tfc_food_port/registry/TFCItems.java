package com.tfc_food_port.registry;

import com.tfc_food_port.TFCFoodPort;
import com.tfc_food_port.common.crop.Berry;
import com.tfc_food_port.common.crop.Crop;
import com.tfc_food_port.common.food.Food;
import com.tfc_food_port.common.food.FoodValues;
import com.tfc_food_port.common.food.Mooncake;
import com.tfc_food_port.common.item.PlantableFruitItem;
import com.tfc_food_port.common.item.WaterConvertibleItem;
import java.util.EnumMap;
import java.util.Map;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.block.Block;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

/**
 * Item registration.
 *
 * Every food is a plain {@link Item} (no custom class, no nutrient tooltip) driven by the {@link Food} enum,
 * registered under {@code tfc_food_port:food/<name>} to mirror TFC's naming. Seeds follow the same idea under
 * {@code tfc_food_port:seeds/<name>}.
 */
public final class TFCItems
{
    public static final DeferredRegister.Items ITEMS = DeferredRegister.createItems(TFCFoodPort.MOD_ID);

    private static final Map<Food, DeferredItem<Item>> FOODS = new EnumMap<>(Food.class);
    private static final Map<Crop, DeferredItem<BlockItem>> SEEDS = new EnumMap<>(Crop.class);
    private static final Map<Berry, DeferredItem<BlockItem>> LEAVES = new EnumMap<>(Berry.class);
    private static final Map<Mooncake, DeferredItem<Item>> MOONCAKES = new EnumMap<>(Mooncake.class);
    private static final Map<Mooncake, DeferredItem<Item>> RAW_MOONCAKES = new EnumMap<>(Mooncake.class);

    /** Flours turn into dough when thrown into water, see {@link WaterConvertibleItem}. */
    private static final Map<Food, Food> DOUGH_FOR_FLOUR = Map.of(
        Food.BARLEY_FLOUR, Food.BARLEY_DOUGH,
        Food.OAT_FLOUR, Food.OAT_DOUGH,
        Food.RYE_FLOUR, Food.RYE_DOUGH,
        Food.WHEAT_FLOUR, Food.WHEAT_DOUGH,
        Food.RICE_FLOUR, Food.RICE_DOUGH,
        Food.MAIZE_FLOUR, Food.MAIZE_DOUGH
    );

    static
    {
        for (final Food food : Food.values())
        {
            final Food dough = DOUGH_FOR_FLOUR.get(food);
            // A berry is its own seed: the berry item places its bush. A tree fruit is also plantable, and places
            // its sapling. Everything else is a plain item, with flour turning into dough when dropped in water.
            final Berry plant = Berry.byFood(food);

            FOODS.put(food, ITEMS.registerItem(
                food.path(),
                properties -> {
                    if (plant != null)
                    {
                        // A berry plants its bush; a tree fruit plants its sapling. Banana can also be planted on
                        // the side of a log, where it grows as a trunk-hugging fruit like cocoa.
                        final Block groundBlock = plant.isTreeFruit()
                            ? TFCBlocks.getSapling(plant).get()
                            : TFCBlocks.getBush(plant).get();

                        if (plant.hasTrunkFruit())
                        {
                            return (Item) new PlantableFruitItem(groundBlock,
                                () -> TFCBlocks.getTrunkFruit(plant).get(), properties);
                        }
                        return (Item) new BlockItem(groundBlock, properties);
                    }
                    if (dough != null)
                    {
                        return (Item) new WaterConvertibleItem(properties, () -> FOODS.get(dough).get());
                    }
                    return new Item(properties);
                },
                // On 1.21.1 the food is a single component, and everything that describes eating it - the
                // nutrition, the saturation, the bowl soups hand back, and the mooncake buffs - is inside it.
                // The bowl remainder used to be set here on Item.Properties; it is a food property on this
                // version, so FoodValues handles it. Item.Properties also has no useItemDescriptionPrefix
                // before 1.21.4, so the plantable and bowl descriptions simply had no equivalent to call.
                //
                // The properties INSTANCE is the third argument on this version, not a supplier of one.
                new Item.Properties().food(FoodValues.properties(food))
            ));
        }

        // Seeds must be a BlockItem for their crop: that is what makes right clicking farmland plant the crop.
        // Vanilla wheat seeds work exactly this way (a BlockItem for minecraft:wheat with a different item id).
        for (final Crop crop : Crop.values())
        {
            SEEDS.put(crop, ITEMS.registerItem(
                crop.seedPath(),
                properties -> new BlockItem(TFCBlocks.getCrop(crop).get(), properties)
            ));
        }

        // Tree fruit saplings deliberately get NO item. The fruit is the seed, so a sapling is only ever reached by
        // planting a fruit, which keeps saplings out of the creative menu and JEI entirely.

        // Leaves DO get an item. Shears or a Silk Touch tool take the leaf block itself, which is how vanilla oak
        // leaves behave, so without an item those drops would have nothing to become. Bushes have no leaf block.
        for (final Berry berry : Berry.treeFruits())
        {
            LEAVES.put(berry, ITEMS.registerItem(
                berry.leavesPath(),
                properties -> new BlockItem(TFCBlocks.getLeaves(berry).get(), properties)
            ));
        }

        // Mooncakes: one per jam plus the two golden apple ones. Each carries a status effect on its consumable,
        // which is what makes eating one worth a jar of jam.
        for (final Mooncake mooncake : Mooncake.values())
        {
            MOONCAKES.put(mooncake, ITEMS.registerItem(
                mooncake.path(),
                properties -> new Item(properties),
                new Item.Properties().food(FoodValues.properties(mooncake))
            ));

            // The unbaked cake. Deliberately NOT edible: raw pastry with jam in it is an ingredient, and leaving it
            // inedible is the clearest signal that it belongs in a furnace.
            RAW_MOONCAKES.put(mooncake, ITEMS.registerItem(
                mooncake.rawPath(),
                properties -> new Item(properties)
            ));
        }
    }

    /** Rennet, dropped by cows and sheep. Not edible - it is only used to curdle milk. */
    public static final DeferredItem<Item> RENNET = ITEMS.registerSimpleItem("rennet");

    /** The barrel block item. Resolved lazily to avoid a static initialiser cycle with {@link TFCBlocks}. */
    public static final DeferredItem<BlockItem> BARREL = ITEMS.registerSimpleBlockItem("barrel", () -> TFCBlocks.BARREL.get());

    private TFCItems() {}

    public static DeferredItem<Item> get(Food food)
    {
        return FOODS.get(food);
    }

    /** A seed is a {@link BlockItem} for its crop block, so it can be planted by right clicking farmland. */
    public static DeferredItem<BlockItem> getSeed(Crop crop)
    {
        return SEEDS.get(crop);
    }

    /**
     * The item form of a tree fruit's leaves.
     *
     * Vanilla lets shears and Silk Touch collect leaves as blocks, and a block needs an item for that to mean
     * anything, so each leaf block gets one. Its icon is the block model rather than a flat sprite, the same way
     * vanilla shows an oak leaves item.
     */
    public static DeferredItem<BlockItem> getLeaves(Berry berry)
    {
        return LEAVES.get(berry);
    }

    /** The mooncake made from the given jam, including the two golden apple cakes. */
    public static DeferredItem<Item> getMooncake(Mooncake mooncake)
    {
        return MOONCAKES.get(mooncake);
    }

    /** The unbaked mooncake, which bakes into {@link #getMooncake(Mooncake)} in a furnace or smoker. */
    public static DeferredItem<Item> getRawMooncake(Mooncake mooncake)
    {
        return RAW_MOONCAKES.get(mooncake);
    }
}
