import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

# Convert float to Q8.8 fixed-point
def to_q8_8(val):
    return int(val * 256) & 0xFFFF

@cocotb.test()
async def test_triangle_area(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper function to run test case
    async def run_case(a, b, c, expected):
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await ClockCycles(dut.clk, 8) # Wait for computation
        
        if expected == -1:
            assert dut.error.value == 1, f"Error not raised for invalid triangle {a},{b},{c}"
            assert dut.area.value == 0xFFFF, f"Incorrect error value for {a},{b},{c}"
        else:
            assert dut.error.value == 0, f"Error raised for valid triangle {a},{b},{c}"
            actual = dut.area.value.signed_integer / 256.0
            # Allow ±0.01 tolerance due to fixed-point rounding
            assert abs(actual - expected) < 0.015, f"Area mismatch: {actual:.2f} vs {expected:.2f}"

    # Define adapted test cases (converted to 8-bit values)
    test_cases = [
        (3, 4, 5, 6.00),
        (1, 2, 10, -1),
        (4, 8, 5, 8.18),  # Expected Q8.8 value: 8.18 approx
        (2, 2, 2, 1.73),  # sqrt(3) ≈ 1.732, scaled
        (1, 2, 3, -1),
        (10, 5, 7, 16.25),
        (2, 6, 3, -1),
        (1, 1, 1, 0.43)   # (sqrt(3)/4) ≈ 0.433 → 0.43
    ]
    
    # Reset the module
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for a, b, c, expected in test_cases:
        try:
            await run_case(a, b, c, expected)
            passed += 1
            dut._log.info(f"PASS: {a},{b},{c} → {expected}")
        except AssertionError as e:
            dut._log.error(f"FAIL: {a},{b},{c} - {str(e)}")
    
    dut._log.info(f"{passed}/{total} tests passed")
    if passed != total:
        raise cocotb.result.TestFailure(f"{passed}/{total} passed")
