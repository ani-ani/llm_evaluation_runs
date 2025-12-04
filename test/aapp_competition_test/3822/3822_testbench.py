import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from fixedpoint import FixedPoint  # cocotb's FixedPoint
import math

# Converts float to Q16.16 integer
def to_q16_16(val):
    return int(val * (1<<16))

@cocotb.test()
async def test_pupil_transport(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Define test cases (scaled to 16-bit)
    test_cases = [
        (5, 10, 1, 2, 5, 5.0),            # Original sample 1
        (3, 6, 1, 2, 1, 4.7142857143),      # Original sample 2
        (1, 1, 1, 2, 1, 0.5),              # Edge case: single pupil
        (16, 65535, 1, 65535, 16, 1.0),    # Max bus speed
        (16, 500, 100, 200, 16, 2.5),      # Multiple groups, small distance
    ]

    # Initialize
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for case in test_cases:
        n, l, v1, v2, k, expected_float = case
        expected_q16 = to_q16_16(expected_float)

        # Load inputs
        dut.n.value = n
        dut.l.value = l
        dut.v1.value = v1
        dut.v2.value = v2
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 16 cycles for computation
        for _ in range(16):
            await RisingEdge(dut.clk)

        # Check outputs
        recv_q16 = dut.time_q16.value.integer
        tolerance = to_q16_16(1e-4)  # Allow 0.0001 error
        diff = abs(recv_q16 - expected_q16)
        if diff <= tolerance:
            passed += 1
        else:
            recv_float = recv_q16 / (1<<16)
            dut._log.error(
                f"Failed: n={n} l={l} v1={v1} v2={v2} k={k}
" + 
                f"  Expected: {expected_float:.7f} ({hex(expected_q16)}), \
                 Got: {recv_float:.7f} ({hex(recv_q16)})")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
