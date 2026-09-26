package com.tfc_food_port.registry;

import com.tfc_food_port.TFCFoodPort;
import com.tfc_food_port.common.crop.Berry;
import com.tfc_food_port.common.crop.Crop;
import com.tfc_food_port.common.food.Food;
import com.tfc_food_port.common.food.Mooncake;
import java.util.function.Supplier;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.level.ItemLike;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class TFCCreativeTabs
{
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, TFCFoodPort.MOD_ID);

    public static final Supplier<CreativeModeTab> FOOD = TABS.register("food", () -> CreativeModeTab.builder()
        .title(Component.translatable("itemGroup.tfc_food_port.food"))
        .icon(() -> TFCItems.get(Food.WHEAT_BREAD).get().getDefaultInstance())
        .displayItems((parameters, output) -> {
            for (final Crop crop : Crop.values())
            {
                output.accept((ItemLike) TFCItems.getSeed(crop).get());
            }
            // No saplings here on purpose: a fruit is its own seed, so saplings have no item at all.
            // Leaves are here, because shears and Silk Touch collect them as blocks.
            for (final Food food : Food.values())
            {
                output.accept((ItemLike) TFCItems.get(food).get());
            }
            for (final Berry berry : Berry.treeFruits())
            {
                output.accept((ItemLike) TFCItems.getLeaves(berry).get());
            }
            // the mooncakes, last so they sit at the end of the tab next to the barrel. The unbaked ones come
            // first, so the tab reads as the order they are made in.
            for (final Mooncake mooncake : Mooncake.values())
            {
                output.accept((ItemLike) TFCItems.getRawMooncake(mooncake).get());
            }
            for (final Mooncake mooncake : Mooncake.values())
            {
                output.accept((ItemLike) TFCItems.getMooncake(mooncake).get());
            }
            output.accept((ItemLike) TFCItems.RENNET.get());
            output.accept((ItemLike) TFCItems.BARREL.get());
        })
        .build());

    private TFCCreativeTabs() {}
}
