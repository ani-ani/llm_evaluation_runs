import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def ascii_to_array(s):
    """Convert string to list of ASCII codes"""
    return [ord(c) for c in s]

def to_uppercase_char(c):
    """Convert single ASCII character to uppercase"""
    if 97 <= c <= 122:  # 'a'-'z'
        return c - 32
    return c

async def write_chars(dut, string, length):
    """Write characters to dut inputs"""
    chars = ascii_to_array(string)
    for i in range(ARRAY_SIZE):
        if i < length:
            val = chars[i]
        else:
            val = 0
        port_name = f'char_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            # Try array notation
            try:
                dut.char_array[i].value = clamp_to_width(val, DATA_WIDTH)
            except:
                pass

def compute_expected(string):
    """Compute expected uppercase string"""
    return ''.join(chr(to_uppercase_char(ord(c))) for c in string)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def read_result(dut):
    """Read result array from dut"""
    result = []
    for i in range(ARRAY_SIZE):
        port_name = f'result_{i}'
        if has_signal(dut, port_name):
            val = int(getattr(dut, port_name).value)
        else:
            try:
                val = int(dut.result_array[i].value)
            except:
                val = 0
        if val >= 32:  # Printable ASCII
            result.append(chr(val))
        else:
            result.append(chr(0))
    return ''.join(result)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_uppercase_conversion(dut):
    """Test string to uppercase conversion"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_string, description)
    test_cases = [
        ("person", "lowercase letters"),
        ("final", "lowercase short"),
        ("Valid", "mixed case"),
        ("ABCD123", "uppercase and numbers"),
        ("hello!", "with punctuation"),
        ("", "empty string"),
        ("a", "single char"),
        ("12345678", "numbers only"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: '{test_str}'")
        
        try:
            length = len(test_str)
            
            # Write input
            await write_chars(dut, test_str, length)
            dut.length.value = clamp_to_width(length, 4)
            
            # Start conversion
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            result = await read_result(dut)
            
            # Expected
            expected = compute_expected(test_str)
            
            # Validate
            if result[:length] != expected:
                raise TestFailure(
                    f"Test '{desc}' failed!\n"
                    f"Input:    '{test_str}' (len={length})\n"
                    f"Expected: '{expected}'\n"
                    f"Got:      '{result[:length]}'"
                )
            
            cocotb.log.info(f"  PASS: '{test_str}' -> '{result[:length]}'")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        await Timer(100, units='ns')
    
    cocotb.log.info(f"\n=== Summary: {passed} passed, {failed} failed ===")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")