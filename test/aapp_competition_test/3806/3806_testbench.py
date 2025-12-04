import cocotb
from cocotb.triggers import RisingEdge, Timer
from math import pi
import numpy as np

@cocotb.test()
async def test_snowblower(dut):
    # Test cases: (max_sq, min_sq, expected_area)
    test_cases = [
        # Original first sample scaled (max^2 - min^2 = 4.0)
        (4 << 16, 0 << 16, 12.566370614359172),
        # Second sample with manual calculation
        (21 << 16, 7 << 16, 21.99114857512855)
    ]

    # Create clock
    clock = cocotb.clock.Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    passed = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for max_val, min_val, expected in test_cases:
        dut.max_sq.value = max_val
        dut.min_sq.value = min_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Get result and convert to float
        diff_val = dut.diff.value.signed_integer / (1 << 16)
        actual_area = diff_val * pi
        
        # Verify within 1e-6 tolerance
        rel_error = abs(actual_area - expected) / max(1.0, abs(expected))
        if rel_error <= 1e-6:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {expected}, got {actual_area}
                           Rel error: {rel_error}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)