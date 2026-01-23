import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4  # 0-15 for coordinates
MAX_RECTS = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'rect_valid'):
        dut.rect_valid.value = 0
    
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

async def start_computation(dut, n):
    """Pulse start signal and set n for one cycle."""
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def send_rectangle(dut, x1, y1, x2, y2):
    """Send one rectangle to the DUT."""
    dut.rect_x1.value = x1
    dut.rect_y1.value = y1
    dut.rect_x2.value = x2
    dut.rect_y2.value = y2
    dut.rect_valid.value = 1
    await RisingEdge(dut.clk)
    dut.rect_valid.value = 0

# ============================================================================
# TEST CASES
# ============================================================================

def compute_expected_area(rectangles):
    """Compute expected area using grid method (same as hardware)."""
    grid = [[0] * 16 for _ in range(16)]
    for (x1, y1, x2, y2) in rectangles:
        for x in range(x1, x2):
            for y in range(y1, y2):
                grid[x][y] = 1
    area = sum(sum(row) for row in grid)
    return area

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_land_area(dut):
    """Test the land_area module with scaled-down problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: list of rectangles and expected area
    test_cases = [
        # Case 1: Two non-overlapping rectangles (total area = 100)
        {
            'rectangles': [(0, 0, 10, 10), (10, 10, 15, 15)],
            'expected': 100,
            'description': 'Two non-overlapping rectangles'
        },
        # Case 2: Two overlapping rectangles (total area = 100, overlaps 9 cells)
        {
            'rectangles': [(0, 0, 10, 10), (3, 3, 6, 6)],
            'expected': 100,
            'description': 'Two overlapping rectangles'
        },
        # Case 3: One rectangle
        {
            'rectangles': [(5, 5, 10, 10)],
            'expected': 25,
            'description': 'Single rectangle'
        },
        # Case 4: Three rectangles forming a chain
        {
            'rectangles': [(0, 0, 5, 5), (3, 3, 8, 8), (6, 6, 12, 12)],
            'expected': 100,
            'description': 'Three overlapping rectangles'
        },
        # Case 5: Four rectangles, one inside another
        {
            'rectangles': [(0, 0, 15, 15), (2, 2, 13, 13), (4, 4, 11, 11), (6, 6, 9, 9)],
            'expected': 225,
            'description': 'Nested rectangles'
        },
        # Case 6: All zeros (edge case)
        {
            'rectangles': [(0, 0, 1, 1)],
            'expected': 1,
            'description': 'Minimal rectangle'
        },
        # Case 7: Empty grid (n=0, but problem says n>0, so skip)
        # Case 8: Full grid coverage
        {
            'rectangles': [(0, 0, 16, 16)],
            'expected': 256,
            'description': 'Full grid'
        },
        # Case 9: Multiple small rectangles
        {
            'rectangles': [(1, 1, 3, 3), (5, 5, 7, 7), (9, 9, 11, 11), (13, 13, 15, 15)],
            'expected': 16,
            'description': 'Four small non-overlapping rectangles'
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test_case in enumerate(test_cases):
        rectangles = test_case['rectangles']
        expected = test_case['expected']
        description = test_case['description']
        
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Rectangles: {rectangles}")
        cocotb.log.info(f"  Expected area: {expected}")
        
        try:
            n = len(rectangles)
            
            # Start computation with n rectangles
            await start_computation(dut, n)
            
            # Send all rectangles
            for rect in rectangles:
                x1, y1, x2, y2 = rect
                await send_rectangle(dut, x1, y1, x2, y2)
            
            # Wait for computation to complete
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.area.value):
                raise TestFailure(f"Area is undefined (X/Z)")
            
            result = int(dut.area.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: area = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")