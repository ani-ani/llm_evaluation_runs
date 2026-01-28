import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TEXT_MAX_LEN = 64
PATTERN_MAX_LEN = 16
INDEX_WIDTH = 6  # 0-63
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000  # Allow extra time for worst case

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

def string_to_ascii_array(text, max_len):
    """Convert string to list of ASCII values, pad to max_len."""
    ascii_values = []
    for i in range(min(len(text), max_len)):
        ascii_values.append(ord(text[i]))
    # Pad with zeros
    while len(ascii_values) < max_len:
        ascii_values.append(0)
    return ascii_values

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
    """Wait for done signal with timeout and X/Z handling."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        
        # Check if done is defined
        if not is_value_defined(dut.done.value):
            continue
        
        if int(dut.done.value) == 1:
            return True
    
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_text_array(dut, text_string):
    """Write text characters to text_char array."""
    ascii_array = string_to_ascii_array(text_string, TEXT_MAX_LEN)
    
    # Try 2D array access first
    try:
        for i, ascii_val in enumerate(ascii_array):
            dut.text_char[i].value = ascii_val
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i, ascii_val in enumerate(ascii_array):
        port_name = f'text_char_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = ascii_val
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def write_pattern_array(dut, pattern_string):
    """Write pattern characters to pattern_char array."""
    ascii_array = string_to_ascii_array(pattern_string, PATTERN_MAX_LEN)
    
    # Try 2D array access first
    try:
        for i, ascii_val in enumerate(ascii_array):
            dut.pattern_char[i].value = ascii_val
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i, ascii_val in enumerate(ascii_array):
        port_name = f'pattern_char_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = ascii_val
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_pattern_matcher(dut):
    """Test the simplified string pattern matcher."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Define test cases
    test_cases = [
        # (text, pattern, expected_found, expected_start, expected_end, description)
        ('The quick brown fox jumps over the lazy dog.', 'fox', True, 16, 19, "Test 1: fox in sentence"),
        ('Its been a very crazy procedure right', 'crazy', True, 16, 21, "Test 2: crazy word"),
        ('Hardest choices required strongest will', 'will', True, 35, 39, "Test 3: will at end"),
        ('abc', 'xyz', False, 64, 64, "Test 4: no match"),
        ('Hello World', 'Hello', True, 0, 5, "Test 5: match at start"),
        ('test', 'test', True, 0, 4, "Test 6: exact match"),
        ('aaaaa', 'aaa', True, 0, 3, "Test 7: first match only"),
        ('', 'a', False, 64, 64, "Test 8: empty text"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, pattern, exp_found, exp_start, exp_end, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Text: '{text}' (len={len(text)})")
        cocotb.log.info(f"  Pattern: '{pattern}' (len={len(pattern)})")
        
        try:
            # Validate test case against constraints
            if len(text) > TEXT_MAX_LEN:
                cocotb.log.warning(f"  SKIPPED: Text too long ({len(text)} > {TEXT_MAX_LEN})")
                continue
            if len(pattern) > PATTERN_MAX_LEN:
                cocotb.log.warning(f"  SKIPPED: Pattern too long ({len(pattern)} > {PATTERN_MAX_LEN})")
                continue
            if len(pattern) == 0:
                cocotb.log.warning(f"  SKIPPED: Empty pattern")
                continue
            
            # Write inputs
            await write_text_array(dut, text)
            await write_pattern_array(dut, pattern)
            
            # Set lengths
            dut.text_length.value = len(text)
            dut.pattern_length.value = len(pattern)
            
            # Wait 2 cycles for inputs to settle
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not all([is_value_defined(dut.found.value),
                       is_value_defined(dut.start_index.value),
                       is_value_defined(dut.end_index.value)]):
                raise TestFailure("Output signals undefined (X/Z)")
            
            found = bool(int(dut.found.value))
            start_idx = int(dut.start_index.value)
            end_idx = int(dut.end_index.value)
            
            # Verify results
            if found != exp_found:
                raise TestFailure(f"found mismatch: expected {exp_found}, got {found}")
            
            if start_idx != exp_start:
                raise TestFailure(f"start_index mismatch: expected {exp_start}, got {start_idx}")
            
            if end_idx != exp_end:
                raise TestFailure(f"end_index mismatch: expected {exp_end}, got {end_idx}")
            
            # Log success
            if found:
                matched_text = text[start_idx:end_idx]
                cocotb.log.info(f"  PASS: found='{matched_text}' at [{start_idx}:{end_idx}]")
            else:
                cocotb.log.info(f"  PASS: no match (start={start_idx}, end={end_idx})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")