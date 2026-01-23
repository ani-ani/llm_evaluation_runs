import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    if value < 0:
        # Handle negative for -1 output
        return 0xFFFFFFFF
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 to float"""
    if value == 0xFFFFFFFF:
        return -1.0
    # Handle sign extension if needed
    if value & 0x80000000:
        return (value - 0x100000000) / 65536.0
    return value / 65536.0

@cocotb.test()
async def test_carpet_area(dut):
    """Test carpet_area module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.dist_a.value = 0
    dut.dist_b.value = 0
    dut.dist_c.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (a, b, c, expected_area)
        (1.0, 1.0, 1.732050, 1.732050808),  # Valid, interior point
        (1.0, 1.0, 3.0, -1.0),              # Invalid, point outside
        (1.732051, 1.732051, 1.732051, 3.897115183),  # Equilateral case
        (0.1, 0.1, 0.1, -1.0),              # Too small, likely invalid
        (50.0, 50.0, 50.0, 2165.0625),     # Large valid case (approx)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a, b, c, expected) in enumerate(test_cases):
        print(f"
Test case {i+1}: a={a}, b={b}, c={c}, expected={expected}")
        
        # Convert to Q16.16
        dut.dist_a.value = float_to_q16_16(a)
        dut.dist_b.value = float_to_q16_16(b)
        dut.dist_c.value = float_to_q16_16(c)
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 200 cycles)
        timeout = 200
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  TIMEOUT after {timeout} cycles")
            continue
        
        # Read result
        result_raw = int(dut.area.value)
        result = q16_16_to_float(result_raw)
        
        print(f"  Result: {result} (raw: 0x{result_raw:08X})")
        print(f"  Expected: {expected}")
        
        # Check result
        if expected < 0:
            # Should be -1 (0xFFFFFFFF)
            if result_raw == 0xFFFFFFFF:
                print("  PASS (correctly returned -1)")
                passed += 1
            else:
                print(f"  FAIL: Expected -1 (0xFFFFFFFF), got {result}")
        else:
            # Should match expected area within tolerance
            error = abs(result - expected)
            tolerance = 0.001  # 10^-3 as specified
            
            if error <= tolerance:
                print(f"  PASS (error={error:.6f} <= {tolerance})")
                passed += 1
            else:
                print(f"  FAIL: error {error:.6f} > {tolerance}")
        
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
