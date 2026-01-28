import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
RESULT_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, s):
    # Pad to 16 chars with null terminators
    padded = s.ljust(16, '\x00')[:16]
    # Write each character to the string array
    for i in range(16):
        char_val = ord(padded[i]) if i < len(padded) else 0
        if has_signal(dut, 'str'):
            dut.str[i].value = clamp_to_width(char_val, DATA_WIDTH)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_char_counter(dut):
    # Check if it's a sequential module
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_string, expected_count, description)
    test_cases = [
        ("python programming", 18, "18 characters"),
        ("language", 8, "8 characters"),
        ("words", 5, "5 characters"),
        ("", 0, "Empty string"),
        ("a", 1, "Single character"),
        ("1234567890123456", 16, "Maximum 16 characters"),
        ("a\x00b", 3, "String with null byte in middle"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - '{inp_str}'")
        
        # Write string to input array
        await write_string(dut, inp_str)
        
        # Write length (actual length, not padded)
        len_val = clamp_to_width(len(inp_str), LEN_WIDTH)
        if has_signal(dut, 'len'):
            dut.len.value = len_val
        
        if is_seq:
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            
            if result_val != exp_count:
                raise TestFailure(f"Expected {exp_count}, got {result_val} for '{inp_str}'")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result_val} == {exp_count}")
        else:
            # Combinational - wait a bit then check
            await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            
            if result_val != exp_count:
                raise TestFailure(f"Expected {exp_count}, got {result_val} for '{inp_str}'")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result_val} == {exp_count}")
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"\nAll tests passed! ({passed}/{len(test_cases)})")