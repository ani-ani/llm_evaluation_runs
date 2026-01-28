import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

# Main test
cocotb.log.setLevel(cocotb.logging.INFO)

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_tetrahedral_number(dut):
    """Test the tetrahedral number module"""
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (5, 35),
        (6, 56),
        (7, 84),
        (0, 0),   # Edge case
        (1, 1),   # 1*2*3/6 = 1
        (10, 220) # Known value
    ]
    
    cocotb.log.info(f"Testing {len(test_cases)} cases on module: {dut._name}")
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle (10ns simulation time)
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test failed for n={n}: Result signal is undefined (X)")
            failed += 1
            continue
            
        actual = int(dut.result.value)
        
        # Handle potential 16-bit saturation if input n is large (>100)
        # For n <= 100, result is < 176851, which fits in 16-bit signed (max 32767)
        # So we expect saturation or proper wrapping depending on implementation.
        # The prompt asks for saturation to 32767.
        
        if n > 100:
            expected = 32767 # Saturated value
            
        if actual == expected:
            cocotb.log.info(f"PASS: n={n}, result={actual}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: n={n}, expected={expected}, got={actual}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")