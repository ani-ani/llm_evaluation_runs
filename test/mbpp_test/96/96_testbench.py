import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_divisor_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (0, 0),
        (1, 1),
        (9, 3),
        (12, 6),
        (15, 4),
        (255, 8)  // Divisors: 1,3,5,15,17,51,85,255
    ]
    
    passed = 0
    dut._log.info("Starting divisor counter tests")
    
    for n_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} count={dut.count.value} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} count={dut.count.value} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)"