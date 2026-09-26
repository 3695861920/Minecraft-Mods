package com.tfc_food_port.common.food;

import java.util.Locale;
import net.minecraft.util.StringRepresentable;

/**
 * Every food item ported from TerraFirmaCraft, balanced against Farmer's Delight rather than against TFC.
 *
 * TFC gives every food a flat hunger of 4 and separates them only through a saturation figure and a nutrient
 * system; this port drops the nutrients, so a flat hunger left 130 items that were all equally filling. The values
 * here instead follow Farmer's Delight's curve, which is the food mod this port is built around:
 *
 * <ul>
 *     <li>raw produce and berries: 1-3 hunger, modifier 0.1-0.4</li>
 *     <li>a cooked single ingredient (baked potato, cooked cassava): 5-6 hunger, modifier 0.5-0.6</li>
 *     <li>bread: 6 hunger, modifier 0.6</li>
 *     <li>a sandwich: 8 hunger, modifier 0.75-0.8</li>
 *     <li>a bowl of salad: 6 hunger, modifier 0.6</li>
 *     <li>a bowl of stew or soup, and anything made in the cooking pot: 12 hunger, modifier 0.8</li>
 * </ul>
 *
 * The second constructor argument is therefore vanilla's saturation MODIFIER (Farmer's Delight stores the same
 * thing the same way), not an absolute saturation. Vanilla restores {@code nutrition * modifier * 2} points, so
 * the 12 point stews give 19.2 saturation, matching Farmer's Delight's own stews.
 *
 * The registry name of each food is {@code tfc_food_port:food/<serializedName>}, mirroring TFC's
 * {@code tfc:food/<name>} layout, so ingredients in ported recipes only ever need a namespace swap.
 */
public enum Food implements StringRepresentable
{
    // ==================== Grains: crop -> grain -> flour -> dough -> bread ====================
    // The harvested crop is a snack, the grain and flour are ingredients, and the bread is a meal.
    BARLEY(1, 0.2F),
    BARLEY_GRAIN(2, 0.3F),
    BARLEY_FLOUR(2, 0.2F),
    BARLEY_DOUGH(2, 0.3F),
    BARLEY_BREAD(6, 0.6F),
    BARLEY_BREAD_SANDWICH(8, 0.8F),
    BARLEY_BREAD_JAM_SANDWICH(8, 0.75F),

    OAT(1, 0.2F),
    OAT_GRAIN(2, 0.3F),
    OAT_FLOUR(2, 0.2F),
    OAT_DOUGH(2, 0.3F),
    OAT_BREAD(6, 0.6F),
    OAT_BREAD_SANDWICH(8, 0.8F),
    OAT_BREAD_JAM_SANDWICH(8, 0.75F),

    RYE(1, 0.2F),
    RYE_GRAIN(2, 0.3F),
    RYE_FLOUR(2, 0.2F),
    RYE_DOUGH(2, 0.3F),
    RYE_BREAD(6, 0.6F),
    RYE_BREAD_SANDWICH(8, 0.8F),
    RYE_BREAD_JAM_SANDWICH(8, 0.75F),

    WHEAT(1, 0.2F),
    WHEAT_GRAIN(2, 0.3F),
    WHEAT_FLOUR(2, 0.2F),
    WHEAT_DOUGH(2, 0.3F),
    WHEAT_BREAD(6, 0.6F),
    WHEAT_BREAD_SANDWICH(8, 0.8F),
    WHEAT_BREAD_JAM_SANDWICH(8, 0.75F),

    RICE(1, 0.2F),
    RICE_GRAIN(2, 0.3F),
    RICE_FLOUR(2, 0.2F),
    RICE_DOUGH(2, 0.3F),
    RICE_BREAD(6, 0.6F),
    RICE_BREAD_SANDWICH(8, 0.8F),
    RICE_BREAD_JAM_SANDWICH(8, 0.75F),
    COOKED_RICE(6, 0.4F),

    MAIZE(1, 0.2F),
    MAIZE_GRAIN(2, 0.3F),
    MAIZE_FLOUR(2, 0.2F),
    MAIZE_DOUGH(2, 0.3F),
    MAIZE_BREAD(6, 0.6F),
    MAIZE_BREAD_SANDWICH(8, 0.8F),
    MAIZE_BREAD_JAM_SANDWICH(8, 0.75F),

    // ==================== Vegetables, tubers and beans ====================
    // Raw produce stays a snack, so a meal still needs the cooking pot. The cooked forms are worth eating.
    BEET(3, 0.4F),
    CABBAGE(2, 0.4F),
    CARROT(3, 0.4F),
    GARLIC(2, 0.4F),
    GREEN_BEAN(2, 0.3F),
    GREEN_BELL_PEPPER(3, 0.4F),
    ONION(2, 0.4F),
    POTATO(1, 0.3F),
    BAKED_POTATO(5, 0.6F),
    RED_BELL_PEPPER(3, 0.4F),
    YELLOW_BELL_PEPPER(3, 0.4F),
    SOYBEAN(2, 0.3F),
    SQUASH(3, 0.4F),
    TOMATO(2, 0.3F),
    CASSAVA(2, 0.3F),
    COOKED_CASSAVA(5, 0.6F),
    LENTIL(2, 0.3F),
    COOKED_LENTIL(5, 0.5F),
    PEANUT(2, 0.3F),
    RADISH(3, 0.4F),
    SUGARCANE(1, 0.1F),

    // ==================== Berries ====================
    // Vanilla's sweet berries are 2 with 0.1; these are the same kind of snack.
    BLACKBERRY(2, 0.2F),
    RASPBERRY(2, 0.2F),
    BLUEBERRY(2, 0.2F),
    ELDERBERRY(2, 0.1F),
    SNOWBERRY(2, 0.2F),
    BUNCHBERRY(2, 0.2F),
    GOOSEBERRY(2, 0.2F),
    CLOUDBERRY(2, 0.2F),
    STRAWBERRY(2, 0.3F),
    WINTERGREEN_BERRY(2, 0.2F),
    CRANBERRY(2, 0.1F),

    // ==================== Tree fruits ====================
    // A vanilla apple is 4 with 0.3, which is the reference for a hand fruit.
    BANANA(4, 0.3F),
    CHERRY(3, 0.3F),
    GREEN_APPLE(4, 0.3F),
    RED_APPLE(4, 0.3F),
    LEMON(3, 0.2F),
    OLIVE(2, 0.3F),
    ORANGE(4, 0.3F),
    PEACH(4, 0.3F),
    PLUM(4, 0.3F),

    // ==================== Melon and pumpkin ====================
    MELON_SLICE(3, 0.3F),
    PUMPKIN_CHUNKS(3, 0.3F),

    // ==================== Eggs ====================
    COOKED_EGG(4, 0.4F),
    BOILED_EGG(4, 0.5F),

    // ==================== Cheese chain ====================
    /** Renamed from TFC's curdled milk -> cheese barrel chain, now a Farmer's Delight cooking pot product. */
    CHEESE_CURD(2, 0.3F),
    CHEESE(6, 0.7F),

    // ==================== Seaweed ====================
    FRESH_SEAWEED(1, 0.2F),
    DRIED_SEAWEED(2, 0.3F),

    // ==================== Soups (Farmer's Delight cooking pot, served in a bowl) ====================
    // 12 hunger with 0.8 is precisely Farmer's Delight's beef stew, so a ported soup is worth a cooking pot.
    GRAIN_SOUP(12, 0.8F, true),
    FRUIT_SOUP(12, 0.8F, true),
    VEGETABLES_SOUP(12, 0.8F, true),
    PROTEIN_SOUP(12, 0.8F, true),
    DAIRY_SOUP(12, 0.8F, true),

    // ==================== Salads (crafting, served in a bowl) ====================
    // Farmer's Delight's mixed salad and fruit salad are both 6 with 0.6, so salads stay a step below a stew.
    GRAIN_SALAD(6, 0.6F, true),
    FRUIT_SALAD(6, 0.6F, true),
    VEGETABLES_SALAD(6, 0.6F, true),
    PROTEIN_SALAD(6, 0.6F, true),
    DAIRY_SALAD(6, 0.6F, true),

    // ==================== Jams (one item per fruit, no sealing mechanic) ====================
    // A jar of jam is concentrated fruit plus sugar: a sweet snack rather than a meal.
    JAM_BLACKBERRY("jam/blackberry", 4, 0.5F),
    JAM_RASPBERRY("jam/raspberry", 4, 0.5F),
    JAM_BLUEBERRY("jam/blueberry", 4, 0.5F),
    JAM_ELDERBERRY("jam/elderberry", 4, 0.5F),
    JAM_SNOWBERRY("jam/snowberry", 4, 0.5F),
    JAM_BUNCHBERRY("jam/bunchberry", 4, 0.5F),
    JAM_GOOSEBERRY("jam/gooseberry", 4, 0.5F),
    JAM_CLOUDBERRY("jam/cloudberry", 4, 0.5F),
    JAM_STRAWBERRY("jam/strawberry", 4, 0.5F),
    JAM_WINTERGREEN_BERRY("jam/wintergreen_berry", 4, 0.5F),
    JAM_CRANBERRY("jam/cranberry", 4, 0.5F),
    JAM_BANANA("jam/banana", 4, 0.5F),
    JAM_CHERRY("jam/cherry", 4, 0.5F),
    JAM_GREEN_APPLE("jam/green_apple", 4, 0.5F),
    JAM_RED_APPLE("jam/red_apple", 4, 0.5F),
    JAM_LEMON("jam/lemon", 4, 0.5F),
    JAM_OLIVE("jam/olive", 4, 0.5F),
    JAM_ORANGE("jam/orange", 4, 0.5F),
    JAM_PEACH("jam/peach", 4, 0.5F),
    JAM_PLUM("jam/plum", 4, 0.5F),
    JAM_MELON_SLICE("jam/melon_slice", 4, 0.5F),
    JAM_PEANUT("jam/peanut", 4, 0.5F),

    // The two magical jams. They are not fruit, so they are not in the plain fruit list, but they are jams: a
    // golden apple from an apple tree can be cooked down like any other fruit and then baked into mooncakes.
    JAM_GOLD_APPLE("jam/gold_apple", 5, 0.6F),
    JAM_ENCHANTED_GOLD_APPLE("jam/enchanted_gold_apple", 6, 0.8F);

    private final String serializedName;
    private final int nutrition;
    private final float saturationModifier;
    private final boolean bowlFood;

    Food(int nutrition, float saturationModifier)
    {
        this(nutrition, saturationModifier, false);
    }

    /** A bowl food is eaten out of a bowl, so eating it hands the bowl back (see {@link #isBowlFood()}). */
    Food(int nutrition, float saturationModifier, boolean bowlFood)
    {
        this.serializedName = name().toLowerCase(Locale.ROOT);
        this.nutrition = nutrition;
        this.saturationModifier = saturationModifier;
        this.bowlFood = bowlFood;
    }

    Food(String serializedName, int nutrition, float saturationModifier)
    {
        this.serializedName = serializedName;
        this.nutrition = nutrition;
        this.saturationModifier = saturationModifier;
        this.bowlFood = false;
    }

    @Override
    public String getSerializedName()
    {
        return serializedName;
    }

    /** Registry path of this food, i.e. {@code food/<serializedName>}. */
    public String path()
    {
        return "food/" + serializedName;
    }

    /** Hunger points restored, i.e. {@link net.minecraft.world.food.FoodProperties#nutrition()}. */
    public int nutrition()
    {
        return nutrition;
    }

    /**
     * {@code true} for soups and salads: they are served in a bowl and eating one returns the bowl.
     *
     * This is not cosmetic. Farmer's Delight validates that a cooking pot recipe's declared container matches the
     * result item's own "use remainder" component, so a soup declared with {@code "container": "minecraft:bowl"}
     * must also be registered with {@code usingConvertsTo(Items.BOWL)}, exactly like vanilla's mushroom stew.
     */
    public boolean isBowlFood()
    {
        return bowlFood;
    }

    /**
     * Vanilla {@link net.minecraft.world.food.FoodProperties} saturation modifier.
     *
     * Stored directly, not derived: these values are the balance table, so they are written out per food the way
     * Farmer's Delight writes its own. Vanilla restores {@code nutrition * saturationModifier * 2} saturation
     * points, so 0.8 on a 12 point stew is 19.2 saturation, which is the shape of the Farmer's Delight numbers.
     */
    public float saturationModifier()
    {
        return saturationModifier;
    }
}
