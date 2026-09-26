package com.tfc_food_port.common.item;

import java.util.function.Supplier;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;

/**
 * An item that turns into something else while lying in water.
 *
 * This is how TFC's "flour plus water makes dough" is kept without a fluid-capable crafting grid: throw the flour
 * into any water and it becomes dough. Implemented through NeoForge's
 * {@link net.neoforged.neoforge.common.extensions.IItemExtension#onEntityItemUpdate(ItemStack, ItemEntity)}, which
 * runs once per tick for the dropped item entity.
 */
public class WaterConvertibleItem extends Item
{
    private final Supplier<Item> result;

    public WaterConvertibleItem(Properties properties, Supplier<Item> result)
    {
        super(properties);
        this.result = result;
    }

    @Override
    public boolean onEntityItemUpdate(ItemStack stack, ItemEntity entity)
    {
        if (entity.level() instanceof ServerLevel level && entity.isInWater())
        {
            final ItemStack converted = new ItemStack(result.get(), stack.getCount());
            entity.setItem(converted);
            level.playSound(null, entity.blockPosition(), SoundEvents.BUCKET_FILL, SoundSource.BLOCKS, 0.6F, 1.0F);
        }
        return false;
    }
}
