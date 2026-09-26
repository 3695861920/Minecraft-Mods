package com.tfc_food_port.gametest;

import com.tfc_food_port.TFCFoodPort;
import com.tfc_food_port.common.block.TFCBerryBushBlock;
import com.tfc_food_port.common.block.TFCPalmFruitBlock;
import com.tfc_food_port.common.blockentity.BarrelBlockEntity;
import com.tfc_food_port.common.crop.Berry;
import com.tfc_food_port.common.crop.Crop;
import com.tfc_food_port.common.food.Food;
import com.tfc_food_port.common.food.Mooncake;
import com.tfc_food_port.registry.TFCBlocks;
import com.tfc_food_port.registry.TFCItems;
import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.gametest.framework.FunctionGameTestInstance;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.gametest.framework.TestData;
import net.minecraft.gametest.framework.TestEnvironmentDefinition;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.ProblemReporter;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.item.enchantment.Enchantments;
import net.minecraft.core.component.DataComponents;
import net.minecraft.tags.TagKey;
import net.minecraft.world.item.component.Consumable;
import net.minecraft.world.item.consume_effects.ApplyStatusEffectsConsumeEffect;
import net.minecraft.world.item.crafting.RecipeHolder;
import net.minecraft.world.item.crafting.RecipeManager;
import net.minecraft.world.item.crafting.RecipeType;
import net.minecraft.world.item.crafting.SingleRecipeInput;
import net.neoforged.fml.ModList;
import net.neoforged.neoforge.items.ItemStackHandler;
import net.neoforged.neoforge.items.wrapper.RecipeWrapper;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.BonemealableBlock;
import net.minecraft.world.level.block.CropBlock;
import net.minecraft.world.level.block.SaplingBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.material.Fluids;
import net.minecraft.world.level.storage.TagValueInput;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.event.RegisterGameTestsEvent;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.registries.DeferredRegister;
import net.neoforged.neoforge.transfer.ResourceHandler;
import net.neoforged.neoforge.transfer.fluid.FluidResource;
import net.neoforged.neoforge.transfer.transaction.Transaction;

/**
 * In-game tests.
 *
 * These run inside a real Minecraft server (started by {@code gradlew gameTestServer}), which is the only way to
 * prove registration, block entities, the fluid transfer API and genuine item interactions work together.
 * They caught the seeds being plain items with no placement behaviour, so they are worth keeping.
 */
public final class TFCFoodPortGameTests
{
    private static final DeferredRegister<Consumer<GameTestHelper>> TEST_FUNCTIONS =
        DeferredRegister.create(Registries.TEST_FUNCTION, TFCFoodPort.MOD_ID);

    private static final ResourceKey<Consumer<GameTestHelper>> SEEDS_PLANT_CROPS = functionKey("seeds_plant_crops");
    private static final ResourceKey<Consumer<GameTestHelper>> BUCKETS_FILL_BARREL = functionKey("buckets_fill_barrel");
    private static final ResourceKey<Consumer<GameTestHelper>> BUSHES_ARE_PLACEABLE = functionKey("bushes_are_placeable");
    private static final ResourceKey<Consumer<GameTestHelper>> BUCKET_ON_BARREL = functionKey("bucket_on_barrel");
    private static final ResourceKey<Consumer<GameTestHelper>> BARREL_FLUID_PERSISTS = functionKey("barrel_fluid_persists");
    private static final ResourceKey<Consumer<GameTestHelper>> BUSHES_TAKE_BONE_MEAL = functionKey("bushes_take_bone_meal");
    private static final ResourceKey<Consumer<GameTestHelper>> BUSHES_DROP_BERRIES_SOMETIMES = functionKey("bushes_drop_berries_sometimes");
    private static final ResourceKey<Consumer<GameTestHelper>> CROPS_DROP_PRODUCE_WHEN_RIPE = functionKey("crops_drop_produce_when_ripe");
    private static final ResourceKey<Consumer<GameTestHelper>> PICKING_A_BUSH_GIVES_FRUIT = functionKey("picking_a_bush_gives_fruit");
    private static final ResourceKey<Consumer<GameTestHelper>> TREE_LEAVES_DROP_FRUIT = functionKey("tree_leaves_drop_fruit");
    private static final ResourceKey<Consumer<GameTestHelper>> SAPLINGS_ARE_GROWABLE = functionKey("saplings_are_growable");
    private static final ResourceKey<Consumer<GameTestHelper>> BANANA_GROWS_ON_A_TRUNK = functionKey("banana_grows_on_a_trunk");
    private static final ResourceKey<Consumer<GameTestHelper>> BANANA_PALM_GROWS_LEAVES_AND_FRUIT = functionKey("banana_palm_grows_leaves_and_fruit");
    private static final ResourceKey<Consumer<GameTestHelper>> BUSHES_PLANT_ON_SOIL = functionKey("bushes_plant_on_soil");
    private static final ResourceKey<Consumer<GameTestHelper>> LEAVES_CAN_BE_SHEARED = functionKey("leaves_can_be_sheared");
    private static final ResourceKey<Consumer<GameTestHelper>> MOONCAKES_GIVE_A_BUFF = functionKey("mooncakes_give_a_buff");
    private static final ResourceKey<Consumer<GameTestHelper>> MOONCAKES_BAKE_FROM_RAW = functionKey("mooncakes_bake_from_raw");
    private static final ResourceKey<Consumer<GameTestHelper>> SOUP_IS_NOT_A_CONFUSED_JAM = functionKey("soup_is_not_a_confused_jam");
    private static final ResourceKey<Consumer<GameTestHelper>> RECIPES_SWITCH_WITH_LOADED_MODS = functionKey("recipes_switch_with_loaded_mods");

    private TFCFoodPortGameTests() {}

    public static void register(IEventBus modEventBus)
    {
        // DeferredRegister only has register(String, Supplier), so the path is taken from the key itself
        TEST_FUNCTIONS.register(SEEDS_PLANT_CROPS.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::seedsPlantCrops);
        TEST_FUNCTIONS.register(BUCKETS_FILL_BARREL.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bucketsFillBarrel);
        TEST_FUNCTIONS.register(BUSHES_ARE_PLACEABLE.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bushesArePlaceable);
        TEST_FUNCTIONS.register(BUCKET_ON_BARREL.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bucketOnBarrel);
        TEST_FUNCTIONS.register(BARREL_FLUID_PERSISTS.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::barrelFluidPersists);
        TEST_FUNCTIONS.register(BUSHES_TAKE_BONE_MEAL.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bushesTakeBoneMeal);
        TEST_FUNCTIONS.register(BUSHES_DROP_BERRIES_SOMETIMES.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bushesDropBerriesSometimes);
        TEST_FUNCTIONS.register(CROPS_DROP_PRODUCE_WHEN_RIPE.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::cropsDropProduceWhenRipe);
        TEST_FUNCTIONS.register(PICKING_A_BUSH_GIVES_FRUIT.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::pickingABushGivesFruit);
        TEST_FUNCTIONS.register(TREE_LEAVES_DROP_FRUIT.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::treeLeavesDropFruit);
        TEST_FUNCTIONS.register(SAPLINGS_ARE_GROWABLE.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::saplingsAreGrowable);
        TEST_FUNCTIONS.register(BANANA_GROWS_ON_A_TRUNK.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bananaGrowsOnATrunk);
        TEST_FUNCTIONS.register(BANANA_PALM_GROWS_LEAVES_AND_FRUIT.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bananaPalmGrowsLeavesAndFruit);
        TEST_FUNCTIONS.register(BUSHES_PLANT_ON_SOIL.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::bushesPlantOnSoil);
        TEST_FUNCTIONS.register(LEAVES_CAN_BE_SHEARED.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::leavesCanBeSheared);
        TEST_FUNCTIONS.register(MOONCAKES_GIVE_A_BUFF.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::mooncakesGiveABuff);
        TEST_FUNCTIONS.register(MOONCAKES_BAKE_FROM_RAW.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::mooncakesBakeFromRaw);
        TEST_FUNCTIONS.register(SOUP_IS_NOT_A_CONFUSED_JAM.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::soupIsNotAConfusedJam);
        TEST_FUNCTIONS.register(RECIPES_SWITCH_WITH_LOADED_MODS.identifier().getPath(),
            () -> (Consumer<GameTestHelper>) TFCFoodPortGameTests::recipesSwitchWithLoadedMods);
        TEST_FUNCTIONS.register(modEventBus);
        modEventBus.addListener(TFCFoodPortGameTests::registerTests);
    }

    private static ResourceKey<Consumer<GameTestHelper>> functionKey(String name)
    {
        return ResourceKey.create(Registries.TEST_FUNCTION, TFCFoodPort.id(name));
    }

    private static void registerTests(RegisterGameTestsEvent event)
    {
        final Holder<TestEnvironmentDefinition<?>> environment =
            event.registerEnvironment(TFCFoodPort.id("core_environment"), new TestEnvironmentDefinition[0]);
        registerTest(event, environment, "seeds_plant_crops", SEEDS_PLANT_CROPS);
        registerTest(event, environment, "buckets_fill_barrel", BUCKETS_FILL_BARREL);
        registerTest(event, environment, "bushes_are_placeable", BUSHES_ARE_PLACEABLE);
        registerTest(event, environment, "bucket_on_barrel", BUCKET_ON_BARREL);
        registerTest(event, environment, "barrel_fluid_persists", BARREL_FLUID_PERSISTS);
        registerTest(event, environment, "bushes_take_bone_meal", BUSHES_TAKE_BONE_MEAL);
        registerTest(event, environment, "bushes_drop_berries_sometimes", BUSHES_DROP_BERRIES_SOMETIMES);
        registerTest(event, environment, "crops_drop_produce_when_ripe", CROPS_DROP_PRODUCE_WHEN_RIPE);
        registerTest(event, environment, "picking_a_bush_gives_fruit", PICKING_A_BUSH_GIVES_FRUIT);
        registerTest(event, environment, "tree_leaves_drop_fruit", TREE_LEAVES_DROP_FRUIT);
        registerTest(event, environment, "saplings_are_growable", SAPLINGS_ARE_GROWABLE);
        registerTest(event, environment, "banana_grows_on_a_trunk", BANANA_GROWS_ON_A_TRUNK);
        registerTest(event, environment, "banana_palm_grows_leaves_and_fruit", BANANA_PALM_GROWS_LEAVES_AND_FRUIT);
        registerTest(event, environment, "bushes_plant_on_soil", BUSHES_PLANT_ON_SOIL);
        registerTest(event, environment, "leaves_can_be_sheared", LEAVES_CAN_BE_SHEARED);
        registerTest(event, environment, "mooncakes_give_a_buff", MOONCAKES_GIVE_A_BUFF);
        registerTest(event, environment, "mooncakes_bake_from_raw", MOONCAKES_BAKE_FROM_RAW);
        registerTest(event, environment, "soup_is_not_a_confused_jam", SOUP_IS_NOT_A_CONFUSED_JAM);
        registerTest(event, environment, "recipes_switch_with_loaded_mods", RECIPES_SWITCH_WITH_LOADED_MODS);
    }

    private static void registerTest(RegisterGameTestsEvent event, Holder<TestEnvironmentDefinition<?>> environment,
                                     String name, ResourceKey<Consumer<GameTestHelper>> function)
    {
        // "minecraft:empty" is the built-in empty structure; each test below builds its own scene inside it
        final TestData<Holder<TestEnvironmentDefinition<?>>> data =
            new TestData<>(environment, Identifier.withDefaultNamespace("empty"), 100, 0, true);
        event.registerTest(TFCFoodPort.id(name), testData -> new FunctionGameTestInstance(function, testData), data);
    }

    // ---------------------------------------------------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------------------------------------------------

    /**
     * Every seed must actually be plantable. This is the check that caught the seeds being plain items with no
     * placement behaviour: right clicking farmland with a seed has to place that crop's block at age 0.
     */
    private static void seedsPlantCrops(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos farmland = new BlockPos(1, 2, 1);
        helper.setBlock(farmland, Blocks.FARMLAND);
        // water beside the farmland keeps it moist; glowstone supplies the light CropBlock.canSurvive asks for
        helper.setBlock(new BlockPos(0, 2, 1), Blocks.WATER);
        helper.setBlock(new BlockPos(1, 4, 1), Blocks.GLOWSTONE);

        final BlockPos plantingSpot = farmland.above();
        final Player player = helper.makeMockPlayer(GameType.SURVIVAL);

        for (final Crop crop : Crop.values())
        {
            final Block cropBlock = TFCBlocks.getCrop(crop).get();
            final ItemStack seeds = new ItemStack(TFCItems.getSeed(crop).get());

            helper.setBlock(plantingSpot, Blocks.AIR);
            player.setItemInHand(InteractionHand.MAIN_HAND, seeds);

            seeds.useOn(new UseOnContext(level, player, InteractionHand.MAIN_HAND, seeds,
                new BlockHitResult(Vec3.atCenterOf(helper.absolutePos(farmland)), Direction.UP, helper.absolutePos(farmland), false)));

            final BlockState planted = level.getBlockState(helper.absolutePos(plantingSpot));
            helper.assertTrue(planted.getBlock() == cropBlock,
                "Seed tfc_food_port:seeds/" + crop.getSerializedName() + " did not plant its crop; found " + planted);
            helper.assertTrue(planted.hasProperty(CropBlock.AGE) && planted.getValue(CropBlock.AGE) == 0,
                "Planted crop tfc_food_port:crop/" + crop.getSerializedName() + " is not at age 0: " + planted);
        }

        helper.succeed();
    }

    /**
     * The barrel is a plain fluid tank driven purely by the NeoForge transfer API, so verify a bucket's worth goes
     * in, comes back out, and that a second, different fluid is accepted as well (the tank is untyped).
     */
    private static void bucketsFillBarrel(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos barrelPos = new BlockPos(1, 2, 1);
        helper.setBlock(barrelPos, TFCBlocks.BARREL.get());

        helper.runAfterDelay(1, () -> {
            final BlockEntity blockEntity = level.getBlockEntity(helper.absolutePos(barrelPos));
            helper.assertTrue(blockEntity instanceof BarrelBlockEntity, "Barrel was placed without a block entity");

            final BarrelBlockEntity barrel = (BarrelBlockEntity) blockEntity;
            final ResourceHandler<FluidResource> tank = barrel.getTank();
            final FluidResource water = FluidResource.of(new FluidStack(Fluids.WATER, 1000));

            try (Transaction transaction = Transaction.openRoot())
            {
                final int inserted = tank.insert(water, 1000, transaction);
                helper.assertTrue(inserted == 1000, "Barrel accepted only " + inserted + " mB of water, expected 1000");
                transaction.commit();
            }

            helper.assertTrue(barrel.getFluid().getAmount() == 1000,
                "Barrel reports " + barrel.getFluid().getAmount() + " mB after filling, expected 1000");

            try (Transaction transaction = Transaction.openRoot())
            {
                final int drained = tank.extract(water, 1000, transaction);
                helper.assertTrue(drained == 1000, "Barrel gave back only " + drained + " mB, expected 1000");
                transaction.commit();
            }
            helper.assertTrue(barrel.getFluid().isEmpty(), "Barrel is not empty after draining");

            try (Transaction transaction = Transaction.openRoot())
            {
                final int lava = tank.insert(FluidResource.of(new FluidStack(Fluids.LAVA, 500)), 500, transaction);
                helper.assertTrue(lava == 500, "Barrel accepted only " + lava + " mB of lava, expected 500");
                transaction.commit();
            }

            helper.succeed();
        });
    }

    /** Bushes and saplings are placeable, so the berry/fruit and sapling items must place their block. */
    private static void bushesArePlaceable(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos ground = new BlockPos(1, 2, 1);
        helper.setBlock(ground, Blocks.DIRT);
        helper.setBlock(new BlockPos(1, 8, 1), Blocks.GLOWSTONE);

        final BlockPos spot = ground.above();
        final Player player = helper.makeMockPlayer(GameType.SURVIVAL);

        // a berry is its own seed and plants its bush
        for (final Berry berry : Berry.bushBerries())
        {
            final Block bushBlock = TFCBlocks.getBush(berry).get();
            final ItemStack berryItem = new ItemStack(TFCItems.get(berry.food()).get());

            helper.setBlock(spot, Blocks.AIR);
            player.setItemInHand(InteractionHand.MAIN_HAND, berryItem);
            berryItem.useOn(new UseOnContext(level, player, InteractionHand.MAIN_HAND, berryItem,
                new BlockHitResult(Vec3.atCenterOf(helper.absolutePos(ground)), Direction.UP, helper.absolutePos(ground), false)));

            helper.assertTrue(level.getBlockState(helper.absolutePos(spot)).getBlock() == bushBlock,
                "Berry " + berry.getSerializedName() + " did not plant its bush; found "
                    + level.getBlockState(helper.absolutePos(spot)));
        }

        // a tree fruit is plantable and always plants its sapling
        for (final Berry berry : Berry.treeFruits())
        {
            final Block saplingBlock = TFCBlocks.getSapling(berry).get();
            final ItemStack plantable = new ItemStack(TFCItems.get(berry.food()).get());

            helper.setBlock(spot, Blocks.AIR);
            player.setItemInHand(InteractionHand.MAIN_HAND, plantable);
            plantable.useOn(new UseOnContext(level, player, InteractionHand.MAIN_HAND, plantable,
                new BlockHitResult(Vec3.atCenterOf(helper.absolutePos(ground)), Direction.UP, helper.absolutePos(ground), false)));

            helper.assertTrue(level.getBlockState(helper.absolutePos(spot)).getBlock() == saplingBlock,
                plantable.getItem() + " did not plant the " + berry.getSerializedName() + " sapling; found "
                    + level.getBlockState(helper.absolutePos(spot)));
        }

        helper.succeed();
    }

    /**
     * The real player interaction: right clicking the barrel with a water bucket must pour it in, and right clicking
     * with an empty bucket must take it back out. This goes through the block's own {@code useItemOn}, which is what
     * the game calls, so it also proves the block entity capability is reachable from the block's interaction path.
     */
    private static void bucketOnBarrel(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos barrelPos = new BlockPos(1, 2, 1);
        helper.setBlock(barrelPos, TFCBlocks.BARREL.get());

        helper.runAfterDelay(1, () -> {
            final BlockPos absolute = helper.absolutePos(barrelPos);
            final BlockEntity blockEntity = level.getBlockEntity(absolute);
            helper.assertTrue(blockEntity instanceof BarrelBlockEntity, "Barrel was placed without a block entity");
            final BarrelBlockEntity barrel = (BarrelBlockEntity) blockEntity;

            final Player player = helper.makeMockPlayer(GameType.SURVIVAL);
            final BlockHitResult hit = new BlockHitResult(Vec3.atCenterOf(absolute), Direction.UP, absolute, false);
            final BlockState state = level.getBlockState(absolute);

            // pour a water bucket in
            final ItemStack waterBucket = new ItemStack(Items.WATER_BUCKET);
            player.setItemInHand(InteractionHand.MAIN_HAND, waterBucket);
            state.useItemOn(waterBucket, level, player, InteractionHand.MAIN_HAND, hit);

            helper.assertTrue(barrel.getFluid().getAmount() == 1000,
                "Right clicking the barrel with a water bucket left it holding " + barrel.getFluid().getAmount()
                    + " mB, expected 1000");
            helper.assertTrue(barrel.getFluid().getFluid() == Fluids.WATER, "Barrel is not holding water after the bucket was emptied into it");

            // and scoop it back out with an empty bucket
            final ItemStack emptyBucket = new ItemStack(Items.BUCKET);
            player.setItemInHand(InteractionHand.MAIN_HAND, emptyBucket);
            state.useItemOn(emptyBucket, level, player, InteractionHand.MAIN_HAND, hit);

            helper.assertTrue(barrel.getFluid().isEmpty(),
                "Right clicking the barrel with an empty bucket left " + barrel.getFluid().getAmount() + " mB behind");
            helper.assertTrue(player.getItemInHand(InteractionHand.MAIN_HAND).is(Items.WATER_BUCKET),
                "The empty bucket did not turn into a water bucket, got "
                    + player.getItemInHand(InteractionHand.MAIN_HAND));

            helper.succeed();
        });
    }

    /**
     * Fluid must survive a save/load cycle, otherwise it would vanish when the world is reloaded.
     * The block entity is serialised through the same NBT path the game uses and read back into a fresh instance.
     */
    private static void barrelFluidPersists(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos barrelPos = new BlockPos(1, 2, 1);
        helper.setBlock(barrelPos, TFCBlocks.BARREL.get());

        helper.runAfterDelay(1, () -> {
            final BlockPos absolute = helper.absolutePos(barrelPos);
            final BarrelBlockEntity barrel = (BarrelBlockEntity) level.getBlockEntity(absolute);
            helper.assertTrue(barrel != null, "Barrel was placed without a block entity");

            try (Transaction transaction = Transaction.openRoot())
            {
                tank(barrel).insert(FluidResource.of(new FluidStack(Fluids.WATER, 1000)), 1000, transaction);
                transaction.commit();
            }
            helper.assertTrue(barrel.getFluid().getAmount() == 1000, "Barrel did not accept the water before saving");

            // write the barrel out the way the game saves a chunk, then read it back into a fresh instance
            final CompoundTag saved = barrel.saveWithoutMetadata(level.registryAccess());
            helper.assertTrue(saved.contains("tank"),
                "The saved barrel data has no tank entry, so the fluid would be lost on reload: " + saved);

            final BarrelBlockEntity restored = new BarrelBlockEntity(absolute, level.getBlockState(absolute));
            restored.loadWithComponents(TagValueInput.create(ProblemReporter.DISCARDING, level.registryAccess(), saved));

            helper.assertTrue(restored.getFluid().getAmount() == 1000,
                "After a save/load cycle the barrel holds " + restored.getFluid().getAmount() + " mB, expected 1000");
            helper.assertTrue(restored.getFluid().getFluid() == Fluids.WATER, "After a save/load cycle the barrel is no longer holding water");

            helper.succeed();
        });
    }

    /** Bone meal must advance a bush exactly like it does for vanilla sweet berries. */
    private static void bushesTakeBoneMeal(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos ground = new BlockPos(1, 2, 1);
        helper.setBlock(ground, Blocks.DIRT);
        helper.setBlock(new BlockPos(1, 8, 1), Blocks.GLOWSTONE);

        final BlockPos spot = ground.above();
        final BlockState growing = TFCBlocks.getBush(Berry.BLACKBERRY).get().defaultBlockState();
        helper.setBlock(spot, growing);

        helper.assertTrue(growing.getBlock() instanceof BonemealableBlock,
            "The berry bush does not implement BonemealableBlock, so bone meal does nothing");
        final BonemealableBlock bonemealable = (BonemealableBlock) growing.getBlock();

        helper.assertTrue(bonemealable.isValidBonemealTarget(level, helper.absolutePos(spot), growing),
            "Bone meal is rejected on a bush that has not finished growing");

        bonemealable.performBonemeal(level, level.getRandom(), helper.absolutePos(spot), growing);

        final BlockState after = level.getBlockState(helper.absolutePos(spot));
        final int age = after.getValue(TFCBerryBushBlock.AGE);
        helper.assertTrue(age == 1, "Bone meal left the bush at age " + age + ", expected 1");

        // and a fully grown bush must refuse it
        helper.setBlock(spot, after.setValue(TFCBerryBushBlock.AGE, TFCBerryBushBlock.MAX_AGE));
        final BlockState full = level.getBlockState(helper.absolutePos(spot));
        helper.assertTrue(!bonemealable.isValidBonemealTarget(level, helper.absolutePos(spot), full),
            "Bone meal is accepted on a fully grown bush");

        helper.succeed();
    }

    private static ResourceHandler<FluidResource> tank(BarrelBlockEntity barrel)
    {
        return barrel.getTank();
    }

    /**
     * What tearing down a bush gives.
     *
     * A bush has no item of its own - the berry is the seed - and breaking one is a lottery rather than a harvest:
     * 5% of breaks give a berry by hand, and Fortune adds 5% per level, so a Fortune III tool makes it 20%. The
     * numbers are asserted over 400 breaks, which is why this test does not use a single bush:
     * {@link #fruitFromRepeatedBreaks} explains the arithmetic.
     *
     * The reward for actually farming berries is the hand harvest, which is covered separately and is guaranteed.
     */
    private static void bushesDropBerriesSometimes(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final Block bush = TFCBlocks.getBush(Berry.BLACKBERRY).get();
        final Item fruit = TFCItems.get(com.tfc_food_port.common.food.Food.BLACKBERRY).get();

        // ---- by hand: 5% of 400 breaks, i.e. about 20 berries ----
        final int byHand = fruitFromRepeatedBreaks(helper, bush, fruit, ItemStack.EMPTY);
        helper.assertTrue(byHand >= 1 && byHand <= 50,
            "400 bush breaks by hand gave " + byHand + " berries; 5% of 400 is about 20, so anything outside"
                + " 1..50 means the chance in the loot table is wrong");

        // ---- with Fortune III: 20% of 400, i.e. about 80 berries ----
        final int withFortune = fruitFromRepeatedBreaks(helper, bush, fruit, fortuneTool(level, 3));
        helper.assertTrue(withFortune >= 35 && withFortune <= 140,
            "400 bush breaks with Fortune III gave " + withFortune + " berries; 20% of 400 is about 80, so"
                + " anything outside 35..140 means Fortune is not reaching the loot table");

        helper.succeed();
    }

    /** Same question for crops: a fully grown crop must drop its produce, an immature one must not. */
    private static void cropsDropProduceWhenRipe(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos farmland = new BlockPos(1, 2, 1);
        helper.setBlock(farmland, Blocks.FARMLAND);

        final BlockPos spot = farmland.above();
        final BlockPos absolute = helper.absolutePos(spot);
        final com.tfc_food_port.common.block.TFCCropBlock wheat =
            (com.tfc_food_port.common.block.TFCCropBlock) TFCBlocks.getCrop(Crop.WHEAT).get();
        final Item produce = TFCItems.get(com.tfc_food_port.common.food.Food.WHEAT).get();
        final Item seeds = TFCItems.getSeed(Crop.WHEAT).get();

        // immature: seeds only
        helper.setBlock(spot, wheat.getStateForAge(0));
        final List<ItemStack> immature = Block.getDrops(level.getBlockState(absolute), level, absolute, null);
        helper.assertTrue(countOf(immature, produce) == 0,
            "An immature wheat crop dropped produce, drops were " + describe(immature));
        helper.assertTrue(countOf(immature, seeds) >= 1,
            "An immature wheat crop did not drop seeds, drops were " + describe(immature));

        // ripe: produce plus seeds
        helper.setBlock(spot, wheat.getStateForAge(wheat.getMaxAge()));
        final List<ItemStack> ripe = Block.getDrops(level.getBlockState(absolute), level, absolute, null);
        helper.assertTrue(countOf(ripe, produce) >= 1,
            "A fully grown wheat crop dropped no produce, drops were " + describe(ripe));
        helper.assertTrue(countOf(ripe, seeds) >= 1,
            "A fully grown wheat crop dropped no seeds, drops were " + describe(ripe));

        helper.succeed();
    }

    /**
     * Tree fruits are harvested from the leaves, and the trunk must be a vanilla oak log, not a custom block.
     *
     * Leaves only give up their fruit on a lucky break - 5% by hand, 20% with Fortune III - so both rates are
     * measured over 400 breaks rather than checked one block at a time. The two bands do not overlap, which makes
     * this a real test of Fortune reaching the loot table, not just of the table parsing.
     */
    private static void treeLeavesDropFruit(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final Item fruit = TFCItems.get(com.tfc_food_port.common.food.Food.RED_APPLE).get();
        final Block leaves = TFCBlocks.getLeaves(Berry.RED_APPLE).get();

        // ---- by hand: 5% of 400 breaks, i.e. about 20 apples ----
        final int byHand = fruitFromRepeatedBreaks(helper, leaves, fruit, ItemStack.EMPTY);
        helper.assertTrue(byHand >= 1 && byHand <= 50,
            "400 red apple leaf breaks by hand gave " + byHand + " apples; 5% of 400 is about 20, so anything"
                + " outside 1..50 means the chance in the loot table is wrong");

        // ---- with Fortune III: 20% of 400, i.e. about 80 apples ----
        final int withFortune = fruitFromRepeatedBreaks(helper, leaves, fruit, fortuneTool(level, 3));
        helper.assertTrue(withFortune >= 35 && withFortune <= 140,
            "400 red apple leaf breaks with Fortune III gave " + withFortune + " apples; 20% of 400 is about"
                + " 80, so anything outside 35..140 means Fortune is not reaching the loot table");

        // and the fruit is plantable as a sapling
        helper.setBlock(new BlockPos(3, 2, 3), Blocks.DIRT);
        helper.setBlock(new BlockPos(3, 3, 3), Blocks.AIR);
        final Player player = helper.makeMockPlayer(GameType.SURVIVAL);
        final ItemStack plantable = new ItemStack(fruit);
        player.setItemInHand(InteractionHand.MAIN_HAND, plantable);
        final BlockPos groundAbs = helper.absolutePos(new BlockPos(3, 2, 3));
        plantable.useOn(new UseOnContext(level, player, InteractionHand.MAIN_HAND, plantable,
            new BlockHitResult(Vec3.atCenterOf(groundAbs), Direction.UP, groundAbs, false)));
        helper.assertTrue(level.getBlockState(groundAbs.above()).getBlock() == TFCBlocks.getSapling(Berry.RED_APPLE).get(),
            "The fruit did not plant a sapling; found " + level.getBlockState(groundAbs.above()));

        helper.succeed();
    }

    /**
     * Every tree fruit's sapling must be growable: a real {@link SaplingBlock}, accepting bone meal, with its
     * configured feature present in the registry.
     *
     * The registry lookup is the important half: the sapling's TreeGrower resolves a configured feature purely by its
     * id, so a typo in the generated {@code <fruit>_tree.json} filename would only surface as a silently useless
     * sapling. Checking the lookup here turns that into a test failure.
     */
    private static void saplingsAreGrowable(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos ground = new BlockPos(1, 2, 1);
        helper.setBlock(ground, Blocks.DIRT);
        helper.setBlock(new BlockPos(1, 8, 1), Blocks.GLOWSTONE);

        final BlockPos spot = ground.above();
        final BlockPos absolute = helper.absolutePos(spot);
        final var configuredFeatures = level.registryAccess().lookupOrThrow(Registries.CONFIGURED_FEATURE);

        for (final Berry berry : Berry.treeFruits())
        {
            final Block block = TFCBlocks.getSapling(berry).get();
            helper.assertTrue(block instanceof SaplingBlock,
                "The " + berry.getSerializedName() + " sapling is not a SaplingBlock, so it would never grow");

            helper.assertTrue(configuredFeatures.get(berry.treeFeature()).isPresent(),
                "No configured feature registered for " + berry.treeFeature().identifier()
                    + ", so the " + berry.getSerializedName() + " sapling could never grow a tree");

            helper.setBlock(spot, block.defaultBlockState());
            final BlockState state = level.getBlockState(absolute);
            helper.assertTrue(((SaplingBlock) block).isValidBonemealTarget(level, absolute, state),
                "The " + berry.getSerializedName() + " sapling refuses bone meal");
        }

        helper.succeed();
    }

    /** Berries must be plantable on grass, dirt and coarse dirt, not just farmland. */
    private static void bushesPlantOnSoil(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        helper.setBlock(new BlockPos(1, 8, 1), Blocks.GLOWSTONE);

        final Player player = helper.makeMockPlayer(GameType.SURVIVAL);
        final Block bush = TFCBlocks.getBush(Berry.BLACKBERRY).get();
        final ItemStack berries = new ItemStack(TFCItems.get(com.tfc_food_port.common.food.Food.BLACKBERRY).get());

        final List<Block> soils = List.of(Blocks.GRASS_BLOCK, Blocks.DIRT, Blocks.COARSE_DIRT);
        for (int i = 0; i < soils.size(); i++)
        {
            final BlockPos ground = new BlockPos(2 + i * 2, 2, 2);
            final BlockPos groundAbs = helper.absolutePos(ground);
            helper.setBlock(ground, soils.get(i));
            helper.setBlock(ground.above(), Blocks.AIR);

            player.setItemInHand(InteractionHand.MAIN_HAND, berries.copy());
            final ItemStack stack = player.getItemInHand(InteractionHand.MAIN_HAND);
            stack.useOn(new UseOnContext(level, player, InteractionHand.MAIN_HAND, stack,
                new BlockHitResult(Vec3.atCenterOf(groundAbs), Direction.UP, groundAbs, false)));

            helper.assertTrue(level.getBlockState(groundAbs.above()).getBlock() == bush,
                "Berries did not plant on " + soils.get(i) + "; found " + level.getBlockState(groundAbs.above()));
        }

        helper.succeed();
    }

    /**
     * The banana is grown like cocoa, but hangs from the canopy: using the fruit on the side of a leaf plants a
     * bunch, bone meal ripens it, a ripe bunch yields exactly 3 bananas (6 with a Fortune III tool), an unripe one
     * yields nothing, and a bunch cannot exist without its leaf.
     */
    private static void bananaGrowsOnATrunk(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos leafPos = new BlockPos(2, 2, 2);
        helper.setBlock(leafPos, TFCBlocks.getLeaves(Berry.BANANA).get().defaultBlockState());

        final BlockPos bunchPos = leafPos.east();
        final BlockPos bunchAbs = helper.absolutePos(bunchPos);
        final Block bunches = TFCBlocks.getTrunkFruit(Berry.BANANA).get();
        final Item banana = TFCItems.get(com.tfc_food_port.common.food.Food.BANANA).get();

        final Player player = helper.makeMockPlayer(GameType.SURVIVAL);
        final ItemStack stack = new ItemStack(banana);
        player.setItemInHand(InteractionHand.MAIN_HAND, stack);

        // use the banana on the side of a leaf
        final BlockHitResult hit = new BlockHitResult(Vec3.atCenterOf(helper.absolutePos(leafPos)), Direction.EAST,
            helper.absolutePos(leafPos), false);
        stack.useOn(new UseOnContext(level, player, InteractionHand.MAIN_HAND, stack, hit));

        helper.assertTrue(level.getBlockState(bunchAbs).getBlock() == bunches,
            "Using a banana on the side of a leaf did not plant a bunch; found " + level.getBlockState(bunchAbs));

        // bone meal ripens it
        final BonemealableBlock bonemealable = (BonemealableBlock) bunches;
        BlockState state = level.getBlockState(bunchAbs);
        helper.assertTrue(bonemealable.isValidBonemealTarget(level, bunchAbs, state),
            "A freshly planted banana bunch refuses bone meal");
        bonemealable.performBonemeal(level, level.getRandom(), bunchAbs, state);
        state = level.getBlockState(bunchAbs);
        helper.assertTrue(state.getValue(TFCPalmFruitBlock.AGE) == 1,
            "Bone meal left the banana bunch at age " + state.getValue(TFCPalmFruitBlock.AGE) + ", expected 1");

        // an unripe bunch pays out nothing, exactly like unripe cocoa
        helper.setBlock(bunchPos, state.setValue(TFCPalmFruitBlock.AGE, 0));
        final List<ItemStack> unripe = Block.getDrops(level.getBlockState(bunchAbs), level, bunchAbs, null);
        helper.assertTrue(unripe.isEmpty(),
            "An unripe banana bunch should give nothing, the way unripe cocoa does; drops were " + describe(unripe));

        // a ripe bunch gives exactly 3 bananas, and never a block item (the bunch has no item at all)
        helper.setBlock(bunchPos, state.setValue(TFCPalmFruitBlock.AGE, TFCPalmFruitBlock.MAX_AGE));
        final List<ItemStack> ripe = Block.getDrops(level.getBlockState(bunchAbs), level, bunchAbs, null);
        helper.assertTrue(countOf(ripe, banana) == 3,
            "A ripe banana bunch dropped " + countOf(ripe, banana) + " bananas, expected exactly 3; drops were "
                + describe(ripe));
        helper.assertTrue(ripe.stream().allMatch(s -> s.is(banana)),
            "A banana bunch dropped something other than bananas (it must never drop a block item): " + describe(ripe));

        // and it benefits from Fortune: +1 banana per level, so Fortune III is exactly 6
        final List<ItemStack> lucky = Block.getDrops(level.getBlockState(bunchAbs), level, bunchAbs, null, null,
            fortuneTool(level, 3));
        helper.assertTrue(countOf(lucky, banana) == 6,
            "A ripe banana bunch with a Fortune III tool dropped " + countOf(lucky, banana)
                + " bananas, expected exactly 6; drops were " + describe(lucky));

        // removing the supporting leaf must remove the bunch
        helper.setBlock(leafPos, Blocks.AIR);
        helper.assertTrue(level.getBlockState(bunchAbs).isAir(),
            "The banana bunch stayed in the air after its leaf was removed: " + level.getBlockState(bunchAbs));

        helper.succeed();
    }

    /**
     * Growing a banana palm must actually produce leaves and bananas.
     *
     * This guards a real bug: the palm's crown used blob_foliage_placer with radius 1 / height 1, which works out to
     * two leaf blocks at the top of an 8 block trunk - an invisible tree, and since bananas come from either the
     * leaves or the trunk bunches, that meant no bananas at all. It also checks the world generation decorator,
     * which is what puts ripe bunches on wild palms.
     */
    private static void bananaPalmGrowsLeavesAndFruit(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos ground = new BlockPos(4, 2, 4);
        final BlockPos groundAbs = helper.absolutePos(ground);
        helper.setBlock(ground, Blocks.DIRT);
        // clear headroom so the tree has somewhere to grow
        for (int y = 1; y <= 20; y++) {
            for (int x = -5; x <= 5; x++) {
                for (int z = -5; z <= 5; z++) {
                    helper.setBlock(new BlockPos(4 + x, 2 + y, 4 + z), Blocks.AIR);
                }
            }
        }

        final Block sapling = TFCBlocks.getSapling(Berry.BANANA).get();
        final Block leaves = TFCBlocks.getLeaves(Berry.BANANA).get();
        final Block bunches = TFCBlocks.getTrunkFruit(Berry.BANANA).get();

        helper.setBlock(ground.above(), sapling.defaultBlockState());
        // A sapling at stage 0 only flips to stage 1 on the first call; the tree is grown on the second, which is
        // exactly what two random ticks or two bone meals would do.
        final BlockPos saplingPos = groundAbs.above();
        ((SaplingBlock) sapling).advanceTree(level, saplingPos, level.getBlockState(saplingPos), level.getRandom());
        ((SaplingBlock) sapling).advanceTree(level, saplingPos, level.getBlockState(saplingPos), level.getRandom());

        int leafCount = 0;
        int logCount = 0;
        int bunchCount = 0;
        // Scan one block wider than the crown, because a bunch hangs in the block next to a leaf.
        for (int y = 1; y <= 20; y++) {
            for (int x = -5; x <= 5; x++) {
                for (int z = -5; z <= 5; z++) {
                    final var state = level.getBlockState(helper.absolutePos(new BlockPos(4 + x, 2 + y, 4 + z)));
                    if (state.getBlock() == leaves) { leafCount++; }
                    else if (state.is(Blocks.OAK_LOG)) { logCount++; }
                    else if (state.getBlock() == bunches) { bunchCount++; }
                }
            }
        }

        helper.assertTrue(logCount >= 6,
            "The banana palm grew too short a trunk: found " + logCount + " oak log blocks, expected at least 6");
        helper.assertTrue(leafCount >= 8,
            "The banana palm grew almost no leaves: found " + leafCount + " leaf blocks, expected at least 8"
                + " (a blob placer with radius 1 would give about 2)");
        helper.assertTrue(bunchCount >= 1,
            "The banana palm grew no banana bunches, so a wild palm would carry no bananas; found " + bunchCount);

        // The crown's own drop rate is not checked here: banana leaves follow the same 5%-per-break rule as every
        // other fruit tree, and that rule is measured properly in treeLeavesDropFruit. A palm crown is only a
        // couple of dozen blocks, which is far too small a sample to assert a 5% chance on.

        helper.succeed();
    }

    private static int countOf(List<ItemStack> stacks, Item item)    {
        int total = 0;
        for (final ItemStack stack : stacks)
        {
            if (stack.is(item))
            {
                total += stack.getCount();
            }
        }
        return total;
    }

    /** How many times a drop rate is measured, so a 5% chance is sampled as about 20 hits out of 400. */
    private static final int DROP_ATTEMPTS = 400;

    /**
     * Shears and Silk Touch must hand back the leaf BLOCK, and everything else must sometimes shake a fruit loose.
     *
     * This is the reason the leaves have an item at all: without one those drops would have nothing to become, so if
     * this test fails it usually means the leaf item registration was forgotten, not that the loot table is wrong.
     * The banana is checked separately, because it deliberately gives no fruit - its leaves are plain jungle leaves.
     */
    private static void leavesCanBeSheared(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos pos = new BlockPos(2, 2, 2);
        final BlockPos absolute = helper.absolutePos(pos);

        for (final Berry berry : Berry.treeFruits())
        {
            final Block leafBlock = TFCBlocks.getLeaves(berry).get();
            final Item leafItem = TFCItems.getLeaves(berry).get();
            final Item fruit = TFCItems.get(berry.food()).get();
            helper.setBlock(pos, leafBlock.defaultBlockState());

            // shears
            final List<ItemStack> sheared = Block.getDrops(level.getBlockState(absolute), level, absolute, null,
                null, new ItemStack(Items.SHEARS));
            helper.assertTrue(countOf(sheared, leafItem) == 1,
                "Shearing " + berry.getSerializedName() + " leaves did not give the leaf block: " + describe(sheared));

            // Silk Touch
            final List<ItemStack> silked = Block.getDrops(level.getBlockState(absolute), level, absolute, null,
                null, silkTool(level));
            helper.assertTrue(countOf(silked, leafItem) == 1,
                "Silk Touch on " + berry.getSerializedName() + " leaves did not give the leaf block: " + describe(silked));

            // bare hands: never the leaf, and only sometimes the fruit
            final List<ItemStack> bare = Block.getDrops(level.getBlockState(absolute), level, absolute, null);
            helper.assertTrue(countOf(bare, leafItem) == 0,
                "Bare hands gave a " + berry.getSerializedName() + " leaf block, which only shears or Silk Touch should: "
                    + describe(bare));
            helper.assertTrue(bare.stream().allMatch(stack -> stack.is(fruit)) || bare.isEmpty(),
                "Breaking " + berry.getSerializedName() + " leaves by hand dropped something that is neither the fruit"
                    + " nor nothing: " + describe(bare));

            // and the banana's leaves must NEVER give a banana, being plain jungle leaves
            if (berry.hasTrunkFruit())
            {
                final int fromLeaves = fruitFromRepeatedBreaks(helper, leafBlock, fruit, ItemStack.EMPTY);
                helper.assertTrue(fromLeaves == 0,
                    "Banana leaves dropped " + fromLeaves + " bananas over " + DROP_ATTEMPTS + " breaks, but banana"
                        + " leaves are supposed to give fruit only through the bunch, never from the leaves");
            }
        }

        helper.succeed();
    }

    /**
     * Every mooncake must be edible and must hand out a buff when eaten.
     *
     * The buff lives in a data component rather than the item class, so it is entirely possible for a mooncake to
     * register successfully and still do nothing on being eaten - this reads the component back to prove it does
     * not, and it checks the golden apple cakes carry more than the jam ones rather than the same five second effect.
     */
    private static void mooncakesGiveABuff(GameTestHelper helper)
    {
        for (final Mooncake mooncake : Mooncake.values())
        {
            final ItemStack stack = new ItemStack(TFCItems.getMooncake(mooncake).get());
            final String name = mooncake.getSerializedName();

            final var food = stack.get(DataComponents.FOOD);
            helper.assertTrue(food != null, "The " + name + " mooncake has no food component, so it cannot be eaten");
            helper.assertTrue(food != null && food.nutrition() > 0,
                "The " + name + " mooncake restores no hunger at all");

            final Consumable consumable = stack.get(DataComponents.CONSUMABLE);
            helper.assertTrue(consumable != null, "The " + name + " mooncake has no consumable component");

            final List<ApplyStatusEffectsConsumeEffect> effects = consumable == null ? List.of() : consumable.onConsumeEffects()
                .stream()
                .filter(effect -> effect instanceof ApplyStatusEffectsConsumeEffect)
                .map(effect -> (ApplyStatusEffectsConsumeEffect) effect)
                .toList();

            helper.assertTrue(!effects.isEmpty(),
                "The " + name + " mooncake applies no status effect when eaten, so it is just a plain cake");

            final var instances = effects.isEmpty() ? List.<net.minecraft.world.effect.MobEffectInstance>of() : effects.get(0).effects();
            helper.assertTrue(!instances.isEmpty(),
                "The " + name + " mooncake has an empty effect list, so eating it does nothing");
            helper.assertTrue(effects.isEmpty() || effects.get(0).probability() >= 1.0F,
                "The " + name + " mooncake's buff is not guaranteed, so eating one can be a waste");

            // a jam cake is a five second thank you; the golden apple cakes reproduce vanilla's apples, which last
            // several minutes. Asserting the split catches a copy paste that would make either one wrong.
            if (instances.isEmpty())
            {
                continue;
            }
            if (mooncake.isGolden())
            {
                helper.assertTrue(instances.size() >= 2,
                    "The " + name + " mooncake should reproduce vanilla's golden apple, which gives more than one effect");
                helper.assertTrue(instances.stream().anyMatch(e -> e.getDuration() > Mooncake.BUFF_TICKS),
                    "The " + name + " mooncake's effects are all five seconds long, so it is not vanilla's golden apple");
            }
            else
            {
                helper.assertTrue(instances.size() == 1,
                    "The " + name + " mooncake should give exactly one five second effect, found " + instances.size());
                helper.assertTrue(instances.get(0).getDuration() == Mooncake.BUFF_TICKS,
                    "The " + name + " mooncake's buff lasts " + instances.get(0).getDuration() + " ticks, expected "
                        + Mooncake.BUFF_TICKS);
                helper.assertTrue(instances.get(0).getAmplifier() == 0,
                    "The " + name + " mooncake's buff is level " + (instances.get(0).getAmplifier() + 1)
                        + ", expected level 1");
            }
        }

        helper.succeed();
    }

    /** A tool with Silk Touch, for the leaf drop tests. */
    private static ItemStack silkTool(ServerLevel level)
    {
        final ItemStack tool = new ItemStack(Items.DIAMOND_AXE);
        tool.enchant(level.registryAccess().lookupOrThrow(Registries.ENCHANTMENT).getOrThrow(Enchantments.SILK_TOUCH), 1);
        return tool;
    }

    /**
     * The cooking pot must be able to tell a fruit soup from a jam.
     *
     * Fruit soup used to be exactly "two fruit plus sugar", which is also exactly a jam: with two strawberries and
     * sugar in the pot both recipes matched, and whichever the recipe manager returned first won, so the player
     * could not actually choose which one to cook. This was reported from playing, and nothing in the build or the
     * asset audit could have caught it - it is a property of the recipe set as a whole, not of any single file.
     *
     * The soup now also takes a water bucket, so the two are separable by ingredient count. This test asks the real
     * recipe manager the same question the pot asks, which is what makes it a proof rather than a restatement: the
     * pot's recipe matching is "the number of non-empty slots must equal the number of ingredients", so a three item
     * probe can only ever find the jam and a four item probe can only find the soup.
     *
     * Farmer's Delight's recipe type is looked up by registry id instead of by class. That keeps this test free of a
     * compile time dependency on Farmer's Delight, which matters because the mod is meant to keep working when
     * Farmer's Delight is not installed.
     */
    @SuppressWarnings({"unchecked", "deprecation"})
    private static void soupIsNotAConfusedJam(GameTestHelper helper)
    {
        // This test asks the cooking pot a question, so it can only run where the cooking pot exists. Farmer's
        // Delight is an optional dependency now, so an absent pot is a valid configuration rather than a failure -
        // recipes_switch_with_loaded_mods covers what should happen in that case.
        if (!ModList.get().isLoaded("farmersdelight"))
        {
            helper.succeed();
            return;
        }

        final ServerLevel level = helper.getLevel();
        final RecipeManager recipes = (RecipeManager) level.recipeAccess();

        // Registry#getOptional returns the value itself; Registry#get returns a Holder.Reference, which is more
        // machinery than a lookup needs and would force the generic type to be spelled out.
        final Optional<RecipeType<?>> cookingType = BuiltInRegistries.RECIPE_TYPE.getOptional(
            Identifier.fromNamespaceAndPath("farmersdelight", "cooking"));
        helper.assertTrue(cookingType.isPresent(),
            "Farmer's Delight's farmersdelight:cooking recipe type is not registered, so the pot could not cook");
        final RecipeType<?> cooking = cookingType.orElse(null);
        if (cooking == null)
        {
            helper.fail("no cooking recipe type");
            return;
        }

        final Item strawberry = TFCItems.get(Food.STRAWBERRY).get();
        final String jamId = TFCFoodPort.MOD_ID + ":food/jam/strawberry";
        final String soupId = TFCFoodPort.MOD_ID + ":food/fruit_soup";

        // two fruit and sugar is a jam, and must resolve to the jam rather than to a soup
        final String fromThree = cookingRecipeAt(recipes, cooking, level,
            new ItemStack(strawberry), new ItemStack(strawberry), new ItemStack(Items.SUGAR));
        helper.assertTrue(jamId.equals(fromThree),
            "Two strawberries and sugar should cook into " + jamId + ", but the pot picked '" + fromThree
                + "'. If that is the fruit soup, the soup is able to masquerade as a jam again.");

        // and with a water bucket it is the soup
        final String fromFour = cookingRecipeAt(recipes, cooking, level,
            new ItemStack(strawberry), new ItemStack(strawberry), new ItemStack(Items.SUGAR),
            new ItemStack(Items.WATER_BUCKET));
        helper.assertTrue(soupId.equals(fromFour),
            "Two strawberries, sugar and a water bucket should cook into " + soupId + ", but the pot picked '"
                + fromFour + "'");

        // the two must never be the same recipe, which is the whole point
        helper.assertTrue(!fromThree.equals(fromFour),
            "Jam and fruit soup resolve to the same recipe '" + fromThree + "', so one of them is unreachable");

        helper.succeed();
    }

    /**
     * Asks the recipe manager what a cooking pot holding these items would cook.
     *
     * Returns the recipe id, or an empty string when nothing matches, so a failure message can show what actually
     * happened instead of just "expected present".
     */
    @SuppressWarnings({"unchecked", "rawtypes"})
    private static String cookingRecipeAt(RecipeManager recipes, RecipeType<?> type, ServerLevel level, ItemStack... items)
    {
        final ItemStackHandler handler = new ItemStackHandler(6);
        for (int i = 0; i < items.length; i++)
        {
            handler.setStackInSlot(i, items[i]);
        }
        final RecipeWrapper wrapper = new RecipeWrapper(handler);

        // getRecipeFor is generic in the recipe type, and the type here is only known at runtime - it is looked up
        // by registry id so that this test carries no compile time dependency on Farmer's Delight. A raw type
        // propagates through the call, so the result comes back untyped and is cast back in one place.
        final Optional<RecipeHolder<?>> found =
            (Optional<RecipeHolder<?>>) (Optional<?>) recipes.getRecipeFor((RecipeType) type, wrapper, level);
        return found.map(holder -> holder.id().identifier().toString()).orElse("");
    }

    /**
     * The recipes must actually change with the installed mods, and this proves it happened at load time.
     *
     * Every processing step that would need a cooking machine exists in three files: one using Farmer's Delight's
     * machines, one using Kaleidoscope Cookery's, and one using only vanilla blocks. Each carries a
     * {@code neoforge:conditions} block, which NeoForge evaluates WHILE THE DATAPACK LOADS - so the recipes that are
     * not applicable should not merely be hidden, they should not be in the recipe manager at all.
     *
     * That distinction is what this test checks, because it is the difference between the feature working and the
     * feature appearing to work: a condition that silently failed to parse would leave all three variants loaded,
     * and the player would find three ways to make a jam with no idea which mods were supposed to matter. Reading
     * the loaded recipe ids back from the manager is the only way to tell those two situations apart.
     *
     * The expectations are derived from which mods are actually present, so this holds in any of the four
     * combinations: neither mod, only Farmer's Delight, only Kaleidoscope Cookery, or both.
     */
    private static void recipesSwitchWithLoadedMods(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final RecipeManager recipes = (RecipeManager) level.recipeAccess();
        final String ns = TFCFoodPort.MOD_ID + ":";

        final boolean hasFD = ModList.get().isLoaded("farmersdelight");
        final boolean hasKC = ModList.get().isLoaded("kaleidoscope_cookery");

        final java.util.Set<String> ids = new java.util.HashSet<>();
        for (final RecipeHolder<?> holder : recipes.getRecipes())
        {
            ids.add(holder.id().identifier().toString());
        }
        helper.assertTrue(!ids.isEmpty(), "The recipe manager returned no recipes at all");

        // Farmer's Delight's variants live at the plain name, so their presence is the condition on that mod.
        helper.assertTrue(ids.contains(ns + "food/jam/strawberry") == hasFD,
            "The Farmer's Delight jam recipe is " + (ids.contains(ns + "food/jam/strawberry") ? "loaded" : "missing")
                + " but Farmer's Delight is " + (hasFD ? "installed" : "not installed"));

        helper.assertTrue(ids.contains(ns + "food/jam/strawberry_kc") == hasKC,
            "The Kaleidoscope Cookery jam recipe is "
                + (ids.contains(ns + "food/jam/strawberry_kc") ? "loaded" : "missing")
                + " but Kaleidoscope Cookery is " + (hasKC ? "installed" : "not installed"));

        // The vanilla fallback is the inverse of BOTH, so it must be absent whenever either mod is present.
        final boolean wantVanilla = !hasFD && !hasKC;
        helper.assertTrue(ids.contains(ns + "food/jam/strawberry_vanilla") == wantVanilla,
            "The vanilla jam fallback is "
                + (ids.contains(ns + "food/jam/strawberry_vanilla") ? "loaded" : "missing")
                + " but it should be " + (wantVanilla ? "loaded" : "absent")
                + " (Farmer's Delight " + (hasFD ? "present" : "absent")
                + ", Kaleidoscope Cookery " + (hasKC ? "present" : "absent") + ")");

        // And the whole point: a jam must always be makeable by exactly one route, whichever mods are installed.
        final long jamRoutes = ids.stream().filter(id -> id.startsWith(ns + "food/jam/strawberry")).count();
        helper.assertTrue(jamRoutes >= 1,
            "No way to make a strawberry jam exists at all with this mod set, so the conditions are too strict");

        // Spot check the same rule on the grain chain, since it goes through cutting boards rather than pots and so
        // exercises a different recipe type with a different condition.
        helper.assertTrue(ids.contains(ns + "food/wheat_grain") == hasFD,
            "The Farmer's Delight wheat-to-grain recipe is "
                + (ids.contains(ns + "food/wheat_grain") ? "loaded" : "missing")
                + " but Farmer's Delight is " + (hasFD ? "installed" : "not installed"));
        helper.assertTrue(ids.contains(ns + "food/wheat_grain_kc") == hasKC,
            "The Kaleidoscope Cookery wheat-to-grain recipe is "
                + (ids.contains(ns + "food/wheat_grain_kc") ? "loaded" : "missing")
                + " but Kaleidoscope Cookery is " + (hasKC ? "installed" : "not installed"));

        helper.succeed();
    }

    /**
     * Every mooncake must be baked from its own raw cake, and this mod's dough must count as dough.
     *
     * Two separate regressions are covered here.
     *
     * The first is the baking chain: an unbaked cake has to be an ingredient that does nothing on its own, and each
     * one has to have a smelting recipe producing exactly its own flavour. Because a furnace input can only have one
     * output, this is what proves the 24 raw items are wired to the 24 finished ones rather than to a shared result.
     *
     * The second is the dough tag. The port's c: tag files used to be written without a .json extension, so
     * Minecraft never loaded them and #c:foods/dough silently resolved to Farmer's Delight's tag alone - meaning the
     * six ported doughs could not be used in ANY recipe, including this mod's own soups and salads. Reading the tag
     * back through the game is the only way to catch that class of mistake, since the files look correct on disk.
     */
    private static void mooncakesBakeFromRaw(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        // ServerLevel exposes the recipe manager as recipeAccess(); Level#getRecipeManager no longer exists.
        final RecipeManager recipes = (RecipeManager) level.recipeAccess();
        final TagKey<Item> doughTag = TagKey.create(Registries.ITEM, Identifier.fromNamespaceAndPath("c", "foods/dough"));

        for (final Food dough : new Food[] { Food.BARLEY_DOUGH, Food.OAT_DOUGH, Food.RYE_DOUGH,
                                             Food.WHEAT_DOUGH, Food.RICE_DOUGH, Food.MAIZE_DOUGH })
        {
            final ItemStack stack = new ItemStack(TFCItems.get(dough).get());
            helper.assertTrue(stack.is(doughTag),
                "tfc_food_port:food/" + dough.getSerializedName() + " is not in #c:foods/dough, so it cannot be used"
                    + " as dough in any recipe (check that the tag file ends in .json)");
        }

        for (final Mooncake mooncake : Mooncake.values())
        {
            final String name = mooncake.getSerializedName();
            final ItemStack raw = new ItemStack(TFCItems.getRawMooncake(mooncake).get());
            final Item baked = TFCItems.getMooncake(mooncake).get();

            helper.assertTrue(raw.get(DataComponents.FOOD) == null,
                "The raw " + name + " mooncake is edible; it is meant to be an ingredient for a furnace");

            final SingleRecipeInput input = new SingleRecipeInput(raw);
            final var found = recipes.getRecipeFor(RecipeType.SMELTING, input, level);
            helper.assertTrue(found.isPresent(),
                "No smelting recipe turns a raw " + name + " mooncake into a mooncake");

            if (found.isPresent())
            {
                final ItemStack result = found.get().value().assemble(input);
                helper.assertTrue(result.is(baked),
                    "Smelting a raw " + name + " mooncake produced " + result + ", expected "
                        + new ItemStack(baked));
            }
        }

        helper.succeed();
    }

    /**
     * How many fruits one plant gives up over many breaks.
     *
     * The tables hand out fruit by chance, so a single break proves nothing: a 5% roll fails 95% of the time, and a
     * test that breaks one block would pass or fail on the weather. Breaking the *same* block
     * {@code DROP_ATTEMPTS} times turns that probability into a count with a tight spread, which is what makes the
     * drop rate assertable at all (see the callers for the bands).
     *
     * Repeating one block is deliberate. {@link Block#getDrops} returns the items without putting them in the
     * world, so nothing has to be built, and - more importantly - a patch of hundreds of plants would spill over
     * the edge of this test's area and wreck its neighbours, because function-based tests are laid out only a few
     * blocks apart.
     *
     * Uses {@link Block#getDrops} with a tool, which is the same path the game takes when a player breaks a block,
     * so both the loot table and the tool-based chance are really exercised.
     */
    private static int fruitFromRepeatedBreaks(GameTestHelper helper, Block plant, Item fruit, ItemStack tool)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos pos = new BlockPos(2, 2, 2);
        final BlockPos absolute = helper.absolutePos(pos);
        helper.setBlock(pos, plant.defaultBlockState());

        int fruits = 0;
        for (int attempt = 0; attempt < DROP_ATTEMPTS; attempt++)
        {
            final List<ItemStack> drops = Block.getDrops(level.getBlockState(absolute), level, absolute, null, null,
                tool);
            helper.assertTrue(drops.stream().allMatch(stack -> stack.is(fruit)),
                "Breaking " + plant + " dropped something other than its fruit: " + describe(drops));
            fruits += countOf(drops, fruit);
        }
        return fruits;
    }

    /** A tool with the given Fortune level, for the half of the drop tests that check the enchantment scaling. */
    private static ItemStack fortuneTool(ServerLevel level, int fortuneLevel)
    {
        final ItemStack tool = new ItemStack(Items.DIAMOND_AXE);
        tool.enchant(level.registryAccess().lookupOrThrow(Registries.ENCHANTMENT).getOrThrow(Enchantments.FORTUNE),
            fortuneLevel);
        return tool;
    }

    /**
     * Picking a ripe bush with an empty hand must give the fruit.
     *
     * This is the regression guard for a real bug: the bush was constructed with its own block item as the harvest
     * item, so right clicking a ripe bush handed back another bush. The loot table was correct all along, which is
     * why the drop tests passed while picking was still broken.
     */
    private static void pickingABushGivesFruit(GameTestHelper helper)
    {
        final ServerLevel level = helper.getLevel();
        final BlockPos ground = new BlockPos(1, 2, 1);
        helper.setBlock(ground, Blocks.DIRT);
        helper.setBlock(new BlockPos(1, 8, 1), Blocks.GLOWSTONE);

        final BlockPos spot = ground.above();
        final BlockPos absolute = helper.absolutePos(spot);
        final TFCBerryBushBlock bush = (TFCBerryBushBlock) TFCBlocks.getBush(Berry.BLACKBERRY).get();
        final Item fruit = TFCItems.get(com.tfc_food_port.common.food.Food.BLACKBERRY).get();

        helper.assertTrue(bush.fruit.value() == fruit,
            "The bush's harvest item is " + bush.fruit.value() + " but should be the fruit " + fruit);

        helper.setBlock(spot, bush.defaultBlockState().setValue(TFCBerryBushBlock.AGE, TFCBerryBushBlock.MAX_AGE));

        final Player player = helper.makeMockPlayer(GameType.SURVIVAL);
        player.setItemInHand(InteractionHand.MAIN_HAND, ItemStack.EMPTY);

        level.getBlockState(absolute).useWithoutItem(level, player,
            new BlockHitResult(Vec3.atCenterOf(absolute), Direction.UP, absolute, false));

        final List<ItemStack> drops = level.getEntitiesOfClass(net.minecraft.world.entity.item.ItemEntity.class,
            new net.minecraft.world.phys.AABB(absolute).inflate(2.0)).stream().map(
                net.minecraft.world.entity.item.ItemEntity::getItem).toList();

        helper.assertTrue(countOf(drops, fruit) >= 1,
            "Picking a ripe bush gave no fruit; the items on the ground were " + describe(drops));
        helper.assertTrue(drops.stream().allMatch(stack -> stack.is(fruit)),
            "Picking a ripe bush produced something other than fruit: " + describe(drops));

        // the plant must survive and be reset to a partly grown state so it can be picked again
        final BlockState after = level.getBlockState(absolute);
        helper.assertTrue(after.getBlock() == bush, "Picking destroyed the bush, found " + after);
        helper.assertTrue(after.getValue(TFCBerryBushBlock.AGE) < TFCBerryBushBlock.MAX_AGE,
            "Picking left the bush fully grown, so it would never regrow: " + after);

        helper.succeed();
    }

    private static String describe(List<ItemStack> stacks)
    {
        final StringBuilder builder = new StringBuilder("[");
        for (final ItemStack stack : stacks)
        {
            builder.append(stack.getCount()).append('x').append(stack.getItem()).append(' ');
        }
        return builder.append(']').toString();
    }
}
