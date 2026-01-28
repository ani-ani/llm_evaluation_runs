import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 3

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

async def write_array(dut, prefix, values):
    """Write values to array using indexed ports."""
    for i, val in enumerate(values):
        port_name = f"{prefix}{i}"
        if has_signal(dut, port_name):
            port = getattr(dut, port_name)
            port.value = from_signed(val, DATA_WIDTH)
        else:
            # Try arr[i] format
            if has_signal(dut, prefix.rstrip('_')):
                arr = getattr(dut, prefix.rstrip('_'))
                arr[i].value = from_signed(val, DATA_WIDTH)
            else:
                raise TestFailure(f"Cannot find port {prefix}{i} or {prefix}")

async def read_array(dut, prefix):
    """Read array values from indexed ports."""
    results = []
    for i in range(ARRAY_SIZE):
        port_name = f"{prefix}{i}"
        if has_signal(dut, port_name):
            port = getattr(dut, port_name)
            if is_value_defined(port.value):
                val = int(port.value)
                results.append(to_signed(val, DATA_WIDTH))
            else:
                results.append(None)
        else:
            # Try arr[i] format
            if has_signal(dut, prefix.rstrip('_')):
                arr = getattr(dut, prefix.rstrip('_'))
                if is_value_defined(arr[i].value):
                    val = int(arr[i].value)
                    results.append(to_signed(val, DATA_WIDTH))
                else:
                    results.append(None)
            else:
                results.append(None)
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_elementwise_subtraction(dut):
    """Test element-wise subtraction of two 3-element arrays."""
    
    cocotb.log.info("Testing element-wise subtraction module")
    
    # Test cases: (a, b, expected_result)
    test_cases = [
        ([10, 4, 5], [2, 5, 18], [8, -1, -13], "Test 1: (10,4,5) - (2,5,18) = (8,-1,-13)"),
        ([11, 2, 3], [24, 45, 16], [-13, -43, -13], "Test 2: (11,2,3) - (24,45,16) = (-13,-43,-13)"),
        ([7, 18, 9], [10, 11, 12], [-3, 7, -3], "Test 3: (7,18,9) - (10,11,12) = (-3,7,-3)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_vals, b_vals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Write input arrays
            await write_array(dut, 'a', a_vals)
            await write_array(dut, 'b', b_vals)
            
            # Combinational logic - wait for propagation
            await Timer(10, units='ns')
            
            # Read result array
            results = await read_array(dut, 'result')
            
            # Verify each element
            for j in range(ARRAY_SIZE):
                if results[j] is None:
                    raise TestFailure(f"Element {j} is undefined (X/Z)")
                
                if results[j] != expected[j]:
                    raise TestFailure(
                        f"Element {j}: expected {expected[j]}, got {results[j]}"
                    )
            
            cocotb.log.info(f"  PASS: result = {tuple(results)}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")