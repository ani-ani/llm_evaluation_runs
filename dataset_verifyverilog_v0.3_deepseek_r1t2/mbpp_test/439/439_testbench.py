import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
    if value < 0:
        # For negative, clamp absolute value then set sign
        abs_val = min(abs(value), 127)
        return from_signed(-abs_val, bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def clamp_int_to_8bit(value):
    """Clamp integer to 8-bit representation, preserving sign for negative."""
    if value < 0:
        # For negative, clamp to -128 to -1
        return max(-128, value)
    else:
        # For positive, clamp to 0-127 (avoiding overflow in 2-digit conversion)
        return min(127, value)

async def reset_dut(dut):
    """Reset the DUT."""
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
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_multi_concat(dut):
    """Test multi-element concatenation."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (input_list, expected_result, description)
    test_cases = [
        ([11, 33, 50], 113350, "Test 1: [11,33,50] -> 113350"),
        ([-1, 2, 3, 4, 5, 6], -123456, "Test 2: [-1,2,3,4,5,6] -> -123456"),
        ([10, 15, 20, 25], 10152025, "Test 3: [10,15,20,25] -> 10152025"),
        ([1, 2, 3], 1230, "Test 4: [1,2,3] -> 1230 (padded)"),
        ([99, 99, 99, 99, 99, 99, 99, 99], 99999999, "Test 5: All 99s"),
        ([0, 0, 0, 0], 0, "Test 6: All zeros"),
        ([-5, -6], -560, "Test 7: Negative first only [-5,-6] -> -560"),
        ([50], 5000, "Test 8: Single element [50] -> 5000")
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Clamp input values to 8-bit and write to array
            clamped_inputs = [clamp_int_to_8bit(x) for x in input_list]
            
            # Write to array elements individually
            for idx, val in enumerate(clamped_inputs):
                # Get the array element by name
                arr_elem = getattr(dut, f'arr_{idx}')
                arr_elem.value = from_signed(val, DATA_WIDTH)
            
            # Set length
            dut.len.value = len(input_list)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            raw_result = int(dut.result.value)
            
            # Convert to signed if needed (check sign bit)
            if raw_result >= (1 << (RESULT_WIDTH - 1)):
                actual_result = raw_result - (1 << RESULT_WIDTH)
            else:
                actual_result = raw_result
            
            # For comparison, adjust expected based on number of elements
            # The design shifts based on len, so we need to compute properly
            expected_final = expected
            
            if actual_result != expected_final:
                raise TestFailure(f"Expected {expected_final}, got {actual_result}")
            
            cocotb.log.info(f"  PASS: result = {actual_result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
