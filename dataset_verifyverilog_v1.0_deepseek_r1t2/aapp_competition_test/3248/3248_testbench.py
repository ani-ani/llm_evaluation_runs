import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
STREET_LEN = 16
MAX_PATTERNS = 8
MAX_PATTERN_LEN = 16
CHAR_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_char_array(dut, array_name, string_value, max_len):
    """Write string to character array, padding with zeros."""
    # Convert string to ASCII values
    ascii_values = [ord(c) for c in string_value[:max_len]]
    # Pad remaining with zeros
    while len(ascii_values) < max_len:
        ascii_values.append(0)
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(max_len):
            arr[i].value = ascii_values[i]
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(max_len):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = ascii_values[i]
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def write_pattern_array(dut, patterns, max_patterns, max_pattern_len):
    """Write pattern strings to 2D array."""
    for p_idx, pattern in enumerate(patterns[:max_patterns]):
        ascii_values = [ord(c) for c in pattern[:max_pattern_len]]
        while len(ascii_values) < max_pattern_len:
            ascii_values.append(0)
        
        # Write pattern length
        if has_signal(dut, f'pattern_len_{p_idx}'):
            getattr(dut, f'pattern_len_{p_idx}').value = len(pattern)
        elif hasattr(dut, 'pattern_len'):
            dut.pattern_len[p_idx].value = len(pattern)
        
        # Write pattern characters
        for c_idx in range(max_pattern_len):
            # Try 2D array first
            if hasattr(dut, 'pattern_chars'):
                dut.pattern_chars[p_idx][c_idx].value = ascii_values[c_idx]
            else:
                # Try individual ports
                port_name = f'pattern_chars_{p_idx}_{c_idx}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = ascii_values[c_idx]
                else:
                    raise TestFailure(f"Cannot find pattern port: pattern_chars[{p_idx}][{c_idx}]")

async def read_result(dut):
    """Read result from module."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_untileable_cells(dut):
    """Test the untileable cells module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (street, patterns, expected_untileable)
    test_cases = [
        ("abcbab", ["cb", "cbab"], 2),
        ("abab", ["bac", "baba"], 4),
        ("abcabc", ["abca", "cab"], 1),
        ("aaaa", ["aa"], 0),  # All covered
        ("a", ["a"], 0),      # Single covered
        ("xyz", ["a", "b"], 3),  # None covered
        ("abababab", ["aba", "bab"], 0),  # All covered with overlaps
    ]
    
    passed = 0
    failed = 0
    
    for i, (street, patterns, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: street='{street}', patterns={patterns}, expected={expected}")
        
        try:
            # Configure inputs
            dut.street_len.value = len(street)
            await write_char_array(dut, 'street_chars', street, STREET_LEN)
            
            dut.num_patterns.value = len(patterns)
            await write_pattern_array(dut, patterns, MAX_PATTERNS, MAX_PATTERN_LEN)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
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
