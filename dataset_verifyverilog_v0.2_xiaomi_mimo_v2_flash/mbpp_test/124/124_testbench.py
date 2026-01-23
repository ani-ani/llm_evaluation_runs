import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_complex_angle(dut):
    """Test the complex_angle module with various inputs"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test cases: (a_int, b_int, expected_angle_rad)
    # a and b are 16-bit integers representing the value (real/imaginary)
    # The module expects them as is, but we treat them as scaled.
    # Wait, the prompt says: "Input values represent numbers multiplied by 2^16".
    # So if a=0, b=1, we send 0 and 65536.
    # However, the original Python test cases were:
    # Test 1: a=0, b=1j -> angle(0, 1) = 1.570796
    # Test 2: a=2, b=1j -> angle(2, 1) = 0.463647
    # Test 3: a=0, b=2j -> angle(0, 2) = 1.570796
    
    # Let's scale them: Factor 2^16 = 65536
    test_cases = [
        (0, 65536, 1.570796),       # 0, 1
        (131072, 65536, 0.463647),  # 2, 1
        (0, 131072, 1.570796),      # 0, 2
        (65536, 0, 0.0),            # 1, 0 (0 degrees)
        (46340, 46340, 0.785398),   # ~0.707, ~0.707 -> 45 degrees (pi/4)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a_val, b_val, expected_rad in test_cases:
        # Reset done flag
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.a.value = a_val
        dut.b.value = b_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100 # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Read result
        result_raw = int(dut.angle.value)
        # Convert to signed integer if necessary (Python handles this)
        if result_raw >= 2**31:
            result_raw -= 2**32
            
        # Convert Q16.16 to float
        result_float = result_raw / 65536.0
        
        # Check tolerance
        tol = 0.01  # Relaxed tolerance for approximations
        diff = abs(result_float - expected_rad)
        
        if diff < tol or (diff / max(1e-9, abs(expected_rad))) < 0.01:
            passed += 1
            dut._log.info(f"PASS: Input ({a_val/65536.0:.2f}, {b_val/65536.0:.2f}) -> Got {result_float:.5f} rad (Expected {expected_rad:.5f})")
        else:
            dut._log.error(f"FAIL: Input ({a_val/65536.0:.2f}, {b_val/65536.0:.2f}) -> Got {result_float:.5f} rad (Expected {expected_rad:.5f})")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
