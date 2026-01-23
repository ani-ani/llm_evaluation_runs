import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def int_to_bytes(val):
    """Convert integer to single byte"""
    return val & 0xFF

def pack_array(arr):
    """Pack list of integers into array format"""
    return [int_to_bytes(x) for x in arr]

@cocotb.test()
async def test_sublist_checker(dut):
    """Test sublist checker with various cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    # Test cases: (main, pattern, expected_result, description)
    test_cases = [
        ([1, 4, 3, 5], [1, 2], False, "Test 1: pattern not in main"),
        ([1, 2, 1], [1, 2, 1], True, "Test 2: exact match"),
        ([1, 0, 2, 2], [2, 2, 0], False, "Test 3: wrong order"),
        ([5, 6, 7, 8], [6, 7], True, "Test 4: pattern in middle"),
        ([1, 2, 3, 4], [5, 6], False, "Test 5: pattern not found"),
        ([1, 2, 3, 4], [1, 2, 3, 4], True, "Test 6: full array match"),
        ([1, 2, 3, 4], [1], True, "Test 7: single element pattern"),
        ([1, 2, 3, 4], [4], True, "Test 8: last element match"),
        ([7], [7], True, "Test 9: both length 1, match"),
        ([7], [8], False, "Test 10: both length 1, no match"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (main, pattern, expected, description) in enumerate(test_cases):
        # Pad arrays to length 8
        main_padded = pack_array(main + [0] * (8 - len(main)))
        pattern_padded = pack_array(pattern + [0] * (8 - len(pattern)))
        
        # Set inputs
        for j in range(8):
            dut.main_array[j].value = main_padded[j]
            dut.pattern[j].value = pattern_padded[j]
        
        dut.main_len.value = len(main)
        dut.pattern_len.value = len(pattern)
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Check result
        result = bool(dut.result.value)
        expected_val = bool(expected)
        
        if result == expected_val and dut.done.value:
            print(f"PASS: {description}")
            passed += 1
        else:
            print(f"FAIL: {description}")
            print(f"  Expected: {expected_val}, Got: {result}, Done: {dut.done.value}")
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    print(f"
Results: {passed}/{total} tests passed")
    assert passed == total, f"Some tests failed: {passed}/{total} passed"
