import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_sum_of_powers_of_two(dut):
    """Test that even numbers return True, odd numbers return False"""
    
    # Test cases from problem: (input, expected_output, description)
    test_cases = [
        (10, True, "10 is even"),
        (7, False, "7 is odd"),
        (14, True, "14 is even"),
        (2, True, "2 is even (and a power of 2)"),
        (4, True, "4 is even (and a power of 2)"),
        (8, True, "8 is even (and a power of 2)"),
        (1, False, "1 is odd"),
        (3, False, "3 is odd"),
        (15, False, "15 is odd"),
        (0, True, "0 is even"),
        (255, False, "255 is odd"),
        (254, True, "254 is even"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} (n={n_input})")
        
        # Clamp input to 8 bits
        n_val = n_input & 0xFF
        
        # Assign input
        dut.n.value = n_val
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Check output is defined
        if not is_value_defined(dut.is_sum.value):
            cocotb.log.error(f"  FAIL: Output is undefined (X/Z)")
            failed += 1
            continue
        
        # Read result
        result = int(dut.is_sum.value)
        
        # Convert expected to integer
        expected_val = 1 if expected else 0
        
        if result != expected_val:
            cocotb.log.error(f"  FAIL: Expected {expected_val}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")