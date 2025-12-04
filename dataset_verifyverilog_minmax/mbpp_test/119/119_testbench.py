import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_unique_finder(dut):
    # Pad test cases with zeros to 16 elements
    test_cases = [
        ([1,1,2,2,3] + [0]*11, 3),
        ([1,1,3,3,4,4,5,5,7,7,8] + [0]*5, 8),
        ([1,2,2,3,3,4,4] + [0]*9, 1),
        # Additional edge cases
        ([5] + [0]*15, 5),
        ([255,255,128,0,0] + [128]*11, 128)  # Last duplicate overwrites zeros
    ]
    
    passed = 0
    for arr, expected in test_cases:
        # Set array inputs (pad to 16 elements)
        for i in range(16):
            dut.arr[i].value = arr[i] if i < len(arr) else 0
        
        await Timer(1, units='ns')  # Wait for combinational logic
        
        if dut.unique_num.value == expected:
            passed += 1
            dut._log.info(f"PASS: {arr[:5]}... => {dut.unique_num.value}")
        else:
            dut._log.error(f"FAIL: {arr[:5]}... => {dut.unique_num.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")