import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools
from collections import Counter

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8          # Character width (ASCII)
GRID_SIZE = 12          # Maximum grid dimension
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# REFERENCE IMPLEMENTATION (Python)
# ============================================================================

def can_pair_rows(r1, r2, W):
    """Check if two rows can be paired by column swaps."""
    pairs = []
    for j in range(W):
        a, b = r1[j], r2[j]
        if a > b:
            a, b = b, a
        pairs.append((a, b))
    count = Counter(pairs)
    for (a, b), cnt in count.items():
        if a == b:
            if cnt % 2 != 0:
                if W % 2 == 0:
                    return False
                else:
                    # One middle column allowed
                    if cnt % 2 != 1:
                        return False
        else:
            if cnt % 2 != 0:
                return False
    return True

def can_pair_columns(grid, H, W):
    """Check if columns can be paired for symmetry."""
    col_vectors = []
    for j in range(W):
        vec = ''.join(chr(grid[i][j]) for i in range(H))
        col_vectors.append(vec)
    count = Counter(col_vectors)
    pairs_needed = W // 2
    middle_needed = W % 2
    for vec in list(count.keys()):
        if count[vec] == 0:
            continue
        rev = vec[::-1]
        if rev not in count:
            return False
        if vec == rev:
            if count[vec] % 2 != 0:
                if middle_needed:
                    middle_needed -= 1
                    count[vec] -= 1
                else:
                    return False
            pairs_needed -= count[vec] // 2
            count[vec] = 0
        else:
            if count[vec] != count[rev]:
                return False
            pairs_needed -= count[vec]
            count[vec] = 0
            count[rev] = 0
    return pairs_needed == 0 and middle_needed == 0

def generate_row_pairings(H):
    """Generate all row pairings for H rows."""
    rows = list(range(H))
    pairings = []
    
    def generate(used, current, unpaired):
        if all(used):
            if unpaired is None:
                pairings.append((current, None))
            else:
                pairings.append((current, unpaired))
            return
        i = used.index(False)
        used[i] = True
        for j in range(i+1, H):
            if not used[j]:
                used[j] = True
                generate(used, current + [(i, j)], unpaired)
                used[j] = False
        used[i] = False
    
    if H % 2 == 0:
        generate([False]*H, [], None)
    else:
        for unpaired in range(H):
            used = [False]*H
            used[unpaired] = True
            generate(used, [], unpaired)
    return pairings

def assign_rows(pair, H):
    """Assign rows to positions based on pairing."""
    grid_assignment = [None] * H
    pairs, unpaired = pair
    pos, end = 0, H-1
    for r, s in pairs:
        grid_assignment[pos] = r
        grid_assignment[end] = s
        pos += 1
        end -= 1
    if unpaired is not None:
        grid_assignment[H//2] = unpaired
    return grid_assignment

def can_make_symmetric(grid, H, W):
    """Reference implementation for symmetry check."""
    grid_int = [[ord(c) for c in row] for row in grid]
    for pair in generate_row_pairings(H):
        row_assign = assign_rows(pair, H)
        new_grid = [grid_int[row_assign[i]] for i in range(H)]
        if can_pair_columns(new_grid, H, W):
            return True
    return False

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_symmetry(dut):
    """Test the symmetry check module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (H, W, grid, expected)
    test_cases = [
        (2, 3, ['arc', 'rac'], True),
        (3, 7, ['atcoder', 'regular', 'contest'], False),
        (1, 1, ['a'], True),
        (2, 2, ['ab', 'ba'], True),
        (3, 3, ['dhh', 'dgz', 'dzg'], True),
        (4, 4, ['abcd', 'badc', 'cdab', 'dcba'], True),
        (4, 4, ['aaaa', 'bbbb', 'cccc', 'dddd'], False),
        (1, 12, ['fsdpzszppfpd'], True),  # Single row, any columns can be swapped
        (2, 2, ['aa', 'bb'], False),
        (3, 3, ['abc', 'def', 'ghi'], False),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (H, W, grid, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: H={H}, W={W}, grid={grid}, expected={expected}")
        
        # Verify with reference implementation
        reference_result = can_make_symmetric(grid, H, W)
        if reference_result != expected:
            cocotb.log.error(f"  Reference error: expected {expected}, got {reference_result}")
            failed += 1
            continue
        
        # Pad grid to 12x12 with zeros (ASCII 0 = NULL)
        full_grid = [[0]*GRID_SIZE for _ in range(GRID_SIZE)]
        for i in range(H):
            for j in range(W):
                full_grid[i][j] = ord(grid[i][j])
        
        # Assign grid to DUT
        for i in range(GRID_SIZE):
            for j in range(GRID_SIZE):
                if has_signal(dut, f'grid_{i}_{j}'):
                    getattr(dut, f'grid_{i}_{j}').value = full_grid[i][j]
                else:
                    # Fallback to 2D array
                    try:
                        dut.grid[i][j].value = full_grid[i][j]
                    except:
                        pass
        
        # Assign H and W
        dut.H.value = H
        dut.W.value = W
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined")
        
        result = int(dut.result.value) == 1
        
        if result == expected:
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")