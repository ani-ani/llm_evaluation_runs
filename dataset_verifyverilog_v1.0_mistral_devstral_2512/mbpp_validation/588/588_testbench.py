import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16

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
    return min(max_val, max(0, value))

async def write_array(dut, values, element_width):
    """Write values to arr_0 through arr_7 individually."""
    # Write each element to its port
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                val = clamp_to_width(values[i], element_width)
                getattr(dut, port_name).value = val
            else:
                # Pad unused elements with 0
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Signal '{port_name}' not found")

async def set_len(dut, length):
    """Set the len input signal."""
    if has_signal(dut, 'len'):
        dut.len.value = clamp_to_width(length, 4)
    else:
        raise TestFailure("Signal 'len' not found")

async def read_result(dut):
    """Read and return the result value."""
    if not has_signal(dut, 'result'):
        raise TestFailure("Signal 'result' not found")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    return int(dut.result.value)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_big_diff(dut):
    """Test big_diff module with all test cases."""
    
    cocotb.log.info("Starting big_diff test...")
    
    # Test cases: (input_list, expected_result, description)
    test_cases = [
        ([1, 2, 3, 4], 3, "Test 1: Sequential 1-4"),
        ([4, 5, 12], 8, "Test 2: 4, 5, 12"),
        ([9, 2, 3], 7, "Test 3: 9, 2, 3"),
        ([100, 50, 75], 50, "Test 4: Larger numbers"),
        ([0, 0, 0, 0, 0], 0, "Test 5: All zeros"),
        ([255, 0, 128], 255, "Test 6: Min/max values"),
        ([10], 0, "Test 7: Single element"),
        ([7, 7, 7, 7, 7, 7, 7, 7], 0, "Test 8: All same"),
        ([1, 255, 128, 64, 32], 254, "Test 9: Mixed spread"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_list}, Expected: {expected}")
        
        try:
            # Write array values
            await write_array(dut, input_list, DATA_WIDTH)
            
            # Set length
            await set_len(dut, len(input_list))
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAILED: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")