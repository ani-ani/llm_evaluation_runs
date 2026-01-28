import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 20

# ASCII values
SPACE = 32
UNDERSCORE = 95
NULL = 0

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_ascii_val(c):
    """Convert character to ASCII value"""
    if c == ' ':
        return SPACE
    elif c == '_':
        return UNDERSCORE
    else:
        return ord(c)

def from_ascii_val(v):
    """Convert ASCII value back to character"""
    if v == SPACE:
        return ' '
    elif v == UNDERSCORE:
        return '_'
    else:
        return chr(v) if 32 <= v <= 126 else '?'

def replace_spaces_py(text):
    """Reference Python implementation"""
    return "".join(" " if c == "_" else ("_" if c == " " else c) for c in text)

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_string(dut, text):
    """Write input string to DUT port by port"""
    ascii_vals = []
    for c in text:
        ascii_vals.append(to_ascii_val(c))
    
    # Pad with null to ARRAY_SIZE
    while len(ascii_vals) < ARRAY_SIZE:
        ascii_vals.append(NULL)
    
    # Write to each port
    for i in range(ARRAY_SIZE):
        port_name = f'input_string_{i}'
        port = getattr(dut, port_name)
        port.value = clamp_to_width(ascii_vals[i], DATA_WIDTH)
    
    # Set length
    if has_signal(dut, 'length'):
        dut.length.value = len(text)

async def read_result_string(dut, expected_len):
    """Read result string from DUT port by port"""
    result_chars = []
    for i in range(ARRAY_SIZE):
        port_name = f'result_{i}'
        port = getattr(dut, port_name)
        if is_value_defined(port.value):
            val = int(port.value)
            if i < expected_len:
                result_chars.append(from_ascii_val(val))
            else:
                # Should be null for indices beyond length
                if val != NULL:
                    raise TestFailure(f"Index {i} (>= length) should be NULL, got {val}")
        else:
            raise TestFailure(f"Result port {i} is undefined")
    
    return "".join(result_chars[:expected_len])

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_replace_spaces(dut):
    """Test the replace_spaces module"""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ('Jumanji The Jungle', 'Jumanji_The_Jungle', "Spaces to underscores"),
        ('The_Avengers', 'The Avengers', "Underscores to spaces"),
        ('Fast and Furious', 'Fast_and_Furious', "Mixed replacements"),
        ('', '', "Empty string"),
        ('a', 'a', "Single character no change"),
        (' ', '_', "Single space"),
        ('_', ' ', "Single underscore"),
        ('test_123 test', 'test 123_test', "Alphanumeric with spaces"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: '{inp_str}'")
        cocotb.log.info(f"  Expected: '{exp_str}'")
        
        try:
            # Write input
            await write_input_string(dut, inp_str)
            
            # Handle start pulse for sequential designs
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            else:
                # Combinational: wait for signals to settle
                await Timer(100, units='ns')
            
            # Read result
            result = await read_result_string(dut, len(inp_str))
            cocotb.log.info(f"  Got: '{result}'")
            
            # Check result
            if result != exp_str:
                raise TestFailure(f"Expected '{exp_str}', got '{result}'")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")