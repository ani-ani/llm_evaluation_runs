import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 6        # Thickness bits (5-30 fits in 6)
HEIGHT_WIDTH = 9      # Height bits (150-300 fits in 9)
RESULT_WIDTH = 20     # Result bits
CLK_PERIOD_NS = 10
MAX_CYCLES = 8000     # 3^8 + overhead

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_books(dut, books):
    """Write books to individual ports, handling width clamping."""
    for i, (h, t) in enumerate(books):
        if i >= 8:
            break
        # Clamp to fit signal widths
        h_clamped = clamp_to_width(h, HEIGHT_WIDTH)
        t_clamped = clamp_to_width(t, DATA_WIDTH)
        
        # Access individual ports
        port_h = getattr(dut, f'h{i}')
        port_t = getattr(dut, f't{i}')
        port_h.value = h_clamped
        port_t.value = t_clamped
    
    # Write book count
    dut.book_count.value = len(books)

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
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

# ============================================================================
# REFERENCE COMPUTATION
# ============================================================================

def compute_expected(books):
    """Compute minimum area using brute force (Python reference)."""
    n = len(books)
    if n < 3:
        return 0
    
    best = float('inf')
    
    # Iterate through all 3^n assignments
    for assignment in range(3**n):
        # Decode assignment
        shelves = [[], [], []]
        temp = assignment
        for i in range(n):
            shelf = temp % 3
            shelves[shelf].append(books[i])
            temp //= 3
        
        # Check all shelves non-empty
        if any(len(s) == 0 for s in shelves):
            continue
        
        # Compute metrics
        max_height = [max(h for h, t in s) if s else 0 for s in shelves]
        sum_thickness = [sum(t for h, t in s) if s else 0 for s in shelves]
        
        total_height = sum(max_height)
        max_width = max(sum_thickness)
        area = total_height * max_width
        
        if area < best:
            best = area
    
    return int(best)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bookcase_optimizer(dut):
    """Test bookcase optimizer with scaled inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases (scaled to N <= 8)
    test_cases = [
        {
            "books": [(220, 29), (195, 20), (200, 9), (180, 30)],
            "description": "Sample 1: N=4"
        },
        {
            "books": [(256, 20), (255, 30), (254, 15), (253, 20), (252, 15), (251, 9)],
            "description": "Sample 2: N=6"
        },
        {
            "books": [(200, 10), (200, 10), (200, 10)],
            "description": "Edge: N=3, identical books"
        },
        {
            "books": [(150, 5), (300, 30), (200, 15)],
            "description": "Edge: N=3, extreme values"
        },
        {
            "books": [(200, 10), (200, 10), (200, 10), (200, 10), (200, 10), 
                      (200, 10), (200, 10), (200, 10)],
            "description": "Max: N=8, identical"
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test_case in enumerate(test_cases):
        books = test_case["books"]
        description = test_case["description"]
        
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        cocotb.log.info(f"  Books: {books}")
        
        try:
            # Compute expected value in Python
            expected = compute_expected(books)
            cocotb.log.info(f"  Expected: {expected}")
            
            # Write books to DUT
            await write_books(dut, books)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.min_area.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.min_area.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: min_area = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
