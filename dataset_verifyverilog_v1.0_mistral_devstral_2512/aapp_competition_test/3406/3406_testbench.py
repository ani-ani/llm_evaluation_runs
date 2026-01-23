import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_castle_danger(dut):
    """Test castle danger detection module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Case 1: Square, castle INSIDE (CCW orientation)
        {
            'points': [(0, 0), (10, 0), (10, 10), (0, 10)],
            'castle': (5, 5),
            'expected': True,
            'description': 'Square, castle at center'
        },
        # Case 2: Square, castle OUTSIDE
        {
            'points': [(0, 0), (10, 0), (10, 10), (0, 10)],
            'castle': (15, 15),
            'expected': False,
            'description': 'Square, castle outside'
        },
        # Case 3: Degenerate quadrilateral (3 collinear)
        {
            'points': [(0, 0), (5, 0), (10, 0), (5, 10)],
            'castle': (5, 5),
            'expected': False,
            'description': 'Degenerate, three collinear points'
        },
        # Case 4: Castle on border
        {
            'points': [(0, 0), (10, 0), (10, 10), (0, 10)],
            'castle': (5, 0),
            'expected': True,
            'description': 'Square, castle on bottom edge'
        },
        # Case 5: Irregular convex quadrilateral, inside
        {
            'points': [(2, 2), (8, 3), (6, 8), (3, 6)],
            'castle': (4, 5),
            'expected': True,
            'description': 'Irregular quadrilateral, inside'
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {test['description']}")
        
        try:
            points = test['points']
            castle = test['castle']
            
            # Write individual signals (following RULE B2)
            dut.p0_x.value = clamp_to_width(points[0][0], DATA_WIDTH)
            dut.p0_y.value = clamp_to_width(points[0][1], DATA_WIDTH)
            dut.p1_x.value = clamp_to_width(points[1][0], DATA_WIDTH)
            dut.p1_y.value = clamp_to_width(points[1][1], DATA_WIDTH)
            dut.p2_x.value = clamp_to_width(points[2][0], DATA_WIDTH)
            dut.p2_y.value = clamp_to_width(points[2][1], DATA_WIDTH)
            dut.p3_x.value = clamp_to_width(points[3][0], DATA_WIDTH)
            dut.p3_y.value = clamp_to_width(points[3][1], DATA_WIDTH)
            
            dut.castle_x.value = clamp_to_width(castle[0], DATA_WIDTH)
            dut.castle_y.value = clamp_to_width(castle[1], DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.danger.value):
                raise TestFailure("Danger signal is undefined (X/Z)")
            
            result = bool(int(dut.danger.value))
            expected = test['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: danger={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")