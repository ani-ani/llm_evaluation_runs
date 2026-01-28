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
MAX_CYCLES = 100

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
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_single_element(dut):
    """Test the find_single_element module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array_values, expected_result, description)
    test_cases = [
        ([1, 1, 2, 2, 3, 0, 0, 0], 3, "Test 1: [1,1,2,2,3] - single 3"),
        ([1, 1, 3, 3, 4, 4, 5, 5], 0, "Test 2: All pairs - should be 0"),
        ([1, 2, 2, 3, 3, 4, 4, 0], 1, "Test 3: [1,2,2,3,3,4,4] - single 1"),
        ([7, 7, 8, 0, 0, 0, 0, 0], 8, "Test 4: [7,7,8] - single 8"),
        ([1, 1, 3, 3, 4, 4, 5, 5], 0, "Test 5: All pairs - XOR of pairs = 0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_values, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Calculate actual XOR result for verification
            expected_xor = 0
            actual_len = 0
            for val in arr_values:
                if val != 0:  # Count non-zero as valid
                    expected_xor ^= val
                    actual_len += 1
            
            # If test case has explicit expected value, use it
            if expected != 0 or arr_values.count(0) == 0:
                expected_xor = expected
            
            # Write array elements individually
            for j, val in enumerate(arr_values):
                if j < ARRAY_SIZE:
                    arr_signal = getattr(dut, f'arr_{j}')
                    arr_signal.value = clamp_to_width(val, DATA_WIDTH)
            
            # Write length (count of valid non-zero elements)
            dut.len.value = actual_len
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read and verify result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected_xor:
                raise TestFailure(f"Expected {expected_xor}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")