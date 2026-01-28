import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    # For signed 32-bit, range is -2^31 to 2^31-1
    if bits == 32:
        if v < -2147483648: return -2147483648
        if v > 2147483647: return 2147483647
        return v
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    if bits == 32 and val < 0:
        return (1 << 32) + val
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def rect_intersect(r1, r2):
    """Check if two rectangles intersect (boundaries touch)"""
    x1_i, y1_i, x2_i, y2_i = r1
    x1_j, y1_j, x2_j, y2_j = r2
    
    # No intersection if one is completely left/right/above/below
    no_intersect = (x2_i <= x1_j) or (x1_i >= x2_j) or (y2_i <= y1_j) or (y1_i >= y2_j)
    return not no_intersect

def check_all_pairs(rectangles):
    """Check all pairs for intersection"""
    n = len(rectangles)
    for i in range(n):
        for j in range(i+1, n):
            if rect_intersect(rectangles[i], rectangles[j]):
                return True
    return False

def write_rectangle_array(dut, rect_idx, coord_name, value, width=DATA_WIDTH):
    """Write a single coordinate to a specific rectangle array element"""
    array_signal = getattr(dut, f'rect_{coord_name}')
    array_signal[rect_idx].value = clamp_to_width(value, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rectangle_intersection(dut):
    """Test rectangle intersection detection"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (rectangles, expected_result, description)
    test_cases = [
        # Case 1: Two rectangles intersect
        ([(0, 0, 2, 2), (1, 1, 3, 4)], 1, "Intersecting rectangles"),
        # Case 2: Two rectangles don't intersect
        ([(0, 0, 1, 1), (2, 2, 3, 3)], 0, "Non-intersecting rectangles"),
        # Case 3: Three rectangles, one pair intersects
        ([(0, 0, 2, 2), (1, 1, 3, 4), (5, 7, 6, 8)], 1, "Three rectangles, one pair intersects"),
        # Case 4: Four rectangles, no intersections
        ([(0, 0, 20, 20), (1, 1, 3, 4), (2, 10, 9, 12), (11, 3, 19, 18)], 0, "Four rectangles, no intersections"),
        # Case 5: Single rectangle (no pairs possible)
        ([(5, 5, 10, 10)], 0, "Single rectangle"),
        # Case 6: Touching boundaries (should intersect)
        ([(0, 0, 5, 5), (5, 0, 10, 5)], 1, "Touching boundaries"),
        # Case 7: Overlapping large rectangles
        ([(0, 0, 100, 100), (50, 50, 150, 150)], 1, "Large overlapping rectangles"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (rectangles, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc}")
        cocotb.log.info(f"  Rectangles: {rectangles}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            if is_seq:
                await reset_dut(dut)
            
            n_rects = len(rectangles)
            
            # Write rectangles to DUT
            for i, (x1, y1, x2, y2) in enumerate(rectangles):
                write_rectangle_array(dut, i, 'x1', x1)
                write_rectangle_array(dut, i, 'y1', y1)
                write_rectangle_array(dut, i, 'x2', x2)
                write_rectangle_array(dut, i, 'y2', y2)
            
            # Set number of rectangles
            if has_signal(dut, 'n'):
                dut.n.value = n_rects
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected_int = int(expected)
            
            cocotb.log.info(f"  Result: {result}")
            
            if result != expected_int:
                raise TestFailure(f"Expected {expected_int}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    cocotb.log.info(f"\n=== Test Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
