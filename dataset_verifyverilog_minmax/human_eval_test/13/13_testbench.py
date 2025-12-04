import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_gcd(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (original values fit in 16 bits)
    test_vectors = [
        (3, 7, 1),
        (10, 15, 5),
        (49, 14, 7),
        (144, 60, 12),
        (65535, 32768, 1),  # Additional edge case
        (0, 15, 15),        # Zero handling case
        (243, 243, 243)     # Equal inputs
    ]
    
    passed = 0
    total = len(test_vectors)
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for a, b, expected in test_vectors:
        # Apply inputs
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (with timeout)
        cycles = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 32:
                break
        
        # Verify result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: GCD({a}, {b}) = {expected}")
        else:
            dut._log.error(f"FAIL: GCD({a}, {b}) = {dut.result.value}, expected {expected}")
        
        # Wait a cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")