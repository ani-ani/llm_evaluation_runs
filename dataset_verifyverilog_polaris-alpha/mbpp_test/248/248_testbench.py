import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def harmonic_sum_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Precomputed Q8.8 values
    def float_to_q8_8(val):
        return int(val * 256)
    
    expected_results = {
        1: float_to_q8_8(1.0),
        4: float_to_q8_8(1 + 1/2 + 1/3),  # ~1.8333
        7: float_to_q8_8(1 + 1/2 + 1/3 + 1/4 + 1/5 + 1/6),  # ~2.45
        15: float_to_q8_8(3.3182289932289297)  # max for n=15
    }

    test_cases = [
        (1, expected_results[1]),
        (4, expected_results[4]),
        (7, expected_results[7]),
        (15, expected_results[15])
    ]

    passed = 0

    for (n_val, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.n_in.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.sum.value.integer
        tolerance = 2  # Allow ±2 in Q8.8 units (~0.0078)
        
        if abs(actual - expected) <= tolerance:
            passed += 1
            dut._log.info(f"PASS: n={n_val} sum={actual} ({actual/256:.5f})")
        else:
            dut._log.error(f"FAIL: n={n_val} got {actual} ({actual/256:.5f}), expected {expected} ({expected/256:.5f})")
        
        await ClockCycles(dut.clk, 2)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")