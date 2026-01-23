import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Pack coordinates into 32-bit value
def pack_coordinates(coords):
    result = 0
    for i, val in enumerate(coords):
        # Clamp to 8-bit signed range
        val = max(-128, min(127, val))
        val_unsigned = from_signed(val, 8)
        result |= (val_unsigned << (i * 8))
    return result

# Python reference implementation
def python_reference(s1_coords, s2_coords):
    # Unpack axis-aligned square
    x_coords = [s1_coords[0], s1_coords[2], s1_coords[4], s1_coords[6]]
    y_coords = [s1_coords[1], s1_coords[3], s1_coords[5], s1_coords[7]]
    x_min, x_max = min(x_coords), max(x_coords)
    y_min, y_max = min(y_coords), max(y_coords)
    
    # Unpack rotated square
    a_coords = [s2_coords[0], s2_coords[2], s2_coords[4], s2_coords[6]]
    b_coords = [s2_coords[1], s2_coords[3], s2_coords[5], s2_coords[7]]
    
    # Transform rotated square to UV space
    u_coords = [a_coords[i] + b_coords[i] for i in range(4)]
    v_coords = [a_coords[i] - b_coords[i] for i in range(4)]
    u_min, u_max = min(u_coords), max(u_coords)
    v_min, v_max = min(v_coords), max(v_coords)
    
    # Check vertices of square1 in square2
    for i in range(4):
        x, y = x_coords[i], y_coords[i]
        u, v = x + y, x - y
        if u_min <= u <= u_max and v_min <= v <= v_max:
            return 1
    
    # Check vertices of square2 in square1
    for i in range(4):
        a, b = a_coords[i], b_coords[i]
        if x_min <= a <= x_max and y_min <= b <= y_max:
            return 1
    
    # Check edge intersections (simplified for small ranges)
    # For this problem, vertex checks often suffice, but we add basic edge check
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    
    def seg_intersect(p1, p2, q1, q2):
        d1 = cross(p1, p2, q1)
        d2 = cross(p1, p2, q2)
        d3 = cross(q1, q2, p1)
        d4 = cross(q1, q2, p2)
        if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
           ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
            return True
        return False
    
    s1_edges = [((x_coords[i], y_coords[i]), (x_coords[(i+1)%4], y_coords[(i+1)%4])) for i in range(4)]
    s2_edges = [((a_coords[i], b_coords[i]), (a_coords[(i+1)%4], b_coords[(i+1)%4])) for i in range(4)]
    
    for s1_edge in s1_edges:
        for s2_edge in s2_edges:
            if seg_intersect(s1_edge[0], s1_edge[1], s2_edge[0], s2_edge[1]):
                return 1
    
    return 0

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_square_intersection(dut):
    """Test square intersection detection module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.square1_coords.value = 0
    dut.square2_coords.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (square1_coords, square2_coords, expected_result)
    test_cases = [
        # Example 1: YES
        ([0,0,6,0,6,6,0,6], [1,3,3,5,5,3,3,1], 1),
        # Example 2: NO  
        ([0,0,6,0,6,6,0,6], [7,3,9,5,11,3,9,1], 0),
        # Example 3: YES
        ([6,0,6,6,0,6,0,0], [7,4,4,7,7,10,10,7], 1),
        # Edge case: touching vertices
        ([0,0,1,0,1,1,0,1], [1,1,2,2,3,1,2,0], 1),
        # No intersection
        ([0,0,1,0,1,1,0,1], [2,0,3,0,3,1,2,1], 0),
        # One inside other
        ([0,0,10,0,10,10,0,10], [2,2,4,4,6,2,4,0], 1),
        # Edge overlap
        ([0,0,2,0,2,2,0,2], [2,0,3,1,2,2,1,1], 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s1, s2, expected) in enumerate(test_cases):
        dut._log.info(f"Running test {i+1}: expected {expected}")
        
        # Pack coordinates
        s1_packed = pack_coordinates(s1)
        s2_packed = pack_coordinates(s2)
        
        # Assign inputs
        dut.square1_coords.value = s1_packed
        dut.square2_coords.value = s2_packed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 20:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read result
        result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
        
        # Verify
        if result != expected:
            # Verify with Python reference
            ref_result = python_reference(s1, s2)
            if ref_result != expected:
                dut._log.error(f"Test {i+1}: Reference mismatch! Expected {expected}, got {ref_result}")
            else:
                dut._log.error(f"Test {i+1}: HDL mismatch! Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1}: PASS (result={result})")
            passed += 1
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{'='*40}")
    dut._log.info(f"Test Summary: {passed}/{len(test_cases)} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")