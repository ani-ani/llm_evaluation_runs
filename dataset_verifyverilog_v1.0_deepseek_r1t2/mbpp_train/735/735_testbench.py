import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_toggle_middle_bits(dut):
    """
    Test the toggle_middle_bits module with various test cases.
    All inputs and outputs are 8-bit values.
    """
    
    # Define test cases: (input, expected_output, description)
    # Note: Original test cases use values that fit in 8 bits
    test_cases = [
        (9, 15, "Test 1: 9 -> 15"),
        (10, 12, "Test 2: 10 -> 12"),
        (11, 13, "Test 3: 11 -> 13"),
        (0b1000001, 0b1111111, "Test 4: 0b1000001 -> 0b1111111"),
        (0b1001101, 0b1110011, "Test 5: 0b1001101 -> 0b1110011"),
        (1, 1, "Test 6: Edge case - 1 should remain 1"),
        (0, 0, "Test 7: Zero input"),
        (255, 255, "Test 8: All bits set"),
        (2, 2, "Test 9: Only bit 1 set (single middle bit)"),
        (4, 6, "Test 10: Only bit 2 set (should toggle to 6)"),
        (8, 12, "Test 11: Only bit 3 set (should toggle to 12)"),
        (16, 24, "Test 12: Only bit 4 set (should toggle to 24)"),
        (32, 48, "Test 13: Only bit 5 set (should toggle to 48)"),
        (64, 96, "Test 14: Only bit 6 set (should toggle to 96)"),
        (128, 192, "Test 15: Only bit 7 set (should toggle to 192)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_val, expected, description) in enumerate(test_cases):
        # Set input with clamping to 8 bits
        dut.n.value = input_val & 0xFF
        
        # Wait for combinational logic to settle (small delay)
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1} FAILED: Result is undefined (X/Z)")
            failed += 1
            continue
        
        actual = int(dut.result.value)
        
        if actual == expected:
            cocotb.log.info(f"Test {i+1} PASSED: {description}")
            cocotb.log.info(f"  Input: 0b{input_val:08b} ({input_val}), Output: 0b{actual:08b} ({actual})")
            passed += 1
        else:
            cocotb.log.error(f"Test {i+1} FAILED: {description}")
            cocotb.log.error(f"  Input:    0b{input_val:08b} ({input_val})")
            cocotb.log.error(f"  Expected: 0b{expected:08b} ({expected})")
            cocotb.log.error(f"  Actual:   0b{actual:08b} ({actual})")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")