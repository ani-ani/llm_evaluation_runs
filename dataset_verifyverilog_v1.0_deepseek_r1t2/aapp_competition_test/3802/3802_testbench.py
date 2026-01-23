import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# HELPER FUNCTIONS FOR THIS TEST
# ============================================================================

def char_to_5bit(c):
    """Convert uppercase char to 5-bit integer (A=0, B=1, ..., Z=25)"""
    return ord(c) - ord('A') if 'A' <= c <= 'Z' else 0

def string_to_padded_list(s, max_len):
    """Convert string to list of 5-bit integers, padded to max_len"""
    padded = [char_to_5bit(c) for c in s[:max_len]]
    padded += [0] * (max_len - len(padded))
    return padded

def list_to_string(char_list):
    """Convert list of 5-bit integers to string"""
    return ''.join(chr(c + ord('A')) for c in char_list if c > 0)

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal"""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_lcs_avoid_virus(dut):
    """Main test function"""
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (s1, s2, virus, expected_output)
    test_cases = [
        ("AJKEQSLOBSROFGZ", "OVGURWZLWVLUXTH", "OZ", "ORZ"),
        ("AA", "A", "A", "0"),
        ("PWBJTZPQHA", "ZJMKLWSROQ", "UQ", "WQ"),
        ("ABABABB", "ABABABB", "ABABB", "ABABAB"),
        ("ABBB", "ABBB", "ABB", "BBB"),
        ("A", "BABAABAAABABABABABABAABABABABBABABABABAABBABBABAABABAABAABBAAAAAABBABABABABAABABAABABABABAABAABABABA", "B", "A"),
        ("BCBCBC", "BCBCBC", "BC", "CCB"),
        ("ZZXXAAZZAXAAZZAZZXXAAZZAXAXZZXXAAZZZZXXAZZXXAAAZZXXAAAZZXXZZXXXAAAZZXZZXXAZZXXZXXAAXAAZZZXXAXAXAZZXZ", "AZZXXAAZZXXAAXZXXAZZXAZZXZZXXAAZZXXAAZAAZZAAZZXXAA", "AAZZXAAXXAAAZZXXAZZXXAAZZXXAAAZZXXZ", "ZZXXAAZZXXAAXZXXAZZXAZZXZZXXAAZZXXAAZAZZAAZZXXAA"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s1, s2, virus, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: s1='{s1}', s2='{s2}', virus='{virus}'")
        
        try:
            # Scale inputs
            s1_padded = string_to_padded_list(s1, 4)
            s2_padded = string_to_padded_list(s2, 4)
            virus_padded = string_to_padded_list(virus, 3)
            
            # Apply inputs
            dut.s1_char0.value = s1_padded[0]
            dut.s1_char1.value = s1_padded[1]
            dut.s1_char2.value = s1_padded[2]
            dut.s1_char3.value = s1_padded[3]
            
            dut.s2_char0.value = s2_padded[0]
            dut.s2_char1.value = s2_padded[1]
            dut.s2_char2.value = s2_padded[2]
            dut.s2_char3.value = s2_padded[3]
            
            dut.virus_char0.value = virus_padded[0]
            dut.virus_char1.value = virus_padded[1]
            dut.virus_char2.value = virus_padded[2]
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            length = int(dut.result_length.value)
            chars = [int(dut.result_char0.value), int(dut.result_char1.value), 
                     int(dut.result_char2.value), int(dut.result_char3.value)]
            
            # Convert to string
            if length == 0:
                result = "0"
            else:
                result = list_to_string(chars[:length])
            
            # Compare
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            dut._log.info(f"  PASS: result = '{result}'")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
