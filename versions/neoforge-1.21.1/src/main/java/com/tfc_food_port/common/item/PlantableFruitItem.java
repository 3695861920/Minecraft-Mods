package com.tfc_food_port.common.item;

import java.util.function.Supplier;
import net.minecraft.core.BlockPos;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockState;

/**
 * A fruit that is also a seed, and knows two ways to be planted.
 *
 * Using it on the side of a leaf plants {@code onLeaves} - the hanging fruit block - so a banana can be re-planted
 * in the canopy the way cocoa is planted on a trunk. Anything else falls through to normal {@link BlockItem}
 * behaviour, which plants {@code ground} (the sapling), so the same item also starts a new tree.
 *
 * Leaves, not logs, is the right test: the bunch hangs off the canopy, and the palm's trunk is a plain oak log
 * that a bunch would not survive on.
 */
public class PlantableFruitItem extends BlockItem
{
    private final Supplier<Block> onLeaves;

    public PlantableFruitItem(Block ground, Supplier<Block> onLeaves, Properties properties)
    {
        super(ground, properties);
        this.onLeaves = onLeaves;
    }

    @Override
    public InteractionResult useOn(UseOnContext context)
    {
        final Level level = context.getLevel();
        final BlockPos clicked = context.getClickedPos();

        // planting into the canopy takes priority, but only when it would actually succeed
        if (level.getBlockState(clicked).is(BlockTags.LEAVES))
        {
            final BlockPlaceContext placeContext = new BlockPlaceContext(context);
            final BlockPos placePos = placeContext.getClickedPos();
            final BlockState state = onLeaves.get().getStateForPlacement(placeContext);

            if (state != null && state.canSurvive(level, placePos) && level.getBlockState(placePos).canBeReplaced(placeContext))
            {
                if (!level.isClientSide())
                {
                    level.setBlock(placePos, state, Block.UPDATE_ALL);
                    level.playSound(null, placePos, SoundType.GRASS.getPlaceSound(), SoundSource.BLOCKS,
                        (SoundType.GRASS.getVolume() + 1.0F) / 2.0F, SoundType.GRASS.getPitch() * 0.8F);

                    final Player player = context.getPlayer();
                    final ItemStack stack = context.getItemInHand();
                    if (player == null || !player.isCreative())
                    {
                        stack.shrink(1);
                    }
                }
                return InteractionResult.SUCCESS;
            }
        }

        return super.useOn(context);
    }
}
