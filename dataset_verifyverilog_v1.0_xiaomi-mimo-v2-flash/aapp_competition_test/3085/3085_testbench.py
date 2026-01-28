import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_INPUT_LEN = 4000
MAX_OUTPUT_LEN = 8192
DATA_WIDTH = 8
CLK_NS = 10

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
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python implementation of the logic for verification
def python_solve(s):
    s = s.strip()
    n = len(s)
    stack = []
    pairs = [] # List of (start_idx, end_idx)
    
    # Parse and find pairs
    for i, char in enumerate(s):
        if char == '(':
            stack.append(i)
        elif char == ')':
            if stack:
                start = stack.pop()
                pairs.append((start, i))
    
    # Pairs are found in order of closing bracket (inner to outer-ish, but roughly)
    # We need to sort them by start index to get the correct order for output.
    # The problem implies: "The header for the outer brackets will appear before the header for the inner bracket"
    # So sort by start index ascending.
    pairs.sort(key=lambda x: x[0])
    
    # Calculate lengths of representations
    # length[i] = len(start_str) + 1 (comma) + len(end_str) + 1 (colon) + sum of nested lengths
    m = len(pairs)
    lengths = [0] * m
    
    # Process bottom-up: iterate pairs in reverse order of start index (innermost first)
    for i in range(m - 1, -1, -1):
        start, end = pairs[i]
        
        # Calculate nested contribution
        nested_sum = 0
        for j in range(i + 1, m):
            # Check if j is nested in i
            if pairs[j][0] > start and pairs[j][1] < end:
                nested_sum += lengths[j]
        
        # Length of this header
        l_start = len(str(start))
        l_end = len(str(end))
        lengths[i] = l_start + 1 + l_end + 1 + nested_sum
        
    # Generate Output String
    output_parts = []
    # Current offset in the output string
    # We need to know where each header starts.
    # Since we process in order 0 to m-1, the start index of header i is the sum of lengths of headers 0 to i-1.
    
    current_offset = 0
    offsets = [0] * m
    for i in range(m):
        offsets[i] = current_offset
        current_offset += lengths[i]
        
    # Now build the string
    result_str = ""
    for i in range(m):
        start, end = pairs[i]
        start_idx = offsets[i]
        end_idx = offsets[i] + lengths[i]
        result_str += f"{start_idx},{end_idx}:"
        
    return result_str

# Input/Output test cases
TEST_CASES = [
    ("(() )", "4,8:8,8:"), # Case 1 (space added for clarity, but input has no spaces)
    ("()", "4,4:"), # Case 2
    ("((())(()))()", "5,29:11,17:17,17:23,29:29,29:35,35:"), # Case 3
]

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_bracket_notation(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for input_str, expected_output in TEST_CASES:
        # Clean input
        clean_input = input_str.strip()
        input_len = len(clean_input)
        
        cocotb.log.info(f"Testing input: '{clean_input}' (len={input_len})")
        
        # Write Input String to DUT
        # We assume s_in is an array of logic vectors
        # dut.s_in[i].value = char
        for i in range(input_len):
            dut.s_in[i].value = ord(clean_input[i])
        
        # Write Length
        dut.len.value = input_len
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        try:
            await wait_for_done(dut, max_cycles=500000) # Allow plenty of time for sequential processing
        except TestFailure as e:
            cocotb.log.error(f"Timeout on test: {e}")
            failed += 1
            continue
        
        # Read Output
        # Output is in result array, length in out_len
        out_len_val = int(dut.out_len.value)
        
        # Read bytes from dut.result
        output_chars = []
        for i in range(out_len_val):
            val = int(dut.result[i].value)
            output_chars.append(chr(val))
        
        actual_output = "".join(output_chars)
        
        cocotb.log.info(f"Expected: '{expected_output}'")
        cocotb.log.info(f"Actual:   '{actual_output}'")
        
        if actual_output == expected_output:
            passed += 1
        else:
            cocotb.log.error(f"Mismatch!")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
