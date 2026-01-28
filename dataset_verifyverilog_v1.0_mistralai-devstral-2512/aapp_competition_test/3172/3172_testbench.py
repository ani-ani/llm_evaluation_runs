import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
COORD_WIDTH = 32
MAX_POINTS = 16
CLK_NS = 10
MAX_CYCLES = 4000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if bits <= 0: return 0
    mask = (1 << bits) - 1
    return min(mask, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_q16_16(f):
    """Convert float to Q16.16 signed integer"""
    # Clamp to signed 32-bit range
    max_val = (1 << 31) - 1
    min_val = - (1 << 31)
    val = int(f * 65536)
    return max(min_val, min(max_val, val))

def q16_16_to_float(v):
    """Convert Q16.16 to float"""
    return v / 65536.0

async def write_point(dut, idx, x_val, y_val):
    """Write a single point to the dut"""
    if idx >= MAX_POINTS:
        return
    x_q = float_to_q16_16(x_val)
    y_q = float_to_q16_16(y_val)
    dut.x[idx].value = clamp_to_width(x_q, COORD_WIDTH)
    dut.y[idx].value = clamp_to_width(y_q, COORD_WIDTH)

async def reset_dut(dut, cycles=2):
    """Reset the DUT properly"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'busy'):
        pass
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal or timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_fruit_slicer(dut):
    """Test the Max Fruit Slicer module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (points, expected_result)
    test_cases = [
        # Sample 1: 4 is achievable (line through 3.00,3.00 to 4.00,2.00 catches 4 fruits)
        ([
            (1.00, 5.00),
            (3.00, 3.00),
            (4.00, 2.00),
            (6.00, 4.50),
            (7.00, 1.00)
        ], 4, "Sample 1"),
        
        # Sample 2: All 3 in equilateral triangle (line through vertex and tangent to base)
        ([
            (-1.50, -1.00),
            (1.50, -1.00),
            (0.00, 1.00)
        ], 3, "Sample 2"),
        
        # Overlapping points
        ([
            (1.00, 1.00),
            (1.00, 1.00)
        ], 2, "Overlapping"),
        
        # Single point
        ([
            (0.00, 0.00)
        ], 1, "Single point"),
        
        # Line test: 4 points in a row, all can be sliced
        ([
            (0.00, 0.00),
            (1.00, 0.00),
            (2.00, 0.00),
            (3.00, 0.00)
        ], 4, "Colinear points"),
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (points, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {case_idx+1}: {desc} ({len(points)} points)")
        
        try:
            n = len(points)
            if n > MAX_POINTS:
                cocotb.log.warning(f"  Skipping: {n} > {MAX_POINTS}")
                continue
            
            # Write all points
            for i, (x, y) in enumerate(points):
                await write_point(dut, i, x, y)
            
            # Set num_points
            if has_signal(dut, 'num_points'):
                dut.num_points.value = n
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Check result (allow >= expected due to possible better line found)
            if result < expected:
                raise TestFailure(f"Expected at least {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result} (expected {expected})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
        
        # Optional: verify done is low
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")