import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_swapsort(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    def perm_to_bits(arr):
        return int(''.join([f"{x-1:02b}" for x in arr]), 2)
    
    # Adapted test cases (N=4 versions)
    test_cases = [
        # Case 1: Simple swap (N=2 reduced to N=4)
        {
            "perm": [2,1,3,4],  # Original [2,1] extended
            "swaps": [[1,2]],     # Only swap allowed
            "m": 1,
            "expected": 1
        },
        # Case 2: Indirect swaps (extended to N=4)
        {
            "perm": [2,1,3,4],  # Original [2,1,3] extended
            "swaps": [[1,3],[2,3],[1,4]],  # Original swaps extended
            "m": 3,
            "expected": 3  # Original expected 3
        },
        # Case 3: Already sorted (0 steps)
        {
            "perm": [1,2,3,4],
            "swaps": [[1,2],[1,3],[2,4]],
            "m": 3,
            "expected": 0
        }
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Load inputs
        dut.initial_perm.value = perm_to_bits(case["perm"])
        swap_bits = 0
        for i, swap in enumerate(case["swaps"]):
            if i < 6:  # Pad to 6 swaps
                a = swap[0]-1; b = swap[1]-1
                swap_bits |= ((a << 2) | b) << (i*4)
        dut.allowed_swaps.value = swap_bits
        dut.m_swaps.value = case["m"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        if dut.min_steps.value == case["expected"]:
            passed +=1
        else:
            dut._log.error(f"FAIL: Perm={case["perm"]} Expected={case["expected"]} Got={dut.min_steps.value}")
        
        # Reset between test cases
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")