package com.tfc_food_port.common.food;

import java.util.EnumMap;
import java.util.Map;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.Items;

/**
 * Builds the vanilla {@link FoodProperties} for every {@link Food}.
 *
 * On 1.21.1 food is a SINGLE data component: {@code minecraft:food}, a {@link FoodProperties} record carrying the
 * nutrition, the saturation, what the eater gets back, and any status effects. The mooncake buffs and the
 * bowl-returning for soups and salads both live on this one object.
 *
 * That is the opposite of 26.1.2, where 1.21.2 split the record in two - {@code minecraft:food} for the numbers and
 * {@code minecraft:consumable} for the eating behaviour and the effects, with effects moving to
 * {@code ApplyStatusEffectsConsumeEffect}. Porting between the two is largely moving those two things between
 * builders, which is why this file has no "consumable" counterpart here.
 *
 * Read out of the 1.21.1 decompile rather than assumed:
 * <pre>
 *   record FoodProperties(int nutrition, float saturation, boolean canAlwaysEat, float eatSeconds,
 *                         Optional&lt;ItemStack&gt; usingConvertsTo, List&lt;PossibleEffect&gt; effects)
 *   Builder: nutrition, saturationModifier, alwaysEdible, fast, effect(MobEffectInstance, float), usingConvertsTo
 * </pre>
 */
public final class FoodValues
{
    private static final Map<Food, FoodProperties> PROPERTIES = new EnumMap<>(Food.class);
    private static final Map<Mooncake, FoodProperties> MOONCAKE_PROPERTIES = new EnumMap<>(Mooncake.class);

    static
    {
        for (final Food food : Food.values())
        {
            final FoodProperties.Builder builder = new FoodProperties.Builder()
                .nutrition(food.nutrition())
                .saturationModifier(food.saturationModifier());

            // Soups and salads are eaten out of a bowl and hand it back. On 1.21.1 this is a property of the food
            // rather than of the item, so it is set here instead of in TFCItems, where 26.1.2 has to put it.
            if (food.isBowlFood())
            {
                builder.usingConvertsTo(Items.BOWL);
            }

            PROPERTIES.put(food, builder.build());
        }

        for (final Mooncake mooncake : Mooncake.values())
        {
            final FoodProperties.Builder builder = new FoodProperties.Builder()
                .nutrition(mooncake.nutrition())
                .saturationModifier(mooncake.saturationModifier());

            // The buff. On 1.21.1 this is Builder#effect and it takes a probability, so a mooncake passes 1.0 to
            // make the buff guaranteed - the same intent as the 26.1.2 side's
            // ApplyStatusEffectsConsumeEffect(effects, 1.0F).
            for (final MobEffectInstance effect : mooncake.effects())
            {
                builder.effect(effect, 1.0F);
            }

            MOONCAKE_PROPERTIES.put(mooncake, builder.build());
        }
    }

    private FoodValues() {}

    public static FoodProperties properties(Food food)
    {
        return PROPERTIES.get(food);
    }

    public static FoodProperties properties(Mooncake mooncake)
    {
        return MOONCAKE_PROPERTIES.get(mooncake);
    }
}
