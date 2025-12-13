import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_check_distinct(dut):
    # Pad test cases to 8 elements with zeros
    test_cases = [
        # Original Test 1 (contains duplicates)
        ({"vals": [1,4,5,6,1,4,0,0]}, False),
        # Original Test 2 (all unique)
        ({"vals": [1,4,5,6,0,0,0,0]}, True),
        # Original Test 3 (all unique)
        ({"vals": [2,3,4,5,6,0,0,0]}, True),
        # Additional edge cases
        ({"vals": [0,0,0,0,0,0,0,0]}, False),  # All zeros
        ({"vals": [1,2,3,4,5,6,7,8]}, True),   # Full unique set
        ({"vals": [5,5,5,5,5,5,5,5]}, False)   # All duplicates
    ]
    
    passed = 0
    for case in test_cases:
        for i, val in enumerate(case[0]["vals"]):
            dut.tuple[i].value = val
        
        await Timer(1, units="ns")
        
        if dut.is_distinct.value == int(case[1]):
            passed += 1
            dut._log.info(f"PASS: {case[0]["vals"]} → {dut.is_distinct.value}")
        else:
            dut._log.error(f"FAIL: {case[0]["vals"]} → got {dut.is_distinct.value}, expected {int(case[1])}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")