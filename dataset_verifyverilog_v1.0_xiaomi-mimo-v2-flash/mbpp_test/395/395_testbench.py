import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers (mandatory)
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

# Array writing helper
def write_string_array(dut, name, string_val, width=8, size=16):
    padded = string_val.ljust(size, ' ')[:size]
    for i, char in enumerate(padded):
        val = ord(char) if i < len(string_val) else 0x00
        dut.__getattr__(name)[i].value = clamp_to_width(val, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_first_non_repeating_character(dut):
    DATA_WIDTH = 8
    ARRAY_SIZE = 16
    CLK_NS = 10
    MAX_CYCLES = 256
    
    # Setup clock if synchronous
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ("abcabc", 0x00, "No non-repeating"),
        ("abc", 0x61, "First 'a' non-repeating"),
        ("ababc", 0x63, "Third 'c' non-repeating"),
        ("aabbcc", 0x00, "No non-repeating full"),
        ("", 0x00, "Empty string")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_char, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: '{inp_str}'")
        try:
            # Write input array
            write_string_array(dut, 'str', inp_str, DATA_WIDTH, ARRAY_SIZE)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(100, units='ns')  # Combinational delay
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            # Convert ASCII char to int for comparison
            exp_int = exp_char if isinstance(exp_char, int) else ord(exp_char) if exp_char != 0x00 else 0x00
            
            if result_val != exp_int:
                raise TestFailure(f"Expected 0x{exp_int:02X}, got 0x{result_val:02X}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")