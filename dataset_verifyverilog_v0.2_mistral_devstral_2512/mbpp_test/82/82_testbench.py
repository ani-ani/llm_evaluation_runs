import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import math

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(value):
    # Sign extend if negative
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_sphere_volume(dut):
    """Test sphere volume calculation with multiple radius values"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.radius.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (radius_float, expected_volume_float)
    test_cases = [
        (10.0, 4188.790204786391),
        (25.0, 65449.84694978735),
        (20.0, 33510.32163829113),
        (1.0, 4.1887902047863905),  # Edge case: small radius
        (0.0, 0.0)  # Edge case: zero radius
    ]
    
    passed = 0
    total = len(test_cases)
    
    for radius_float, expected_float in test_cases:
        # Convert to Q16.16
        radius_q16 = float_to_q16_16(radius_float)
        expected_q16 = float_to_q16_16(expected_float)
        
        dut.radius.value = radius_q16
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (should take ~6 cycles)
        timeout = 10
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout waiting for done signal for radius={radius_float}")
        
        # Read result
        result_q16 = int(dut.volume.value)
        result_float = q16_16_to_float(result_q16)
        expected_float = q16_16_to_float(expected_q16)
        
        # Check with relative tolerance
        if radius_float == 0.0:
            # For zero, check exact match
            if result_q16 == 0:
                passed += 1
                print(f"Radius={radius_float:.1f}: Got 0.0 (Expected 0.0) ✓")
            else:
                print(f"Radius={radius_float:.1f}: Got {result_float:.6f} (Expected 0.0) ✗")
        else:
            rel_error = abs(result_float - expected_float) / expected_float
            if rel_error <= 0.001:  # 0.1% tolerance
                passed += 1
                print(f"Radius={radius_float:.1f}: Got {result_float:.2f} (Expected {expected_float:.2f}, error={rel_error*100:.3f}%) ✓")
            else:
                print(f"Radius={radius_float:.1f}: Got {result_float:.2f} (Expected {expected_float:.2f}, error={rel_error*100:.3f}%) ✗")
                raise TestFailure(f"Result mismatch for radius={radius_float}")
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    if passed == total:
        print("All tests passed successfully!")
    else:
        raise TestFailure(f"Only {passed}/{total} tests passed")