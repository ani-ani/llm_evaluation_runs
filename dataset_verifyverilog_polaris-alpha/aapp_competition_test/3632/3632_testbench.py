import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

PERMUTATION_LOOKUP = {
  (3,1): 3, (4,1): 4, (5,1): 5, (6,1): 6, (7,1): 7,
  (3,2): 6, (4,2): 12, (5,2): 20, (6,2): 30, (7,2): 42,
  (2,1): 2, (3,0): 1, (4,3): 24, (5,3): 60, (6,3): 120,
  (1,0): 1, (2,0): 1, (4,0): 1, (7,3): 210
}

@cocotb.test()
async def test_composite_position(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Test case 1: n=5, k=3, indices [2,0,3] -> position 26
    await run_test(dut, 5, 3, [2,0,3], 26)
    
    # Test case 2: n=4, k=2, indices [3,1] -> 4P2 - 1 = 12-1=11? (validate calculation)
    await reset_dut(dut)
    await run_test(dut, 4, 2, [3,1], 11)
    
    # Test case 3: n=8, k=1, indices [7] -> last of 8 strings (position 8)
    await reset_dut(dut)
    await run_test(dut, 8, 1, [7], 8)
    
    # Test case 4: Edge case - first permutation (indices [0,1,2] in n=5,k=3)
    await reset_dut(dut)
    await run_test(dut, 5, 3, [0,1,2], 1)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def run_test(dut, n_val, k_val, indices, expected):
    # Pad indices to 4 elements (unused slots don't matter)
    padded_indices = indices + [0]*(4-len(indices))
    
    dut.n.value = n_val
    dut.k.value = k_val
    for i in range(4):
        dut.test_indices.value[i] = padded_indices[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait exactly k cycles
    for _ in range(k_val):
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        await RisingEdge(dut.done)
    
    assert dut.position.value == expected, f"Position mismatch: got {dut.position.value}, expected {expected}"
    dut._log.info(f"Test passed: {dut.position.value} == {expected}")