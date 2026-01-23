import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_N = 8
MAX_M = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def python_reference(n, hints):
    """
    Python reference for the hint counting problem.
    hints: list of (l, r, type) where type is 0 for same, 1 for different
    """
    count = 0
    for seq in range(2**n):
        valid = True
        for (l, r, type_hint) in hints:
            # Extract bits from l-1 to r-1 (0-indexed)
            bits = (seq >> (l-1)) & ((1 << (r-l+1)) - 1)
            
            if type_hint == 0:  # same
                # Check if all 0 or all 1
                all_0 = (bits == 0)
                all_1 = (bits == ((1 << (r-l+1)) - 1))
                if not (all_0 or all_1):
                    valid = False
                    break
            else:  # different
                # Check if NOT(all 0 OR all 1)
                all_0 = (bits == 0)
                all_1 = (bits == ((1 << (r-l+1)) - 1))
                if all_0 or all_1:
                    valid = False
                    break
        if valid:
            count += 1
    return count % 1000000007

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_hint_counter(dut):
    """Main test function for HintCounter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Sample 1
    # n=5, m=2, hints: [2,4] same, [3,5] same
    # Expected output: 4
    n1 = 5
    m1 = 2
    hints1 = [(2, 4, 0), (3, 5, 0)]
    expected1 = python_reference(n1, hints1)
    
    cocotb.log.info(f"Test case 1: n={n1}, m={m1}, expected={expected1}")
    
    dut.n.value = n1
    dut.m.value = m1
    
    # Set hints
    for i, (l, r, t) in enumerate(hints1):
        getattr(dut, f'l_{i}').value = l
        getattr(dut, f'r_{i}').value = r
        getattr(dut, f'type_{i}').value = t
    
    # Clear remaining hints
    for i in range(m1, 4):
        getattr(dut, f'l_{i}').value = 0
        getattr(dut, f'r_{i}').value = 0
        getattr(dut, f'type_{i}').value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result1 = int(dut.result.value)
    cocotb.log.info(f"Result: {result1}")
    
    if result1 != expected1:
        raise TestFailure(f"Test case 1 failed: expected {expected1}, got {result1}")
    
    cocotb.log.info("Test case 1: PASS")
    
    # Test case 2: Sample 2
    # n=5, m=3, hints: [1,3] same, [2,5] same, [1,5] different
    # Expected output: 0
    n2 = 5
    m2 = 3
    hints2 = [(1, 3, 0), (2, 5, 0), (1, 5, 1)]
    expected2 = python_reference(n2, hints2)
    
    cocotb.log.info(f"Test case 2: n={n2}, m={m2}, expected={expected2}")
    
    await reset_dut(dut)
    
    dut.n.value = n2
    dut.m.value = m2
    
    for i, (l, r, t) in enumerate(hints2):
        getattr(dut, f'l_{i}').value = l
        getattr(dut, f'r_{i}').value = r
        getattr(dut, f'type_{i}').value = t
    
    for i in range(m2, 4):
        getattr(dut, f'l_{i}').value = 0
        getattr(dut, f'r_{i}').value = 0
        getattr(dut, f'type_{i}').value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result2 = int(dut.result.value)
    cocotb.log.info(f"Result: {result2}")
    
    if result2 != expected2:
        raise TestFailure(f"Test case 2 failed: expected {expected2}, got {result2}")
    
    cocotb.log.info("Test case 2: PASS")
    
    # Test case 3: Edge case - no hints
    # n=3, m=0, expected: 2^3 = 8
    n3 = 3
    m3 = 0
    expected3 = 2**n3
    
    cocotb.log.info(f"Test case 3: n={n3}, m={m3}, expected={expected3}")
    
    await reset_dut(dut)
    
    dut.n.value = n3
    dut.m.value = m3
    
    for i in range(4):
        getattr(dut, f'l_{i}').value = 0
        getattr(dut, f'r_{i}').value = 0
        getattr(dut, f'type_{i}').value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result3 = int(dut.result.value)
    cocotb.log.info(f"Result: {result3}")
    
    if result3 != expected3:
        raise TestFailure(f"Test case 3 failed: expected {expected3}, got {result3}")
    
    cocotb.log.info("Test case 3: PASS")
    
    # Test case 4: Conflict - same range with same and different
    # n=3, m=2, [1,2] same, [1,2] different, expected: 0
    n4 = 3
    m4 = 2
    hints4 = [(1, 2, 0), (1, 2, 1)]
    expected4 = python_reference(n4, hints4)
    
    cocotb.log.info(f"Test case 4: n={n4}, m={m4}, expected={expected4}")
    
    await reset_dut(dut)
    
    dut.n.value = n4
    dut.m.value = m4
    
    for i, (l, r, t) in enumerate(hints4):
        getattr(dut, f'l_{i}').value = l
        getattr(dut, f'r_{i}').value = r
        getattr(dut, f'type_{i}').value = t
    
    for i in range(m4, 4):
        getattr(dut, f'l_{i}').value = 0
        getattr(dut, f'r_{i}').value = 0
        getattr(dut, f'type_{i}').value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result4 = int(dut.result.value)
    cocotb.log.info(f"Result: {result4}")
    
    if result4 != expected4:
        raise TestFailure(f"Test case 4 failed: expected {expected4}, got {result4}")
    
    cocotb.log.info("Test case 4: PASS")
    
    cocotb.log.info("All tests passed!")
