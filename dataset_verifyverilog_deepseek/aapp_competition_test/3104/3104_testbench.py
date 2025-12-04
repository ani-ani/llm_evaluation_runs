import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_plus(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    test_cases = [
        # (digits, digit_count, target_sum, expected_plus_count, expected_positions_mask)
        ([1,4,3,1,7,5,0,0], 6, 120, 2, 0b011010), # "143175"→14+31+75
        ([5,0,2,5,0,0,0,0], 4, 30, 1, 0b1000),    # "5025"→5+025 (positions 1)
        ([9,9,9,8,9,9,0,0], 6, 125, 4, 0b101101) # "999899"→9+9+9+89+9
    ]

    passed = 0
    for idx, (digits, count, target, exp_plus_cnt, exp_mask) in enumerate(test_cases):
        # Apply inputs
        for i in range(8):
            dut.digits[i].value = digits[i]
        dut.digit_count.value = count
        dut.target_sum.value = target
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify outputs
        plus_mask = dut.plus_positions.value & ((1 << (count-1)) - 1)
        if (dut.plus_count.value == exp_plus_cnt and 
            plus_mask == exp_mask and 
            dut.computed_sum.value == target):
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: Plus count {dut.plus_count.value} != {exp_plus_cnt}, "
                          f"Positions {bin(dut.plus_positions.value)} != {bin(exp_mask)}, "
                          f"Sum {dut.computed_sum.value} != {target}")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
