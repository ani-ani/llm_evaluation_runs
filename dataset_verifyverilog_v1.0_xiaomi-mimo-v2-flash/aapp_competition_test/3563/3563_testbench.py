import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 16, 10, 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def write_coordinates(dut, x_vals, y_vals):
    for i in range(ARRAY_SIZE):
        # Ensure within 16-bit range
        x_clamped = clamp_to_width(x_vals[i] if i < len(x_vals) else 0, DATA_WIDTH)
        y_clamped = clamp_to_width(y_vals[i] if i < len(y_vals) else 0, DATA_WIDTH)
        dut.x[i].value = x_clamped
        dut.y[i].value = y_clamped

def collinear_points(x, y, n):
    """Check if all n points are collinear"""
    if n <= 2:
        return True
    # Check if all points lie on line through first two points
    x1, y1 = x[0], y[0]
    x2, y2 = x[1], y[1]
    
    if x1 == x2 and y1 == y2:
        # First two points same, check if all points same
        for i in range(2, n):
            if x[i] != x1 or y[i] != y1:
                return False
        return True
    
    dx, dy = x2 - x1, y2 - y1
    for i in range(2, n):
        # Check (x[i] - x1) * dy == (y[i] - y1) * dx
        if (x[i] - x1) * dy != (y[i] - y1) * dx:
            return False
    return True

def minimum_lines(x, y, n):
    """Compute minimum lines needed (Python reference)"""
    if n == 0:
        return 0
    if n == 1:
        return 1
    
    # Try k = 1 first
    if collinear_points(x, y, n):
        return 1
    
    # Generate all possible lines (pairs of distinct points)
    lines = []
    for i in range(n):
        for j in range(i, n):
            lines.append((i, j))
    
    num_lines = len(lines)
    
    # For k = 2 to n
    for k in range(2, n+1):
        # Try all combinations of k lines
        # Using recursion for combination generation
        if try_k_lines(x, y, n, lines, k, 0, []):
            return k
    
    return n

def try_k_lines(x, y, n, lines, k, start_idx, chosen):
    """Recursively try combinations of k lines"""
    if len(chosen) == k:
        # Check if all vertices are covered by chosen lines
        covered = [False] * n
        for (i, j) in chosen:
            # Mark vertices on this line
            if i == j:
                covered[i] = True
            else:
                x1, y1 = x[i], y[i]
                x2, y2 = x[j], y[j]
                dx, dy = x2 - x1, y2 - y1
                for v in range(n):
                    if covered[v]:
                        continue
                    # Check if vertex v is on line (i,j)
                    if (x[v] - x1) * dy == (y[v] - y1) * dx:
                        covered[v] = True
        
        # Check if all covered
        if all(covered):
            return True
        return False
    
    if start_idx >= len(lines):
        return False
    
    # Choose line at start_idx
    if try_k_lines(x, y, n, lines, k, start_idx + 1, chosen + [lines[start_idx]]):
        return True
    
    # Don't choose line at start_idx
    if try_k_lines(x, y, n, lines, k, start_idx + 1, chosen):
        return True
    
    return False

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_convexity_lines(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, x_coords, y_coords, expected_result, description)
    test_cases = [
        (4, [0, 1, 1, 0], [0, 1, 0, 1], 2, "Square (diamond)"),
        (8, [0, 2, 0, 2, 0, 1, 0, 1], [0, 2, 2, 0, 1, 0, 1, 2], 3, "More complex"),
        (3, [0, 1, 0], [0, 0, 1], 2, "Triangle"),
        (3, [0, 1, 2], [0, 1, 2], 1, "Collinear 3 points"),
        (4, [0, 1, 2, 3], [0, 1, 2, 3], 1, "Collinear 4 points"),
        (6, [0, 0, 1, 1, 2, 2], [0, 2, 0, 2, 0, 2], 3, "Grid points"),
    ]
    
    passed = failed = 0
    
    for i, (n, x_vals, y_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n})")
        try:
            # Write n (4-bit)
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            # Write coordinates
            write_coordinates(dut, x_vals, y_vals)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_large_n(dut):
    """Test with larger n (but still <= 16 due to hardware limits)"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Create a rectangle (4 corners) plus points along edges
    n = 8
    x_vals = [0, 4, 4, 0, 1, 3, 3, 1]
    y_vals = [0, 0, 4, 4, 1, 1, 3, 3]
    expected = 3  # Need 3 lines: top, bottom, vertical sides
    
    try:
        if has_signal(dut, 'n'):
            dut.n.value = n
        
        write_coordinates(dut, x_vals, y_vals)
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        cocotb.log.info(f"Large n test PASSED: result={result}")
        
    except TestFailure as e:
        cocotb.log.error(f"Large n test FAIL: {e}")
        raise TestFailure(str(e))
