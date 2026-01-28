import cocotb
from cocotb.triggers import Timer, RisingEdge, Combine
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
LINE_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500

# Helpers
import random

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, max_len=16, width=8):
    val = 0
    for i, char in enumerate(s[:max_len]):
        val |= ord(char) << (i * width)
    # Pad remaining with spaces (ASCII 32) if needed for full width 16
    return val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_verse_matcher(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (line_string, target_p, should_match)
    test_cases = [
        ("intel", 2, True),   # i, e -> 2
        ("code", 2, True),    # o, e -> 2
        ("ch allenge", 3, True), # a, e, e -> 3 (ignoring non-vowels)
        ("a", 1, True),       # a -> 1
        ("bcd", 0, True),     # 0 vowels
        ("aeiouy", 6, True),  # all vowels
        ("intel", 3, False),  # mismatch
        ("a", 0, False),      # mismatch
        ("", 0, True),        # empty line
    ]
    
    passed = 0
    failed = 0
    
    for i, (line, expected_p, should_match) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Line='{line}', Target={expected_p}, Expect={'MATCH' if should_match else 'NO MATCH'}")
        
        try:
            # Calculate actual vowel count for verification
            vowels = set('aeiouy')
            actual_count = sum(1 for c in line if c in vowels)
            
            # Determine expected result
            expected_match_val = 1 if (actual_count == expected_p) else 0
            
            # Check if this aligns with test case intent
            if should_match and expected_match_val != 1:
                 cocotb.log.warning(f"Test case {i+1} logic mismatch: Line '{line}' has {actual_count} vowels, expected {expected_p} for MATCH")
            if not should_match and expected_match_val != 0:
                 cocotb.log.warning(f"Test case {i+1} logic mismatch: Line '{line}' has {actual_count} vowels, expected {expected_p} for NO MATCH")

            # Inputs
            dut.target_p.value = expected_p
            dut.line_len.value = len(line)
            
            # Pack string into array signals or packed bus
            # Assuming packed interface for simplicity or individual array access
            # Let's assume an array of 16 signals `line_str[0]` ... `line_str[15]`
            # And a packed signal `line_packed` for convenience if exists
            
            if has_signal(dut, 'line_packed'):
                dut.line_packed.value = pack_string(line, LINE_SIZE, DATA_WIDTH)
            elif has_signal(dut, 'line_str'):
                # Individual assignment for array
                for k in range(LINE_SIZE):
                    char_code = ord(line[k]) if k < len(line) else 32  # Space padding
                    dut.line_str[k].value = clamp_to_width(char_code, DATA_WIDTH)
            else:
                 # Fallback to individual ports line_0, line_1...
                 for k in range(LINE_SIZE):
                    port_name = f'line_{k}'
                    if has_signal(dut, port_name):
                        char_code = ord(line[k]) if k < len(line) else 32
                        getattr(dut, port_name).value = clamp_to_width(char_code, DATA_WIDTH)

            # Trigger
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check results
            match_val = int(dut.match.value) if is_value_defined(dut.match.value) else 0
            
            if match_val != expected_match_val:
                raise TestFailure(f"Line '{line}': Expected match={expected_match_val}, got {match_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
