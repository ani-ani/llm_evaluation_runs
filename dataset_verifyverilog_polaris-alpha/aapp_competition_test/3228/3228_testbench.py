import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_scheduler(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (n, t, g, skiers, expected_sum)
    test_cases = [
        (4, 10, 2, [0, 15, 30, 45], 10),
        (4, 10, 3, [0, 15, 30, 45], 5),
        (5, 16, 3, [16, 7, 5, 8, 1], 4),
        # Edge cases: max inputs
        (8, 16, 3, [0,0,0,0,0,0,0,0], 0),
        (1, 1, 1, [0], 0)
    ]

    passed = 0
    for (n, t_in, g_in, skiers, expected) in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await ClockCycles(dut.clk, 1)

        # Load inputs (pad skiers to 8 elements)
        dut.n.value = min(n, 8)
        dut.t.value = min(t_in, 16)
        dut.g.value = min(g_in, 3)
        for i in range(8):
            dut.skier_times[i].value = skiers[i] if i < len(skiers) else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 40 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        # Verify result
        if dut.sum.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed test case: n={n}, t={t_in}, g={g_in}, skiers={skiers}"
                          f"  Expected: {expected}, Got: {dut.sum.value}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")