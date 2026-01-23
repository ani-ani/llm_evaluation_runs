import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_hexagonal_num(dut):
    """Test hexagonal number calculation."""
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (10, 190),
        (5, 45),
        (7, 91),
        (1, 1),   # Edge case: first hexagonal number
        (0, 0),   # Edge case: zero
    ]
    
    cocotb.log.info("Testing hexagonal number calculation")
    
    passed = 0
    failed = 0
    
    for i, (input_n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={input_n}, expected={expected}")
        
        # Write input
        dut.n.value = input_n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")