import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def write_string(dut, input_string):
    """Write string to input array."""
    # Pad to 16 characters with zeros (null terminator concept)
    padded_string = input_string.ljust(MAX_LEN, '\x00')
    for i in range(MAX_LEN):
        if i < len(input_string):
            dut.arr[i].value = ord(padded_string[i])
        else:
            dut.arr[i].value = 0
    # Set length
    dut.len.value = len(input_string)

async def read_result(dut):
    """Read result string from output array."""
    length = safe_int(dut.out_len.value)
    if length == 0:
        return ""
    result = ""
    for i in range(length):
        if i < MAX_LEN and is_value_defined(dut.result[i].value):
            char_val = int(dut.result[i].value)
            if char_val != 0:
                result += chr(char_val)
    return result

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_longest_repeated_substring(dut):
    """Test longest repeated substring module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_output, description)
    test_cases = [
        ("abcefgabc", "abc", "Sample 1: abcefgabc"),
        ("abcbabcba", "abcba", "Sample 2: abcbabcba"),
        ("aaaa", "aaa", "Sample 3: aaaa"),
        ("bbcaadbbeaa", "aa", "Sample 4: bbcaadbbeaa"),
        ("abcabc", "abc", "Overlapping: abcabc"),
        ("ababa", "aba", "Overlapping: ababa"),
        ("xyxyxy", "xyx", "Complex: xyxyxy"),
        ("abcdef", "", "No repetition: abcdef"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}'")
        cocotb.log.info(f"  Expected: '{expected}'")
        
        try:
            # Write input
            await write_string(dut, input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=500)
            
            # Read result
            result = await read_result(dut)
            
            cocotb.log.info(f"  Got: '{result}'")
            
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