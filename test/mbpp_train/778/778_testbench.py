import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_packer(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define test cases (input, expected groups)
    test_cases = [
        {"input": [0,0,1,2,3,4,4,5,6,6,6,7,8,9,4,4], "groups": [[0,0],[1],[2],[3],[4,4],[5],[6,6,6],[7],[8],[9],[4,4]]},
        {"input": [10,10,15,19,18,18,17,26,26,17,18,10], "groups": [[10,10],[15],[19],[18,18],[17],[26,26],[17],[18],[10]]},
        {"input": [ord('a'), ord('a'), ord('b'), ord('c'), ord('d'), ord('d')], "groups": [[ord('a'),ord('a')],[ord('b')],[ord('c')],[ord('d'),ord('d')]]}
    ]

    passed = 0
    total = len(test_cases)

    for case in test_cases:
        # Setup inputs
        data = case["input"]
        expected = case["groups"]
        
        # Load data into DUT
        for i in range(16):
            dut.data_in[i].value = data[i] if i < len(data) else 0
        dut.length_in.value = len(data)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Wait 1 cycle for outputs to stabilize
        await RisingEdge(dut.clk)
        
        # Verify outputs
        groups_found = []
        current_start = 0
        total_elements = 0
        
        for i in range(int(dut.group_count.value)):
            start = int(dut.start_indices[i].value)
            length = int(dut.group_lengths[i].value)
            
            # Verify contiguous grouping
            assert start == current_start, f"Group {i} start mismatch"
            group_elements = [int(dut.data_in[j].value) for j in range(start, start+length)]
            groups_found.append(group_elements)
            total_elements += length
            current_start += length
        
        # Check all elements processed
        assert total_elements == len(data), "Element count mismatch"
        
        # Compare with expected groups
        if groups_found == expected:
            passed += 1
            dut._log.info(f"PASS: {data} -> {groups_found}")
        else:
            dut._log.error(f"FAIL: Input {data}
Expected: {expected}
Got: {groups_found}")
    
    dut._log.info(f"{passed}/{total} tests passed")
