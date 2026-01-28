import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
TUPLE_SIZE = 4
RESULT_SIZE = 5
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

def pack_dict(key_val_pairs):
    """Pack dictionary key-value pairs into 32-bit value.
    Format: [8-bit val2][8-bit key2][8-bit val1][8-bit key1] (simplified)
    """
    # For this test, we'll encode as: key1=MSAM, val1=1, key2=is, val2=2, key3=best, val3=3
    # But we only have 32 bits, so we'll use a simple encoding
    # Let's encode as: {val3[7:0], val2[7:0], val1[7:0], key1[7:0]}
    # For test cases:
    # Test1: {3, 2, 1, 1} where 1 represents 'M' from MSAM (simplified)
    # Test2: {4, 3, 2, 2} where 2 represents 'U' from UTS
    # Test3: {5, 4, 3, 3} where 3 represents 'P' from POS
    return key_val_pairs

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_tuple(dut, values):
    """Write values to tuple_data array."""
    for i, val in enumerate(values):
        dut.tuple_data[i].value = val

async def read_result(dut):
    """Read result array."""
    results = []
    for i in range(RESULT_SIZE):
        if is_value_defined(dut.result[i].value):
            results.append(int(dut.result[i].value))
        else:
            results.append(None)
    return results

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_dict_appender(dut):
    """Test tuple and dictionary appending."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (tuple_data, dict_data, expected_result)
    # Dictionary data is packed as: {val3, val2, val1, key1}
    test_cases = [
        (
            [4, 5, 6, 0],  # Tuple data (4 elements)
            pack_dict(0x03020101),  # Dict: {3, 2, 1, 1} -> Test1
            [4, 5, 6, 0, 0x03020101],  # Expected result
            "Test 1: (4,5,6) + dict"
        ),
        (
            [1, 2, 3, 0],  # Tuple data
            pack_dict(0x04030202),  # Dict: {4, 3, 2, 2} -> Test2
            [1, 2, 3, 0, 0x04030202],  # Expected result
            "Test 2: (1,2,3) + dict"
        ),
        (
            [8, 9, 10, 0],  # Tuple data
            pack_dict(0x05040303),  # Dict: {5, 4, 3, 3} -> Test3
            [8, 9, 10, 0, 0x05040303],  # Expected result
            "Test 3: (8,9,10) + dict"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tuple_data, dict_data, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_tuple(dut, tuple_data)
            dut.dict_data.value = dict_data
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            for j in range(RESULT_SIZE):
                if not is_value_defined(dut.result[j].value):
                    raise TestFailure(f"Result[{j}] is undefined (X/Z)")
            
            # Convert to readable format for comparison
            result_actual = result
            
            if result_actual != expected:
                raise TestFailure(f"Expected {expected}, got {result_actual}")
            
            cocotb.log.info(f"  PASS: Result = {result_actual}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST FOR PRACTICAL VALUES
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_empty_tuple(dut):
    """Test appending to empty tuple."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test with all zeros
    await write_tuple(dut, [0, 0, 0, 0])
    dut.dict_data.value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = await read_result(dut)
    expected = [0, 0, 0, 0, 0]
    
    if result != expected:
        raise TestFailure(f"Empty tuple test failed: expected {expected}, got {result}")
    
    cocotb.log.info("Empty tuple test: PASS")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_large_values(dut):
    """Test with large 32-bit values."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test with maximum values
    tuple_data = [0xFFFFFFFF, 0x12345678, 0x87654321, 0x0]
    dict_data = 0xDEADBEEF
    
    await write_tuple(dut, tuple_data)
    dut.dict_data.value = dict_data
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = await read_result(dut)
    expected = [0xFFFFFFFF, 0x12345678, 0x87654321, 0x0, 0xDEADBEEF]
    
    if result != expected:
        raise TestFailure(f"Large values test failed: expected {expected}, got {result}")
    
    cocotb.log.info("Large values test: PASS")

# ============================================================================
# HELPERS FOR DICTIONARY ENCODING
# ============================================================================

def encode_dict_simple(key1, val1, key2, val2, key3, val3):
    """Encode dictionary to 32-bit value."""
    # Simple encoding: val3[23:16] | val2[15:8] | val1[7:0]
    # Keys are implicit in test context
    return (val3 << 16) | (val2 << 8) | val1

# Pre-encoded values for test cases
test_dict_1 = encode_dict_simple('M', 1, 'i', 2, 'b', 3)  # MSAM: 0x030201
test_dict_2 = encode_dict_simple('U', 2, 'i', 3, 'W', 4)  # UTS: 0x040302
test_dict_3 = encode_dict_simple('P', 3, 'i', 4, 'O', 5)  # POS: 0x050403