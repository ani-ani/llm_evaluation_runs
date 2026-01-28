import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_FROGS = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_frog_inputs(dut, frogs, num_frogs):
    """Write frog inputs to the DUT."""
    # Clear all inputs first
    dut.frog_x_0.value = 0
    dut.frog_d_0.value = 0
    dut.frog_x_1.value = 0
    dut.frog_d_1.value = 0
    dut.frog_x_2.value = 0
    dut.frog_d_2.value = 0
    dut.frog_x_3.value = 0
    dut.frog_d_3.value = 0
    
    # Write frog data
    for i, (x, d) in enumerate(frogs):
        if i >= MAX_FROGS:
            break
        x_val = clamp_to_width(x, DATA_WIDTH)
        d_val = clamp_to_width(d, DATA_WIDTH)
        
        if i == 0:
            dut.frog_x_0.value = x_val
            dut.frog_d_0.value = d_val
        elif i == 1:
            dut.frog_x_1.value = x_val
            dut.frog_d_1.value = d_val
        elif i == 2:
            dut.frog_x_2.value = x_val
            dut.frog_d_2.value = d_val
        elif i == 3:
            dut.frog_x_3.value = x_val
            dut.frog_d_3.value = d_val
    
    dut.num_frogs.value = num_frogs

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_frog_tower_finder(dut):
    """Main test function for frog tower finder."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (frogs, expected_position, expected_size, description)
    # Format: ([(x, d), ...], expected_pos, expected_size, description)
    # Note: Positions and distances are scaled to 8-bit values
    test_cases = [
        # Example 1: frogs at 0(d=2), 1(d=2), 3(d=3)
        # Frogs can meet at position 3 (size 2) or 6 (size 2)
        # Smallest position with max size is 3
        ([(0, 2), (1, 2), (3, 3)], 3, 2, "Sample 1 scaled down"),
        
        # Example 2: frogs at 0(d=2), 1(d=3), 3(d=3), 7(d=5), 9(d=5)
        # Can meet at 12 (size 3)
        ([(0, 2), (1, 3), (3, 3), (7, 5), (9, 5)], 12, 3, "Sample 2 scaled down"),
        
        # Additional test: single frog
        ([(10, 2)], 10, 1, "Single frog"),
        
        # Additional test: two frogs with same pattern
        ([(5, 3), (8, 3)], 8, 2, "Two frogs, same pattern"),
        
        # Additional test: no meeting points
        ([(0, 2), (1, 5)], 0, 1, "No meeting points"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (frogs, expected_pos, expected_size, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {frogs}")
        
        try:
            # Write inputs
            num_frogs = len(frogs)
            await write_frog_inputs(dut, frogs, num_frogs)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.best_position.value):
                raise TestFailure("best_position is undefined (X/Z)")
            if not is_value_defined(dut.tower_size.value):
                raise TestFailure("tower_size is undefined (X/Z)")
            
            actual_pos = int(dut.best_position.value)
            actual_size = int(dut.tower_size.value)
            
            # Verify results
            if actual_pos != expected_pos or actual_size != expected_size:
                raise TestFailure(
                    f"Expected ({expected_pos}, {expected_size}), "
                    f"got ({actual_pos}, {actual_size})"
                )
            
            cocotb.log.info(f"  PASS: Position={actual_pos}, Size={actual_size}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")