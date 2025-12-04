import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_array_minmax_sum(dut):
    test_cases = [
        # (array, size, expected)
        ([1,2,3], 3, 4),   # 1+3=4
        ([-1,2,3,4], 4, 3),  # -1+4=3
        ([2,3,6], 3, 8),   # 2+6=8
        ([-5,-3,-1], 3, -6), # -5 + (-1) = -6
        ([100], 1, 200),   # single element (min=max)
        # Full 8-element test
        ([32767, -32768, 0, 100, 200, -42, 1234, 77], 8, -1)  # (-32768 + 32767) = -1
    ]
    
    passed = 0
    for i, (arr, size, expected) in enumerate(test_cases):
        # Pad array to 8 elements
        padded_arr = list(arr) + [0]*(8 - len(arr))
        
        # Set inputs
        for idx in range(8):
            dut.array_input[idx].value = padded_arr[idx]
        dut.array_size.value = size
        
        await Timer(1, 'ns')  # Wait for combinational logic
        
        if dut.result.value.signed_integer == expected:
            passed += 1
            dut._log.info(f"TEST {i} PASS: {arr} => {dut.result.value}")
        else:
            dut._log.error(f"TEST {i} FAIL: {arr} got {dut.result.value.signed_integer}, expected {expected}")
    
    test_count = len(test_cases)
    dut._log.info(f"
SUMMARY: {passed}/{test_count} tests passed")
    assert passed == test_count, f"Failed {test_count - passed} tests"