import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_apple_collector(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (n, parent_list, expected)
    test_cases = [
        (3, [1,1], 1),   # Original example scaled down
        (5, [1,2,2,2], 3), # Original example
        (4, [1,2,3], 4),   # All depths contribute
        (8, [1,1,1,1,1,1,1], 1), # All nodes except root annihilate
        (5, [1,1,2,2], 2)  # Custom case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, parents, expected in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Assign inputs
        dut.n.value = n_val
        parent_arr = [0] * 7
        for i, p in enumerate(parents):
            parent_arr[i] = p
        
        for i in range(7): 
            getattr(dut, f"p_{i+2}").value = parent_arr[i] if i < len(parents) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles)
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1 and dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={n_val} Parents={parents} Got={dut.result.value}, Expected={expected}")
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total