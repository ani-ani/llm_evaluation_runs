import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper to convert float to Q16.16 fixed-point
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper to calculate broom tip coordinates
def calculate_tip(x, y, r):
    tip_x = x + math.cos(r)
    tip_y = y + math.sin(r)
    return tip_x, tip_y

# Check if two line segments intersect
def segments_intersect(p1, q1, p2, q2):
    def orient(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])
    
    o1 = orient(p1, q1, p2)
    o2 = orient(p1, q1, q2)
    o3 = orient(p2, q2, p1)
    o4 = orient(p2, q2, q1)
    
    # Check for general case
    if (o1 * o2 < 0) and (o3 * o4 < 0):
        return True
    
    # Check for collinear cases (on segment)
    if o1 == 0 and on_segment(p1, p2, q1): return True
    if o2 == 0 and on_segment(p1, q2, q1): return True
    if o3 == 0 and on_segment(p2, p1, q2): return True
    if o4 == 0 and on_segment(p2, q1, q2): return True
    
    return False

def on_segment(a, b, c):
    return min(a[0], c[0]) <= b[0] <= max(a[0], c[0]) and \
           min(a[1], c[1]) <= b[1] <= max(a[1], c[1])

@cocotb.test()
async def test_witch_collision(dut):
    """Test witch broom collision detection"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x0.value = 0; dut.y0.value = 0; dut.r0.value = 0
    dut.x1.value = 0; dut.y1.value = 0; dut.r1.value = 0
    dut.x2.value = 0; dut.y2.value = 0; dut.r2.value = 0
    dut.x3.value = 0; dut.y3.value = 0; dut.r3.value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test 1: No collision (sample input 1)
        {
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 0.0, 'y': 1.5, 'r': 0.0},
                {'x': 10.0, 'y': 0.0, 'r': 0.0},  # Far away
                {'x': 10.0, 'y': 10.0, 'r': 0.0}, # Far away
            ],
            'expected_crash': False
        },
        # Test 2: Collision (sample input 2 - brooms cross)
        {
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 0.0, 'y': 1.5, 'r': math.pi},  # Rotated left
                {'x': 10.0, 'y': 0.0, 'r': 0.0},
                {'x': 10.0, 'y': 10.0, 'r': 0.0},
            ],
            'expected_crash': True
        },
        # Test 3: Collinear but not overlapping
        {
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 5.0, 'y': 0.0, 'r': 0.0},
                {'x': 10.0, 'y': 0.0, 'r': 0.0},
                {'x': 15.0, 'y': 0.0, 'r': 0.0},
            ],
            'expected_crash': False  # Parallel, no intersection
        },
        # Test 4: Touching at pivot points
        {
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 0.0, 'y': 0.0, 'r': math.pi/2},  # Same pivot!
                {'x': 10.0, 'y': 0.0, 'r': 0.0},
                {'x': 10.0, 'y': 10.0, 'r': 0.0},
            ],
            'expected_crash': True  # Same pivot = collision
        },
        # Test 5: Perpendicular crossing
        {
            'witches': [
                {'x': 0.0, 'y': 0.5, 'r': 0.0},    # Points right from (0,0.5)
                {'x': 0.5, 'y': 0.0, 'r': math.pi/2}, # Points up from (0.5,0)
                {'x': 10.0, 'y': 0.0, 'r': 0.0},
                {'x': 10.0, 'y': 10.0, 'r': 0.0},
            ],
            'expected_crash': True
        },
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"
Test {i+1}: {tc['witches'][:2]}")
        
        # Set inputs
        for j in range(4):
            w = tc['witches'][j]
            setattr(dut, f'x{j}', float_to_q16_16(w['x']))
            setattr(dut, f'y{j}', float_to_q16_16(w['y']))
            setattr(dut, f'r{j}', float_to_q16_16(w['r']))
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  FAILED: Timeout waiting for done")
            continue
        
        # Check result
        crash = bool(dut.crash.value)
        expected = tc['expected_crash']
        
        if crash == expected:
            print(f"  PASSED: crash={crash}, expected={expected}")
            passed += 1
        else:
            print(f"  FAILED: crash={crash}, expected={expected}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
