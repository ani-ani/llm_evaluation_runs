import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_woodall(dut):
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
    
    test_cases = [
        (383, 1, "True"),
        (254, 0, "False"),
        (200, 0, "False"),
        (1, 1, "True"),
        (47, 0, "False")
    ]
    passed = 0
    
    for x_val, expected, msg in test_cases:
        # Apply stimulus
        dut.x_in.value = x_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.is_woodall.value == expected:
            passed += 1
            dut._log.info(f"PASS: Input={x_val} ({msg})")
        else:
            dut._log.error(f"FAIL: Input={x_val} Got {dut.is_woodall.value}, Expected {expected} ({msg})")
        
        # Wait 1 cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")