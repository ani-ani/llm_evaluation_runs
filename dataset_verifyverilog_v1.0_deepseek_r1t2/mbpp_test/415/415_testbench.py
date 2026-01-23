import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 256

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        min_val = -(1 << (bits - 1))
        return from_signed(max(min_val, min(max_val, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_product_finder(dut):
    """Test the max_product_finder module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array_values, expected_x, expected_y, description)
    # Note: We scale down to fit 8-bit signed range
    test_cases = [
        ([1, 2, 3, 4, 7, 0, 8, 4], 7, 8, "Test 1: Mixed positive"),
        ([0, -1, -2, -4, 5, 0, -6, 0], -4, -6, "Test 2: Negative numbers"),
        ([1, 2, 3, 0, 0, 0, 0, 0], 2, 3, "Test 3: Small array"),
        ([-10, -5, 2, 3, 0, 0, 0, 0], -10, -5, "Test 4: Larger negatives"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, exp_x, exp_y, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {arr_vals}")
        
        try:
            # Calculate expected product for verification
            expected_product = exp_x * exp_y
            
            # Set array inputs (element by element)
            dut.arr_0.value = clamp_to_width(arr_vals[0], DATA_WIDTH)
            dut.arr_1.value = clamp_to_width(arr_vals[1], DATA_WIDTH)
            dut.arr_2.value = clamp_to_width(arr_vals[2], DATA_WIDTH)
            dut.arr_3.value = clamp_to_width(arr_vals[3], DATA_WIDTH)
            dut.arr_4.value = clamp_to_width(arr_vals[4], DATA_WIDTH)
            dut.arr_5.value = clamp_to_width(arr_vals[5], DATA_WIDTH)
            dut.arr_6.value = clamp_to_width(arr_vals[6], DATA_WIDTH)
            dut.arr_7.value = clamp_to_width(arr_vals[7], DATA_WIDTH)
            
            # Set length
            dut.len.value = len([x for x in arr_vals if x != 0 or arr_vals.index(x) < 2])
            dut.len.value = 8  # Use full array for simplicity
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not (is_value_defined(dut.result_x.value) and is_value_defined(dut.result_y.value)):
                raise TestFailure("Outputs are undefined (X/Z)")
            
            # Convert from unsigned to signed
            raw_x = int(dut.result_x.value)
            raw_y = int(dut.result_y.value)
            
            # Since result_x and result_y are 16-bit signed, we need to convert
            # But the module stores them as 16-bit values where upper bits are zero
            # Actually, let's read the actual 16-bit signed values
            result_x = to_signed(raw_x, 16)
            result_y = to_signed(raw_y, 16)
            
            # Check if result matches expected pair (order may vary)
            if (result_x == exp_x and result_y == exp_y) or (result_x == exp_y and result_y == exp_x):
                cocotb.log.info(f"  PASS: Got ({result_x}, {result_y}), product = {result_x * result_y}")
                passed += 1
            else:
                raise TestFailure(f"Expected ({exp_x}, {exp_y}), got ({result_x}, {result_y})")
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")