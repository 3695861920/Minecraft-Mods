package com.tfc_food_port.common.blockentity;

import com.tfc_food_port.registry.TFCBlocks;
import com.tfc_food_port.registry.TFCComponents;
import net.minecraft.core.BlockPos;
import net.minecraft.core.component.DataComponentGetter;
import net.minecraft.core.component.DataComponentMap;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.neoforged.neoforge.fluids.FluidStack;
import net.neoforged.neoforge.fluids.SimpleFluidContent;
import net.neoforged.neoforge.transfer.ResourceHandler;
import net.neoforged.neoforge.transfer.fluid.FluidResource;
import net.neoforged.neoforge.transfer.fluid.FluidStacksResourceHandler;
import net.neoforged.neoforge.transfer.fluid.FluidUtil;

/**
 * A barrel that is nothing but a fluid tank: no GUI, no sealing, no recipes, no fermentation.
 *
 * Right clicking with a fluid container moves fluid in or out, see {@link com.tfc_food_port.common.block.BarrelBlock}.
 * The tank is exposed through the NeoForge {@code Capabilities.Fluid.BLOCK} capability so pipes and other
 * automation can interact with it.
 */
public class BarrelBlockEntity extends BlockEntity
{
    /** 1000 buckets, as requested. TFC's own barrel only holds 10000 mB. */
    public static final int CAPACITY = 1_000_000;

    private final FluidStacksResourceHandler tank = new FluidStacksResourceHandler(1, CAPACITY)
    {
        @Override
        protected void onContentsChanged(int index, FluidStack previousContents)
        {
            setChanged();
        }
    };

    public BarrelBlockEntity(BlockPos pos, BlockState state)
    {
        super(TFCBlocks.BARREL_ENTITY.get(), pos, state);
    }

    public ResourceHandler<FluidResource> getTank()
    {
        return tank;
    }

    /** The stored fluid, for display or recipe lookups. */
    public FluidStack getFluid()
    {
        return FluidUtil.getStack(tank, 0);
    }

    @Override
    protected void saveAdditional(ValueOutput output)
    {
        super.saveAdditional(output);
        tank.serialize(output.child("tank"));
    }

    @Override
    protected void loadAdditional(ValueInput input)
    {
        super.loadAdditional(input);
        tank.deserialize(input.childOrEmpty("tank"));
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
    protected void applyImplicitComponents(DataComponentGetter components)
    {
        super.applyImplicitComponents(components);

        final SimpleFluidContent content = components.get(TFCComponents.BARREL_FLUID.get());
        if (content != null && !content.isEmpty())
        {
            tank.set(0, FluidResource.of(content.copy()), content.getAmount());
        }
    }
}
