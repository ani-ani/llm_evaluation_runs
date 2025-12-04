import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_roads(dut):
    # Test cases (scaled version)
    test_cases = [
        # (adjacency_matrix, current_roads, expected_output)
        # Sample 1: n=2, m=1 (0->1 only)
        (0b00000001_00000000_00000000_00000000_00000000_00000000_00000000_00000000, 1, 0),
        # Sample 2: n=5, m=7 (pre-scaled)
        (0b00000000_00000001_00000000_00010100_00100000_00000000_00000000_00000000, 7, 2),
        # Custom test: n=3, fully connected
        (0b00000000_00000000_00000000_00000000_00000101_00000010_00000000_00000000, 3, 0)
    ]
    
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for adj_matrix, roads, expected in test_cases:
        dut.adjacency_matrix.value = adj_matrix
        dut.current_road_count.value = roads
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 20 cycles for computation
        for _ in range(22):
            await RisingEdge(dut.clk)
        
        if dut.done.value == 1 and dut.max_new_roads.value == expected:
            passed += 1
            dut._log.info(f"Test passed: {expected}")
        else:
            dut._log.error(f"Test failed: Got {dut.max_new_roads.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)