import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_max(dut):
    # Padding helper for 8-element lists
    def pad(arr):
        return arr + [0]*(8-len(arr))
    
    test_cases = [
        (pad([1, 2, 3]), 3),
        (pad([5, 3, -5, 2, -3, 9]), 9),
        ([-128, -10, 0, 10, 20, 30, 40, 127], 127),
        ([100, 100, 100, 100, 0, 0, 0, 0], 100),
        ([-5, -3, -1, -10, -8, -2, -4, -6], -1)
    ]
    passed = 0
    
    for inputs, expected in test_cases:
        for i, val in enumerate(inputs):
            # Handle negative two's complement
            if val < 0:
                val = val + 256
            dut.values[i].value = val
        
        await Timer(1, units='ns')
        result = dut.max_value.value.signed_integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {inputs} -> {result}")
        else:
            dut._log.error(f"FAIL: {inputs} -> {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")