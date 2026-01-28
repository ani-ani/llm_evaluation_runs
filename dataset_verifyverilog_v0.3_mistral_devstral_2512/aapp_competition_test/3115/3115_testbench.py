import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

MAX_N = 8
MAX_M = 16

def pack_eq(eq_list):
    """Pack list of eq flags (0/1) into a 16-bit integer."""
    packed = 0
    for i, val in enumerate(eq_list):
        if val:
            packed |= (1 << i)
    return packed

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_chess_consistency(dut):
    """Test the chess consistency checker."""
    
    # No clock, combinational module
    
    # Test cases: (description, num_matches, match_k_list, match_l_list, match_eq_list, expected_result)
    test_cases = [
        (
            "inconsistent example 1",
            3,
            [0, 1, 2],
            [1, 2, 0],
            [0, 1, 1],  # 0>1, 1=2, 0=2
            0
        ),
        (
            "consistent example 2",
            5,
            [0, 1, 3, 0, 1],
            [1, 2, 4, 3, 4],
            [1, 1, 1, 0, 0],  # 0=1,1=2,3=4,0>3,1>4
            1
        ),
        (
            "inconsistent example 3",
            5,
            [0, 1, 3, 4, 5],
            [1, 2, 4, 5, 3],
            [0, 0, 1, 1, 0],  # 0>1,1>2,3=4,4=5,5>3
            0
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (desc, num_matches, k_list, l_list, eq_list, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Pad lists to length MAX_M
        k_padded = k_list + [0] * (MAX_M - len(k_list))
        l_padded = l_list + [0] * (MAX_M - len(l_list))
        eq_padded = eq_list + [0] * (MAX_M - len(eq_list))
        
        try:
            # Set num_matches
            dut.num_matches.value = num_matches
            
            # Set match_k array
            for idx in range(MAX_M):
                dut.match_k[idx].value = clamp_to_width(k_padded[idx], 3)
            
            # Set match_l array
            for idx in range(MAX_M):
                dut.match_l[idx].value = clamp_to_width(l_padded[idx], 3)
            
            # Set match_eq vector
            dut.match_eq.value = pack_eq(eq_padded)
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")