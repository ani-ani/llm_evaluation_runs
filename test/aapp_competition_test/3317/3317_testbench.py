import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random
@cocotb.test()
async def test_trade_matcher(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Predefined test cases (adapted from original)
    test_cases = [
        (0, 2, 4),   # Match ABAB (4 chars)
        (1, 6, 0),   # B vs c
        (0, 7, 5),   # Match ABABA (5 chars)
        (8, 3, 3)    # Match ABA (3 chars)
    ]
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    total = len(test_cases)
    for idx, (i_val, j_val, expected) in enumerate(test_cases):
        # Apply inputs
        dut.i.value = i_val
        dut.j.value = j_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for computation (2 cycles)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        # Check results
        if dut.done.value == 1 and dut.max_length.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: i={i_val}, j={j_val} -> {dut.max_length.value} (expected {expected})")
        await RisingEdge(dut.clk)  # Extra cycle for cleanup
    dut._log.info(f"{passed}/{total} tests passed")