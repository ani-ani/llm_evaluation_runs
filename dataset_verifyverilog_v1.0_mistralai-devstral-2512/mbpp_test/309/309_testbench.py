import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Helpers
def clamp_to_signed8(val):
    """Clamp value to signed 8-bit range (-128 to 127)"""
    val = int(val)
    return max(-128, min(127, val))

def to_signed8(val):
    """Convert signed Python int to signed 8-bit representation"""
    val = clamp_to_signed8(val)
    if val < 0:
        return val + 256
    return val

def from_signed8(val):
    """Convert from 8-bit signed to Python int"""
    if val >= 128:
        return val - 256
    return val

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_maximum(dut):
    """Test maximum of two signed 8-bit integers"""
    
    # Define test cases: (a, b, expected_max)
    test_cases = [
        (5, 10, 10),        # Test 1: positive numbers
        (-1, -2, -1),       # Test 2: negative numbers  
        (9, 7, 9),          # Test 3: positive numbers
        (-128, 127, 127),   # Edge case: min and max
        (5, 5, 5),          # Equality case
        (-5, -3, -3),       # Negative with smaller magnitude
        (0, 0, 0),          # Zero case
        (-128, -127, -127), # Near minimum
        (126, 127, 127),    # Near maximum
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_val, b_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_val}, b={b_val}")
        try:
            # Convert to signed 8-bit and assign
            a_signed = to_signed8(a_val)
            b_signed = to_signed8(b_val)
            
            dut.a.value = a_signed
            dut.b.value = b_signed
            
            # Small delay for combinational logic
            await Timer(10, units='ns')
            
            # Read and convert result
            result_raw = int(dut.max_result.value)
            result = from_signed8(result_raw)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: max({a_val},{b_val}) = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")
