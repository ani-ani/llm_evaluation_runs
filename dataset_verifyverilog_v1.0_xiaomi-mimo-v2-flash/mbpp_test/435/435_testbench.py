import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_last_digit(dut):
    """Test last digit computation for various numbers"""
    # Test cases: (input_num, expected_last_digit, description)
    test_cases = [
        (123, 3, "Test 123 -> 3"),
        (25, 5, "Test 25 -> 5"),
        (30, 0, "Test 30 -> 0"),
        (0, 0, "Test 0 -> 0"),
        (99, 9, "Test 99 -> 9"),
        (100, 0, "Test 100 -> 0"),
        (255, 5, "Test 255 -> 5"),
        (199, 9, "Test 199 -> 9"),
        (1, 1, "Test 1 -> 1"),
        (10, 0, "Test 10 -> 0")
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Apply input (clamp to 8 bits for safety)
            dut.num.value = clamp_to_width(num, 8)
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not hasattr(dut, 'result'):
                raise TestFailure("Module does not have 'result' output")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {num} -> {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
