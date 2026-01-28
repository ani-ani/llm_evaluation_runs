import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_text(dut, text_str, length=None):
    if length is None:
        length = len(text_str)
    length = clamp_to_width(length, 4)
    dut.length.value = length
    for i in range(ARRAY_SIZE):
        if i < length:
            char_code = ord(text_str[i])
            dut.text[i].value = clamp_to_width(char_code, DATA_WIDTH)
        else:
            dut.text[i].value = 0

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_text_match_two_three(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("ac", False, "No 'a' followed by b's"),
        ("dc", False, "No 'a' at all"),
        ("abbbba", True, "Pattern 'abb' found (indices 1-3)"),
        ("", False, "Empty string"),
        ("a", False, "Only 'a'"),
        ("ab", False, "Only 1 'b'"),
        ("abb", True, "Pattern with exactly 2 b's"),
        ("abbb", True, "Pattern with exactly 3 b's"),
        ("abbbb", True, "Pattern with 3 b's at start"),
        ("babb", True, "Pattern at end"),
        ("abcbabbb", True, "Pattern found later"),
        ("abab", False, "Multiple a's but not enough b's"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} (input='{input_str}')")
        
        try:
            # Write input
            await write_text(dut, input_str)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result_val = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result_val}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
