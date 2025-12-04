import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

# Helper function to create padded string
def str_to_bytes(s, max_len=16):
    byte_arr = [0]*16
    for i,c in enumerate(s[:max_len]):
        byte_arr[i] = ord(c)
    return byte_arr

@cocotb.test()
async def test_longest_repeat(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (input_str, expected_max_len)
    test_cases = [
        ("ababa", 3),   # "aba" repeats
        ("abcdabc", 3), # "abc" repeats
        ("abcdef", 0),  # no repeats
        ("aaaa", 3),    # "aaa" repeats
        ("aabbccddeeffgghh", 2) # multiple 2-char repeats
    ]

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for s, expected in test_cases:
        # Setup input
        byte_arr = str_to_bytes(s)
        for i in range(16):
            dut.str[i].value = byte_arr[i]
        dut.length.value = len(s)

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.max_len.value == expected:
            passed += 1
            dut._log.info(f"Test passed: '{s}' -> {dut.max_len.value}")
        else:
            dut._log.error(f"Test failed: '{s}' Expected {expected}, got {dut.max_len.value}")

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
