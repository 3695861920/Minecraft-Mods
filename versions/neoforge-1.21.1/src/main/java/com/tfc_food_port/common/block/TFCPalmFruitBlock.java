package com.tfc_food_port.common.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.RandomSource;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.BonemealableBlock;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.phys.shapes.CollisionContext;
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

    /**
     * Same geometry as a cocoa pod, widening as it ripens, so it reads as hanging off the log.
     *
     * These are vanilla cocoa's own four arrays, copied literally. 1.21.1 has no shape rotation helper - no
     * {@code Shapes.rotateHorizontal} and no {@code Block.column} - so the four facings are four hand written boxes
     * rather than one box rotated at load time. Copying the numbers from {@code CocoaBlock} also guarantees the two
     * pods line up visually.
     */
    private static final VoxelShape[] NORTH_SHAPES = new VoxelShape[] {
        Block.box(6.0, 7.0, 1.0, 10.0, 12.0, 5.0),
        Block.box(5.0, 5.0, 1.0, 11.0, 12.0, 7.0),
        Block.box(4.0, 3.0, 1.0, 12.0, 12.0, 9.0)
    };
    private static final VoxelShape[] SOUTH_SHAPES = new VoxelShape[] {
        Block.box(6.0, 7.0, 11.0, 10.0, 12.0, 15.0),
        Block.box(5.0, 5.0, 9.0, 11.0, 12.0, 15.0),
        Block.box(4.0, 3.0, 7.0, 12.0, 12.0, 15.0)
    };
    private static final VoxelShape[] WEST_SHAPES = new VoxelShape[] {
        Block.box(1.0, 7.0, 6.0, 5.0, 12.0, 10.0),
        Block.box(1.0, 5.0, 5.0, 7.0, 12.0, 11.0),
        Block.box(1.0, 3.0, 4.0, 9.0, 12.0, 12.0)
    };
    private static final VoxelShape[] EAST_SHAPES = new VoxelShape[] {
        Block.box(11.0, 7.0, 6.0, 15.0, 12.0, 10.0),
        Block.box(9.0, 5.0, 5.0, 15.0, 12.0, 11.0),
        Block.box(7.0, 3.0, 4.0, 15.0, 12.0, 12.0)
    };

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
        final int age = Math.min(state.getValue(AGE), MAX_AGE);

        return switch (state.getValue(FACING))
        {
            case SOUTH -> SOUTH_SHAPES[age];
            case WEST -> WEST_SHAPES[age];
            case EAST -> EAST_SHAPES[age];
            default -> NORTH_SHAPES[age];
        };
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

    /**
     * Re-checks support on any neighbour change, and drops off when the leaves go away - which is what vanilla
     * cocoa does when its log is removed.
     *
     * 1.21.1 declares this as the classic six argument {@code updateShape(BlockState, Direction, BlockState,
     * LevelAccessor, BlockPos, BlockPos)}. The later versions replaced it with a wider form that also receives the
     * scheduled tick access and a random source, which is the only reason this signature differs from 26.1.2.
     */
    @Override
    protected BlockState updateShape(BlockState state, Direction directionToNeighbour, BlockState neighbourState,
                                     LevelAccessor level, BlockPos pos, BlockPos neighbourPos)
    {
        return !state.canSurvive(level, pos)
            ? Blocks.AIR.defaultBlockState()
            : super.updateShape(state, directionToNeighbour, neighbourState, level, pos, neighbourPos);
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
