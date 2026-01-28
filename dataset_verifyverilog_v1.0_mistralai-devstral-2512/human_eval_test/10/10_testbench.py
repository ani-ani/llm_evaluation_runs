import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
MAX_INPUT_LEN = 16
MAX_OUTPUT_LEN = 32
CLK_NS = 10
MAX_CYCLES = 256

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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        v = 0
    elif v > max_val:
        v = max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def str_to_array(s):
    """Convert string to list of ASCII values, padded with zeros"""
    return [ord(c) for c in s] + [0] * (MAX_INPUT_LEN - len(s))

def array_to_str(arr, length):
    """Convert array of ASCII values back to string"""
    return ''.join(chr(arr[i]) for i in range(length))

def write_input_string(dut, s, length):
    """Write input string to dut.input_str"""
    vals = str_to_array(s)[:MAX_INPUT_LEN]
    for i, v in enumerate(vals):
        dut.input_str[i].value = clamp_to_width(v, DATA_WIDTH)
    dut.input_len.value = clamp_to_width(length, 5)

def read_output_string(dut):
    """Read output string from dut.output_str"""
    if not has_signal(dut, 'output_str'):
        return None
    arr = []
    for i in range(MAX_OUTPUT_LEN):
        try:
            val = int(dut.output_str[i].value)
            arr.append(val)
        except ValueError:
            arr.append(0)
    output_len = int(dut.output_len.value) if has_signal(dut, 'output_len') else 0
    output_len = clamp_to_width(output_len, 6)
    return array_to_str(arr, output_len)

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal or timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_make_palindrome(dut):
    """Test the make_palindrome module"""
    
    # Check for required signals
    required_signals = ['clk', 'rst_n', 'start', 'input_len', 'output_len', 'done']
    missing = [s for s in required_signals if not has_signal(dut, s)]
    if missing:
        raise TestFailure(f"Missing required signals: {missing}")
    
    # Start clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_output, description)
    test_cases = [
        ('', '', 'empty string'),
        ('x', 'x', 'single char'),
        ('xyx', 'xyx', 'already palindrome'),
        ('xyz', 'xyzyx', 'simple non-palindrome'),
        ('cat', 'catac', 'simple example'),
        ('cata', 'catac', 'example from docstring'),
        ('jerry', 'jerryrrej', 'example from test'),
        ('ab', 'aba', '2 chars'),
        ('abc', 'abcba', '3 chars'),
        ('abcd', 'abcdcba', '4 chars'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_output, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - '{input_str}' -> '{expected_output}'")
        
        try:
            # Write input
            write_input_string(dut, input_str, len(input_str))
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output
            actual_output = read_output_string(dut)
            
            if actual_output is None:
                raise TestFailure("Cannot read output string")
            
            if actual_output != expected_output:
                raise TestFailure(
                    f"Expected '{expected_output}', got '{actual_output}'"
                )
            
            passed += 1
            cocotb.log.info(f"PASS: '{input_str}' -> '{actual_output}'")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")
