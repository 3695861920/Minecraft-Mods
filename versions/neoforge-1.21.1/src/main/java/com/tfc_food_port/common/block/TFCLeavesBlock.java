package com.tfc_food_port.common.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.world.level.block.LeavesBlock;

/**
 * Leaves for the ported fruit trees.
 *
 * Vanilla {@link LeavesBlock} already handles everything that matters: the {@code distance} property so leaves decay
 * when the trunk is removed, waterlogging, and shears support. Only a codec has to be supplied; the texture comes
 * from the blockstate/model.
 *
 * What makes these worth having is the loot table: breaking them drops the tree's fruit and, with shears or Silk
 * Touch, the leaf block itself.
 *
 * 26.1.2 declares an abstract {@code spawnFallingLeavesParticle} that a subclass must implement. 1.21.1 has no such
 * method, so there is nothing to override and the class is smaller here.
 */
public class TFCLeavesBlock extends LeavesBlock
{
    public static final MapCodec<TFCLeavesBlock> CODEC = simpleCodec(TFCLeavesBlock::new);

    // 1.21.1's LeavesBlock takes only the properties. The leading float - the leaf particle chance - was added in a
    // later version, which is why the port loses falling-leaf particles. Nothing else depends on it.
    public TFCLeavesBlock(Properties properties)
    {
        super(properties);
    }

    @Override
    public MapCodec<TFCLeavesBlock> codec()
    {
        return CODEC;
    }
}
