import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_loda(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Simple case (Original Sample 1 scaled)
    strings = [
        b"A".ljust(16), b"B".ljust(16), b"AA".ljust(16),
        b"BBB".ljust(16), b"AAA".ljust(16),
        b"".ljust(16), b"".ljust(16), b"".ljust(16)
    ]
    lengths = [1,1,2,3,3,0,0,0]
    await run_test(dut, 5, strings, lengths, 3)

    # Test case 2: Overlapping patterns (Original Sample 2 scaled)
    strings = [
        b"A".ljust(16), b"ABA".ljust(16), b"BBB".ljust(16),
        b"ABABA".ljust(16), b"AAAAAB".ljust(16),
        b"".ljust(16), b"".ljust(16), b"".ljust(16)
    ]
    lengths = [1,3,3,5,6,0,0,0]
    await run_test(dut, 5, strings, lengths, 3)

    # Test case 3: Duplicate strings
    strings = [
        b"A".ljust(16), b"B".ljust(16), b"A".ljust(16),
        b"B".ljust(16), b"A".ljust(16), b"B".ljust(16),
        b"".ljust(16), b"".ljust(16)
    ]
    lengths = [1,1,1,1,1,1,0,0]
    await run_test(dut, 6, strings, lengths, 3)

async def run_test(dut, count, strings, lengths, expected):
    # Load strings into DUT
    dut.string_count.value = count
    for i in range(8):
        dut.lengths[i].value = lengths[i]
        for j in range(16):
            dut.strings[i][j].value = strings[i][j]

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion (max 100 cycles)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        assert False, "Timeout waiting for done signal"

    # Check result
    assert dut.max_length.value == expected, \
        f"Wrong result: got {dut.max_length.value}, expected {expected}"
    dut._log.info(f"Test passed: {expected}")
