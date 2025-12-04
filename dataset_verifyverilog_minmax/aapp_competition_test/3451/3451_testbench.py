import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_effort(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (Original sample scaled)
    seq = '((()'  # Original length 4, pad to 8
    padded_seq = seq + ')' * (8 - len(seq))  # Expanded to 8 chars
    costs = [480, 617, -570, 928] + [0]*4  # Pad with zeros
    seq_bits = int(''.join(['0' if c=='(' else '1' for c in padded_seq]), 2)

    dut.start.value = 1
    dut.k_in.value = 1  # k=1
    dut.seq_bits.value = seq_bits
    for i in range(8):
        dut.costs.value[i] = costs[i] if i < len(costs) else 0
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait 15 cycles
    for _ in range(15):
        await RisingEdge(dut.clk)

    assert dut.done.value == 1, "Test1: Done not asserted"
    assert dut.impossible_flag.value == 0, "Test1: Shouldn't be impossible"
    assert dut.min_effort.value.signed_integer == 480, f"Test1: Expected 480, got {dut.min_effort.value.signed_integer}"

    # Test case 2 - Impossible case
    seq = ')()('  # Scale to 8 chars - balance possible with 2 moves
    padded_seq = seq + '()' * 2  # Now balanced with original k=3  
    costs = [-532, 870, 617, 905] + [100, 200, 300, 400]
    seq_bits = int(''.join(['0' if c=='(' else '1' for c in padded_seq]), 2)

    dut.start.value = 1
    dut.k_in.value = 3 # k=3 (original test case)
    dut.seq_bits.value = seq_bits
    for i in range(8):
        dut.costs.value[i] = costs[i]
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(15):
        await RisingEdge(dut.clk)

    assert dut.done.value == 1, "Test2: Done not asserted"
    assert dut.impossible_flag.value == 1, "Test2: Should be impossible (output '?')"

    dut._log.info("2/2 tests passed")
