import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_magical(dut):
    test_cases = [
        # Original sample scaled to 8 elements (pad with 0)
        {
            "arr": [5,4,3,3,2,0,0,0],
            "queries": [(1,2,2), (1,1,1), (2,4,3)]
        },
        # Second sample scaled
        {
            "arr": [6,6,5,1,6,2,0,0],
            "queries": [(4,5,2), (4,6,2), (1,4,4)]
        },
        # Edge case: full array magic
        {
            "arr": [5,5,5,5,5,5,5,5],
            "queries": [(1,8,8)]
        },
        # Edge case: decreasing sequence
        {
            "arr": [8,7,6,5,4,3,2,1],
            "queries": [(1,8,8), (2,5,4)]  # Magical subarrays contain all elements
        }
    ]

    passed = 0
    total = sum(len(case["queries"]) for case in test_cases)

    for case in test_cases:
        # Wait 1ns
        await Timer(1, units='ns')
        # Set array inputs
        for idx, val in enumerate(case["arr"]):
            dut.arr[idx].value = val
        # Test each query
        for (L, R, expected) in case["queries"]:
            dut.L.value = L - 1 # Module uses 0-based internally (but input is 1-based)
            dut.R.value = R - 1
            await Timer(1, units='ns')
            if int(dut.max_len.value) != expected:
                dut._log.error(f"Failed L={L},R={R}: Got {int(dut.max_len.value)}, Expected {expected}")
            else:
                passed += 1

    dut._log.info(f"{passed}/{total} tests passed")
    if passed < total:
        raise TestFailure("Some tests failed")
