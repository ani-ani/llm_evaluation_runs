import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_vote_swap(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        ("12210020", 4, False),
        ("11111111", 0, True),  # No tellers -> impossible
        ("00211222220", 5, False),  # Truncated to 16 chars (input_str[0:16])
        ("1000000000000002", 0, False)  # Minimal swaps needed
    ]
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    passed = 0
    for (pattern, expected_swaps, expect_impossible) in test_cases:
        # Pad/truncate to 16 chars
        padded_pattern = pattern.ljust(16, '1')[:16]
        # Convert to packed 32-bit input (2 bits per char)
        input_val = 0
        for i, c in enumerate(padded_pattern[::-1]):
            input_val |= (int(c) & 0x3) << (i*2)
        dut.input_str.value = input_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done signal (max 100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        if dut.is_impossible.value == expect_impossible:
            if expect_impossible or (dut.min_swaps.value == expected_swaps):
                passed += 1
            else:
                dut._log.error(f"Test failed: Pattern {pattern} got swaps={dut.min_swaps.value}, expected={expected_swaps}")
        else:
            dut._log.error(f"Test failed: Pattern {pattern} got impossible={dut.is_impossible.value}, expected={expect_impossible}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")