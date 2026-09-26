package com.tfc_food_port;

import com.tfc_food_port.gametest.TFCFoodPortGameTests;
import com.tfc_food_port.registry.TFCBlocks;
import com.tfc_food_port.registry.TFCComponents;
import com.tfc_food_port.registry.TFCCreativeTabs;
import com.tfc_food_port.registry.TFCItems;
import net.minecraft.resources.Identifier;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.gametest.GameTestHooks;

/**
 * TFC Food Port - a heavily simplified port of TerraFirmaCraft's food items, crops and barrel.
 *
 * Removed compared to TFC: nutrition, decay, water, extra animals, TFC pots/stoves, cheese cloth, brine.
 * All TFC pot/stove/barrel food recipes are converted to Farmer's Delight cooking/cutting or vanilla recipes.
 */
@Mod(TFCFoodPort.MOD_ID)
public final class TFCFoodPort
{
    public static final String MOD_ID = "tfc_food_port";

    public TFCFoodPort(IEventBus modEventBus, ModContainer modContainer)
    {
        // Registries must be registered to the mod bus in a deterministic order.
        TFCComponents.COMPONENTS.register(modEventBus);
        TFCItems.ITEMS.register(modEventBus);
        TFCBlocks.BLOCKS.register(modEventBus);
        TFCBlocks.BLOCK_ENTITIES.register(modEventBus);
        TFCCreativeTabs.TABS.register(modEventBus);

        if (GameTestHooks.isGametestEnabled())
        {
            TFCFoodPortGameTests.register(modEventBus);
        }
    }

    public static Identifier id(String path)
    {
        return Identifier.fromNamespaceAndPath(MOD_ID, path);
    }
}
