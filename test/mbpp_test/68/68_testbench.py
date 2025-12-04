import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_monotonic(dut):
    test_cases = [
        # Test 1: Non-increasing (4 elements)
        {'arr': [6,5,4,4,0,0,0,0], 'n': 4, 'expected': 1},
        # Test 2: Non-decreasing (4 elements)
        {'arr': [1,2,2,3,0,0,0,0], 'n': 4, 'expected': 1},
        # Test 3: Non-monotonic (3 elements)
        {'arr': [1,3,2,0,0,0,0,0], 'n': 3, 'expected': 0},
        # Additional edge cases
        {'arr': [5,5,5,5,5,5,5,5], 'n': 8, 'expected': 1},  # All equal
        {'arr': [127, -128, 0, 0, 0, 0, 0, 0], 'n': 3, 'expected': 0}  # Boundary values
    ]
    
    passed = 0
    for case in test_cases:
        # Convert Python list to bit-packed value
        arr_value = 0
        for i, val in enumerate(case['arr']):
            # Convert to 8-bit signed (2's complement)
            if val < 0:
                val = val & 0xFF
            arr_value |= val << (i*8)
        
        dut.array_in.value = arr_value
        dut.actual_elements.value = case['n']
        
        await Timer(1, units='ns')
        
        result = int(dut.is_monotonic.value)
        if result == case['expected']:
            passed += 1
            dut._log.info(f"PASS: {case['arr'][:case['n']]} -> {result}")
        else:
            dut._log.error(f"FAIL: {case['arr'][:case['n']]} returned {result}, expected {case['expected']}")
    
    total = len(test_cases)
    dut._log.info(f"Test summary: {passed}/{total} tests passed")
    assert passed == total, f"{passed}/{total} tests passed"