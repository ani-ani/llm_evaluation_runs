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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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

async def write_array(dut, values):
    """Write values to individual array ports."""
    # Pad to 8 elements
    padded_values = values[:8] + [0] * (8 - len(values))
    
    for i in range(8):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            val = clamp_to_width(padded_values[i], DATA_WIDTH)
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_product_even_odd(dut):
    """Test the find_product_even_odd module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_list, expected_result, description)
    # Expected results:
    # Test 1: [1,3,5,7,4,1,6,8] -> first_even=4, first_odd=1 -> 4*1=4
    # Test 2: [1,2,3,4,5,6,7,8,9,10] -> first_even=2, first_odd=1 -> 2*1=2  
    # Test 3: [1,5,7,9,10] -> first_even=10, first_odd=1 -> 10*1=10
    test_cases = [
        ([1, 3, 5, 7, 4, 1, 6, 8], 4, "First even at index 4 (value 4), first odd at index 0 (value 1)"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 2, "First even at index 1 (value 2), first odd at index 0 (value 1)"),
        ([1, 5, 7, 9, 10], 10, "First even at index 4 (value 10), first odd at index 0 (value 1)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_list}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            await write_array(dut, input_list)
            
            # Set length
            dut.len.value = len(input_list) if len(input_list) <= 8 else 8
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")