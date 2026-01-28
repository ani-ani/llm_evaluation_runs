import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_LEN = 15
CLK_NS = 10
MAX_CYCLES = 50

# ASCII whitespace values
WHITESPACE = [0x20, 0x09, 0x0A, 0x0D]  # space, tab, newline, carriage return

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_string(s, width=DATA_WIDTH):
    """Pack ASCII string into integer for packed array input"""
    packed = 0
    for i, c in enumerate(s):
        packed |= (ord(c) & ((1 << width) - 1)) << (i * width)
    return packed

def unpack_string(packed, length, width=DATA_WIDTH):
    """Unpack integer to ASCII string"""
    result = []
    for i in range(length):
        byte = (packed >> (i * width)) & ((1 << width) - 1)
        result.append(chr(byte))
    return ''.join(result)

# Test helper functions
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_string(dut, text):
    """Write string to input array port"""
    for i in range(MAX_LEN):
        if i < len(text):
            dut.input_str[i].value = ord(text[i]) & 0xFF
        else:
            dut.input_str[i].value = 0
    dut.valid_len.value = len(text) & 0xF

def compute_expected(text):
    """Python reference implementation"""
    import re
    return re.sub(r'\s+', '', text)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_all_spaces(dut):
    """Test remove_all_spaces module"""
    
    # Check if sequential module
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("python  program", "pythonprogram", "Basic double space"),
        ("python   programming    language", "pythonprogramminglanguage", "Multiple spaces"),
        ("python                     program", "pythonprogram", "Long space sequence"),
        ("   python                     program", "pythonprogram", "Leading spaces"),
        ("   \t\n", "", "All whitespace"),
        ("a\tb\nc", "abc", "Mixed whitespace"),
        ("", "", "Empty string"),
        ("python", "python", "No whitespace"),
        ("a b c d e", "abcde", "Single spaces"),
        ("    test    ", "test", "Leading and trailing"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_text, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_text}' (len={len(input_text)})")
        cocotb.log.info(f"  Expected: '{expected}' (len={len(expected)})")
        
        try:
            if is_seq:
                # Write input
                await write_input_string(dut, input_text)
                
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read results
                if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                    raise TestFailure("Done signal not asserted")
                
                output_len = safe_int(dut.output_len.value)
                
                # Read output string
                output_chars = []
                for j in range(MAX_LEN):
                    if j < output_len:
                        char_val = safe_int(dut.output_str[j].value)
                        if char_val < 128:  # ASCII only
                            output_chars.append(chr(char_val))
                        else:
                            output_chars.append('?')
                    else:
                        # Check that unused positions are cleared
                        unused_val = safe_int(dut.output_str[j].value)
                        if unused_val != 0:
                            cocotb.log.warning(f"  Position {j} expected 0, got {unused_val}")
                
                output_text = ''.join(output_chars)
                
            else:
                # Combinatorial - directly assign and read
                for j, c in enumerate(input_text):
                    if j < MAX_LEN:
                        dut.input_str[j].value = ord(c) & 0xFF
                dut.valid_len.value = len(input_text) & 0xF
                await Timer(100, units='ns')
                
                output_len = safe_int(dut.output_len.value)
                output_chars = []
                for j in range(output_len):
                    char_val = safe_int(dut.output_str[j].value)
                    output_chars.append(chr(char_val) if char_val < 128 else '?')
                output_text = ''.join(output_chars)
                
                # Simulate done for combinatorial
                if output_len == len(input_text) or (len(input_text) > 0):
                    # Validate that output matches expected
                    pass
            
            cocotb.log.info(f"  Result: '{output_text}' (len={output_len})")
            
            # Validate
            if output_text != expected:
                raise TestFailure(f"Expected '{expected}', got '{output_text}'")
            
            if output_len != len(expected):
                raise TestFailure(f"Length mismatch: expected {len(expected)}, got {output_len}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        # Reset for next test
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
