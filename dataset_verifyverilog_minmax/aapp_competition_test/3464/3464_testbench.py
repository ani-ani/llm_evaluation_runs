import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_casino(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Function to convert float to Q16.16 fixed-point
    def to_q16_16(val):
        return int(val * 65536)

    # Test cases (original scaled to fixed-point)
    test_cases = [
        # Input: (x, p), expected output (Q16.16)
        ((0.0, 49.9), 0.0),
        ((50.0, 49.85), 7.10178453)
    ]

    passed = 0
    for (x_val, p_val), expected in test_cases:
        # Convert inputs to fixed-point representation
        x_fp = int(x_val * 100)
        p_fp = int(p_val * 100)
        expected_fp = to_q16_16(expected)

        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Set inputs
        dut.x.value = x_fp
        dut.p.value = p_fp
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        await ClockCycles(dut.clk, 18)
        if not dut.done.value:
            dut._log.error("Calculation did not complete in 18 cycles")
            continue

        # Verify output within tolerance (error = ±1 in fixed-point)
        result = dut.max_profit.value.signed_integer
        error = abs(result - expected_fp)
        if error <= 655:  # ~0.01 error margin (65536 * 0.0001)
            passed += 1
        else:
            actual_val = result / 65536.0
            dut._log.error(f"Test failed: x={x_val}, p={p_val}
                Expected: {expected} ({expected_fp})
                Actual: {actual_val} ({result})
                Error: {error} units")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
