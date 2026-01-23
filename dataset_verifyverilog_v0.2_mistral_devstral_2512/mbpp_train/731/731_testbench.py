import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

def float_to_fixed(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def int_to_fixed(value):
    """Convert integer (scaled by 1000) to Q16.16 fixed-point"""
    return int((value / 1000.0) * 65536) & 0xFFFFFFFF

def fixed_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    # Handle sign extension for negative values
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_cone_lsa(dut):
    """Test cone lateral surface area calculation with fixed-point arithmetic"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.r.value = 0
    dut.h.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (r_input, h_input, expected_lsa_float)
    test_cases = [
        (5000, 12000, 204.20352248333654),  # r=5.0, h=12.0
        (10000, 15000, 566.3586699569488),  # r=10.0, h=15.0
        (19000, 17000, 1521.8090132193388), # r=19.0, h=17.0
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (r_int, h_int, expected) in enumerate(test_cases):
        print(f"
Test {i+1}: r={r_int/1000.0}, h={h_int/1000.0}")
        
        # Convert to integer representation for inputs
        dut.r.value = r_int
        dut.h.value = h_int
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
            print(f"  FAILED: Timeout after {timeout} cycles")
            continue
        
        # Read result
        result_raw = int(dut.result.value)
        result_float = fixed_to_float(result_raw)
        
        # Calculate error
        error_pct = abs(result_float - expected) / expected * 100
        
        print(f"  Result: {result_float:.6f}")
        print(f"  Expected: {expected:.6f}")
        print(f"  Error: {error_pct:.2f}%")
        print(f"  Cycles: {cycles}")
        
        # Check if within 1% tolerance
        if error_pct < 1.0:
            print("  PASSED")
            passed += 1
        else:
            print(f"  FAILED: Error {error_pct:.2f}% exceeds 1% tolerance")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
