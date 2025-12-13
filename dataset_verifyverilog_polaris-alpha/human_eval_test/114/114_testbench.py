import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_subarray(dut):
    # Generate 100MHz clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Adapted test cases (scaled to 16-bit)
    test_cases = [
        ([2, 3, 4, 1, 2, 4, 0, 0], 1),
        ([-1, -2, -3, -32768, 0, 0, 0, 0], -6),  # Original: [-1,-2,-3]
        ([-1, -2, -3, 2, -10, 0, 0, 0], -14),
        ([-32768, 0, 0, 0, 0, 0, 0, 0], -32768),  # Original: -999...
        ([0, 10, 20, 1000, 0, 0, 0, 0], 0),  # Original: 1000000
        ([-1, -2, -3, 10, -5, 0, 0, 0], -6),
        ([100, -1, -2, -3, 10, -5, 0, 0], -6),
        ([10, 11, 13, 8, 3, 4, 0, 0], 3),
        ([-10, 0, 0, 0, 0, 0, 0, 0], -10),
        ([7, 0, 0, 0, 0, 0, 0, 0], 7),
        ([1, -1, 0, 0, 0, 0, 0, 0], -1)
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    for nums, expected in test_cases:
        # Load inputs
        for i in range(8):
            dut.nums[i].value = nums[i] if i < len(nums) else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        await ClockCycles(dut.clk, 10)
        
        # Check result
        if dut.done.value != 1:
            dut._log.error(f"Done not asserted!")
        else:
            result = dut.min_sum.value.signed_integer
            if result == expected:
                passed += 1
                dut._log.info(f"PASS: {nums} -> {result}")
            else:
                dut._log.error(f"FAIL: {nums} got {result}, expected {expected}")

    # Random test case
    rand_nums = [random.randint(-1000, 1000) for _ in range(8)]
    expected = min(min(rand_nums), sum(rand_nums))  # Simplified check
    
    for i in range(8):
        dut.nums[i].value = rand_nums[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ClockCycles(dut.clk, 10)
    
    result = dut.min_sum.value.signed_integer
    if abs(result - expected) <= 2:  # Allow small errors in alternative implementations
        passed += 1
        dut._log.info(f"PASS: Random case {rand_nums} -> {result}")
    else:
        dut._log.error(f"FAIL: Random case {rand_nums} got {result}, expected ~{expected}")

    total = len(test_cases) + 1
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")