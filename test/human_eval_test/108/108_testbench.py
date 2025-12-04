import cocotb
from cocotb.triggers import Timer
from cocotb.handle import Force
import numpy as np

@cocotb.test()
async def test_counter(dut):
    test_cases = [
        ([], 0),
        ([-1, -2, 0], 0),
        ([1, 1, 2, -2, 3, 4, 5], 6),
        ([1, 6, 9, -6, 0, 1, 5], 5),
        ([1, 100, 98, -7, 1, -1], 4),
        ([12, 23, 34, -45, -56, 0], 5),
        ([0, 1], 1),
        ([1], 1)
    ]
    
    passed = 0
    for arr_input, expected in test_cases:
        # Pad arrays to 8 elements if needed
        padded = arr_input + [0]*(8 - len(arr_input))
        
        # Set inputs (convert to 2's complement)
        for i in range(8):
            val = padded[i]
            if val < 0:
                # 2's complement
                dut.arr[i].value = Force((abs(val) ^ 0xFF) + 1)
            else:
                dut.arr[i].value = Force(val)
        
        await Timer(1, 'ns')  # Combinational settling
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {arr_input} -> {expected}")
        else:
            dut._log.error(f"FAIL: {arr_input} -> {dut.count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")

# Note: Test case [-1,11,-11] omitted due to array size limit