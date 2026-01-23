import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SUBLISTS = 8
RESULT_WIDTH = 8

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

async def write_sublists(dut, sublists):
    """Write sublists to the input ports."""
    # Pad to exactly 8 sublists
    padded = sublists + [[]] * (8 - len(sublists))
    
    # Write each sublist's first element to corresponding port
    for i, sublist in enumerate(padded):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            first_elem = sublist[0] if sublist else 0
            getattr(dut, port_name).value = clamp_to_width(first_elem, DATA_WIDTH)
        else:
            raise TestFailure(f"Port {port_name} not found")
    
    # Set number of sublists
    dut.num_sublists.value = len(sublists)

async def read_results(dut, expected_count):
    """Read extracted first elements from output ports."""
    results = []
    
    for i in range(expected_count):
        port_name = f"result_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    # Read result count
    result_count = int(dut.result_count.value) if is_value_defined(dut.result_count.value) else 0
    
    return results, result_count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_extract_first_elements(dut):
    """Test extracting first element from each sublist."""
    
    # Wait for combinational logic to settle
    await Timer(10, units='ns')
    
    # Test cases: (input sublists, expected first elements, description)
    test_cases = [
        ([[1, 2], [3, 4, 5], [6, 7, 8, 9]], [1, 3, 6], "Three sublists of varying lengths"),
        ([[1, 2, 3], [4, 5]], [1, 4], "Two sublists"),
        ([[9, 8, 1], [1, 2]], [9, 1], "Two sublists with larger first elements"),
        ([[1]], [1], "Single element list"),
        ([[5], [6], [7], [8], [9], [10], [11], [12]], [5, 6, 7, 8, 9, 10, 11, 12], "Eight sublists"),
        ([[0, 1], [0, 2], [0, 3]], [0, 0, 0], "First elements are zero"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sublists, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        dut._log.info(f"  Input: {sublists}")
        dut._log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            await write_sublists(dut, sublists)
            
            # Wait for propagation (combinational)
            await Timer(10, units='ns')
            
            # Read results
            results, result_count = await read_results(dut, len(expected))
            
            # Validate result count
            if result_count != len(expected):
                raise TestFailure(f"Result count mismatch: expected {len(expected)}, got {result_count}")
            
            # Validate each result
            for j, (actual, exp) in enumerate(zip(results, expected)):
                if actual != exp:
                    raise TestFailure(f"Element {j}: expected {exp}, got {actual}")
            
            dut._log.info(f"  Result: {results} [PASS]")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info("="*60)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")