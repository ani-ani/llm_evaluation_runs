import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SEGMENTS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
MOD = 1000000007

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
    return min(max_val, max(0, value))

# ============================================================================
# TEST HELPER FUNCTIONS
# ============================================================================

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
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def parse_board(s1, s2):
    """
    Parse board strings and return segment types.
    Returns (segment_types_list, num_segments)
    segment_types_list: list of 0 (X) or 1 (Y)
    """
    n = len(s1)
    segments = []
    i = 0
    
    while i < n:
        if s1[i] == s2[i]:
            # Vertical domino (X)
            segments.append(0)
            i += 1
        else:
            # Horizontal segment (Y) - covers this column and next
            segments.append(1)
            i += 2
    
    return segments, len(segments)

def pack_types(segments):
    """Pack segment types into 8-bit vector."""
    result = 0
    for i, seg_type in enumerate(segments):
        if seg_type == 1:
            result |= (1 << i)
    return result

def calculate_expected(s1, s2):
    """Calculate expected result using Python."""
    segments, num_segs = parse_board(s1, s2)
    
    if num_segs == 0:
        return 0
    
    if segments[0] == 0:
        ans = 3
    else:
        ans = 6
    
    for i in range(1, num_segs):
        if segments[i-1] == 0 and segments[i] == 0:
            ans = (ans * 2) % MOD
        elif segments[i-1] == 0 and segments[i] == 1:
            ans = (ans * 2) % MOD
        elif segments[i-1] == 1 and segments[i] == 0:
            ans = (ans * 1) % MOD
        elif segments[i-1] == 1 and segments[i] == 1:
            ans = (ans * 3) % MOD
    
    return ans

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_domino_coloring(dut):
    """Test the domino coloring module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (S1, S2, expected_result, description)
    test_cases = [
        ("aab", "ccb", 6, "Sample: N=3, Y-X"),
        ("Z", "Z", 3, "Single vertical (X)"),
        ("X", "X", 3, "Single vertical (X)"),
        ("abc", "abc", 12, "Three vertical (X-X-X)"),
        ("aabb", "ccdd", 18, "Two horizontal (Y-Y)"),
        ("aba", "cbc", 12, "X-Y-X"),
        ("abb", "cbb", 6, "X-Y"),
        ("aa", "bb", 6, "Single horizontal (Y)"),
        ("abcd", "abcd", 48, "Four vertical (X-X-X-X)"),
        ("aabbcc", "ddeeff", 108, "Three horizontal (Y-Y-Y)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s1, s2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Skip if lengths exceed our max
        if len(s1) > 8 or len(s2) > 8:
            cocotb.log.warning(f"  Skipping: length {len(s1)} exceeds MAX=8")
            continue
        
        try:
            # Parse board
            segments, num_segments = parse_board(s1, s2)
            
            # Pack types
            packed_types = pack_types(segments)
            
            cocotb.log.info(f"  Segments: {segments}, Packed: {packed_types:08b}, Count: {num_segments}")
            
            # Apply inputs
            dut.segment_types.value = packed_types
            dut.num_segments.value = num_segments
            
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
    cocotb.log.info("=" * 50)
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")