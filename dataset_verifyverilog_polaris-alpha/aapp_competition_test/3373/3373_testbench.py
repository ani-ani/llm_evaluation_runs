import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_balanced(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    \
    # Test cases (scaled versions)
    test_cases = [
        (["110000", "111100", "001100"], 10),  # Original: ()) ((() )() → scaled
        (["000000", "00", "11"], 2),          # ))))) ) (( → scaled
        (["1100", "11", "00"], 4)           # (()) () → balanced string
    ]
    \
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    \
    for (pieces_str, expected) in test_cases:
        dut.start.value = 0
        # Convert strings to bit vectors (1='(', 0=')')
        for i in range(3):
            s = pieces_str[i] if i < len(pieces_str) else ''
            val = int(s.replace('1','').replace('0','1'),2) if s else 0
            dut.pieces[i].value = val
        \
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        \
        for _ in range(5):  # Wait 4 cycles + output
            await RisingEdge(dut.clk)
        \
        if dut.done.value:
            result = dut.max_length.value.integer
            if result == expected:
                passed += 1
            else:
                dut._log.error(f"Failed: {pieces_str} => {result} (expected {expected})")
        else:
            dut._log.error("Done signal not asserted")
    \
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")