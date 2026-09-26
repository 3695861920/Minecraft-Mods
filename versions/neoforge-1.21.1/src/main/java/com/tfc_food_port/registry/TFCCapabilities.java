package com.tfc_food_port.registry;

import com.tfc_food_port.TFCFoodPort;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.capabilities.RegisterCapabilitiesEvent;

/**
 * Exposes block entity capabilities.
 *
 * On 1.21.1 the fluid capability is {@code Capabilities.FluidHandler.BLOCK}, a
 * {@code BlockCapability<IFluidHandler, Direction>}. The transfer API that replaced it on 1.21.9 -
 * {@code Capabilities.Fluid.BLOCK} with a {@code ResourceHandler<FluidResource>} - does not exist on this version,
 * so this is a real difference between the two targets rather than a rename.
 */
@EventBusSubscriber(modid = TFCFoodPort.MOD_ID)
public final class TFCCapabilities
{
    private TFCCapabilities() {}

    @SubscribeEvent
    public static void register(RegisterCapabilitiesEvent event)
    {
        event.registerBlockEntity(Capabilities.FluidHandler.BLOCK, TFCBlocks.BARREL_ENTITY.get(), (barrel, side) -> barrel.getTank());
    }
}
