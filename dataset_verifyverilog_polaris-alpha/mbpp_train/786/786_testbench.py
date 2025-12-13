import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_insertion(dut):
    tests = [
        ([1,2,4,5], 6, 4),
        ([1,2,4,5], 3, 2),
        ([1,2,4,5], 7, 4),
        ([1,3,5,7,9,11,13,15], 0, 0),
        ([2,4,6,8,10,12,14,16], 9, 4),
        ([2,4,6,8,10,12,14,16], 16, 8)
    ]

    passed = 0
    for arr, val, expected in tests:
        # Pad array to 8 elements
        padded = list(arr) + [0]*(8 - len(arr))
        dut.array.value = [int(x) for x in padded]
        dut.value.value = val
        await Timer(1, 'ns')
        result = dut.pos.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {val} → {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {val}={result}, expected {expected}")
    dut._log.info(f"{passed}/{len(tests)} tests passed")