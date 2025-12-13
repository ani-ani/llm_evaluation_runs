import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_lnd(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    test_cases = [
        # (n, T, a_arr, expected_output)
        (4, 3, [3, 1, 4, 2, 0,0,0,0], 5),   # Original sample input
        (2, 2, [1, 2, 0,0,0,0,0,0], 4),     # Simple increasing sequence
        (1, 4, [5, 0,0,0,0,0,0,0], 4),      # Single repeated element
        (3, 3, [5,3,4,0,0,0,0,0], 5)        # Partial sequence 3,3,4,4,4
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for tc in test_cases:
        n_val, T_val, a_arr, expected = tc
        
        # Apply inputs
        dut.n.value = n_val
        dut.T.value = T_val
        for i in range(8):
            dut.a[i].value = a_arr[i] if i < n_val else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for done signal
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val}, T={T_val} => {dut.result.value}, expected {expected}")
        
        # Wait 2 cycles between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")