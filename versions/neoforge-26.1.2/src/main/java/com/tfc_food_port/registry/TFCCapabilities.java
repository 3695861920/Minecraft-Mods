package com.tfc_food_port.registry;

import com.tfc_food_port.TFCFoodPort;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.capabilities.RegisterCapabilitiesEvent;

/**
 * Exposes block entity capabilities.
 *
 * Note that since 1.21.9 NeoForge's fluid capability is the transfer API
 * ({@code Capabilities.Fluid.BLOCK} with a {@code ResourceHandler<FluidResource>}), the old {@code IFluidHandler}
 * capability no longer exists.
 */
@EventBusSubscriber(modid = TFCFoodPort.MOD_ID)
public final class TFCCapabilities
{
    private TFCCapabilities() {}

    @SubscribeEvent
    public static void register(RegisterCapabilitiesEvent event)
    {
        event.registerBlockEntity(Capabilities.Fluid.BLOCK, TFCBlocks.BARREL_ENTITY.get(), (barrel, side) -> barrel.getTank());
    }
}
