package com.tfc_food_port.common.block;

import com.tfc_food_port.common.crop.Crop;
import com.tfc_food_port.registry.TFCItems;
import net.minecraft.core.BlockPos;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.ItemInteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.ItemLike;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.CropBlock;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

/**
 * A vanilla {@link CropBlock} driven by a {@link Crop}.
 *
 * Growth needs nothing but farmland, nearby water and light - exactly like vanilla wheat. The only additions are
 * per-crop growth stages and, for pickable crops (tomato, bell peppers), a right click harvest that does not
 * destroy the plant.
 */
public class TFCCropBlock extends CropBlock
{
    private static final VoxelShape[] SHAPE_BY_AGE = new VoxelShape[] {
        Block.box(0.0, 0.0, 0.0, 16.0, 2.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 3.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 4.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 5.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 6.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 7.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 8.0, 16.0),
        Block.box(0.0, 0.0, 0.0, 16.0, 9.0, 16.0)
    };

    private final Crop crop;

    public TFCCropBlock(BlockBehaviour.Properties properties, Crop crop)
    {
        super(properties);
        this.crop = crop;
    }

    public Crop getCrop()
    {
        return crop;
    }

    @Override
    public int getMaxAge()
    {
        return crop.maxAge();
    }

    @Override
    protected ItemLike getBaseSeedId()
    {
        return TFCItems.getSeed(crop).get();
    }

    @Override
    public VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context)
    {
        return SHAPE_BY_AGE[Math.min(getAge(state), SHAPE_BY_AGE.length - 1)];
    }

    @Override
    protected ItemInteractionResult useItemOn(ItemStack stack, BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hitResult)
    {
        if (!crop.isPickable() || getAge(state) < crop.maxAge())
        {
            return super.useItemOn(stack, state, level, pos, player, hand, hitResult);
        }

        if (level.isClientSide())
        {
            return ItemInteractionResult.SUCCESS;
        }

        // Harvest without destroying the plant, then let it regrow
        Block.popResource(level, pos, new ItemStack(crop.product()));
        level.playSound(null, pos, SoundEvents.CROP_BREAK, SoundSource.BLOCKS, 1.0F, 1.0F);
        level.setBlock(pos, getStateForAge(crop.regrowAge()), 2);
        // No separate server-side success constant on this version; SUCCESS is the whole story.
        return ItemInteractionResult.SUCCESS;
    }
}
