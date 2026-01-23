import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
TEXT_LEN = 32
PATTERN_LEN = 8
CHAR_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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

async def write_string_array(dut, array_name, string, size):
    """Write string characters to array, padding with zeros."""
    # Get the array object
    arr = getattr(dut, array_name)
    
    # Write each character
    for i in range(size):
        if i < len(string):
            # Convert char to ASCII and clamp to 8 bits
            char_val = ord(string[i])
            arr[i].value = clamp_to_width(char_val, CHAR_WIDTH)
        else:
            # Pad with zeros
            arr[i].value = 0

async def read_signal_array(dut, array_name, size):
    """Read array elements individually."""
    results = []
    arr = getattr(dut, array_name)
    for i in range(size):
        if is_value_defined(arr[i].value):
            results.append(int(arr[i].value))
        else:
            results.append(None)
    return results

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_substring_search(dut):
    """Test substring search functionality."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (text, pattern, expected_found, expected_start, expected_end, description)
    test_cases = [
        ('python programming, python language', 'python', True, 0, 6, "Test 1: First occurrence"),
        ('python programming,programming language', 'programming', True, 7, 18, "Test 2: Second occurrence"),
        ('python programming,programming language', 'language', True, 31, 39, "Test 3: Third occurrence"),
        ('c++ programming, c++ language', 'python', False, 0, 0, "Test 4: No match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, pattern, exp_found, exp_start, exp_end, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Text: '{text}'")
        cocotb.log.info(f"  Pattern: '{pattern}'")
        
        try:
            # Write text and pattern to DUT arrays
            await write_string_array(dut, 'text', text, TEXT_LEN)
            await write_string_array(dut, 'pattern', pattern, PATTERN_LEN)
            
            # Set valid lengths
            dut.text_valid_len.value = len(text)
            dut.pattern_valid_len.value = len(pattern)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.found.value):
                raise TestFailure("found signal is undefined (X/Z)")
            
            found = int(dut.found.value) == 1
            
            if found != exp_found:
                raise TestFailure(f"found={found}, expected={exp_found}")
            
            if exp_found:
                if not is_value_defined(dut.match_start.value):
                    raise TestFailure("match_start is undefined")
                if not is_value_defined(dut.match_end.value):
                    raise TestFailure("match_end is undefined")
                
                start_pos = int(dut.match_start.value)
                end_pos = int(dut.match_end.value)
                
                if start_pos != exp_start or end_pos != exp_end:
                    raise TestFailure(f"Position mismatch: got ({start_pos}, {end_pos}), expected ({exp_start}, {exp_end})")
                
                # Extract matched substring
                matched_text = text[start_pos:end_pos]
                cocotb.log.info(f"  Result: FOUND '{matched_text}' at ({start_pos}, {end_pos})")
            else:
                cocotb.log.info(f"  Result: NOT FOUND (correct)")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
