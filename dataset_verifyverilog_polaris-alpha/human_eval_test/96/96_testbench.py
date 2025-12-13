import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_primes(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (5, [2,3]),
        (6, [2,3,5]),
        (7, [2,3,5]),
        (10, [2,3,5,7]),
        (0, []),
        (1, []),
        (18, [2,3,5,7,11,13,17])
    ]
    
    passed = 0
    
    for n_val, expected_primes in test_cases:
        # Setup input
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        results = []
        timeout = 100
        
        # Capture primes until done
        while timeout > 0 and not dut.done.value:
            await RisingEdge(dut.clk)
            if dut.valid.value:
                results.append(dut.prime.value.integer)
            timeout -= 1
        
        # Check results
        if results == expected_primes:
            passed += 1
            dut._log.info(f"PASS: n={n_val} got {results}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {results}, expected {expected_primes}")
        
        # Wait for done to clear
        await RisingEdge(dut.clk)
    
    # Summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total