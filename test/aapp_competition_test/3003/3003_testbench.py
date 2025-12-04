import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_graph_color(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases: (n_val, adjacency, expected_colors)
    test_cases = [
        # Sample 1 (Output 3)
        (4, 0x060D030200000000, 3),
        # Sample 2 (Output 2)
        (5, 0x1C1C638380800000, 2),
        # Sample 3 (Output 2)
        (6, 0x4A15A22A942A0000, 2),
        # Sample 4 (Output 4)
        (4, 0x0E0E0E0E00000000, 4),
        # Additional test (Output 3)
        (5, 0x0207060C08000000, 3)
    ]
    
    passed = 0
    for n_val, adj, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.n_val.value = n_val
        dut.adjacency.value = adj
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 1024 cycles)
        timeout = 0
        while not dut.done.value and timeout < 1024:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout == 1024:
            dut._log.error("Test timed out")
            continue
            
        # Check result
        if dut.colors.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: {dut.colors.value} != {expected} for test case {test_cases.index((n_val, adj, expected))+1}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)