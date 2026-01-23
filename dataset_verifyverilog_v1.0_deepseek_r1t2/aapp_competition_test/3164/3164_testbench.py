import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, values):
    """Write values to array using individual ports."""
    for i in range(8):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            # Fallback to indexed array
            try:
                dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
            except:
                raise TestFailure(f"Cannot find array port: {port_name} or arr[{i}]")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    """Test the longest_exactly_twice module."""
    
    # Module is combinational, no clock/reset needed
    
    # Define test cases: (values, N, expected_max_length, description)
    test_cases = [
        ([1,2,3,3,4,2], 6, 2, "Sample 1: [3,3] valid, length=2"),
        ([1,2,1,3,1,3,1,2], 8, 4, "Sample 2: [1,3,1,3] valid, length=4"),
        ([1,10,100,1000,100,10,1], 7, 0, "Sample 3: no valid subarray"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (values, n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input array (first {n} elements): {values}")
        
        try:
            # Write inputs
            await write_array(dut, values)
            dut.N.value = n
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.max_length.value):
                raise TestFailure("max_length is undefined (X/Z)")
            
            result = int(dut.max_length.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: max_length = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
