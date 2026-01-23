import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
INDEX_WIDTH = 3

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def write_input_array(dut, values):
    """Write values to arr[0:7]."""
    # Try indexed array first
    try:
        for i in range(ARRAY_SIZE):
            val = values[i] if i < len(values) else 0
            dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find array port: arr[{i}] or {port_name}")

async def read_output_signals(dut):
    """Read result, valid, and index outputs."""
    result = None
    valid = None
    index = None
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
    if is_value_defined(dut.valid.value):
        valid = int(dut.valid.value)
    if is_value_defined(dut.index.value):
        index = int(dut.index.value)
    
    return result, valid, index

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_first_odd(dut):
    """Test finding first odd number in array."""
    
    cocotb.log.info("=" * 60)
    cocotb.log.info("Testing First Odd Number Finder Module")
    cocotb.log.info("=" * 60)
    
    # Give combinational logic time to settle
    await Timer(10, units='ns')
    
    # Test cases: (input_array, expected_result, expected_valid, expected_index, description)
    test_cases = [
        ([1, 3, 5], 1, 1, 0, "All odd, first is at index 0"),
        ([2, 4, 1, 3], 1, 1, 2, "First odd at index 2"),
        ([8, 9, 1], 9, 1, 1, "First odd at index 1"),
        ([2, 4, 6, 8], 0, 0, 0, "No odd numbers"),
        ([1, 0, 0, 0, 0, 0, 0, 0], 1, 1, 0, "Only first is odd"),
        ([0, 0, 0, 0, 0, 0, 0, 1], 1, 1, 7, "Only last is odd"),
        ([255, 2, 3], 255, 1, 0, "First is odd (255 = 0xFF)"),
        ([254, 253, 252], 253, 1, 1, "Second is odd (253 = 0xFD)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, exp_result, exp_valid, exp_index, description) in enumerate(test_cases):
        # Pad input to ARRAY_SIZE with zeros
        padded_input = input_arr + [0] * (ARRAY_SIZE - len(input_arr))
        
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_arr}")
        cocotb.log.info(f"  Expected: result={exp_result}, valid={exp_valid}, index={exp_index}")
        
        try:
            # Write inputs
            await write_input_array(dut, padded_input)
            
            # Wait for combinational logic
            await Timer(20, units='ns')
            
            # Read outputs
            result, valid, index = await read_output_signals(dut)
            
            # Validate outputs are defined
            if result is None or valid is None or index is None:
                raise TestFailure("Output signals are undefined (X/Z)")
            
            cocotb.log.info(f"  Got:      result={result}, valid={valid}, index={index}")
            
            # Check results
            errors = []
            if result != exp_result:
                errors.append(f"result mismatch (expected {exp_result}, got {result})")
            if valid != exp_valid:
                errors.append(f"valid mismatch (expected {exp_valid}, got {valid})")
            if index != exp_index:
                errors.append(f"index mismatch (expected {exp_index}, got {index})")
            
            if errors:
                raise TestFailure(" | ".join(errors))
            
            cocotb.log.info(f"  Result: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  Result: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info("\n" + "=" * 60)
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info("=" * 60)
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
