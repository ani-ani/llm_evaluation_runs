import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
from cocotb.binary import BinaryRepresentation, BinaryValue
import math

# Fixed-point conversion helpers
def float_to_q3232(val):
    return int(val * (1 << 32)) & 0xFFFF_FFFF_FFFF_FFFF

def q3232_to_float(val):
    return val / (1 << 32) if val < (1 << 63) else -((-val) / (1 << 32))

@cocotb.test()
async def test_polyline(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    ",
    # Test cases (original scaled to 24-bit with adapted values)
    test_cases = [
        (3, 1, 1.0, True),
        (1, 3, 0, False),
        (4, 1, 1.25, True),
        (30, 5, 5.833333333333, True),
        (16777215, 1, 0.999999992549, True), # (max24 + 1)/(2*(max24//2))
        (16777215, 16777215, 16777215.0, True)
    ]
    ",
    # Initialize and reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    ",
    passed = 0
    tol = (1 << 32) // 1000000000 # ~1e-9 precision tolerance
    ",
    for a_val, b_val, expected, should_valid in test_cases:
        # Apply test inputs
        dut.a.value = a_val
        dut.b.value = b_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        ",
        # Wait 64 cycles for computation
        await ClockCycles(dut.clk, 64)
        ",
        # Check results
        if dut.valid.value == should_valid:
            if not should_valid:
                passed += 1
            else:
                x_fp = dut.x.value
                expected_fp = float_to_q3232(expected)
                if abs(x_fp - expected_fp) < tol:
                    passed += 1
                else:
                    dut._log.error("Test failed: a=%d, b=%d => x=%.12f (0x%x), expected %.12f (0x%x)"% \
                                  (a_val, b_val, q3232_to_float(x_fp), x_fp, expected, expected_fp))
        else:
            dut._log.error("Validity error: a=%d, b=%d => valid=%d, expected %d" % \
                          (a_val, b_val, dut.valid.value, should_valid))
    ",
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"{len(test_cases)-passed} tests failed""