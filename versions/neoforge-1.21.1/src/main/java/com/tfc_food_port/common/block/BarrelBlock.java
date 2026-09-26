package com.tfc_food_port.common.block;

import com.tfc_food_port.common.blockentity.BarrelBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.ItemInteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.EntityBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.fluids.FluidUtil;

/**
 * The barrel: a plain block with no block state properties, backed by a {@link BarrelBlockEntity} fluid tank.
 *
 * There is no GUI and no sealing. Right clicking with a fluid container (bucket of water, milk, ...) moves fluid
 * between the container and the barrel; anything else falls through to the vanilla interaction.
 * Handing this off to {@link FluidUtil#interactWithFluidHandler} gives exactly the requested rules:
 * <ul>
 *     <li>empty container + barrel with fluid -&gt; take out a bucket's worth, or whatever is left</li>
 *     <li>filled container + empty or matching barrel -&gt; put in a bucket's worth, or whatever still fits</li>
 *     <li>anything else -&gt; no reaction</li>
 * </ul>
 *
 * Two things differ from 26.1.2 here. The item capability is {@code Capabilities.FluidHandler.ITEM} rather than
 * {@code Capabilities.Fluid.ITEM}, and it is reached through {@code stack.getCapability(...)} - the 1.21.1 form -
 * rather than through the transfer API's {@code ItemAccess.forStack(...)}. The interaction call is otherwise the
 * same, minus the transaction 26.1.2 requires.
 */
public class BarrelBlock extends Block implements EntityBlock
{
    /** Matches the 2..14 wide barrel model, so selection and collision line up with what is drawn. */
    private static final VoxelShape SHAPE = Block.box(2.0, 0.0, 2.0, 14.0, 16.0, 14.0);

    public BarrelBlock(Properties properties)
    {
        super(properties);
    }

    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state)
    {
        return new BarrelBlockEntity(pos, state);
    }

    @Override
    public VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context)
    {
        return SHAPE;
    }

    @Override
    protected ItemInteractionResult useItemOn(ItemStack stack, BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hitResult)
    {
        if (!(level.getBlockEntity(pos) instanceof BarrelBlockEntity))
        {
            return ItemInteractionResult.PASS_TO_DEFAULT_BLOCK_INTERACTION;
        }

        if (!isFluidContainer(stack))
        {
            return ItemInteractionResult.PASS_TO_DEFAULT_BLOCK_INTERACTION;
        }

        if (level.isClientSide())
        {
            // The transfer is server authoritative; the client only needs to know that the click was used.
            return ItemInteractionResult.SUCCESS;
        }

        // 1.21.1 has no transaction to thread through, and its InteractionResult is an enum without the
        // server/client split 26.1.2 introduced, so a handled interaction is simply SUCCESS.
        return FluidUtil.interactWithFluidHandler(player, hand, level, pos, hitResult.getDirection())
            ? ItemInteractionResult.SUCCESS
            : ItemInteractionResult.PASS_TO_DEFAULT_BLOCK_INTERACTION;
    }

    private static boolean isFluidContainer(ItemStack stack)
    {
        return !stack.isEmpty() && stack.getCapability(Capabilities.FluidHandler.ITEM) != null;
    }
}
