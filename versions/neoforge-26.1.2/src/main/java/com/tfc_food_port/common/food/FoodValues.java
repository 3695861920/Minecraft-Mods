package com.tfc_food_port.common.food;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.component.Consumable;
import net.minecraft.world.item.component.Consumables;
import net.minecraft.world.item.consume_effects.ApplyStatusEffectsConsumeEffect;

/**
 * Builds the vanilla {@link FoodProperties} / {@link Consumable} pair for every {@link Food}.
 *
 * Since MC 1.21.2 food is split into two data components: {@code minecraft:food} (hunger + saturation) and
 * {@code minecraft:consumable} (eating animation, sounds, effects). Items must be given both.
 *
 * Mooncakes are built here too, because they follow the same shape as every other food - hunger, saturation and a
 * consumable - and differ only in that their consumable carries a status effect.
 */
public final class FoodValues
{
    private static final Map<Food, FoodProperties> PROPERTIES = new EnumMap<>(Food.class);
    private static final Map<Mooncake, FoodProperties> MOONCAKE_PROPERTIES = new EnumMap<>(Mooncake.class);

    static
    {
        for (final Food food : Food.values())
        {
            PROPERTIES.put(food, new FoodProperties.Builder()
                .nutrition(food.nutrition())
                .saturationModifier(food.saturationModifier())
                .build());
        }

        for (final Mooncake mooncake : Mooncake.values())
        {
            MOONCAKE_PROPERTIES.put(mooncake, new FoodProperties.Builder()
                .nutrition(mooncake.nutrition())
                .saturationModifier(mooncake.saturationModifier())
                .build());
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

    /** Standard food consumable: 1.6s eat time, food particles and sounds. No side effects, matching TFC. */
    public static Consumable consumable()
    {
        return Consumables.DEFAULT_FOOD;
    }

    /**
     * A consumable that applies status effects on being eaten, which is how a mooncake buff is delivered.
     *
     * Since 1.21.2 the effects of a food live on its {@code minecraft:consumable} component rather than on
     * {@code FoodProperties}, and the only supported way to add them is a consume effect - there is no
     * {@code FoodProperties.Builder#effect} any more. A 100% probability means the buff is guaranteed, so a
     * mooncake is never a wasted item.
     */
    public static Consumable consumable(List<MobEffectInstance> effects)
    {
        return Consumables.defaultFood()
            .onConsume(new ApplyStatusEffectsConsumeEffect(effects, 1.0F))
            .build();
    }
}
