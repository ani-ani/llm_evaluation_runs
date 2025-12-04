import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_tuple_union(dut):
    # Test cases adapted for 5-bit values and 8-element tuples
    test_cases = [
        # Test 1 with padding
        (list((3,4,5,6,0,0,0,0)), list((5,7,4,10,0,0,0,0)), [3,4,5,6,7,10]),
        # Test 2 with padding
        (list((1,2,3,4,0,0,0,0)), list((3,4,5,6,0,0,0,0)), [1,2,3,4,5,6]),
        # Test 3 with padding
        (list((11,12,13,14,0,0,0,0)), list((13,15,16,17,0,0,0,0)), [11,12,13,14,15,16,17]),
        # Additional edge case: duplicates and full range
        (list((31,31,31,5,5,5,0,0)), list((5,31,7,0,0,0,0,0)), [5,7,31])
    ]
    
    passed = 0
    for t1, t2, expected in test_cases:
        # Load inputs
        for i in range(8):
            dut.tuple1[i].value = t1[i]
            dut.tuple2[i].value = t2[i]
        
        await Timer(10, units='ns')  # Allow combinational logic to settle
        
        # Extract valid output
        valid = dut.valid_count.value
        result = [dut.union_result[i].value for i in range(valid)]
        
        # Compare with expected (ignore zero padding)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {t1} ∪ {t2} = {result}")
        else:
            dut._log.error(f"FAIL: {t1} ∪ {t2} got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)