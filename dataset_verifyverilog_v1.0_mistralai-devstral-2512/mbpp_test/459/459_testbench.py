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

# String Helpers
def pack_string(s, max_len=16):
    """Pack string into 128-bit vector (16 bytes)"""
    val = 0
    for i, c in enumerate(s[:max_len]):
        val |= (ord(c) & 0xFF) << (8 * i)
    return val

def unpack_string(val, length):
    """Unpack 128-bit vector to string of given length"""
    s = ""
    for i in range(length):
        char_code = (val >> (8 * i)) & 0xFF
        if char_code == 0:
            s += '\x00'
        else:
            s += chr(char_code)
    return s

def remove_uppercase_py(s):
    """Python reference function"""
    return ''.join([c for c in s if not ('A' <= c <= 'Z')])

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_uppercase(dut):
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumption
        await Timer(10, units='ns')
    
    # Test cases
    test_strings = [
        ('cAstyoUrFavoRitETVshoWs', 'cstyoravoitshos'),
        ('wAtchTheinTernEtrAdIo', 'wtchheinerntrdo'),
        ('VoicESeaRchAndreComMendaTionS', 'oiceachndreomendaion'),
        ('', ''),  # Empty string
        ('ABC', ''),  # All uppercase
        ('abc', 'abc'),  # No uppercase
        ('123!@#', '123!@#'),  # Non-letters
        ('MixEDCaSe', 'ixdsse'),  # Mixed
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_strings):
        cocotb.log.info(f"Test {i+1}: Input='{input_str}' -> Expected='{expected_str}'")
        
        try:
            # Prepare input
            input_len = len(input_str)
            packed_input = pack_string(input_str, 16)
            
            # Apply inputs
            dut.input_string.value = packed_input
            dut.input_length.value = input_len
            
            if is_seq:
                # Trigger processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.output_string.value) or not is_value_defined(dut.output_length.value):
                raise TestFailure("Output signals undefined")
            
            out_len = int(dut.output_length.value)
            out_val = int(dut.output_string.value)
            
            # Unpack and verify
            result_str = unpack_string(out_val, out_len)
            
            # Compare (truncate to expected length for padded nulls check)
            if result_str != expected_str:
                raise TestFailure(f"Expected '{expected_str}', got '{result_str}' (len={out_len})")
            
            # Additional check: remaining bytes should be 0
            if out_len < 16:
                remaining = (out_val >> (8 * out_len)) & ((1 << (8 * (16 - out_len))) - 1)
                if remaining != 0:
                    raise TestFailure(f"Non-zero padding detected: {remaining:X}")
                    
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_strings)} tests failed")