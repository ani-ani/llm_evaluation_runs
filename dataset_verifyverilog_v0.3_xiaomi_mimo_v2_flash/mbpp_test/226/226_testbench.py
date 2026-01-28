import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_STRING_LEN = 16
MAX_RESULT_LEN = 8
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

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

async def write_string_to_dut(dut, test_string):
    """Write string to DUT input array."""
    # Pad or truncate to MAX_STRING_LEN
    chars = list(test_string)
    if len(chars) > MAX_STRING_LEN:
        chars = chars[:MAX_STRING_LEN]
    
    # Write characters individually
    for i in range(MAX_STRING_LEN):
        if i < len(chars):
            dut.str[i].value = ord(chars[i])
        else:
            dut.str[i].value = 0
    
    # Write length
    dut.len.value = len(chars)

async def read_result_from_dut(dut):
    """Read result from DUT output array."""
    # Read result length
    result_len = int(dut.result_len.value)
    
    # Read result characters
    result_chars = []
    for i in range(min(result_len, MAX_RESULT_LEN)):
        if is_value_defined(dut.result[i].value):
            char_val = int(dut.result[i].value)
            if char_val != 0:
                result_chars.append(chr(char_val))
    
    return ''.join(result_chars), result_len

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_odd_values_string(dut):
    """Test the odd_values_string module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_output, description)
    test_cases = [
        ('abcdef', 'ace', "Test 1: 6-char string"),
        ('python', 'pto', "Test 2: 6-char string"),
        ('data', 'dt', "Test 3: 4-char string"),
        ('lambs', 'lms', "Test 4: 5-char string"),
        ('', '', "Test 5: Empty string"),
        ('a', 'a', "Test 6: Single character"),
        ('ab', 'a', "Test 7: Two characters"),
        ('abcdefgh', 'aceg', "Test 8: Full 8-char input"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}'")
        cocotb.log.info(f"  Expected: '{expected}'")
        
        try:
            # Write input
            await write_string_to_dut(dut, input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result, result_len = await read_result_from_dut(dut)
            
            cocotb.log.info(f"  Got: '{result}' (length {result_len})")
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            # Also verify result length matches
            if result_len != len(expected):
                raise TestFailure(f"Length mismatch: expected {len(expected)}, got {result_len}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
