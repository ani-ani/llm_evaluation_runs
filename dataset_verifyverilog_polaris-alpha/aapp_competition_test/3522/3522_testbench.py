import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_battery(dut):
    test_cases = [
        ([1,2,3,4,5,6,7,8], 1),  # Paired diffs: 1,1,1,1
        ([3,1,3,3,3,3,3,3], 2),  # Sorted:1,3,3,3,3,3,3,3 → diffs:2,0,0,0
        ([10,1,20,15,0,0,0,0], 9)  # Sorted:0,0,0,0,1,10,15,20 → diffs:0,0,9,5
    ]
    passed = 0
    for batteries, expected_d in test_cases:
        # Pack into 64-bit value (big-endian)
        packed = 0
        for b in batteries:
            packed = (packed << 8) | b
        dut.batteries_packed.value = packed
        await Timer(1, units='ns')  # Allow combinational logic to settle
        observed = dut.d.value.integer
        if observed == expected_d:
            passed += 1
        else:
            dut._log.error(f"Test failed: Batteries {batteries} → observed={observed}, expected={expected_d}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")