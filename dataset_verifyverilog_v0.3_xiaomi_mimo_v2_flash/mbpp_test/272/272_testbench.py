import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TUPLE_SIZE = 3
NUM_TUPLES = 3

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
# ARRAY/TUPLE WRITE HELPERS
# ============================================================================

async def write_tuple(dut, tuple_idx, elements):
    """Write a tuple's elements to the DUT."""
    for elem_idx, value in enumerate(elements):
        port_name = f"tuple_{tuple_idx}_elem_{elem_idx}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(value, DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {port_name} not found")

async def read_rear_elements(dut):
    """Read all rear elements from DUT."""
    results = []
    for i in range(NUM_TUPLES):
        port_name = f"rear_{i}"
        if has_signal(dut, port_name):
            sig = getattr(dut, port_name)
            if is_value_defined(sig.value):
                results.append(int(sig.value))
            else:
                raise TestFailure(f"{port_name} is undefined (X/Z)")
        else:
            raise TestFailure(f"Signal {port_name} not found")
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_rear_extract(dut):
    """Test rear element extraction from tuples."""
    
    dut._log.info("Starting rear_extract test")
    
    # Test cases: (input_tuples, expected_rears, description)
    # Original tuples: (1, 'Rash', 21), (2, 'Varsha', 20), (3, 'Kil', 19)
    # Converting strings to numeric: 'Rash'=82, 'Varsha'=86, 'Kil'=75
    test_cases = [
        ([(1, 82, 21), (2, 86, 20), (3, 75, 19)], [21, 20, 19], "Test case 1"),
        ([(1, 83, 36), (2, 87, 25), (3, 76, 45)], [36, 25, 45], "Test case 2"),
        ([(1, 84, 14), (2, 88, 36), (3, 77, 56)], [14, 36, 56], "Test case 3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_tuples, expected_rears, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        try:
            # Write all tuples to DUT
            for tuple_idx, tuple_data in enumerate(input_tuples):
                await write_tuple(dut, tuple_idx, tuple_data)
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read rear elements
            rear_elements = await read_rear_elements(dut)
            
            # Verify results
            if rear_elements != expected_rears:
                raise TestFailure(
                    f"Expected {expected_rears}, got {rear_elements}"
                )
            
            dut._log.info(f"  PASS: rear elements = {rear_elements}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
