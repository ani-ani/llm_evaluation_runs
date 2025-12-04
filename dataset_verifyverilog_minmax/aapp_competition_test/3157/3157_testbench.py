import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_hash_counter(dut):
    # Test cases (N, K, M, expected_count)
    test_cases = [
        (1, 0, 10, 0),
        (1, 2, 10, 1),
        (3, 16, 10, 4)
    ]
    passed = 0
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for tc in test_cases:
        (n_val, k_val, m_val, expected) = tc
        dut.N.value = n_val
        dut.K.value = k_val
        dut.M.value = m_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (N+2 cycles)
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Timeout waiting for done signal")
        else:
            # Check result
            if dut.count.value == expected:
                passed += 1
            else:
                dut._log.error(f"Test failed: N={n_val} K={k_val} M={m_val} => {dut.count.value}, expected {expected}")
        
        # Reset for next test case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")