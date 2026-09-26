package com.tfc_food_port.common.block;

import com.mojang.serialization.MapCodec;
import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.RandomSource;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.ScheduledTickAccess;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.BonemealableBlock;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.neoforged.neoforge.common.CommonHooks;
import org.jetbrains.annotations.Nullable;

/**
 * A fruit that grows stuck to the side of a tree trunk, exactly like vanilla cocoa.
 *
 * This is how the banana is grown: the palm's trunk is a plain oak log, and the bananas hang off its side. Plant one
 * by using a banana on a log, let it ripen, then break it to harvest. Growing needs nothing but the trunk and
 * random ticks, and bone meal speeds it up, matching cocoa's behaviour.
 *
 * Modelled directly on {@link net.minecraft.world.level.block.CocoaBlock}.
 */
public class TFCPalmFruitBlock extends HorizontalDirectionalBlock implements BonemealableBlock
{
    public static final MapCodec<TFCPalmFruitBlock> CODEC = simpleCodec(TFCPalmFruitBlock::new);
    public static final int MAX_AGE = 2;
    public static final IntegerProperty AGE = BlockStateProperties.AGE_2;

    /** Same geometry as a cocoa pod, widening as it ripens, so it reads as hanging off the log. */
    private static final List<Map<Direction, VoxelShape>> SHAPES = IntStream.rangeClosed(0, MAX_AGE)
        .mapToObj(age -> Shapes.rotateHorizontal(
            Block.column(4 + age * 2, 7 - age * 2, 12.0).move(0.0, 0.0, (age - 5) / 16.0).optimize()))
        .toList();

    public TFCPalmFruitBlock(BlockBehaviour.Properties properties)
    {
        super(properties);
        registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(AGE, 0));
    }

    @Override
    public MapCodec<TFCPalmFruitBlock> codec()
    {
        return CODEC;
    }

    @Override
    protected boolean isRandomlyTicking(BlockState state)
    {
        return state.getValue(AGE) < MAX_AGE;
    }

    @Override
    protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random)
    {
        final int age = state.getValue(AGE);
        if (age < MAX_AGE && CommonHooks.canCropGrow(level, pos, state, random.nextInt(5) == 0))
        {
            level.setBlock(pos, state.setValue(AGE, age + 1), 2);
            CommonHooks.fireCropGrowPost(level, pos, state);
        }
    }

    /**
     * The fruit hangs from the canopy: it needs leaves in at least one neighbouring block.
     *
     * All six neighbours are accepted rather than only the two on the facing axis, because the two ways a bunch is
     * created disagree about orientation. Using a banana on a leaf gives a facing that points at the leaf, while world
     * generation (minecraft:attached_to_leaves) places the bunch one step away from a leaf using a fixed facing. A
     * facing-only check would let world generated bunches be deleted by {@link #updateShape} the moment they appear.
     */
    @Override
    protected boolean canSurvive(BlockState state, LevelReader level, BlockPos pos)
    {
        for (final Direction side : Direction.values())
        {
            if (isLeaves(level, pos, side, state))
            {
                return true;
            }
        }
        return false;
    }

    private static boolean isLeaves(LevelReader level, BlockPos pos, Direction side, BlockState self)
    {
        final BlockPos supportPos = pos.relative(side);
        final BlockState support = level.getBlockState(supportPos);
        final var soilDecision = support.canSustainPlant(level, supportPos, side.getOpposite(), self);
        if (!soilDecision.isDefault())
        {
            return soilDecision.isTrue();
        }
        return support.is(BlockTags.LEAVES);
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context)
    {
        return SHAPES.get(state.getValue(AGE)).get(state.getValue(FACING));
    }

    @Override
    public @Nullable BlockState getStateForPlacement(BlockPlaceContext context)
    {
        BlockState state = defaultBlockState();
        for (final Direction direction : context.getNearestLookingDirections())
        {
            if (direction.getAxis().isHorizontal())
            {
                state = state.setValue(FACING, direction);
                if (state.canSurvive(context.getLevel(), context.getClickedPos()))
                {
                    return state;
                }
            }
        }
        return null;
    }

    @Override
    protected BlockState updateShape(BlockState state, LevelReader level, ScheduledTickAccess ticks, BlockPos pos,
                                     Direction directionToNeighbour, BlockPos neighbourPos, BlockState neighbourState, RandomSource random)
    {
        // Re-check on any neighbour change, not just the facing one, because support can come from any side.
        // Dropping off when the leaves are removed is what vanilla cocoa does when its log goes away.
        return !state.canSurvive(level, pos)
            ? Blocks.AIR.defaultBlockState()
            : super.updateShape(state, level, ticks, pos, directionToNeighbour, neighbourPos, neighbourState, random);
    }

    @Override
    public boolean isValidBonemealTarget(LevelReader level, BlockPos pos, BlockState state)
    {
        return state.getValue(AGE) < MAX_AGE;
    }

    @Override
    public boolean isBonemealSuccess(net.minecraft.world.level.Level level, RandomSource random, BlockPos pos, BlockState state)
    {
        return true;
    }

    @Override
    public void performBonemeal(ServerLevel level, RandomSource random, BlockPos pos, BlockState state)
    {
        level.setBlock(pos, state.setValue(AGE, Math.min(MAX_AGE, state.getValue(AGE) + 1)), 2);
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
    {
        builder.add(FACING, AGE);
    }
}
