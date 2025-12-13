import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_elf_seating(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize and reset
    dut.start.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test case 1: Sample Input 1 (expect 2 victories)
        {
            "n": 2,  # represents 3 pairs (0-3)
            "a": [2,3,3,0],  # padded to 4 (1-based: 2,3,3)
            "p": [4,1,10,0],
            "v": [2,7,3,0],
            "order": [1,0,2,0],  # elf processing order (indices)
            "expected": 2
        },
        # Test case 2: Sample Input 2 (expect 1 victory)
        {
            "n": 3,  # represents 4 pairs
            "a": [3,1,3,3], 
            "p": [5,8,7,10],
            "v": [4,1,2,6],
            "order": [3,1,0,2], 
            "expected": 1
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Apply test inputs
        dut.n.value = case["n"]
        for i in range(4):
            dut.a[i].value = case["a"][i] - 1  # convert to 0-based
            dut.p[i].value = case["p"][i]
            dut.v[i].value = case["v"][i]
            dut.elf_order[i].value = case["order"][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if int(dut.victory_count.value) == case["expected"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {case['expected']} victories, got {dut.victory_count.value}")
        await ClockCycles(dut.clk, 2)  # add recovery time
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)