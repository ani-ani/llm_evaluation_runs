import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
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
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_string_array(dut, text, max_len=16):
    """Write string characters to array, padded with zeros."""
    # Truncate if too long
    text = text[:max_len]
    
    for i in range(max_len):
        if i < len(text):
            char_val = ord(text[i])
            dut.char_array[i].value = char_val
        else:
            dut.char_array[i].value = 0

async def read_result_array(dut, max_len=16):
    """Read result array and construct string."""
    result_chars = []
    for i in range(max_len):
        if is_value_defined(dut.result_array[i].value):
            val = int(dut.result_array[i].value)
            if val != 0:
                result_chars.append(chr(val))
            else:
                # Stop at first null terminator or padding
                break
        else:
            break
    return "".join(result_chars)

async def read_result_array_full(dut, length):
    """Read exactly 'length' characters."""
    result_chars = []
    for i in range(length):
        if is_value_defined(dut.result_array[i].value):
            val = int(dut.result_array[i].value)
            result_chars.append(chr(val))
        else:
            result_chars.append('?')
    return "".join(result_chars)

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

async def start_computation(dut, text_len):
    """Pulse start signal and set length."""
    dut.len.value = text_len
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_replace_spaces(dut):
    """Test the replace_spaces module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_text, expected_output, description)
    test_cases = [
        ("Jumanji The Jungle", "Jumanji_The_Jungle", "Replace spaces with underscores"),
        ("The_Avengers", "The Avengers", "Replace underscores with spaces"),
        ("Fast and Furious", "Fast_and_Furious", "Multiple replacements"),
        ("Test", "Test", "No replacements needed"),
        ("_", " ", "Single underscore"),
        (" ", "_", "Single space"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_text, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_text}'")
        cocotb.log.info(f"  Expected: '{expected}'")
        
        try:
            # Write input string to array
            await write_string_array(dut, input_text)
            
            # Start computation
            await start_computation(dut, len(input_text))
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_result_array_full(dut, len(input_text))
            
            cocotb.log.info(f"  Result: '{result}'")
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")