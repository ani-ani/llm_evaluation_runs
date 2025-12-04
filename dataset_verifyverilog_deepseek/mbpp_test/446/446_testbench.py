import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_element_counter(dut):
    # Test cases: Original + edge cases
    test_cases = [
        # Test 1 (scaled)
        {'tuple': [ord('a'), ord('a'), ord('c'), ord('b'), ord('d'), 0, 0, 0], 
         'list': [ord('a'), ord('b'), 0, 0], 
         'expected': 3},
        
        # Test 2 (scaled)
        {'tuple': [1, 2, 3, 1, 4, 6, 7, 1], 
         'list': [1, 4, 7, 0], 
         'expected': 6},
        
        # Test 3 (scaled)
        {'tuple': [1,2,3,4,5,6,0,0], 
         'list': [1,2,0,0], 
         'expected': 2},
        
        # Edge case: zero matches
        {'tuple': [10,20,30,40,0,0,0,0], 
         'list': [5,6,7,8], 
         'expected': 0},
        
        # Full match
        {'tuple': [5,5,5,5,5,5,5,5], 
         'list': [5,0,0,0], 
         'expected': 8}
    ]
    
    passed = 0
    for case in test_cases:
        # Apply inputs
        for i in range(8):
            dut.tuple__i__value = case['tuple'][i] if i < len(case['tuple']) else 0
        for i in range(4):
            dut.list__i__value = case['list'][i] if i < len(case['list']) else 0
        
        # Wait for combinational logic
        await Timer(1, units='ns')
        
        # Check output
        actual = dut.count.value
        if int(actual) == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Expected {case['expected']}, got {actual}")
        else:
            dut._log.error(f"FAIL: Expected {case['expected']}, got {actual}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")