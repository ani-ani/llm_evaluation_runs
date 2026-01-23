import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_text_match_z_middle(dut):
    """Test the text_match_z_middle module with various string inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases with expected results
    test_cases = [
        # Test 1: "pythonzabc" - 'z' at position 6 (0-indexed), expected True
        (['p', 'y', 't', 'h', 'o', 'n', 'z', 'a'], True, "pythonzabc - 'z' at position 6"),
        # Test 2: "zxyabc__" - 'z' at position 0, expected False  
        (['z', 'x', 'y', 'a', 'b', 'c', '_', '_'], False, "zxyabc__ - 'z' at position 0"),
        # Test 3: "__lang__" - no 'z', expected False
        (['_', '_', 'l', 'a', 'n', 'g', '_', '_'], False, "__lang__ - no 'z' present"),
        # Test 4: "ab__z__c" - 'z' at position 4, expected True
        (['a', 'b', '_', '_', 'z', '_', 'c', '_'], True, "ab__z__c - 'z' at position 4"),
        # Test 5: "_____z__" - 'z' at position 5, expected True
        (['_', '_', '_', '_', '_', 'z', '_', '_'], True, "_____z__ - 'z' at position 5"),
        # Test 6: "______z_" - 'z' at position 6, expected True
        (['_', '_', '_', '_', '_', '_', 'z', '_'], True, "______z_ - 'z' at position 6"),
        # Test 7: "_______z" - 'z' at position 7, expected False
        (['_', '_', '_', '_', '_', '_', '_', 'z'], False, "_______z - 'z' at position 7"),
        # Test 8: "z______z" - 'z' at positions 0 and 7, expected False
        (['z', '_', '_', '_', '_', '_', '_', 'z'], False, "z______z - 'z' at positions 0 and 7"),
        # Test 9: "az______" - 'z' at position 1, expected True
        (['a', 'z', '_', '_', '_', '_', '_', '_'], True, "az______ - 'z' at position 1"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (chars, expected, description) in enumerate(test_cases):
        print(f"
Test {i+1}: {description}")
        print(f"  Input string: {''.join(chars)}")
        print(f"  Expected: {expected}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one by one
        for pos in range(8):
            # Convert char to ASCII value
            ascii_val = ord(chars[pos]) if chars[pos] != '_' else 0x20
            dut.char_in.value = ascii_val
            dut.char_index.value = pos
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        # Wait for done signal
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Check result
        actual = bool(dut.result.value)
        print(f"  Actual: {actual}")
        print(f"  Result: {'PASS' if actual == expected else 'FAIL'}")
        
        assert actual == expected, f"Test failed: {description} - Expected {expected}, got {actual}"
        if actual == expected:
            passed += 1
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
