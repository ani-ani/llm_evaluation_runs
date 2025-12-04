import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_string_modifier(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test cases (scaled to 16 chars)
    test_cases = [
        ("hello", "teams", 4, 27),  # Scaled from sample 1
        ("abc", "bcd", 3, 1),      # Single forward shift
        ("aabb", "bbaa", 4, 24),   # Multiple shifts
        ("aaaa", "zzzz", 4, 24)    # Max backward shifts
    ]
    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for s1, s2, length, expected in test_cases:
        # Load strings (pad with zeros)
        for i in range(16):
            dut.s1[i].value = ord(s1[i]) if i < len(s1) else 0
            dut.s2[i].value = ord(s2[i]) if i < len(s2) else 0
        dut.length.value = length
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await ClockCycles(dut.clk, 16)  # Wait max cycles
        if not dut.done.value:
            await RisingEdge(dut.done) # Wait until done
        if dut.moves.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: {s1}->{s2} = {dut.moves.value}, expected {expected}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
