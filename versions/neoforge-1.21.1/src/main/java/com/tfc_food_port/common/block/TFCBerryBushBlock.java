package com.tfc_food_port.common.block;

import com.mojang.serialization.MapCodec;
import com.mojang.serialization.codecs.RecordCodecBuilder;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.BonemealableBlock;
import net.minecraft.world.level.block.BushBlock;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.neoforged.neoforge.common.CommonHooks;

/**
 * A pickable bush in the style of vanilla sweet berries, used for every berry and fruit in this port.
 *
 * It grows on dirt, grass or farmland, needs light, is harvested by right clicking once fully grown (which resets
 * it to a partly grown state so it regrows) and drops itself when broken so it can be replanted.
 *
 * Modelled on the vanilla sweet berry bush, which is the reference implementation of a {@link BushBlock} with a
 * configurable harvest item. This base class is called VegetationBlock from 1.21.5 onwards, which is why the two
 * targets name it differently.
 */
public class TFCBerryBushBlock extends BushBlock implements BonemealableBlock
{
    public static final MapCodec<TFCBerryBushBlock> CODEC = RecordCodecBuilder.mapCodec(
        builder -> builder.group(
            BuiltInRegistries.ITEM.holderByNameCodec().fieldOf("fruit").forGetter(block -> block.fruit),
            propertiesCodec()
        ).apply(builder, TFCBerryBushBlock::new)
    );

    public static final int MAX_AGE = 3;
    public static final IntegerProperty AGE = BlockStateProperties.AGE_3;

    private static final VoxelShape[] SHAPE_BY_AGE = new VoxelShape[] {
        Block.box(3.0, 0.0, 3.0, 13.0, 5.0, 13.0),
        Block.box(2.0, 0.0, 2.0, 14.0, 9.0, 14.0),
        Block.box(1.0, 0.0, 1.0, 15.0, 13.0, 15.0),
        Block.box(1.0, 0.0, 1.0, 15.0, 14.0, 15.0)
    };

    /**
     * The berry or fruit picked from this bush; also how the block is serialised.
     *
     * This must be the harvest item's holder, NOT the bush's own block item - using the block item here made a ripe
     * bush hand back another bush when picked.
     */
    public final Holder<Item> fruit;

    public TFCBerryBushBlock(Holder<Item> fruit, BlockBehaviour.Properties properties)
    {
        super(properties);
        this.fruit = fruit;
        registerDefaultState(stateDefinition.any().setValue(AGE, 0));
    }

    public IntegerProperty getAgeProperty()
    {
        return AGE;
    }

    public int getAge(BlockState state)
    {
        return state.getValue(AGE);
    }

    public BlockState getStateForAge(int age)
    {
        return defaultBlockState().setValue(AGE, age);
    }

    public boolean isMaxAge(BlockState state)
    {
        return getAge(state) >= MAX_AGE;
    }

    @Override
    public MapCodec<TFCBerryBushBlock> codec()
    {
        return CODEC;
    }

    @Override
    public VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context)
    {
        return SHAPE_BY_AGE[Math.min(getAge(state), SHAPE_BY_AGE.length - 1)];
    }

    /**
     * Bushes grow on any vegetation-supporting block: grass, dirt, coarse dirt, podzol, farmland and friends.
     *
     * 1.21.1 has no {@code #minecraft:supports_vegetation}; that tag, and the {@code VegetationBlock} that uses it,
     * arrived later. Here the equivalent is {@link BlockTags#DIRT}, which is what this version's own {@code BushBlock}
     * checks.
     */
    @Override
    protected boolean mayPlaceOn(BlockState state, BlockGetter level, BlockPos pos)
    {
        return state.is(BlockTags.DIRT);
    }

    @Override
    public boolean isRandomlyTicking(BlockState state)
    {
        return !isMaxAge(state);
    }

    @Override
    public void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random)
    {
        if (level.isAreaLoaded(pos, 1) && level.getRawBrightness(pos, 0) >= 9)
        {
            final int age = getAge(state);
            if (age < MAX_AGE && CommonHooks.canCropGrow(level, pos, state, random.nextInt(5) == 0))
            {
                level.setBlockAndUpdate(pos, getStateForAge(age + 1));
                CommonHooks.fireCropGrowPost(level, pos, state);
            }
        }
    }

    @Override
    public InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hitResult)
    {
        if (!isMaxAge(state))
        {
            return super.useWithoutItem(state, level, pos, player, hitResult);
        }

        if (level.isClientSide())
        {
            return InteractionResult.SUCCESS;
        }

        final int count = 1 + level.getRandom().nextInt(2);
        Block.popResource(level, pos, new ItemStack(fruit.value(), count));
        level.playSound(null, pos, SoundEvents.SWEET_BERRY_BUSH_PICK_BERRIES, SoundSource.BLOCKS, 1.0F, 0.8F + level.getRandom().nextFloat() * 0.4F);
        // Leave the bush partly grown so it can be picked again later
        level.setBlock(pos, getStateForAge(1), 2);
        // 1.21.1's InteractionResult is an enum without a separate server-side success, so a handled interaction
        // is SUCCESS. The server-only distinction arrived with the later interaction rework.
        return InteractionResult.SUCCESS;
    }

    // 1.21.1 takes three arguments here; the trailing "includeData" flag is a later addition. The base method is
    // public on this version, so the override cannot narrow it to protected.
    @Override
    public ItemStack getCloneItemStack(LevelReader level, BlockPos pos, BlockState state)
    {
        return new ItemStack(this);
    }

    // ---- bone meal ---------------------------------------------------------------------------------------------

    /** Bone meal only does something while the bush can still grow, just like vanilla sweet berries. */
    @Override
    public boolean isValidBonemealTarget(LevelReader level, BlockPos pos, BlockState state)
    {
        return !isMaxAge(state);
    }

    @Override
    public boolean isBonemealSuccess(Level level, RandomSource random, BlockPos pos, BlockState state)
    {
        return true;
    }

    /** Advances the bush by one growth stage. */
    @Override
    public void performBonemeal(ServerLevel level, RandomSource random, BlockPos pos, BlockState state)
    {
        level.setBlock(pos, getStateForAge(Math.min(MAX_AGE, getAge(state) + 1)), 2);
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
    {
        builder.add(AGE);
    }
}

