package com.tfc_food_port.registry;

import com.tfc_food_port.TFCFoodPort;
import net.minecraft.core.component.DataComponentType;
import net.minecraft.core.registries.Registries;
import net.neoforged.neoforge.fluids.SimpleFluidContent;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

/**
 * Data components.
 *
 * The barrel's contents live in a component so that breaking the barrel keeps the fluid: the block entity exposes
 * it through {@code collectImplicitComponents}, the loot table copies it onto the dropped item with
 * {@code minecraft:copy_components}, and placing the barrel hands it back to the new block entity.
 */
public final class TFCComponents
{
    public static final DeferredRegister.DataComponents COMPONENTS =
        DeferredRegister.createDataComponents(Registries.DATA_COMPONENT_TYPE, TFCFoodPort.MOD_ID);

    /** Fluid held by a barrel, so that it survives being broken and replaced. */
    public static final DeferredHolder<DataComponentType<?>, DataComponentType<SimpleFluidContent>> BARREL_FLUID =
        COMPONENTS.registerComponentType("barrel_fluid", builder -> builder
            .persistent(SimpleFluidContent.CODEC)
            .networkSynchronized(SimpleFluidContent.STREAM_CODEC)
            .cacheEncoding());

    private TFCComponents() {}
}
