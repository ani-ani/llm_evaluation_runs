import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_POINTS = 4
COORD_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def compute_min_additions(points):
    """Compute minimum additions for point symmetry (Python reference)."""
    n = len(points)
    if n == 0:
        return 0
    
    # Try all possible centers (midpoints of pairs)
    max_symmetric = 0
    
    for i in range(n):
        for j in range(i+1, n):
            # Candidate center from points[i] and points[j]
            cx = (points[i][0] + points[j][0]) / 2
            cy = (points[i][1] + points[j][1]) / 2
            
            # Count symmetric points for this center
            symmetric = 0
            for k in range(n):
                # Check if reflection of point k exists
                rx = 2*cx - points[k][0]
                ry = 2*cy - points[k][1]
                
                # Look for matching point
                found = False
                for m in range(n):
                    if abs(points[m][0] - rx) < 0.1 and abs(points[m][1] - ry) < 0.1:
                        found = True
                        break
                
                if found:
                    symmetric += 1
            
            max_symmetric = max(max_symmetric, symmetric)
    
    # Also try each point as center
    for i in range(n):
        cx = points[i][0]
        cy = points[i][1]
        symmetric = 0
        for k in range(n):
            rx = 2*cx - points[k][0]
            ry = 2*cy - points[k][1]
            found = False
            for m in range(n):
                if abs(points[m][0] - rx) < 0.1 and abs(points[m][1] - ry) < 0.1:
                    found = True
                    break
            if found:
                symmetric += 1
        max_symmetric = max(max_symmetric, symmetric)
    
    return n - max_symmetric

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_symmetry_solver(dut):
    """Test the symmetry solver module."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    
    cocotb.log.info(f"Interface detection - clk: {has_clk}, rst: {has_rst}, start: {has_start}, done: {has_done}")
    
    # Start clock if sequential
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await Timer(50, units='ns')
    
    # Reset
    if has_rst:
        dut.rst_n.value = 0
        if has_start:
            dut.start.value = 0
        if has_clk:
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        dut.rst_n.value = 1
        await Timer(50, units='ns')
    
    # Test cases
    test_cases = [
        # (points, expected_min_additions, description)
        ([(0, 0), (10, 0), (0, 10), (10, 10)], 0, "Square - already symmetric"),
        ([(0, 0), (10, 0)], 0, "Two points - symmetric about midpoint"),
        ([(0, 0)], 0, "Single point - symmetric about itself"),
        ([(0, 0), (10, 0), (0, 10)], 1, "Right triangle - needs one more point"),
        ([(0, 0), (10, 0), (5, 5)], 1, "Isosceles - needs one more"),
        ([(0, 0), (10, 0), (20, 0), (30, 0)], 2, "Line of points - needs many for symmetry"),
        ([(0, 0), (10, 10), (20, 0), (10, -10)], 0, "Diamond - already symmetric"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (points, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Points: {points}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Limit points to MAX_POINTS
            n = len(points)
            if n > MAX_POINTS:
                cocotb.log.warning(f"  Skipping: n={n} exceeds MAX_POINTS={MAX_POINTS}")
                continue
            
            # Pad points to MAX_POINTS with (0,0)
            padded_points = points + [(0,0)] * (MAX_POINTS - n)
            
            # Pack points into 16-bit values (x[7:0], y[7:0])
            for idx, (x, y) in enumerate(padded_points):
                # Clamp values to 8-bit
                x_clamped = clamp_to_width(x, DATA_WIDTH)
                y_clamped = clamp_to_width(y, DATA_WIDTH)
                packed = (y_clamped << 8) | x_clamped
                
                # Assign to array element
                if has_signal(dut, f'points_{idx}'):
                    getattr(dut, f'points_{idx}').value = packed
                else:
                    dut.points[idx].value = packed
            
            # Assign n
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            # Start computation
            if has_start:
                dut.start.value = 1
                if has_clk:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(20, units='ns')
                dut.start.value = 0
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Wait for done or timeout
            if has_done and has_clk:
                await RisingEdge(dut.clk)
                timeout = 0
                while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
                    await RisingEdge(dut.clk)
                    timeout += 1
                    if timeout > MAX_CYCLES:
                        raise TestFailure(f"Timeout waiting for done signal")
            else:
                # Combinational or no done signal
                await Timer(200, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Compute expected using Python reference
            expected_calc = compute_min_additions(points)
            
            # Verify
            if result != expected_calc:
                raise TestFailure(f"Expected {expected_calc}, got {result}")
            
            # Also check against hardcoded expected
            if result != expected:
                cocotb.log.warning(f"  Result {result} differs from hardcoded {expected}, but matches calculated {expected_calc}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: RANDOMIZED TESTS
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random points."""
    
    # Setup
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await Timer(50, units='ns')
    
    if has_rst:
        dut.rst_n.value = 0
        if has_start:
            dut.start.value = 0
        if has_clk:
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        dut.rst_n.value = 1
        await Timer(50, units='ns')
    
    random.seed(42)  # Reproducible
    num_tests = 10
    passed = 0
    failed = 0
    
    for test_num in range(num_tests):
        # Generate random n (1 to MAX_POINTS)
        n = random.randint(1, MAX_POINTS)
        points = []
        
        for _ in range(n):
            x = random.randint(0, 255)  # 8-bit range
            y = random.randint(0, 255)
            points.append((x, y))
        
        cocotb.log.info(f"\nRandom Test {test_num+1}: n={n}, points={points}")
        
        try:
            # Calculate expected
            expected = compute_min_additions(points)
            cocotb.log.info(f"  Expected: {expected}")
            
            # Prepare padded input
            padded_points = points + [(0,0)] * (MAX_POINTS - n)
            
            # Assign to DUT
            for idx, (x, y) in enumerate(padded_points):
                packed = (y << 8) | x
                if has_signal(dut, f'points_{idx}'):
                    getattr(dut, f'points_{idx}').value = packed
                else:
                    dut.points[idx].value = packed
            
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            # Start
            if has_start:
                dut.start.value = 1
                if has_clk:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(20, units='ns')
                dut.start.value = 0
            else:
                await Timer(100, units='ns')
            
            # Wait for done
            if has_done and has_clk:
                await RisingEdge(dut.clk)
                timeout = 0
                while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
                    await RisingEdge(dut.clk)
                    timeout += 1
                    if timeout > MAX_CYCLES:
                        raise TestFailure(f"Timeout")
            else:
                await Timer(200, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Undefined result")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Random Tests: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} random tests failed")
