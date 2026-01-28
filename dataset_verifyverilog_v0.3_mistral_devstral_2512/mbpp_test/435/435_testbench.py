import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 8

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_last_digit(dut):
    """Test the last digit calculator."""
    
    # Combinational module - no clock or reset needed
    
    # Define test cases: (input, expected_output, description)
    test_cases = [
        (123, 3, "Test 1: last digit of 123"),
        (25, 5, "Test 2: last digit of 25"),
        (30, 0, "Test 3: last digit of 30"),
        (0, 0, "Test 4: last digit of 0"),
        (99, 9, "Test 5: last digit of 99"),
        (255, 5, "Test 6: last digit of 255"),
        (100, 0, "Test 7: last digit of 100"),
        (1, 1, "Test 8: last digit of 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input
            dut.n.value = input_val
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.last_digit.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.last_digit.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: last_digit({input_val}) = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")