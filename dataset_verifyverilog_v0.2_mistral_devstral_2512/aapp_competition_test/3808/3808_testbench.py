import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_bracket_fix_checker(dut):
    """Test bracket fix checker module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_result)
    # Expected: 1 = Yes, 0 = No
    test_cases = [
        (")(", 1),      # Can fix: move first ')' to end -> "()"
        ("(()", 0),     # Cannot fix (3 chars, but we'll test 8-char padded)
        ("()", 1),      # Already correct
        ("))))((((", 0), # Too many imbalances
        (")(", 1),      # Move first ')' to end
        ("((()))()", 1), # Already correct
        (")()()()(", 1), # Can fix by moving first ')' to end
    ]
    
    # We'll test with 8-char padded strings
    padded_cases = []
    for s, exp in test_cases:
        if len(s) <= 8:
            padded = s + '(' * (8 - len(s))  # Pad with '(' to make 8 chars
            # Adjust expected for padding (if original was correct, padded might not be)
            # Actually, we should test the core logic properly
            # Let's create proper 8-char test cases
    
    # Better approach: test the algorithm's core logic
    # Test case format: 8-character string
    test_vectors = [
        (")((((((", 1),  # Single ')' at start, can move to make correct
        ("((()))()", 1), # Balanced and valid
        (")()()()(", 1), # Single ')' at start, single '(' at end - can fix
        ("))))((((", 0), # Too many imbalances
        ("()()()()", 1), # Perfectly balanced
        ("((((((((", 0), # All open, cannot fix
        ("))))))))", 0), # All close, cannot fix
        ("(()()(()", 1), # Single imbalance, can potentially fix
    ]
    
    passed = 0
    total = len(test_vectors)
    
    for i, (input_str, expected) in enumerate(test_vectors):
        dut._log.info(f"Test {i+1}: Input='{input_str}', Expected={expected}")
        
        # Start the process
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one by one
        for j in range(8):
            char = input_str[j]
            # ASCII values
            if char == '(':
                dut.char_in.value = 0x28
            else:  # ')'
                dut.char_in.value = 0x29
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # Wait for done signal
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 20:
            raise TestFailure(f"Test {i+1} timed out waiting for done")
        
        # Check result
        actual = int(dut.result.value)
        
        if actual == expected:
            dut._log.info(f"Test {i+1} PASSED: Got {actual}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Got {actual}, expected {expected}")
            # Don't raise, continue testing
    
    # Additional edge case tests
    # Test: empty-like (all matching pairs in first few chars)
    dut._log.info("Testing edge cases...")
    
    # Test case: "()()()()" (already correct)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in "()()()()":
        dut.char_in.value = 0x28 if char == '(' else 0x29
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) == 1:
        passed += 1
        dut._log.info("Edge case 1 PASSED")
    else:
        dut._log.error("Edge case 1 FAILED")
    total += 1
    
    # Test case: "))))))((" (should be No)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in "))))))((":
        dut.char_in.value = 0x28 if char == '(' else 0x29
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) == 0:
        passed += 1
        dut._log.info("Edge case 2 PASSED")
    else:
        dut._log.error("Edge case 2 FAILED")
    total += 1
    
    dut._log.info(f"
{'='*40}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*40}")
    
    if passed != total:
        raise TestFailure(f"Some tests failed: {passed}/{total}")