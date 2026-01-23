import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ASCII values for vowels
VOWELS = {'a': 97, 'e': 101, 'i': 105, 'o': 111, 'u': 117}

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

def char_to_ascii(c):
    """Convert character to ASCII value."""
    return ord(c)

def is_vowel(ascii_val):
    """Check if ASCII value is a vowel."""
    return ascii_val in [97, 101, 105, 111, 117]

def python_count_vowels(test_str):
    """Reference Python implementation."""
    res = 0
    vow_list = ['a', 'e', 'i', 'o', 'u']
    for idx in range(1, len(test_str) - 1):
        if test_str[idx] not in vow_list and (test_str[idx - 1] in vow_list or test_str[idx + 1] in vow_list):
            res += 1
    if len(test_str) > 1:
        if test_str[0] not in vow_list and test_str[1] in vow_list:
            res += 1
        if test_str[-1] not in vow_list and test_str[-2] in vow_list:
            res += 1
    elif len(test_str) == 1:
        if test_str[0] not in vow_list:
            res = 0
    return res

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

async def write_string_to_array(dut, test_str):
    """Write string characters to array as ASCII values."""
    ascii_values = [char_to_ascii(c) for c in test_str]
    
    # Try 2D array first
    try:
        for i, val in enumerate(ascii_values):
            dut.char_array[i].value = clamp_to_width(val, DATA_WIDTH)
        # Pad remaining with zeros
        for i in range(len(ascii_values), ARRAY_SIZE):
            dut.char_array[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i, val in enumerate(ascii_values):
        port_name = f"char_array_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")
    
    # Pad remaining
    for i in range(len(ascii_values), ARRAY_SIZE):
        port_name = f"char_array_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_vowel_neighbor_counter(dut):
    """Test the character counter with vowel neighbors."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ("bestinstareels", 7, "Test 1: bestinstareels"),
        ("partofthejourneyistheend", 12, "Test 2: partofthejourneyistheend"),
        ("amazonprime", 5, "Test 3: amazonprime"),
        ("a", 0, "Single vowel"),
        ("b", 0, "Single consonant"),
        ("ab", 1, "Two chars: ab"),
        ("ba", 1, "Two chars: ba"),
        ("test", 2, "Simple test: test"),
        ("aeiou", 0, "All vowels"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: '{test_str}' (len={len(test_str)})")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write string to array
            await write_string_to_array(dut, test_str)
            
            # Write length
            dut.str_len.value = len(test_str)
            
            # Wait a cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
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
