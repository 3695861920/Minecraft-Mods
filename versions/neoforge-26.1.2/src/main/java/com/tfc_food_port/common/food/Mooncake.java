package com.tfc_food_port.common.food;

import java.util.List;
import java.util.Locale;
import net.minecraft.core.Holder;
import net.minecraft.util.StringRepresentable;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;

/**
 * The mooncakes: one per jam, plus two golden apple cakes.
 *
 * A mooncake is the port's way of using up a jar of jam. Each is a pastry shell stamped with its filling, and each
 * grants a five second buff while it is eaten, so the buff is a small thank you rather than a meal substitute. The
 * duration is deliberately short: five seconds is long enough to notice the effect icon appear and short enough
 * that a stack of mooncakes is not a stack of potions.
 *
 * The effects are one per fruit and picked to suit the fruit: citrus and berries for mobility, oil and winter fruit
 * for protection, the unusual ones (banana, watermelon) for the effects nothing else provides. Two fruits share an
 * effect at most, so a full shelf of 22 cakes covers a wide spread instead of 22 copies of one buff.
 *
 * The two golden apple cakes are the exception on both counts: their effects are exactly vanilla's golden apple and
 * enchanted golden apple effects, including vanilla's longer durations, because that is what they are meant to be.
 *
 * The registry name of each mooncake is {@code tfc_food_port:food/mooncake/<serializedName>}, i.e. the jam's own
 * name in a {@code mooncake/} subfolder, so the recipe and the icon for a fruit are obviously related.
 */
public enum Mooncake implements StringRepresentable
{
    BLACKBERRY("blackberry", MobEffects.NIGHT_VISION),
    RASPBERRY("raspberry", MobEffects.SPEED),
    BLUEBERRY("blueberry", MobEffects.WATER_BREATHING),
    ELDERBERRY("elderberry", MobEffects.REGENERATION),
    SNOWBERRY("snowberry", MobEffects.FIRE_RESISTANCE),
    BUNCHBERRY("bunchberry", MobEffects.JUMP_BOOST),
    GOOSEBERRY("gooseberry", MobEffects.HASTE),
    CLOUDBERRY("cloudberry", MobEffects.SLOW_FALLING),
    STRAWBERRY("strawberry", MobEffects.HEALTH_BOOST),
    WINTERGREEN_BERRY("wintergreen_berry", MobEffects.RESISTANCE),
    CRANBERRY("cranberry", MobEffects.ABSORPTION),

    BANANA("banana", MobEffects.LUCK),
    CHERRY("cherry", MobEffects.REGENERATION),
    GREEN_APPLE("green_apple", MobEffects.HASTE),
    RED_APPLE("red_apple", MobEffects.ABSORPTION),
    LEMON("lemon", MobEffects.SPEED),
    OLIVE("olive", MobEffects.RESISTANCE),
    ORANGE("orange", MobEffects.NIGHT_VISION),
    PEACH("peach", MobEffects.JUMP_BOOST),
    PLUM("plum", MobEffects.WATER_BREATHING),
    MELON_SLICE("melon_slice", MobEffects.STRENGTH),
    PEANUT("peanut", MobEffects.SLOW_FALLING),

    GOLD_APPLE("gold_apple"),
    ENCHANTED_GOLD_APPLE("enchanted_gold_apple");

    /** Five seconds. The whole point of a mooncake buff is that it is brief. */
    public static final int BUFF_TICKS = 100;

    private final String serializedName;
    private final boolean golden;
    /** The single five second effect of a jam cake; {@code null} for the golden apple cakes. */
    private final Holder<MobEffect> effect;

    Mooncake(String serializedName, Holder<MobEffect> effect)
    {
        this.serializedName = serializedName;
        this.golden = false;
        this.effect = effect;
    }

    Mooncake(String serializedName)
    {
        this.serializedName = serializedName;
        this.golden = true;
        this.effect = null;
    }

    @Override
    public String getSerializedName()
    {
        return serializedName;
    }

    /** Registry path of this mooncake, i.e. {@code food/mooncake/<serializedName>}. */
    public String path()
    {
        return "food/mooncake/" + serializedName;
    }

    /**
     * Registry path of the unbaked version, i.e. {@code food/raw_mooncake/<serializedName>}.
     *
     * There is one raw cake per finished cake rather than a single shared raw item. A furnace input can only have
     * one output, so a shared raw mooncake could not bake into 24 different fillings; carrying the flavour on the
     * raw item is also what lets a player see which jar they pressed before baking it.
     */
    public String rawPath()
    {
        return "food/raw_mooncake/" + serializedName;
    }

    /** {@code true} for the golden apple cakes, which take their effects from vanilla's golden apples. */
    public boolean isGolden()
    {
        return golden;
    }

    /**
     * The effects this mooncake applies on being eaten.
     *
     * A jam cake applies one five second effect. The golden apple cakes reproduce vanilla's items: the plain one is
     * Regeneration II for 5 seconds plus Absorption for 2 minutes, and the enchanted one adds Resistance and Fire
     * Resistance for 5 minutes on top, which is exactly what eating the apple does.
     */
    public List<MobEffectInstance> effects()
    {
        if (this == GOLD_APPLE)
        {
            return List.of(
                new MobEffectInstance(MobEffects.REGENERATION, 100, 1),
                new MobEffectInstance(MobEffects.ABSORPTION, 2400, 0)
            );
        }
        if (this == ENCHANTED_GOLD_APPLE)
        {
            return List.of(
                new MobEffectInstance(MobEffects.REGENERATION, 400, 1),
                new MobEffectInstance(MobEffects.RESISTANCE, 6000, 0),
                new MobEffectInstance(MobEffects.FIRE_RESISTANCE, 6000, 0),
                new MobEffectInstance(MobEffects.ABSORPTION, 2400, 3)
            );
        }
        return List.of(new MobEffectInstance(effect, BUFF_TICKS, 0));
    }

    /** The jam this cake is made from, including the two golden apple jams. */
    public Food jam()
    {
        return Food.valueOf("JAM_" + serializedName.toUpperCase(Locale.ROOT));
    }

    /** A golden apple cake is worth a little more than a jam one, being made of gold. */
    public int nutrition()
    {
        return 6;
    }

    public float saturationModifier()
    {
        return golden ? 0.9F : 0.7F;
    }
}
