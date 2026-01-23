import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16

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

def sum_div_python(number):
    """Reference Python implementation."""
    if number <= 1:
        return 0
    divisors = [1]
    for i in range(2, number):
        if (number % i) == 0:
            divisors.append(i)
    return sum(divisors)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sum_div(dut):
    """Test the sum_div module with various inputs."""
    
    # Test cases: (input, expected_output, description)
    test_cases = [
        (8, 7, "8: divisors 1,2,4 = 7"),
        (12, 16, "12: divisors 1,2,3,4,6 = 16"),
        (7, 1, "7: divisors 1 = 1"),
        (1, 0, "1: no proper divisors = 0"),
        (2, 1, "2: divisors 1 = 1"),
        (6, 6, "6: divisors 1,2,3 = 6"),
        (10, 8, "10: divisors 1,2,5 = 8"),
        (0, 0, "0: edge case = 0"),
        (255, 177, "255: divisors 1,3,5,15,17,51,85 = 177"),
        (4, 3, "4: divisors 1,2 = 3"),
        (9, 4, "9: divisors 1,3 = 4"),
        (16, 15, "16: divisors 1,2,4,8 = 15"),
        (25, 6, "25: divisors 1,5 = 6"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (number, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input
            dut.number.value = number
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: sum_div({number}) = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Verify against Python reference for additional test cases
    cocotb.log.info(f"\nVerifying with Python reference for numbers 1-20...")
    for number in range(1, 21):
        dut.number.value = number
        await Timer(50, units='ns')
        
        if is_value_defined(dut.result.value):
            hw_result = int(dut.result.value)
            py_result = sum_div_python(number)
            
            if hw_result != py_result:
                cocotb.log.error(f"  MISMATCH: number={number}, HW={hw_result}, Python={py_result}")
                failed += 1
            else:
                passed += 1
        else:
            cocotb.log.error(f"  Undefined result for number={number}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")