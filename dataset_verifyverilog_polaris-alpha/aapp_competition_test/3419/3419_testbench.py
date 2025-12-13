import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_license_counter(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # Sample from problem
        (5, 20, 20, [7, 11, 9, 12, 2], 4),
        # With max time
        (5, 100, 100, [101, 1, 1, 1, 1], 0),
        # All fit
        (3, 10, 10, [5,5,5], 3),
        # Edge case - no customers
        (0, 50, 50, [], 0)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, s1, s2, t_vals, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Load inputs
        dut.n.value = n
        dut.s1.value = s1
        dut.s2.value = s2
        
        # Pad t array with 0s for unset values
        t_padded = t_vals + [0]*(16 - len(t_vals)) if len(t_vals) < 16 else t_vals
        for i in range(16):
            dut.t[i].value = t_padded[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait n + 2 cycles
        for _ in range(n + 2):
            await RisingEdge(dut.clk)
        
        # Check result
        if not dut.done.value:
            await RisingEdge(dut.done)
        
        assert dut.done.value == 1, "Done not asserted"
        actual = dut.max_customers.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"Test passed: n={n} => {actual}")
        else:
            dut._log.error(f"Test failed: n={n} expected={expected} got={actual}")
    
    dut._log.info(f"{passed}/{total} tests passed")
