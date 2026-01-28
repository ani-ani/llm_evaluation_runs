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
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_array(dut, values, element_width):
    """Write values to arr_0 through arr_7 individually."""
    # Pad values to 8 elements with zeros
    padded_values = values + [0] * (ARRAY_SIZE - len(values))
    
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = clamp_to_width(padded_values[i], element_width)
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def read_array(dut):
    """Read sorted array from sorted_0 through sorted_7."""
    results = []
    for i in range(ARRAY_SIZE):
        port_name = f"sorted_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_comb_sort(dut):
    """Test comb_sort module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (input_list, expected_sorted, description)
    test_cases = [
        ([5, 15, 37, 25, 79], [5, 15, 25, 37, 79, 0, 0, 0], "Test 1: 5 elements"),
        ([41, 32, 15, 19, 22], [15, 19, 22, 32, 41, 0, 0, 0], "Test 2: 5 elements"),
        ([99, 15, 13, 47], [13, 15, 47, 99, 0, 0, 0, 0], "Test 3: 4 elements"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8], "Test 4: Already sorted"),
        ([8, 7, 6, 5, 4, 3, 2, 1], [1, 2, 3, 4, 5, 6, 7, 8], "Test 5: Reverse sorted"),
        ([5, 5, 5, 5, 5, 5, 5, 5], [5, 5, 5, 5, 5, 5, 5, 5], "Test 6: All duplicates"),
        ([0, 255, 128, 64, 192, 32, 160, 96], [0, 16, 32, 64, 96, 128, 192, 255], "Test 7: Edge values"),
        ([42], [42, 0, 0, 0, 0, 0, 0, 0], "Test 8: Single element"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"Input:    {input_list}")
        cocotb.log.info(f"Expected: {expected}")
        
        try:
            # Write input array
            await write_array(dut, input_list, DATA_WIDTH)
            
            # Pulse start signal
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read sorted output
            result = await read_array(dut)
            
            # Remove None values and validate
            if None in result:
                raise TestFailure(f"Output contains undefined values: {result}")
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"Result:   {result}")
            cocotb.log.info(f"Status:   PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Status:   FAIL - {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")