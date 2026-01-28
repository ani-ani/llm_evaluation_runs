import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
FLAT_WIDTH = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        value = from_signed(value, bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def pack_array(values, element_bits=8):
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_statue_rearrangement(dut):
    """Test the statue rearrangement module."""
    
    # Generate test cases: (a_list, b_list, expected, description)
    test_cases = [
        ([1,2,3,4,5,6,7,0], [1,2,3,4,5,6,7,0], 1, "Same sequence"),
        ([1,2,3,4,5,6,7,0], [7,1,2,3,4,5,6,0], 1, "Rotated by 6"),
        ([1,2,3,4,5,6,7,0], [1,2,4,3,5,6,7,0], 0, "Not a rotation"),
        ([1,0,2,3,4,5,6,7], [2,3,4,5,6,7,1,0], 1, "Zero in middle, rotated"),
        ([5,6,7,1,2,3,4,0], [1,2,3,4,5,6,7,0], 1, "Rotated by 3"),
        ([1,2,3,4,5,6,7,0], [3,4,5,6,7,1,2,0], 1, "Rotated by 2"),
        ([1,2,3,0,4,5,6,7], [4,5,6,7,1,2,3,0], 1, "Zero at index 3, rotated"),
        ([1,2,3,0,4,5,6,7], [1,2,3,4,5,6,7,0], 0, "Different sequences"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_vals, b_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Pack arrays into 64-bit values
        a_packed = pack_array(a_vals, DATA_WIDTH)
        b_packed = pack_array(b_vals, DATA_WIDTH)
        
        # Assign inputs
        dut.a_flat.value = a_packed
        dut.b_flat.value = b_packed
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            cocotb.log.error(f"    a: {a_vals}")
            cocotb.log.error(f"    b: {b_vals}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")