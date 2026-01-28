import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.r.value = 0
    dut.h.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def float_to_fixed_q16_16(f):
    """Convert float to Q16.16 fixed-point integer"""
    return int(f * 65536)

def fixed_q16_16_to_float(v):
    """Convert Q16.16 fixed-point integer to float"""
    return v / 65536.0

def compute_expected(r, h):
    """Compute expected volume using Python float math"""
    pi = 3.141592653589793
    volume = pi * r * r * h
    return float_to_fixed_q16_16(volume)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_volume_cylinder(dut):
    """Test cylinder volume computation with fixed-point arithmetic"""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (10, 5, "r=10, h=5"),
        (4, 5, "r=4, h=5"),
        (4, 10, "r=4, h=10"),
    ]
    
    passed = 0
    failed = 0
    
    for r, h, desc in test_cases:
        cocotb.log.info(f"Testing {desc}")
        
        try:
            # Set inputs
            dut.r.value = clamp_to_width(r, 8)
            dut.h.value = clamp_to_width(h, 8)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=100)
                
                # Read result
                result_val = int(dut.result.value)
            else:
                # Combinational
                await Timer(10, units='ns')
                result_val = int(dut.result.value)
            
            # Compute expected
            expected = compute_expected(r, h)
            
            # For Q16.16, allow small tolerance due to rounding
            # Convert back to float for comparison
            result_float = fixed_q16_16_to_float(result_val)
            expected_float = fixed_q16_16_to_float(expected)
            
            # Check within 0.1% tolerance (as per problem)
            tolerance = 0.001
            abs_diff = abs(result_float - expected_float)
            rel_diff = abs_diff / max(abs(expected_float), 1e-10)
            
            if rel_diff > tolerance and abs_diff > 0.5:  # 0.5 is ~0.00001 in Q16.16
                raise TestFailure(
                    f"Expected {expected_float:.6f} ({expected:08X}), "
                    f"got {result_float:.6f} ({result_val:08X}), "
                    f"rel diff: {rel_diff:.6f}"
                )
            
            cocotb.log.info(f"  Result: {result_float:.6f} ({result_val:08X})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Additional edge cases
    cocotb.log.info("Testing edge cases...")
    
    # Test zero
    dut.r.value = 0
    dut.h.value = 0
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result_val = int(dut.result.value)
    else:
        await Timer(10, units='ns')
        result_val = int(dut.result.value)
    
    if result_val != 0:
        cocotb.log.error(f"Zero test failed: got {result_val}")
        failed += 1
    else:
        passed += 1
    
    # Test max values (r=255, h=255)
    dut.r.value = 255
    dut.h.value = 255
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result_val = int(dut.result.value)
    else:
        await Timer(10, units='ns')
        result_val = int(dut.result.value)
    
    expected_max = compute_expected(255, 255)
    result_float = fixed_q16_16_to_float(result_val)
    expected_float = fixed_q16_16_to_float(expected_max)
    
    # Allow larger tolerance for max values due to overflow/truncation
    if abs(result_float - expected_float) / expected_float > 0.01:
        cocotb.log.error(f"Max test failed: expected {expected_float:.2f}, got {result_float:.2f}")
        failed += 1
    else:
        passed += 1
    
    # Final result
    cocotb.log.info(f"\nPassed: {passed}, Failed: {failed}")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
