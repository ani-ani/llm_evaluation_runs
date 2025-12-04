import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_geometric_sum(dut):
    # Pre-calculate expected fixed-point values
    test_cases = [
        (4, 1.9375),
        (7, 1.9921875),
        (8, 1.99609375),
        (0, 1.0),  # Edge case
        (3, 1.875)  # Additional test
    ]
    fixed_test = [(n, int(v * (1 << 16))) for n, v in test_cases]

    # Clock generation
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    passed = 0
    total = len(fixed_test)
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for tn, (n_val, expected) in enumerate(fixed_test):
        dut._log.info(f"Testing n={n_val} (expected: 0x{expected:08X})")
        
        # Apply inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation
        cycles_waited = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles_waited += 1
            if cycles_waited > 20:
                break
        
        # Check result
        result = dut.sum_q16.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS Test #{tn+1}: n={n_val} -> 0x{result:08X}")
        else:
            dut._log.error(f"FAIL Test #{tn+1}: n={n_val} got 0x{result:08X}, expected 0x{expected:08X}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")