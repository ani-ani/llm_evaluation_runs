import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_evolution(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to encode strings
    def encode(s):
        val = 0
        for c in s:
            val <<= 2
            if c == 'A': val |= 0
            elif c == 'C': val |= 1
            elif c == 'M': val |= 2
        return val << (16 - 2*len(s))

    # Test case 1: Possible example (Scaled-down from sample input 1)
    # Original: 1 4 split with sequences MM, A, AA, ACA, ACMAA
    # Reduced to 3 fossils:
    test_fossils1 = [encode('A'), encode('AA'), encode('ACA')]
    for i in range(8):
        dut.fossil_seqs[i].value = test_fossils1[i] if i<3 else 0
    dut.current_seq.value = encode('ACMAA')
    dut.num_fossils.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ClockCycles(dut.clk, 256)
    if not dut.done.value:
        dut._log.error("Test 1 timed out")
    assert dut.possible.value == 1, "Test 1 should be possible"

    # Test case 2: Impossible example (Sample input 3 scaled)
    test_fossils2 = [encode('MA')]
    for i in range(8):
        dut.fossil_seqs[i].value = test_fossils2[i] if i<1 else 0
    dut.current_seq.value = encode('AM')
    dut.num_fossils.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ClockCycles(dut.clk, 256)
    if not dut.done.value:
        dut._log.error("Test 2 timed out")
    assert dut.possible.value == 0, "Test 2 should be impossible"

    # Test case 3: Edge case with no fossils (Sample 4 scaled)
    for i in range(8):
        dut.fossil_seqs[i].value = 0
    dut.current_seq.value = encode('AAAAAA')[0:8] # Truncated to 4 chars
    dut.num_fossils.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ClockCycles(dut.clk, 256)
    if not dut.done.value:
        dut._log.error("Test 3 timed out")
    assert dut.possible.value == 1, "Test 3 (no fossils) should be possible"
    assert dut.s1.value + dut.s2.value == 0, "Test 3 should use no fossils"

    dut._log.info("3/3 tests passed")