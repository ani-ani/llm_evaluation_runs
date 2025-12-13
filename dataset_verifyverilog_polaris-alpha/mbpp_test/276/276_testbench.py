import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_cylinder(dut):
    # Test cases: (radius, height, expected_float)
    test_cases = [
        (10, 5, 1570.75),
        (4, 5, 251.32),
        (4, 10, 502.64),
        (0, 5, 0.0),      # edge case - zero radius
        (65535, 1, 3.1415 * 65535**2)  # max input case
    ]

    # Convert float to fixed-point (Q16.16)
    def float_to_q16_16(val):
        return int(val * 65536)

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for r, h, expected_float in test_cases:
        dut.radius.value = r
        dut.height.value = h
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0  # Single cycle pulse

        # Wait 4 cycles for result (3 computation + done assertion)
        await ClockCycles(dut.clk, 4)

        expected = float_to_q16_16(expected_float)
        
        # Allow 1% tolerance due to fixed-point precision
        actual = dut.volume.value.integer
        if abs(actual - expected) < max(1, 0.01 * expected):
            passed += 1
            dut._log.info(f"PASS: r={r}, h={h} => 0x{actual:08X} (~{actual/65536:.2f})")
        else:
            dut._log.error(f"FAIL: r={r}, h={h} => 0x{actual:08X} ({actual/65536:.2f}), expected 0x{expected:08X} ({expected_float:.2f})")

        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")