import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_SHOWS = 8
MAX_MACHINES = 4
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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
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

async def write_shows(dut, start_times, end_times, n):
    """Write show data to DUT."""
    # Write n and k first
    dut.n.value = n
    
    # Write start and end times
    for i in range(MAX_SHOWS):
        if i < n:
            dut.start_times[i].value = clamp_to_width(start_times[i], DATA_WIDTH)
            dut.end_times[i].value = clamp_to_width(end_times[i], DATA_WIDTH)
        else:
            dut.start_times[i].value = 0
            dut.end_times[i].value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tv_recorder(dut):
    """Main test for TV recorder scheduler."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (k, shows, expected_count, description)
    # Shows are list of (start, end) tuples
    test_cases = [
        # Sample Input 1: 3 shows, 1 machine
        (1, [(1, 2), (2, 3), (2, 3)], 2, "Sample 1: 3 shows, 1 machine"),
        
        # Sample Input 2: 4 shows, 1 machine  
        (1, [(1, 3), (4, 6), (7, 8), (2, 5)], 3, "Sample 2: 4 shows, 1 machine"),
        
        # Additional test: 5 shows, 2 machines
        (2, [(1, 4), (5, 9), (2, 7), (3, 8), (6, 10)], 3, "5 shows, 2 machines"),
        
        # Test with all shows non-overlapping
        (1, [(1, 2), (3, 4), (5, 6), (7, 8)], 4, "Non-overlapping shows"),
        
        # Test with all shows overlapping
        (1, [(1, 10), (2, 11), (3, 12), (4, 13)], 1, "All overlapping shows"),
        
        # Test with k=2
        (2, [(1, 3), (2, 4), (3, 5), (4, 6)], 4, "k=2, chain of shows"),
        
        # Test with exact boundaries
        (1, [(0, 5), (5, 10), (10, 15)], 3, "Exact boundary matches"),
        
        # Test with more machines than needed
        (3, [(1, 2), (3, 4), (5, 6)], 3, "More machines than shows"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, shows, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Shows: {shows}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Prepare test data
            n = len(shows)
            start_times = [s[0] for s in shows]
            end_times = [s[1] for s in shows]
            
            # Write k
            dut.k.value = k
            
            # Write shows
            await write_shows(dut, start_times, end_times, n)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.count.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test with single show
    dut.k.value = 1
    dut.n.value = 1
    dut.start_times[0].value = 1
    dut.end_times[0].value = 2
    for i in range(1, MAX_SHOWS):
        dut.start_times[i].value = 0
        dut.end_times[i].value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.count.value)
    if result != 1:
        raise TestFailure(f"Single show test failed: expected 1, got {result}")
    
    cocotb.log.info("Single show test: PASS")
    
    # Test with k=0 (edge case, though problem says k>=1)
    # Our design should handle this gracefully
    dut.k.value = 0
    dut.n.value = 2
    dut.start_times[0].value = 1
    dut.end_times[0].value = 2
    dut.start_times[1].value = 3
    dut.end_times[1].value = 4
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.count.value)
    if result != 0:
        raise TestFailure(f"k=0 test failed: expected 0, got {result}")
    
    cocotb.log.info("k=0 test: PASS")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_large_times(dut):
    """Test with large time values (within 16-bit range)."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test with large but fitting times
    dut.k.value = 2
    dut.n.value = 3
    
    # Show 1: 10000-20000
    dut.start_times[0].value = 10000
    dut.end_times[0].value = 20000
    
    # Show 2: 15000-25000 (overlaps with 1)
    dut.start_times[1].value = 15000
    dut.end_times[1].value = 25000
    
    # Show 3: 20000-30000 (overlaps with 2 but not 1)
    dut.start_times[2].value = 20000
    dut.end_times[2].value = 30000
    
    for i in range(3, MAX_SHOWS):
        dut.start_times[i].value = 0
        dut.end_times[i].value = 0
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.count.value)
    # With k=2, we should get all 3 shows
    if result != 3:
        raise TestFailure(f"Large times test failed: expected 3, got {result}")
    
    cocotb.log.info(f"Large times test: PASS (result={result})")