import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# TEST CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER: Pack string into 128-bit integer
# ============================================================================
def pack_string(s):
    """Pack string into 128-bit integer (LSB = s[0])."""
    packed = 0
    for i, char in enumerate(s):
        packed |= (ord(char) << (i * 8))
    return packed

# ============================================================================
# HELPER: Compute expected winner vector
# ============================================================================
def compute_expected(s):
    """Compute expected winner vector using Python logic."""
    min_char = 'z'
    winner = 0
    for i, char in enumerate(s):
        if min_char < char:
            winner |= (1 << i)  # Ann wins at position i
        if char < min_char:
            min_char = char
    return winner

# ============================================================================
# RESET SEQUENCE
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

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_game_solver(dut):
    """Test the game_solver module with multiple test cases."""
    
    # Start clock
    clock = Clock(dut.clk, CLK_PERIOD_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string, description)
    test_cases = [
        ("abba", "Example 1: abba"),
        ("cba", "Example 2: cba"),
        ("a", "Single character"),
        ("abcdefghijklmnopqrstuvwxyz", "Full alphabet"),
        ("abacabadabacaba", "Alternating pattern"),
        ("z", "Single character 'z'"),
        ("xyyx", "Repeated pattern"),
        ("abcabcabc", "Repeated sequence"),
        ("mike", "Name test"),
        ("aaaa", "All same"),
    ]
    
    passed = 0
    failed = 0
    
    for s, description in test_cases:
        dut._log.info(f"Test: {description} (s='{s}')")
        
        # Skip if string too long for our scaled design
        if len(s) > 16:
            dut._log.warning(f"  SKIPPED: String length {len(s)} exceeds HDL limit of 16")
            continue
        
        # Prepare inputs
        packed_s = pack_string(s)
        len_val = len(s)
        expected_winner = compute_expected(s)
        
        # Apply inputs
        dut.packed_s.value = packed_s
        dut.len.value = len_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        done_found = False
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            dut._log.error(f"  FAIL: Timeout after {MAX_CYCLES} cycles")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.winner.value):
            dut._log.error("  FAIL: Winner output is undefined (X/Z)")
            failed += 1
            continue
            
        actual_winner = int(dut.winner.value)
        
        # Mask to valid length (only first len_val bits matter)
        mask = (1 << len_val) - 1
        actual_masked = actual_winner & mask
        expected_masked = expected_winner & mask
        
        # Check
        if actual_masked != expected_masked:
            dut._log.error(f"  FAIL: Expected {bin(expected_masked)}, got {bin(actual_masked)}")
            failed += 1
        else:
            dut._log.info(f"  PASS: winner={bin(actual_masked)}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")