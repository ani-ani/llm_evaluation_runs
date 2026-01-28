import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Fixed-point constants
FRAC_BITS = 8
PI = 3.14159265
PI_FIXED = int(PI * (1 << FRAC_BITS))  # 804

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cylinder_surface_area(dut):
    """Test cylinder surface area calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (radius, height, expected_area_float, description)
    test_cases = [
        (10.0, 5.0, 942.45, "r=10, h=5"),
        (4.0, 5.0, 226.188, "r=4, h=5"),
        (4.0, 10.0, 351.848, "r=4, h=10"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius, height, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Convert to fixed-point
            radius_fixed = float_to_fixed(radius)
            height_fixed = float_to_fixed(height)
            
            # Expected result in fixed-point
            expected_fixed = float_to_fixed(expected, frac_bits=16)
            
            # Set inputs
            dut.radius.value = radius_fixed
            dut.height.value = height_fixed
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            result_float = fixed_to_float(result_raw, frac_bits=16)
            
            # Check with tolerance for fixed-point rounding
            tolerance = 2.0  # Allow ~2 units error
            diff = abs(result_float - expected)
            
            if diff > tolerance:
                raise TestFailure(f"Expected {expected:.4f}, got {result_float:.4f} (diff={diff:.4f})")
            
            cocotb.log.info(f"  PASS: result = {result_float:.4f} (raw={result_raw}, expected={expected:.4f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")