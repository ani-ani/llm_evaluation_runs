import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_CHARS = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions from section A
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

async def write_string(dut, s, length):
    """Write string to dut.str array, clamping to 8-bit ASCII"""
    # Convert string to ASCII values, pad with zeros
    values = [ord(c) for c in s] + [0] * (MAX_CHARS - len(values))
    for i in range(MAX_CHARS):
        dut.str[i].value = clamp_to_width(values[i], DATA_WIDTH)
    if has_signal(dut, 'len'):
        dut.len.value = clamp_to_width(length, 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_palindrome(dut):
    # Setup clock
    if not has_signal(dut, 'clk'):
        raise TestFailure("DUT must have 'clk' signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (string, expected_result, description)
    test_cases = [
        ('', 1, "Empty string"),
        ('aba', 1, "'aba' palindrome"),
        ('aaaaa', 1, "'aaaaa' palindrome"),
        ('zbcd', 0, "'zbcd' not palindrome"),
        ('xywyx', 1, "'xywyx' palindrome"),
        ('xywyz', 0, "'xywyz' not palindrome"),
        ('xywzx', 0, "'xywzx' not palindrome"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (string='{s}', expected={expected})")
        
        try:
            # Write string to DUT
            await write_string(dut, s, len(s))
            
            # Start the palindrome check
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
            # Wait a cycle to ensure clean state for next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset between failed tests
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")