import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper function to convert float to Q16.16 format
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(q):
    if q == 0xFFFFFFFF:
        return -1.0
    # Handle signed values properly
    if q & 0x80000000:
        q = q - 0x100000000
    return q / 65536.0

@cocotb.test()
async def test_triangle_area(dut):
    """Test triangle area calculation with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.c.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (a, b, c, expected_float)
    test_cases = [
        (3, 4, 5, 6.00),      # Right triangle, valid
        (1, 2, 10, -1.0),     # Invalid: 1+2 < 10
        (4, 8, 5, 8.18),      # Valid scalene
        (2, 2, 2, 1.73),      # Valid equilateral
        (1, 2, 3, -1.0),      # Invalid: degenerate
        (10, 5, 7, 16.25),    # Valid scalene
        (2, 6, 3, -1.0),      # Invalid: 2+3 < 6
        (1, 1, 1, 0.43),      # Valid small equilateral
        (2, 2, 10, -1.0),     # Invalid: 2+2 < 10
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a, b, c, expected in test_cases:
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        cycles = 0
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Read result
        result_raw = int(dut.result.value)
        result_float = q16_16_to_float(result_raw)
        
        # Check result (allow small tolerance for rounding)
        tolerance = 0.02  # 2 cents tolerance due to fixed-point rounding
        
        if expected < 0:
            # Should be invalid
            if result_raw == 0xFFFFFFFF:
                print(f"PASS: ({a},{b},{c}) => Invalid (expected -1, got -1)")
                passed += 1
            else:
                print(f"FAIL: ({a},{b},{c}) => Expected -1, got {result_float:.4f}")
        else:
            # Should match expected area
            diff = abs(result_float - expected)
            if diff <= tolerance:
                print(f"PASS: ({a},{b},{c}) => {result_float:.4f} (expected {expected:.4f}, diff={diff:.4f})")
                passed += 1
            else:
                print(f"FAIL: ({a},{b},{c}) => {result_float:.4f} (expected {expected:.4f}, diff={diff:.4f})")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
