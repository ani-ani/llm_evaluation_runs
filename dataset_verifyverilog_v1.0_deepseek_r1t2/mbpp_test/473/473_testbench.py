import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_TUPLES = 4
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def normalize_tuple(a, b):
    """Normalize tuple (min, max) for order-independent comparison."""
    if a <= b:
        return (a, b)
    else:
        return (b, a)

async def reset_dut(dut):
    """Reset the DUT."""
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_intersection(dut):
    """Test tuple intersection function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (list1, list2, expected_matches_set, description)
    # Each list is list of tuples (a, b)
    test_cases = [
        (
            [(3, 4), (5, 6), (9, 10), (4, 5)],
            [(5, 4), (3, 4), (6, 5), (9, 11)],
            {(3, 4), (4, 5), (5, 6)},
            "Test 1: Basic order-independent matches"
        ),
        (
            [(4, 1), (7, 4), (11, 13), (17, 14)],
            [(1, 4), (7, 4), (16, 12), (10, 13)],
            {(1, 4), (4, 7)},
            "Test 2: Unsorted inputs"
        ),
        (
            [(2, 1), (3, 2), (1, 3), (1, 4)],
            [(11, 2), (2, 3), (6, 2), (1, 3)],
            {(1, 3), (2, 3)},
            "Test 3: Multiple matches"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, expected_set, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Clamp values to 8 bits and prepare inputs
            len1 = len(list1)
            len2 = len(list2)
            
            # Write list1
            for j, (a, b) in enumerate(list1):
                if j >= MAX_TUPLES:
                    break
                setattr(dut, f'list1_a_{j}', clamp_to_width(a, DATA_WIDTH))
                setattr(dut, f'list1_b_{j}', clamp_to_width(b, DATA_WIDTH))
            
            # Write list2
            for j, (a, b) in enumerate(list2):
                if j >= MAX_TUPLES:
                    break
                setattr(dut, f'list2_a_{j}', clamp_to_width(a, DATA_WIDTH))
                setattr(dut, f'list2_b_{j}', clamp_to_width(b, DATA_WIDTH))
            
            # Set lengths
            dut.len1.value = len1
            dut.len2.value = len2
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read results
            match_count = int(dut.match_count.value)
            
            # Read all possible matches
            matches = []
            for j in range(match_count):
                if j < MAX_TUPLES:
                    a = int(getattr(dut, f'match_a_{j}').value)
                    b = int(getattr(dut, f'match_b_{j}').value)
                    matches.append((a, b))
            
            # Convert to normalized set for comparison
            result_set = set(matches)
            
            if result_set != expected_set:
                raise TestFailure(f"Expected {expected_set}, got {result_set}")
            
            cocotb.log.info(f"  PASS: Found {match_count} matches: {matches}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
