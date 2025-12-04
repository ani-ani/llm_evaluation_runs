import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_piles(dut):
    """Test adapted cases (n≤8) from original problem"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Initialize/reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        (3, [2,6,8], 2),
        (5, [2,3,4,9,12], 4),
        (4, [5,7,2,9], 1)
    ]

    passed = 0
    for idx, (n_val, a_vals, expected) in enumerate(test_cases):
        # Load inputs (pad array to 8 elements)
        dut.n.value = n_val
        for i in range(8):
            dut.a[i].value = a_vals[i] if i < len(a_vals) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout=200 cycles)
        for _ in range(200):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            dut._log.error(f"Test {idx} timed out")
            continue
        
        # Check result
        result_val = dut.result.value.integer
        if result_val % 1000000007 == expected:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: got {result_val}, expected {expected}")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")