package com.tfc_food_port;

import com.tfc_food_port.registry.TFCBlocks;
import com.tfc_food_port.registry.TFCComponents;
import com.tfc_food_port.registry.TFCCreativeTabs;
import com.tfc_food_port.registry.TFCItems;
import net.minecraft.resources.ResourceLocation;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;

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

        // Game tests are NOT registered here yet.
        //
        // 1.21.1 discovers them reflectively through @GameTestHolder on the test class rather than through a
        // registry filled at mod construction time, so there is no call to make. The tests themselves are excluded
        // from this module's compilation while they are ported; see the exclude in build.gradle.
    }

    /**
     * Namespaced id helper.
     *
     * 1.21.1 spells this {@link ResourceLocation}; the class was renamed to {@code Identifier} in a later version,
     * which is why the two targets differ here.
     */
    public static ResourceLocation id(String path)
    {
        return ResourceLocation.fromNamespaceAndPath(MOD_ID, path);
    }
}
