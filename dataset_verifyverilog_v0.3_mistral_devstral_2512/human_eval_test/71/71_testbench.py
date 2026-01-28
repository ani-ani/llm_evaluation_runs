import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    if value < 0:
        return 0xFFFFFFFF
    return int(value * 65536) & 0xFFFFFFFF

# Helper to check if value is defined
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_triangle_area(dut):
    """Test triangle_area module with various test cases"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.c.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (a, b, c, expected_result_as_float)
    test_cases = [
        (3, 4, 5, 6.00),      # Valid: 3-4-5 right triangle
        (1, 2, 10, -1),       # Invalid: 1+2 <= 10
        (4, 8, 5, 8.18),      # Valid
        (2, 2, 2, 1.73),      # Valid: equilateral
        (1, 2, 3, -1),        # Invalid: 1+2 = 3 (degenerate)
        (10, 5, 7, 16.25),    # Valid
        (2, 6, 3, -1),        # Invalid: 2+3 <= 6
        (1, 1, 1, 0.43),      # Valid: small equilateral
        (2, 2, 10, -1),       # Invalid: 2+2 <= 10
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, c, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: a={a}, b={b}, c={c}, expected={expected}")
        
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        max_cycles = 150
        completed = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                completed = True
                break
        
        if not completed:
            dut._log.error(f"Test {i+1} TIMEOUT: Did not complete in {max_cycles} cycles")
            failed += 1
            continue
        
        # Verify output is defined
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1}: Result is undefined (X/Z)")
            failed += 1
            continue
        
        # Read result
        result_value = int(dut.result.value)
        
        # Convert expected to Q16.16
        if expected < 0:
            expected_q = 0xFFFFFFFF
        else:
            expected_q = float_to_q16_16(expected)
        
        # For floating point comparison, allow small rounding error
        # Convert both back to float for comparison
        result_float = result_value / 65536.0 if result_value != 0xFFFFFFFF else -1.0
        
        # Check if both are invalid or both are valid with tolerance
        if expected < 0:
            if result_value == 0xFFFFFFFF:
                dut._log.info(f"Test {i+1} PASSED: Correctly returned -1")
                passed += 1
            else:
                dut._log.error(f"Test {i+1} FAILED: Expected -1 (0xFFFFFFFF), got {result_value:#010x} ({result_float:.4f})")
                failed += 1
        else:
            # Allow 0.02 tolerance due to fixed-point precision and sqrt approximation
            if abs(result_float - expected) <= 0.02:
                dut._log.info(f"Test {i+1} PASSED: {result_float:.4f} (expected {expected:.4f})")
                passed += 1
            else:
                dut._log.error(f"Test {i+1} FAILED: Expected {expected:.4f}, got {result_float:.4f} ({result_value:#010x})")
                failed += 1
    
    # Summary
    total = passed + failed
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")
