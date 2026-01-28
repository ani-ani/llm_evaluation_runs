import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

CLK_NS = 10
MAX_CYCLES = 100

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_lateral_surface(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # PI constant used in HDL
    PI = 3.1415
    HDL_PI_CONST = int(2 * PI * (1 << 16))  # 205891
    
    # Test cases: (radius, height, expected_float)
    test_cases = [
        (10, 5, 314.15000000000003),
        (4, 5, 125.66000000000001),
        (4, 10, 251.32000000000002)
    ]
    
    passed = 0
    failed = 0
    
    for i, (r, h, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: r={r}, h={h}, expected={expected}")
        try:
            # Calculate expected Q16.16 value
            expected_q16 = int(expected * (1 << 16))
            
            # Apply inputs
            dut.radius.value = clamp_to_width(r, 16)
            dut.height.value = clamp_to_width(h, 16)
            await RisingEdge(dut.clk)
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.area.value):
                raise TestFailure("Result undefined")
            
            result_q16 = int(dut.area.value)
            
            # Compare with tolerance (due to fixed-point approx)
            # Allow small error due to PI approximation and fixed-point
            error = abs(result_q16 - expected_q16)
            tolerance = 500  # ~0.0077 at Q16.16 scale
            
            if error <= tolerance:
                cocotb.log.info(f"PASS: Got {result_q16}, Expected {expected_q16}")
                passed += 1
            else:
                # Convert back to float for debugging
                result_float = result_q16 / (1 << 16)
                raise TestFailure(f"Mismatch: Got {result_float:.4f}, Expected {expected:.4f} (Q16 diff: {error})")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
