import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000  # Large enough for 65536 subsets * 560 triangles

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
    return min(max_val, max(0, value))

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION (4x4 board)
# ============================================================================

def compute_max_queens_4x4(broken_mask):
    """
    Compute max queens and number of ways for a 4x4 board.
    broken_mask: 16-bit integer, 1=broken cell.
    Returns (max_queens, num_ways).
    """
    # Precompute attack matrix and triangle table
    board_size = 4
    cells = list(range(16))
    # Attack relation: True if two cells attack each other
    attack = [[False]*16 for _ in range(16)]
    for i in cells:
        for j in cells:
            if i == j:
                continue
            r1, c1 = i // board_size, i % board_size
            r2, c2 = j // board_size, j % board_size
            if r1 == r2 or c1 == c2 or abs(r1 - r2) == abs(c1 - c2):
                attack[i][j] = True
    # Triangle table: list of masks where three cells pairwise attack
    triangle_masks = []
    for i, j, k in itertools.combinations(cells, 3):
        if attack[i][j] and attack[j][k] and attack[k][i]:
            mask = (1 << i) | (1 << j) | (1 << k)
            triangle_masks.append(mask)
    # Enumerate subsets
    max_q = 0
    ways = 0
    for subset in range(1 << 16):
        # Skip if intersects broken
        if subset & broken_mask:
            continue
        # Check triangle
        valid = True
        for tm in triangle_masks:
            if (subset & tm) == tm:
                valid = False
                break
        if not valid:
            continue
        # Count queens
        cnt = bin(subset).count('1')
        if cnt > max_q:
            max_q = cnt
            ways = 1
        elif cnt == max_q:
            ways += 1
    return max_q, ways

# ============================================================================
# COCOTB TEST
# ============================================================================

@cocotb.test(timeout_time=30000, timeout_unit="ms")
async def test_max_queens_4x4(dut):
    """Test the 4x4 max queens module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases: broken_mask (16-bit) and expected result
    # Sample 1: 3x4 board embedded in 4x4 with 4th row broken
    # Original board:
    # ....
    # .#.#
    # ....
    # Broken row added: ####
    # Broken mask: bits for broken cells
    # Let's compute manually or use Python function
    
    # Test case 1: 3x4 with broken cells at (1,1) and (1,3) in 0-indexed rows
    # In 4x4: rows 0,1,2 are used; row3 is all broken.
    # Broken cells: row3 all 4 bits, plus row1 col1 and row1 col3.
    # Convert to bit indices: row0: 0-3, row1:4-7, row2:8-11, row3:12-15
    broken1 = 0
    # Row3 all broken: bits 12-15
    for b in range(12, 16):
        broken1 |= (1 << b)
    # Row1 col1: index = 4+1 = 5
    broken1 |= (1 << 5)
    # Row1 col3: index = 4+3 = 7
    broken1 |= (1 << 7)
    expected1 = compute_max_queens_4x4(broken1)
    
    # Test case 2: 4x4 full board, no broken cells
    broken2 = 0
    expected2 = compute_max_queens_4x4(broken2)
    
    test_cases = [
        (broken1, expected1, "3x4 board with broken cells"),
        (broken2, expected2, "4x4 full board"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (broken, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Write broken input
        if is_sequential:
            # Assuming broken is a 16-bit input signal
            dut.broken.value = broken
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            cycles = 0
            while True:
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            # Read results
            max_q = int(dut.max_queens.value)
            ways = int(dut.num_ways.value)
        else:
            # Combinational module: set inputs and wait
            dut.broken.value = broken
            await Timer(100, units='ns')
            max_q = int(dut.max_queens.value)
            ways = int(dut.num_ways.value)
        
        # Compare
        if max_q != expected[0] or ways != expected[1]:
            cocotb.log.error(f"  FAIL: expected ({expected[0]}, {expected[1]}), got ({max_q}, {ways})")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: max={max_q}, ways={ways}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")