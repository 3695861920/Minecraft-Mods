package com.tfc_food_port.common.crop;

import com.tfc_food_port.common.food.Food;
import com.tfc_food_port.registry.TFCItems;
import java.util.Locale;
import java.util.function.Supplier;
import net.minecraft.util.StringRepresentable;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Items;

/**
 * Every crop ported from TerraFirmaCraft.
 *
 * TFC grows crops through soil nutrients, moisture, temperature and seasons. All of that is dropped here: a crop is
 * a plain vanilla {@link net.minecraft.world.level.block.CropBlock} that only needs farmland, water nearby and
 * light, i.e. exactly the vanilla rules.
 *
 * The number of growth stages is taken from TFC so that the original growth textures can be reused verbatim.
 * Each stage {@code 0..stages-1} maps to {@code tfc_food_port:block/crop/<name>_<stage>}.
 *
 * Two TFC behaviours are kept because they are cheap and charming: bell peppers start out green, and tomatoes and
 * bell peppers are "pickable" (right clicked to harvest without breaking the plant).
 */
public enum Crop implements StringRepresentable
{
    // Grains
    BARLEY(8, food(Food.BARLEY)),
    OAT(8, food(Food.OAT)),
    RYE(8, food(Food.RYE)),
    WHEAT(8, food(Food.WHEAT)),
    RICE(8, food(Food.RICE)),
    MAIZE(3, food(Food.MAIZE)),

    // Vegetables, tubers, beans
    BEET(6, food(Food.BEET)),
    CABBAGE(6, food(Food.CABBAGE)),
    CARROT(5, food(Food.CARROT)),
    GARLIC(5, food(Food.GARLIC)),
    ONION(7, food(Food.ONION)),
    POTATO(7, food(Food.POTATO)),
    GREEN_BEAN(4, food(Food.GREEN_BEAN)),
    LENTIL(6, food(Food.LENTIL)),
    SOYBEAN(7, food(Food.SOYBEAN)),
    PEANUT(6, food(Food.PEANUT)),
    RADISH(6, food(Food.RADISH)),
    CASSAVA(6, food(Food.CASSAVA)),
    SQUASH(8, food(Food.SQUASH)),

    // Pickable (right click to harvest): the plant is not destroyed
    TOMATO(4, food(Food.TOMATO), true),
    RED_BELL_PEPPER(7, food(Food.RED_BELL_PEPPER), food(Food.GREEN_BELL_PEPPER), true),
    YELLOW_BELL_PEPPER(7, food(Food.YELLOW_BELL_PEPPER), food(Food.GREEN_BELL_PEPPER), true),

    // Vanilla fruits: the crop produces the vanilla block, which is then cut on a Farmer's Delight cutting board
    PUMPKIN(8, () -> Items.PUMPKIN),
    MELON(8, () -> Items.MELON),

    // Vanilla-like cane: a normal crop here, since TFC's version is a regular planted crop too
    SUGARCANE(4, food(Food.SUGARCANE));

    private final String name;
    private final int stages;
    private final Supplier<Item> product;
    private final Supplier<Item> earlyProduct;
    private final boolean pickable;

    Crop(int stages, Supplier<Item> product)
    {
        this(stages, product, null, false);
    }

    Crop(int stages, Supplier<Item> product, boolean pickable)
    {
        this(stages, product, null, pickable);
    }

    Crop(int stages, Supplier<Item> product, Supplier<Item> earlyProduct, boolean pickable)
    {
        this.name = name().toLowerCase(Locale.ROOT);
        this.stages = stages;
        this.product = product;
        this.earlyProduct = earlyProduct;
        this.pickable = pickable;
    }

    @Override
    public String getSerializedName()
    {
        return name;
    }

    /** Registry path of the seed, i.e. {@code seeds/<name>}. */
    public String seedPath()
    {
        return "seeds/" + name;
    }

    /** Registry path of the crop block, i.e. {@code crop/<name>}. */
    public String cropPath()
    {
        return "crop/" + name;
    }

    /** Highest {@code age} value, mirroring {@link net.minecraft.world.level.block.CropBlock#getMaxAge()}. */
    public int maxAge()
    {
        return stages - 1;
    }

    /** How many growth stages TFC has textures for. */
    public int stages()
    {
        return stages;
    }

    /** The item harvested from a fully grown plant. */
    public Item product()
    {
        return product.get();
    }

    /**
     * The item harvested from a plant that is ripe but not fully coloured, i.e. green bell peppers.
     * Empty when the crop has no such intermediate product.
     */
    public Item earlyProduct()
    {
        return earlyProduct != null ? earlyProduct.get() : Items.AIR;
    }

    public boolean hasEarlyProduct()
    {
        return earlyProduct != null;
    }

    /** Age at which {@link #earlyProduct()} can be harvested, i.e. one stage before fully grown. */
    public int earlyProductAge()
    {
        return maxAge() - 1;
    }

    public boolean isPickable()
    {
        return pickable;
    }

    /** Age a pickable crop is reset to after being harvested, and regrows from. */
    public int regrowAge()
    {
        return maxAge() - 1;
    }

    private static Supplier<Item> food(Food food)
    {
        return () -> TFCItems.get(food).get();
    }
}
