import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 200
NUM_DIRECTIONS = 16
MAX_TREES = 8

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# EXPECTED RESULT CALCULATION
# ============================================================================

def compute_expected_probability(trees, b, d):
    """Compute expected probability using same discrete directions."""
    # Precompute direction vectors for 16 angles (0 to 360 degrees in 22.5° steps)
    directions = []
    for i in range(NUM_DIRECTIONS):
        angle = 2 * math.pi * i / NUM_DIRECTIONS
        cos_val = math.cos(angle)
        sin_val = math.sin(angle)
        # Scale to fixed-point 16.16 for consistency
        cos_fixed = int(cos_val * 65536)
        sin_fixed = int(sin_val * 65536)
        directions.append((cos_fixed, sin_fixed))
    
    safe_count = 0
    
    for cos_fixed, sin_fixed in directions:
        # Compute end point coordinates (scaled by d, then shift right by 16)
        vx = (d * cos_fixed) >> 16
        vy = (d * sin_fixed) >> 16
        
        safe = True
        for tree in trees:
            x_i, y_i, r_i = tree
            R = r_i + b
            R_sq = R * R
            
            # Convert to integers
            x_int = x_i
            y_int = y_i
            vx_int = vx
            vy_int = vy
            
            # Compute dot products
            dot = x_int * vx_int + y_int * vy_int
            len_sq = vx_int * vx_int + vy_int * vy_int
            
            if len_sq == 0:
                # Segment is a point
                dist_sq = x_int * x_int + y_int * y_int
                if dist_sq <= R_sq:
                    safe = False
                    break
                continue
            
            if dot <= 0:
                # Closest point is origin
                dist_sq = x_int * x_int + y_int * y_int
                if dist_sq <= R_sq:
                    safe = False
                    break
            elif dot >= len_sq:
                # Closest point is end point
                dx = x_int - vx_int
                dy = y_int - vy_int
                dist_sq = dx * dx + dy * dy
                if dist_sq <= R_sq:
                    safe = False
                    break
            else:
                # Closest point is along the segment
                # Use 64-bit to avoid overflow
                x_sq = x_int * x_int
                y_sq = y_int * y_int
                left = (x_sq + y_sq) * len_sq - dot * dot
                right = R_sq * len_sq
                if left <= right:
                    safe = False
                    break
        
        if safe:
            safe_count += 1
    
    return safe_count / NUM_DIRECTIONS

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_boar_collision(dut):
    """Test the boar collision probability module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (trees, b, d, description)
    # Trees are (x, y, r) tuples
    test_cases = [
        (
            [(3, 0, 1)],  # One tree at (3,0) with radius 1
            1,            # boar radius
            4,            # charge distance
            "One tree at (3,0), b=1, d=4"
        ),
        (
            [(6, 0, 3), (0, 6, 3), (-6, 0, 3), (0, -6, 3)],  # Four trees
            1,            # boar radius
            3,            # charge distance
            "Four trees in plus formation, b=1, d=3"
        ),
        (
            [],  # No trees
            1,
            5,
            "No trees"
        ),
        (
            [(100, 100, 10)],  # Far away tree
            1,
            50,
            "Tree too far to hit"
        ),
        (
            [(0, 2, 1)],  # Tree directly in path
            1,
            5,
            "Tree directly in path"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (trees, b, d, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        # Set number of trees
        n = len(trees)
        dut.n.value = n
        
        # Set tree parameters
        for j in range(MAX_TREES):
            if j < n:
                x, y, r = trees[j]
                # Set individual tree signals
                if has_signal(dut, f'tree{j}_x'):
                    getattr(dut, f'tree{j}_x').value = from_signed(x, 16)
                    getattr(dut, f'tree{j}_y').value = from_signed(y, 16)
                    getattr(dut, f'tree{j}_r').value = clamp_to_width(r, 16)
                else:
                    # Fallback to array access if available
                    if has_signal(dut, 'tree_x'):
                        dut.tree_x[j].value = from_signed(x, 16)
                        dut.tree_y[j].value = from_signed(y, 16)
                        dut.tree_r[j].value = clamp_to_width(r, 16)
            else:
                # Clear unused trees
                if has_signal(dut, f'tree{j}_x'):
                    getattr(dut, f'tree{j}_x').value = 0
                    getattr(dut, f'tree{j}_y').value = 0
                    getattr(dut, f'tree{j}_r').value = 0
                elif has_signal(dut, 'tree_x'):
                    dut.tree_x[j].value = 0
                    dut.tree_y[j].value = 0
                    dut.tree_r[j].value = 0
        
        # Set boar parameters
        dut.b.value = clamp_to_width(b, 16)
        dut.d.value = clamp_to_width(d, 16)
        
        # Calculate expected result
        expected_prob = compute_expected_probability(trees, b, d)
        expected_fixed = int(expected_prob * 65536)  # Convert to 16.16 fixed-point
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout_count = 0
        done = False
        while timeout_count < MAX_CYCLES:
            await RisingEdge(dut.clk)
            timeout_count += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"  TIMEOUT: done not asserted after {MAX_CYCLES} cycles")
            failed += 1
            continue
        
        # Read probability result
        if not is_value_defined(dut.probability.value):
            cocotb.log.error(f"  FAIL: probability is undefined (X/Z)")
            failed += 1
            continue
        
        result_fixed = int(dut.probability.value)
        result_prob = result_fixed / 65536.0
        
        # Allow small error due to fixed-point approximation
        error = abs(result_prob - expected_prob)
        if error < 1e-6:
            cocotb.log.info(f"  PASS: got {result_prob:.8f}, expected {expected_prob:.8f}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: got {result_prob:.8f}, expected {expected_prob:.8f}, error={error:.8f}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info("All tests passed!")