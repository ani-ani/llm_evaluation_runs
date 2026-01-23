import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
NUM_STRINGS = 5
MAX_STRING_LEN = 8
MAX_SUB_LEN = 8
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def char_to_ascii(char):
    """Convert single character to ASCII value."""
    return ord(char) if char != 0 else 0

def string_to_array(s, max_len=MAX_STRING_LEN):
    """Convert string to fixed-length array of ASCII values, padded with 0."""
    chars = list(s[:max_len])
    ascii_vals = [char_to_ascii(c) for c in chars]
    # Pad with zeros
    while len(ascii_vals) < max_len:
        ascii_vals.append(0)
    return ascii_vals

# ============================================================================
# RESET AND START HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_PERIOD_NS, units='ns')
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    if not has_signal(dut, 'done'):
        await Timer(100, units='ns')
        return
    
    for cycle in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_PERIOD_NS, units='ns')
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    if not has_signal(dut, 'start'):
        return
    
    dut.start.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(CLK_PERIOD_NS, units='ns')
    
    dut.start.value = 0

# ============================================================================
# INPUT/OUTPUT HELPERS
# ============================================================================

async def write_strings(dut, strings):
    """Write fixed-width strings to DUT input ports."""
    # Format each string to 8 characters
    formatted_strings = []
    for s in strings:
        # Truncate or pad to 8 characters
        s_padded = s[:MAX_STRING_LEN].ljust(MAX_STRING_LEN, '\x00')
        ascii_vals = string_to_array(s_padded, MAX_STRING_LEN)
        formatted_strings.append(ascii_vals)
    
    # Write each character to individual ports
    for str_idx in range(NUM_STRINGS):
        for char_idx in range(MAX_STRING_LEN):
            # Try multiple port naming conventions
            port_name = f'string{str_idx}_char{char_idx}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = formatted_strings[str_idx][char_idx]
            elif has_signal(dut, f'str_{str_idx}_{char_idx}'):
                getattr(dut, f'str_{str_idx}_{char_idx}').value = formatted_strings[str_idx][char_idx]
            elif has_signal(dut, f's_{str_idx}_{char_idx}'):
                getattr(dut, f's_{str_idx}_{char_idx}').value = formatted_strings[str_idx][char_idx]
            else:
                # Try indexed array
                try:
                    dut.strings[str_idx][char_idx].value = formatted_strings[str_idx][char_idx]
                except:
                    raise TestFailure(f"Cannot find port for string{str_idx}[{char_idx}]")

async def write_substring(dut, substring):
    """Write substring to DUT."""
    sub_array = string_to_array(substring, MAX_SUB_LEN)
    actual_len = len(substring) if len(substring) <= MAX_SUB_LEN else MAX_SUB_LEN
    
    # Write substring characters
    for char_idx in range(MAX_SUB_LEN):
        port_name = f'sub_char{char_idx}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = sub_array[char_idx]
        elif has_signal(dut, f'sub_{char_idx}'):
            getattr(dut, f'sub_{char_idx}').value = sub_array[char_idx]
        else:
            try:
                dut.substring[char_idx].value = sub_array[char_idx]
            except:
                raise TestFailure(f"Cannot find port for substring[{char_idx}]")
    
    # Write sub_len if exists
    if has_signal(dut, 'sub_len'):
        dut.sub_len.value = actual_len

async def read_result(dut):
    """Read result from DUT."""
    if not has_signal(dut, 'found'):
        raise TestFailure("Output 'found' not found")
    
    if not is_value_defined(dut.found.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    found = int(dut.found.value) == 1
    string_idx = None
    
    if has_signal(dut, 'string_idx') and is_value_defined(dut.string_idx.value):
        string_idx = int(dut.string_idx.value)
    
    return found, string_idx

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_substring_search(dut):
    """Test substring search functionality."""
    
    # Detect if sequential or combinational
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    else:
        # Combinational - just wait for propagation
        await Timer(100, units='ns')
    
    # Test cases adapted for 8-char strings
    test_cases = [
        # (strings_list, substring, expected_found, description)
        (["red", "black", "white", "green", "orange"], "ack", True, "Test 1: 'ack' in black"),
        (["red", "black", "white", "green", "orange"], "abc", False, "Test 2: 'abc' not found"),
        (["red", "black", "white", "green", "orange"], "ange", True, "Test 3: 'ange' in orange"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (strings, substring, expected_found, description) in enumerate(test_cases):
        cocotb.log.info(f"Running {description}")
        
        try:
            # Write inputs
            await write_strings(dut, strings)
            await write_substring(dut, substring)
            
            if is_sequential:
                # Start computation
                await start_computation(dut)
                # Wait for done
                await wait_for_done(dut, max_cycles=200)
                # Small delay for output to settle
                await Timer(CLK_PERIOD_NS, units='ns')
            else:
                # Combinational - wait for propagation
                await Timer(200, units='ns')
            
            # Read result
            found, string_idx = read_result(dut)
            
            # Verify
            if found != expected_found:
                raise TestFailure(f"Expected found={expected_found}, got {found}")
            
            if expected_found:
                # Verify string_idx is in valid range
                if string_idx is None:
                    raise TestFailure("string_idx is not defined")
                if string_idx < 0 or string_idx >= NUM_STRINGS:
                    raise TestFailure(f"string_idx {string_idx} out of range")
                cocotb.log.info(f"  PASS: found in string {string_idx}")
            else:
                cocotb.log.info(f"  PASS: not found (as expected)")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")