import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_digit_sum(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases
    test_cases = [
        (345, 12),
        (12, 3),
        (97, 16),
        (0, 0),
        (65535, 24)  # 6+5+5+3+5=24
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for input_val, expected in test_cases:
        # Apply input
        dut.start.value = 1
        dut.num.value = input_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        await Timer(1, units="ns")  # Allow output to stabilize
        if dut.sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: {input_val} => {dut.sum.value}")
        else:
            dut._log.error(f"FAIL: {input_val} => {dut.sum.value} (expected {expected})")
        
        # Wait a cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")