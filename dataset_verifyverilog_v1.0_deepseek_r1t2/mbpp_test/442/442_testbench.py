import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
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
        # Convert signed to unsigned for assignment
        if value < -((1 << (bits-1))):
            value = -((1 << (bits-1)))
        return (value + (1 << bits)) & max_val
    return min(max_val, value)

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

async def write_array_to_ports(dut, values, max_size=8):
    """Write values to individual array ports (arr_0, arr_1, ...)."""
    # Pad to max_size
    values = values + [0] * (max_size - len(values))
    
    for i in range(max_size):
        if has_signal(dut, f'arr_{i}'):
            val = clamp_to_width(values[i], DATA_WIDTH)
            getattr(dut, f'arr_{i}').value = val
        else:
            raise TestFailure(f"Cannot find port arr_{i}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_positive_ratio(dut):
    """Test the positive_ratio module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array_values, expected_fixed_point_ratio)
    # Expected values in Q8.8 format: ratio * 256
    # Example: 0.54 * 256 = 138
    test_cases = [
        ([0, 1, 2, -1, -5, 6, 0, -3, -2, 3, 4, 6, 8], 138, "Test 1: 7/13 ≈ 0.54"),
        ([2, 1, 2, -1, -5, 6, 4, -3, -2, 3, 4, 6, 8], 177, "Test 2: 9/13 ≈ 0.69"),
        ([2, 4, -6, -9, 11, -12, 14, -5, 17], 143, "Test 3: 5/9 ≈ 0.56"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 256, "Test 4: All positive"),
        ([-1, -2, -3, -4], 0, "Test 5: All negative"),
        ([0, 0, 0, 0], 0, "Test 6: All zeros"),
        ([1, 0, 1, 0, 1], 128, "Test 7: 3/5 = 0.6 (153.6 expected, rounding applies)"),
        ([1], 256, "Test 8: Single positive"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (values, expected_fp, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input array: {values}")
        cocotb.log.info(f"  Expected (Q8.8): {expected_fp} ({expected_fp/256:.3f})")
        
        try:
            # Clamp values to 8-bit signed range and write
            # Note: HDL treats values as unsigned for comparison (bit 7 = sign)
            clamped_values = [clamp_to_width(v, DATA_WIDTH) for v in values]
            await write_array_to_ports(dut, clamped_values, max_size=8)
            
            # Write length (but only use first 8 elements)
            test_len = min(len(values), 8)
            dut.start.value = 0
            
            # Wait for idle
            await RisingEdge(dut.clk)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Compare with expected
            # Allow ±2 tolerance due to fixed-point rounding
            if abs(result - expected_fp) <= 2:
                cocotb.log.info(f"  PASS: got {result} ({result/256:.3f})")
                passed += 1
            else:
                raise TestFailure(f"Expected {expected_fp}, got {result}")
            
            # Wait for done to go low
            await FallingEdge(dut.done)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")