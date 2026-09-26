package com.tfc_food_port.common.blockentity;

import com.tfc_food_port.registry.TFCBlocks;
import com.tfc_food_port.registry.TFCComponents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.component.DataComponentMap;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.SimpleFluidContent;
import net.neoforged.neoforge.fluids.capability.IFluidHandler;
import net.neoforged.neoforge.fluids.capability.templates.FluidTank;

/**
 * A barrel that is nothing but a fluid tank: no GUI, no sealing, no recipes, no fermentation.
 *
 * Right clicking with a fluid container moves fluid in or out, see {@link com.tfc_food_port.common.block.BarrelBlock}.
 * The tank is exposed through the NeoForge {@code Capabilities.FluidHandler.BLOCK} capability so pipes and other
 * automation can interact with it.
 *
 * This is the 1.21.1 shape of the barrel. On 26.1.2 the fluid capability was replaced by the generic transfer API -
 * {@code ResourceHandler<FluidResource>} with a {@code FluidStacksResourceHandler} behind it and an explicit
 * transaction threaded through every call - and block entity persistence moved from NBT to
 * {@code ValueInput}/{@code ValueOutput}. Neither exists here, so this is a {@link FluidTank} plus a plain
 * {@link CompoundTag}, which is what 1.21.1 actually has.
 */
public class BarrelBlockEntity extends BlockEntity
{
    /** 1000 buckets, as requested. TFC's own barrel only holds 10000 mB. */
    public static final int CAPACITY = 1_000_000;

    private final FluidTank tank = new FluidTank(CAPACITY)
    {
        @Override
        protected void onContentsChanged()
        {
            // Without this the level would not know the block entity changed, and would not save it.
            setChanged();
        }
    };

    public BarrelBlockEntity(BlockPos pos, BlockState state)
    {
        super(TFCBlocks.BARREL_ENTITY.get(), pos, state);
    }

    /** The tank as a capability, used by the block capability registration and by the tests. */
    public IFluidHandler getTank()
    {
        return tank;
    }

    /** The stored fluid, for display or recipe lookups. */
    public FluidStack getFluid()
    {
        return tank.getFluid();
    }

    @Override
    protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries)
    {
        super.saveAdditional(tag, registries);
        // FluidTank writes itself, and needs the registries because a fluid stack holds a registry entry.
        tank.writeToNBT(registries, tag);
    }

    @Override
    protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries)
    {
        super.loadAdditional(tag, registries);
        tank.readFromNBT(registries, tag);
    }

    /**
     * Hands the contents to the dropped item, so breaking a barrel does not lose its fluid.
     * The loot table copies this component onto the drop (see the barrel loot table), and
     * {@link #applyImplicitComponents} reads it back when the barrel is placed again.
     */
    @Override
    protected void collectImplicitComponents(DataComponentMap.Builder components)
    {
        super.collectImplicitComponents(components);

        final FluidStack fluid = getFluid();
        if (!fluid.isEmpty())
        {
            components.set(TFCComponents.BARREL_FLUID.get(), SimpleFluidContent.copyOf(fluid));
        }
    }

    /** Restores the contents carried over by the item when the barrel is placed. */
    @Override
    protected void applyImplicitComponents(BlockEntity.DataComponentInput components)
    {
        super.applyImplicitComponents(components);

        final SimpleFluidContent content = components.get(TFCComponents.BARREL_FLUID.get());
        if (content != null && !content.isEmpty())
        {
            // setFluid, not set: the transfer API's index based setter has no equivalent on FluidTank.
            tank.setFluid(content.copy());
        }
    }
}
