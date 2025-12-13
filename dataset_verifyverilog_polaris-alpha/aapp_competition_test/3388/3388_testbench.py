import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_julia(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (adapted for 8-bit n=3 and n=5)
    tests = [
        (3, 0x03_03_02_00_00_00_00_00, 1),  # n=3, scores[3,3,2]
        (5, 0x08_04_03_05_02_00_00_00, 6)   # n=5, scores[8,4,3,5,2] truncated to 8b
    ]

    passed = 0
    for (n_val, packed_scores, expected) in tests:
        dut.n.value = n_val
        dut.julia_score.value = (packed_scores >> 56) & 0xFF
        dut.p_scores.value = packed_scores
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        for _ in range(20):  # Wait for processing (max 16 cycles)
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        if dut.done.value != 1:
            dut._log.error("Timeout waiting for done")
        result = dut.k.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val} expected {expected} got {result}")
    dut._log.info(f"{passed}/{len(tests)} tests passed")
    assert passed == len(tests)