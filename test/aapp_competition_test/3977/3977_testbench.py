import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_max_edges(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Original '4 1 2, output 2' (scaled to 4 nodes)
    edges_4 = [0] * 16
    edges_4[1] = 0b0010  # Node 0 connected to 1 (bits [15:0] representing nodes 15-0)
    gov_4 = [0, 2, 0, 0]
    await run_test_case(dut, 4, 2, gov_4, 1, edges_4, 2)
    
    # Test case 2: Original '3 3 1, output 0'
    edges_3 = [0] * 16
    edges_3[0] = 0b0110  # Node 0 connected to 1 and 2
    edges_3[1] = 0b0010  # Node 1 connected to 2
    gov_3 = [1, 0, 0, 0]" // gov node 1
    await run_test_case(dut, 3, 1, gov_3, 3, edges_3, 0)
    
    # Test case 3: Additional case (10 nodes scaled to 10)
    edges_10 = [0] * 16
    edges_10[0] = 0b0000000011  # Node 0 connected to 1 and 2
    gov_10 = [0, 9, 0, 0]
    await run_test_case(dut, 10, 2, gov_10, 3, edges_10, 33)
    
async def run_test_case(dut, n, k, gov_list, m, edge_mask, expected):
    dut.node_count.value = n 
    dut.gov_count.value = k
    for i in range(4):
        dut.gov_list[i].value = gov_list[i]
    dut.edge_count.value = m
    for i in range(16):
        dut.edge_mask[i].value = edge_mask[i] if i < n else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (35 cycles max)
    for _ in range(40):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Timeout waiting for done"
    
    assert dut.max_edges.value == expected, f"Test failed: Expected {expected}, got {dut.max_edges.value}"
    dut._log.info(f"Test passed: {dut.max_edges.value} == {expected}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
