import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
STRING_LEN = 16
CLK_NS = 10
MAX_CYCLES = 200

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_puppy_recolor(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (string, expected_result)
    test_cases = [
        ("aabddc", 1),  # Duplicates exist
        ("abc", 0),     # All unique
        ("jjj", 1),     # All same
        ("d", 1),       # Single char
        ("aa", 1),      # Two same
        ("ab", 0),      # Two different
        ("aabb", 1),    # Multiple duplicates
        ("abcdefgh", 0), # All unique
        ("aaaaaaaa", 1), # All same
    ]
    
    passed = 0
    failed = 0
    
    for s_str, expected in test_cases:
        n = len(s_str)
        cocotb.log.info(f"Test: '{s_str}' (len={n}), expected: {'Yes' if expected else 'No'}")
        
        try:
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = n
            
            # Set string characters
            s_vals = [ord(c) for c in s_str]
            # Pad with zeros for unused slots
            while len(s_vals) < STRING_LEN:
                s_vals.append(0)
            
            # Set each s_i port
            for i in range(STRING_LEN):
                port_name = f's_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(s_vals[i], DATA_WIDTH)
                else:
                    # Try s[i] array notation
                    try:
                        dut.s[i].value = clamp_to_width(s_vals[i], DATA_WIDTH)
                    except (AttributeError, IndexError):
                        pass
            
            # Start operation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_val = int(dut.result.value)
            if result_val != expected:
                raise TestFailure(f"Expected {'Yes' if expected else 'No'}, got {'Yes' if result_val else 'No'}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: '{s_str}': {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
