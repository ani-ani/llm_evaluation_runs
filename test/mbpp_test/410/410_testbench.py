import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import itertools

@cocotb.test()
async def test_min_hetero(dut):
    # Convert human-readable test cases to hardware representation
    # Format: (input_list, validity_mask, expected_min)
    test_cases = [
        # Original Test 1: [PYTHON,3,2,4,5,VERSION] → min=2
        ([0,3,2,4,5,0,0,0], 0b01111000, 2),
        
        # Original Test 2: [PYTHON,15,20,25] → min=15
        ([0,15,20,25,0,0,0,0], 0b01110000, 15),
        
        # Original Test 3: [PYTHON,30,20,40,50,VERSION] → min=20
        ([0,30,20,40,50,0,0,0], 0b01111000, 20),
        
        # All invalid test
        ([10,20,30,40,0,0,0,0], 0b00000000, 0),
        
        # Mult-valid test
        ([99,25,5,75,1,0,42,55], 0b11111111, 1)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for inputs, mask, expected in test_cases:
        # Assign inputs
        for i in range(8):
            getattr(dut, f"elem_{i}").value = inputs[i]
        dut.validity_mask.value = mask
        
        await Timer(1, units='ns')
        
        # Hex display for debug
        observed = dut.min_val.value
        actual = observed.integer
        
        # Validation
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: MASK={bin(mask)} IN={inputs} → MIN={actual}")
        else:
            dut._log.error(f"FAIL: MASK={bin(mask)} IN={inputs} → EXPECT={expected} GOT={actual}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"{total-passed} tests failed")