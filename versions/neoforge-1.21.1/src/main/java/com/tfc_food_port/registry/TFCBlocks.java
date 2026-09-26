package com.tfc_food_port.registry;

import com.tfc_food_port.TFCFoodPort;
import com.tfc_food_port.common.block.BarrelBlock;
import com.tfc_food_port.common.block.TFCBerryBushBlock;
import com.tfc_food_port.common.block.TFCCropBlock;
import com.tfc_food_port.common.block.TFCLeavesBlock;
import com.tfc_food_port.common.block.TFCPalmFruitBlock;
import com.tfc_food_port.common.blockentity.BarrelBlockEntity;
import com.tfc_food_port.common.crop.Berry;
import com.tfc_food_port.common.crop.Crop;
import java.util.EnumMap;
import java.util.Map;
import java.util.function.Supplier;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.block.SaplingBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraft.world.level.material.PushReaction;
import net.neoforged.neoforge.registries.DeferredBlock;
import net.neoforged.neoforge.registries.DeferredRegister;

/**
 * Block and block entity registration.
 *
 * Crops are registered without a block item (like vanilla wheat): the seed item is their only item form.
 * Trees use a vanilla {@link SaplingBlock} driven by each fruit's own tree grower, so only the leaves are custom -
 * the trunks are plain vanilla oak logs, as requested.
 */
public final class TFCBlocks
{
    public static final DeferredRegister.Blocks BLOCKS = DeferredRegister.createBlocks(TFCFoodPort.MOD_ID);
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES =
        DeferredRegister.create(BuiltInRegistries.BLOCK_ENTITY_TYPE, TFCFoodPort.MOD_ID);

    // 1.21.1's registerBlock takes the properties INSTANCE as its third argument; the later API takes a supplier.
    // That is the whole reason every call site below passes a finished properties object rather than a method
    // reference to a builder.
    public static final DeferredBlock<BarrelBlock> BARREL = BLOCKS.registerBlock(
        "barrel",
        BarrelBlock::new,
        BlockBehaviour.Properties.of()
            .mapColor(MapColor.WOOD)
            .strength(2.0F)
            .sound(SoundType.WOOD)
            .ignitedByLava()
    );

    // 1.21.1 has no two argument BlockEntityType constructor: it is (supplier, Set<Block>, dataType). The builder
    // sets the set for you, and the data type is null for blocks that carry no stored-schema upgrades.
    public static final Supplier<BlockEntityType<BarrelBlockEntity>> BARREL_ENTITY = BLOCK_ENTITIES.register(
        "barrel",
        () -> BlockEntityType.Builder.of(BarrelBlockEntity::new, BARREL.get()).build(null)
    );

    private static final Map<Crop, DeferredBlock<TFCCropBlock>> CROPS = new EnumMap<>(Crop.class);
    private static final Map<Berry, DeferredBlock<TFCBerryBushBlock>> BUSHES = new EnumMap<>(Berry.class);
    private static final Map<Berry, DeferredBlock<SaplingBlock>> SAPLINGS = new EnumMap<>(Berry.class);
    private static final Map<Berry, DeferredBlock<TFCLeavesBlock>> LEAVES = new EnumMap<>(Berry.class);
    private static final Map<Berry, DeferredBlock<TFCPalmFruitBlock>> TRUNK_FRUITS = new EnumMap<>(Berry.class);

    static
    {
        for (final Crop crop : Crop.values())
        {
            CROPS.put(crop, BLOCKS.registerBlock(crop.cropPath(), properties -> new TFCCropBlock(properties, crop), cropProperties()));
        }

        for (final Berry berry : Berry.bushBerries())
        {
            // The bush is constructed with its HARVEST item holder (the berry), not its own block item.
            // Passing the block item here made a picked bush hand back another bush instead of fruit.
            // The holder is the lazy DeferredItem, so no item has to be resolved during block registration.
            BUSHES.put(berry, BLOCKS.registerBlock(
                berry.bushPath(),
                properties -> new TFCBerryBushBlock(TFCItems.get(berry.food()), properties),
                bushProperties()));
        }

        for (final Berry berry : Berry.treeFruits())
        {
            // A plain vanilla SaplingBlock, but with this fruit's own tree grower, so bonemeal and random ticks
            // grow the tree feature defined in <name>_tree.json (oak trunk, our leaves).
            // Saplings deliberately have no item: the fruit is the seed, so the sapling block is only ever reached
            // by planting a fruit, which keeps the sapling hidden from the creative menu and JEI.
            SAPLINGS.put(berry, BLOCKS.registerBlock(
                berry.saplingPath(),
                properties -> new SaplingBlock(berry.treeGrower(), properties),
                saplingProperties()));

            LEAVES.put(berry, BLOCKS.registerBlock(berry.leavesPath(), TFCLeavesBlock::new, leavesProperties()));

            if (berry.hasTrunkFruit())
            {
                TRUNK_FRUITS.put(berry, BLOCKS.registerBlock(berry.trunkFruitPath(), TFCPalmFruitBlock::new, trunkFruitProperties()));
            }
        }
    }

    private TFCBlocks() {}

    public static DeferredBlock<TFCCropBlock> getCrop(Crop crop)
    {
        return CROPS.get(crop);
    }

    public static DeferredBlock<TFCBerryBushBlock> getBush(Berry berry)
    {
        return BUSHES.get(berry);
    }

    public static DeferredBlock<SaplingBlock> getSapling(Berry berry)
    {
        return SAPLINGS.get(berry);
    }

    public static DeferredBlock<TFCLeavesBlock> getLeaves(Berry berry)
    {
        return LEAVES.get(berry);
    }

    /** The trunk-hugging fruit block; only banana has one. */
    public static DeferredBlock<TFCPalmFruitBlock> getTrunkFruit(Berry berry)
    {
        return TRUNK_FRUITS.get(berry);
    }

    private static BlockBehaviour.Properties trunkFruitProperties()
    {
        return BlockBehaviour.Properties.of()
            .mapColor(MapColor.PLANT)
            .randomTicks()
            .strength(0.2F)
            .sound(SoundType.WOOD)
            .noOcclusion()
            .pushReaction(PushReaction.DESTROY);
    }

    private static BlockBehaviour.Properties saplingProperties()
    {
        return BlockBehaviour.Properties.of()
            .mapColor(MapColor.PLANT)
            // 1.21.1 spells this noCollission. The double 's' was fixed in a later version, so this is a genuine
            // difference between the two targets rather than a typo.
            .noCollission()
            .randomTicks()
            .instabreak()
            .sound(SoundType.GRASS)
            .pushReaction(PushReaction.DESTROY);
    }

    private static BlockBehaviour.Properties leavesProperties()
    {
        return BlockBehaviour.Properties.of()
            .mapColor(MapColor.PLANT)
            .strength(0.2F)
            .randomTicks()
            .sound(SoundType.GRASS)
            .noOcclusion()
            .isValidSpawn((state, level, pos, type) -> type == net.minecraft.world.entity.EntityType.OCELOT)
            .isSuffocating((state, level, pos) -> false)
            .isViewBlocking((state, level, pos) -> false)
            .ignitedByLava()
            .pushReaction(PushReaction.DESTROY);
    }

    private static BlockBehaviour.Properties cropProperties()
    {
        return BlockBehaviour.Properties.of()
            .mapColor(MapColor.PLANT)
            .noCollission()
            .randomTicks()
            .instabreak()
            .sound(SoundType.CROP)
            .pushReaction(PushReaction.DESTROY);
    }

    private static BlockBehaviour.Properties bushProperties()
    {
        return BlockBehaviour.Properties.of()
            .mapColor(MapColor.PLANT)
            .noCollission()
            .randomTicks()
            .strength(0.2F)
            .sound(SoundType.SWEET_BERRY_BUSH)
            .pushReaction(PushReaction.DESTROY);
    }
}
