import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 5
IDX_WIDTH = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_hut(dut, idx, value):
    """Write value to hut[idx] using memory interface."""
    dut.addr.value = clamp_to_width(idx, IDX_WIDTH)
    dut.data_in.value = clamp_to_width(value, DATA_WIDTH)
    dut.wr_en.value = 1
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0

async def compute_and_wait(dut):
    """Trigger computation and wait for done signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with timeout
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_beach_food_truck(dut):
    """Test the BeachFoodTruck module with scaled problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    dut._log.info("="*60)
    dut._log.info("Testing Oostende Beach Food Truck Module")
    dut._log.info("Scaled to 5 huts, 8-bit values")
    dut._log.info("="*60)
    
    # Define test sequence: initial array, then updates
    # Each update: (hut_index, new_value, expected_optimal_pos)
    test_sequence = [
        # Initial array: [3, 1, 3, 4, 2]
        (None, None, 2),  # Initial computation
        (0, 5, 2),        # Update hut 0 to 5
        (0, 9, 1),        # Update hut 0 to 9
        (4, 5, 2),        # Update hut 4 to 5
        (2, 1, 1),        # Update hut 2 to 1
    ]
    
    # Write initial array
    initial_array = [3, 1, 3, 4, 2]
    dut._log.info(f"Loading initial array: {initial_array}")
    for i, val in enumerate(initial_array):
        await write_hut(dut, i, val)
    
    # Process test sequence
    passed = 0
    failed = 0
    
    for i, (update_idx, new_val, expected) in enumerate(test_sequence):
        if update_idx is not None:
            dut._log.info(f"\nTest {i}: Update hut {update_idx} to {new_val}")
            await write_hut(dut, update_idx, new_val)
        else:
            dut._log.info(f"\nTest {i}: Initial computation")
        
        # Compute
        try:
            await compute_and_wait(dut)
            
            # Read result
            if not is_value_defined(dut.optimal_pos.value):
                raise TestFailure("optimal_pos is undefined (X/Z)")
            
            result = int(dut.optimal_pos.value)
            
            # Validate
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: optimal_pos = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info("\n" + "="*60)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    dut._log.info("="*60)
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
