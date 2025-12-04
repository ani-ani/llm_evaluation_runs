import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def lottery_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        # Original problem scaled down
        (10, 5, 2, 1, 0.5),           # ~0.1 in original becomes 0.5
        (10, 5, 2, 2, 0.3968253968),  # 33/84 ≈ 0.3928 (scales to 0.3968)
        (5, 5, 3, 2, 1.0),            # All tickets available
        (8, 4, 2, 4, 0.1428571428)    # Edge case
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for m, n, t, p, expected_prob in test_cases:
        dut.start.value = 0
        dut.m.value = m
        dut.n.value = n
        dut.t.value = t
        dut.p.value = p
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(25):  # Wait for computation
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Convert fixed-point to float
        prob_val = dut.probability.value.integer
        actual = prob_val / (1 << 16)
        
        if abs(actual - expected_prob) < 0.001:
            passed += 1
        else:
            dut._log.error("Test failed: m=%d n=%d t=%d p=%d got %.10f expected %.10f" % 
                          (m, n, t, p, actual, expected_prob))
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)