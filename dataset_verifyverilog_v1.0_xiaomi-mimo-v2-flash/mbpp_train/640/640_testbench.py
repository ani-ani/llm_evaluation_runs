import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
STRING_LEN = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helpers
import re

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Helper to convert string to packed 64-bit value
import struct

def str_to_packed(s):
    # Pad to 8 chars with nulls, pack little-endian
    padded = s.ljust(STRING_LEN, '\x00')
    # Python 3: convert to bytes
    b = padded.encode('ascii')[:STRING_LEN]
    # Pack into 64-bit integer (little-endian)
    val = 0
    for i in range(len(b)):
        val |= b[i] << (i * 8)
    return val

def packed_to_str(val, length):
    """Extract string from packed 64-bit value"""
    chars = []
    for i in range(length):
        byte = (val >> (i * 8)) & 0xFF
        if byte == 0:
            break
        chars.append(chr(byte))
    return ''.join(chars)

# Python reference implementation
def remove_parenthesis_python(s):
    # Remove parentheses and contents, including optional space before
    # Using regex as in original problem
    return re.sub(r" ?\([^)]+\)", "", s)

# Expected result packing
def expected_result(input_str):
    filtered = remove_parenthesis_python(input_str)
    packed = str_to_packed(filtered)
    return packed, len(filtered)

# Wait for done signal
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset sequence
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Write input string
async def write_string(dut, input_str):
    packed = str_to_packed(input_str)
    dut.input_string.value = packed
    dut.input_len.value = clamp_to_width(len(input_str), 4)

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_parenthesis(dut):
    # Determine if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("python (chrome)", "python"),
        ("string(.abc)", "string"),
        ("alpha(num)", "alpha"),
        ("test", "test"),  # No parens
        ("(all)", ""),     # Only parens
        ("a(b)c(d)e", "ace"),  # Multiple parens
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{input_str}' -> '{expected_str}'")
        try:
            # Write input
            await write_string(dut, input_str)
            
            if is_seq:
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                await wait_for_done(dut)
                await RisingEdge(dut.clk)  # Sample after done
            else:
                # Combinational: wait a bit
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.output_string.value):
                raise TestFailure("output_string undefined")
            if not is_value_defined(dut.output_len.value):
                raise TestFailure("output_len undefined")
            
            result_packed = int(dut.output_string.value)
            result_len = int(dut.output_len.value)
            
            # Convert to string for comparison
            result_str = packed_to_str(result_packed, result_len)
            
            # Compare
            if result_str != expected_str:
                raise TestFailure(
                    f"Expected '{expected_str}' (len={len(expected_str)}), "
                    f"got '{result_str}' (len={result_len})"
                )
            
            passed += 1
            cocotb.log.info(f"PASS: '{result_str}'")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Summary
    if failed:
        raise TestFailure(f"{failed}/{len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
