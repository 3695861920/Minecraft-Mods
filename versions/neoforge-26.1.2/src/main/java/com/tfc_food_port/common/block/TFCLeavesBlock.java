package com.tfc_food_port.common.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.LeavesBlock;

/**
 * Leaves for the ported fruit trees.
 *
 * Vanilla {@link LeavesBlock} already handles everything that matters: the {@code distance} property so leaves decay
 * when the trunk is removed, waterlogging, and shears support. Only a codec and the falling-leaf particles have to
 * be supplied; the texture comes from the blockstate/model.
 *
 * What makes these worth having is the loot table: breaking them drops the tree's fruit, which is the only way to
 * harvest apples, oranges and friends.
 */
public class TFCLeavesBlock extends LeavesBlock
{
    public static final MapCodec<TFCLeavesBlock> CODEC = simpleCodec(TFCLeavesBlock::new);

    public TFCLeavesBlock(Properties properties)
    {
        super(0.01F, properties);
    }

    @Override
    public MapCodec<TFCLeavesBlock> codec()
    {
        return CODEC;
    }

    /** Falling leaf particles, just like vanilla leaves (and just as invisible without a texture). */
    @Override
    protected void spawnFallingLeavesParticle(Level level, BlockPos pos, RandomSource random)
    {
        // Intentionally empty: this port ships no custom particle type, so leaves simply do not shed particles.
    }
}
