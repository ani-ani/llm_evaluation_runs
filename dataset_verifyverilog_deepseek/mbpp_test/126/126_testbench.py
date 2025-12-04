import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_common_divisor_sum(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (10, 15, 6),   # Divisors: 1,5 => sum=6
        (100, 150, 93),# Divisors: 1,2,5,10,25,50 => sum=93
        (4, 6, 3),     # Divisors: 1,2 => sum=3
        (255, 255, 256)# Edge case: divisor=1 (when a=b)
    ]
    
    passed = 0
    for a, b, expected in test_cases:
        # Apply inputs
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: {a},{b} => {dut.sum.value}")
        else:
            dut._log.error(f"FAIL: {a},{b} => {dut.sum.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")