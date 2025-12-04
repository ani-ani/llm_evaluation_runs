import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_seven_counter(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Test cases (scaled from original)
    test_cases = [
        (50, 0),
        (78, 2),
        (79, 3),
        (100, 3),
        (200, 6),
        (300, 8),  # New case for mid-range
        (1024, 39)  # Final edge case (pre-calculated)
    ]
    
    passed = 0
    
    for n_val, expected in test_cases:
        # Reset the module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Check results
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} -> count={int(dut.count.value)}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {int(dut.count.value)}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)