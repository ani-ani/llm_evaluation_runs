import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def create_mask(length):
    return (1 << length) - 1  # Generating validity mask

@cocotb.test()
async def test_min_sublist(dut):
    test_cases = [
        # Test 1: Original [[1],[1,2],[1,2,3]]
        {
            'valid': [create_mask(1), create_mask(2), create_mask(3), 0],
            'data': [[1,0,0,0], [1,2,0,0], [1,2,3,0], [0,0,0,0]],
            'expected': ([1,0,0,0], create_mask(1))
        },
        # Test 2: Original [[1,1],[1,1,1],[1,2,7,8]]
        {
            'valid': [create_mask(2), create_mask(3), create_mask(4), 0],
            'data': [[1,1,0,0], [1,1,1,0], [1,2,7,8], [0,0,0,0]],
            'expected': ([1,1,0,0], create_mask(2))
        },
        # Test 3: Original [['x'],['x','y'],['x','y','z']] (char ordinals)
        {
            'valid': [create_mask(1), create_mask(2), create_mask(3), 0],
            'data': [[ord('x'),0,0,0], [ord('x'),ord('y'),0,0], [ord('x'),ord('y'),ord('z'),0], [0,0,0,0]],
            'expected': ([ord('x'),0,0,0], create_mask(1))
        },
        # Additional test: tie-breaker (first shortest wins)
        {
            'valid': [create_mask(2), create_mask(2), create_mask(3), create_mask(1)],
            'data': [[5,6,0,0], [7,8,0,0], [1,2,3,0], [9,0,0,0]],
            'expected': ([5,6,0,0], create_mask(2))
        }
    ]

    passed = 0
    for case in test_cases:
        for i in range(4):
            dut.valid_mask[i].value = case['valid'][i]
            for j in range(4):
                dut.data[i][j].value = case['data'][i][j]
        
        await Timer(1, units='ns')
        
        expected_data, expected_mask = case['expected']
        errors = []
        
        # Check validity mask
        if dut.out_valid_mask.value != expected_mask:
            errors.append(f"Mask mismatch: Got {dut.out_valid_mask.value}, expected {expected_mask}")
        
        # Check data elements
        for i in range(4):
            actual = dut.min_data[i].value
            expected = expected_data[i]
            if actual != expected:
                errors.append(f"Element [{i}] mismatch: Got {actual}, expected {expected}")
        
        if errors:
            msg = "Failure in test case:
"
            msg += "
  ".join(errors)
            dut._log.error(msg)
        else:
            passed += 1
            dut._log.info("PASSED test case")
            
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")
