import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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

async def wait_for_done(dut, max_cycles=2048):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_string(dut, test_str, data_width=7):
    """Stream string characters via char_in/char_valid"""
    for i, char in enumerate(test_str):
        dut.char_in.value = ord(char) & ((1 << data_width) - 1)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)

# Main test
@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_longest_repeated_substring(dut):
    DATA_WIDTH, CLK_NS = 8, 10
    
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("sabcabcfabc", 3, "sample1"),
        ("trutrutiktiktappop", 4, "sample2"),
        ("abcdef", 0, "no duplicates")
    ]
    
    passed = failed = 0
    
    for idx, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc} - String: '{test_str}'")
        
        try:
            # Set string length
            str_len = len(test_str)
            if has_signal(dut, 'str_len'):
                dut.str_len.value = str_len
            
            # Start pulse
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Stream characters
            await write_string(dut, test_str, 7)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=2048)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            result = clamp_to_width(result, 6)  # 6-bit result
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")