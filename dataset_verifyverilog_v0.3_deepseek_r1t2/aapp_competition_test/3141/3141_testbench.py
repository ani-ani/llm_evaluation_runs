import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32          # 16.16 fixed-point
FRAC_BITS = 16
MAX_N = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to Q16.16 fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert Q16.16 fixed-point integer to float."""
    return fixed / (1 << frac_bits)

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_points(dut, points, N):
    """Write N points to DUT inputs."""
    # Map points to individual ports
    point_ports = [
        ('x0','y0','z0'), ('x1','y1','z1'), ('x2','y2','z2'), ('x3','y3','z3'),
        ('x4','y4','z4'), ('x5','y5','z5'), ('x6','y6','z6'), ('x7','y7','z7')
    ]
    
    for i in range(MAX_N):
        if i < N:
            x_val, y_val, z_val = points[i]
            setattr(dut, point_ports[i][0], float_to_fixed(x_val))
            setattr(dut, point_ports[i][1], float_to_fixed(y_val))
            setattr(dut, point_ports[i][2], float_to_fixed(z_val))
        else:
            # Clear unused ports
            setattr(dut, point_ports[i][0], 0)
            setattr(dut, point_ports[i][1], 0)
            setattr(dut, point_ports[i][2], 0)
    
    dut.N.value = N

async def read_result(dut):
    """Read the result diameter and convert to float."""
    if not is_value_defined(dut.diameter.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result_fixed = int(dut.diameter.value)
    return fixed_to_float(result_fixed)

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_drill_bit(dut):
    """Test the drill_bit module with given examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (points, expected_diameter, description)
    # Points are list of (x, y, z) tuples
    test_cases = [
        (
            [(1.0, 0.0, 1.4), (-1.0, 0.0, -1.4), (0.0, 1.0, -0.2)],
            2.0,
            "Sample Input 1: 3 points"
        ),
        (
            [(1.4, 1.0, 0.0), (-0.4, -1.0, 0.0), (-0.1, -0.25, -0.5), (-1.2, 0.0, 0.9), (0.2, 0.5, 0.5)],
            2.0,
            "Sample Input 2: 5 points"
        ),
        (
            [(435.249, -494.71, -539.356), (455.823, -507.454, -539.257),
             (423.394, -520.682, -538.858), (446.507, -501.953, -539.37),
             (434.266, -503.664, -560.631), (445.059, -549.71, -537.501),
             (449.65, -506.637, -513.778), (456.05, -499.715, -561.329)],
            49.9998293198,
            "Sample Input 3: 8 points"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (points, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Points: {len(points)}, Expected diameter: {expected}")
        
        try:
            # Write points
            await write_points(dut, points, len(points))
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Check with tolerance
            tolerance = 1e-4
            abs_error = abs(result - expected)
            rel_error = abs_error / expected if expected != 0 else abs_error
            
            if abs_error > tolerance and rel_error > tolerance:
                raise TestFailure(f"Result {result} not within tolerance of {expected}")
            
            cocotb.log.info(f"  PASS: result = {result:.10f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")