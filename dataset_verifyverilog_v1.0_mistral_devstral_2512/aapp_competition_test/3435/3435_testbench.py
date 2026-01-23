import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_N = 8
MAX_M = 6
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# PATTERN ENCODING HELPERS
# ============================================================================

def encode_pattern(pattern_str, max_m=MAX_M):
    """Convert pattern string to pattern_len and pattern_mask."""
    pattern_len = len(pattern_str)
    pattern_mask = 0
    for i, char in enumerate(pattern_str):
        if char == '1':
            pattern_mask |= (1 << i)
    return pattern_len, pattern_mask

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_spy_id_counter(dut):
    """Test the SpyIDCounter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, pattern_str, expected_result, description)
    # Scaled down from original problem
    test_cases = [
        # Original example scaled: n=10, pattern="1" -> 1023
        # Scaled: n=8, pattern="1" -> 2^8 - 1 = 255
        (8, "1", 255, "n=8, pattern='1': all strings with at least one 1"),
        
        # Original example: n=3, pattern="1*1" -> 2
        (3, "1*1", 2, "n=3, pattern='1*1': strings 101, 111"),
        
        # Additional test cases
        (4, "1", 15, "n=4, pattern='1': 2^4 - 1 = 15"),
        (2, "11", 1, "n=2, pattern='11' (m=n): only '11' matches"),
        (5, "10*1", 4, "n=5, pattern='10*1' (m=4): substrings with 1 at pos 0,3, 0 at pos 1"),
        (6, "1**1", 15, "n=6, pattern='1**1' (m=4): wildcards at pos 1,2"),
        (3, "1*1*1", 0, "n=3, pattern='1*1*1' (m=5>3): no matches"),
        (4, "1*1*", 6, "n=4, pattern='1*1*' (m=4): matches at pos 0 only"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, pattern_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: n={n_val}, pattern='{pattern_str}'")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Encode pattern
            pattern_len, pattern_mask = encode_pattern(pattern_str)
            
            # Set inputs
            dut.n.value = n_val
            dut.pattern_len.value = pattern_len
            dut.pattern_mask.value = pattern_mask
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
