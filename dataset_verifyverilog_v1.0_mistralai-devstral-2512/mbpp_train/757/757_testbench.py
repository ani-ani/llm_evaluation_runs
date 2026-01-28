import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Pack 8-byte string into 64-bit integer
def pack_string(s, width=8):
    result = 0
    for i, c in enumerate(s[:width]):
        result |= (ord(c) & 0xFF) << (i * 8)
    # Pad with spaces if shorter
    for i in range(len(s), width):
        result |= (ord(' ') & 0xFF) << (i * 8)
    return result

# Pack array of strings into total bits (64*8 = 512 bits)
def pack_strings(strings, num_strings=8, str_width=8):
    packed = 0
    for i, s in enumerate(strings[:num_strings]):
        str_val = pack_string(s, str_width)
        packed |= str_val << (i * str_width * 8)
    return packed

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_reverse_pairs(dut):
    # Check for required signals
    if not has_signal(dut, 'clk') or not has_signal(dut, 'rst_n'):
        raise TestFailure("Missing required clock/reset signals")
    
    if not has_signal(dut, 'start'):
        raise TestFailure("Missing required start signal")
    
    if not has_signal(dut, 'result') or not has_signal(dut, 'done'):
        raise TestFailure("Missing required output signals")
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.strings.value = 0
    dut.len.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Verify reset state
    if int(dut.done.value) != 0:
        raise TestFailure("done should be 0 after reset")
    if int(dut.result.value) != 0:
        raise TestFailure("result should be 0 after reset")
    
    # Test cases
    test_cases = [
        # (strings_list, expected_count, description)
        (["julia", "best", "tseb", "for", "ailuj"], 2, "julia/ailuj and best/tseb"),
        (["geeks", "best", "for", "skeeg"], 1, "geeks/skeeg"),
        (["makes", "best", "sekam", "for", "rof"], 2, "makes/sekam and for/rof"),
        (["ab", "ba", "cd"], 1, "simple ab/ba"),
        (["a", "b"], 0, "no pairs"),
        (["abba", "abba"], 1, "same string is own reverse"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (strings, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        
        try:
            # Pack strings into 512-bit array
            num_strings = len(strings)
            packed = pack_strings(strings, num_strings)
            
            # Assign to dut
            dut.strings.value = clamp_to_width(packed, 512)
            dut.len.value = clamp_to_width(num_strings, 4)
            
            # Start pulse
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done (with timeout protection)
            max_cycles = 250
            done = False
            for cycle in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout after {max_cycles} cycles")
            
            # Read result
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
            # Clear for next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")
