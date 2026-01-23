import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4  # Number of rows
M = 4  # Number of columns
DATA_WIDTH = 4  # Bits per element
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000  # Allow enough cycles for state machine

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_table(table):
    """Pack 2D table into packed array for HDL input."""
    result = 0
    for i in range(N):
        for j in range(M):
            value = clamp_to_width(table[i][j], DATA_WIDTH)
            pos = (i * M + j) * DATA_WIDTH
            result |= value << pos
    return result

def unpack_table(packed):
    """Unpack packed array into 2D table for verification."""
    table = []
    for i in range(N):
        row = []
        for j in range(M):
            pos = (i * M + j) * DATA_WIDTH
            value = (packed >> pos) & ((1 << DATA_WIDTH) - 1)
            row.append(value)
        table.append(row)
    return table

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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
# REFERENCE IMPLEMENTATION
# ============================================================================

def reference_check(table):
    """Reference Python implementation of the algorithm."""
    n, m = N, M
    
    def is_row_fixable(row, target):
        mismatches = []
        for idx in range(m):
            if row[idx] != target[idx]:
                mismatches.append(idx)
        if len(mismatches) == 0:
            return True
        if len(mismatches) == 2:
            i, j = mismatches
            return row[i] == target[j] and row[j] == target[i]
        return False
    
    identity = list(range(1, m+1))
    
    # Try all column swaps
    for i in range(m):
        for j in range(i, m):
            # Option A: column swap then row swaps to identity
            T1 = [row[:] for row in table]
            for r in T1:
                r[i], r[j] = r[j], r[i]
            if all(is_row_fixable(row, identity) for row in T1):
                return 1
            
            # Option B: row swaps then column swap
            target_swapped = identity[:]
            target_swapped[i], target_swapped[j] = target_swapped[j], target_swapped[i]
            if all(is_row_fixable(row, target_swapped) for row in table):
                return 1
    
    return 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_table_sort_check(dut):
    """Main test function for table_sort_check module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (table, expected_result, description)
    # Tables are N x M arrays
    test_cases = [
        # Test 1: Already sorted
        (
            [[1,2,3,4], [1,2,3,4], [1,2,3,4], [1,2,3,4]],
            1,
            "Already sorted"
        ),
        # Test 2: Simple row swaps needed
        (
            [[1,3,2,4], [1,3,4,2], [1,2,3,4], [1,2,3,4]],
            1,
            "Row swaps only"
        ),
        # Test 3: Column swap needed (from problem examples)
        (
            [[1,3,2,4], [1,3,4,2], [1,2,3,4], [1,2,3,4]],
            1,
            "Column swap + row swaps"
        ),
        # Test 4: Impossible case
        (
            [[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]],
            0,
            "Impossible - too many misplacements"
        ),
        # Test 5: Mixed case with column swap
        (
            [[2,1,3,4], [1,2,4,3], [1,2,3,4], [1,2,3,4]],
            1,
            "Mixed column and row swaps"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (table, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {description}")
        
        try:
            # Pack table into input
            packed_input = pack_table(table)
            
            # Verify packing
            unpacked = unpack_table(packed_input)
            if unpacked != table:
                raise TestFailure(f"Packing verification failed: {unpacked} != {table}")
            
            # Set input
            dut.table_in.value = packed_input
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")