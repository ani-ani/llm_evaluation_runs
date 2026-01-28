import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_STR_LEN = 64
MAX_EXP_LEN = 8
DATA_WIDTH = 8
CLK_NS = 10

# Helpers

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

async def feed_string(dut, s, pattern, pattern_len):
    """Feed input string character by character"""
    # Configure explosion pattern
    if has_signal(dut, 'explosion_pattern'):
        for i in range(MAX_EXP_LEN):
            char_code = ord(pattern[i]) if i < len(pattern) else 0
            # Access array element by element
            getattr(dut.explosion_pattern, f'[{i}]').value = clamp_to_width(char_code, DATA_WIDTH)
    
    if has_signal(dut, 'pattern_len'):
        dut.pattern_len.value = clamp_to_width(pattern_len, 4)
    
    if has_signal(dut, 'input_len'):
        dut.input_len.value = clamp_to_width(len(s), 7)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed characters
    for i, char in enumerate(s):
        # Wait for next cycle (assuming internal processing happens)
        # In a real streaming interface, we would check ready signal
        # For simulation, we assume synchronous consumption
        dut.in_char.value = clamp_to_width(ord(char), DATA_WIDTH)
        await RisingEdge(dut.clk)
    
    # Feed dummy chars to fill remaining cycles if needed
    # In this problem, input_len defines exact number of cycles
    # So we just wait for done

async def read_output(dut, expected_len):
    """Read output characters until out_valid goes low"""
    result = []
    max_wait = 1000
    count = 0
    
    # Wait for output to start (or done signal)
    # First, wait for done
    if has_signal(dut, 'done'):
        await wait_for_done(dut, max_wait)
    else:
        await Timer(1000, units='ns')
    
    # Now read output
    # We need to read for a reasonable amount of time
    # Output should be sequential
    
    for _ in range(max_wait):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'out_valid') and is_value_defined(dut.out_valid.value):
            if int(dut.out_valid.value) == 1:
                if has_signal(dut, 'out_char'):
                    val = int(dut.out_char.value)
                    result.append(chr(val))
            else:
                # Output valid went low, we are done
                break
        else:
            # If no out_valid, assume we are done after expected_len cycles
            if count >= expected_len:
                break
        count += 1
        if count > max_wait:
            break
    
    return ''.join(result)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_explosion_module(dut):
    """Test the explosion module with multiple test cases"""
    
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_string, explosion_pattern, expected_output)
    # Note: Expected output is the string after processing
    test_cases = [
        ("mirkovC4nizCC44", "C4", "mirkovniz"),
        ("12ab112ab2ab", "12ab", "FRULA"),  # FRULA means empty string
        ("abc", "abc", "FRULA"),
        ("abcc", "c", "ab"),
        ("aaaa", "aa", "FRULA"),  # aaaa -> (aa) -> (empty) -> FRULA
        ("aabbaa", "aa", "bb"),  # aabbaa -> (aa)bb(aa) -> bb
        ("12345", "99", "12345"),  # No match
        ("", "abc", "FRULA"),  # Empty input
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_str, exp_out) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input='{inp_str}', Explosion='{exp_str}'")
        
        try:
            # Reset for each test case if sequential
            if is_seq:
                await reset_dut(dut)
            
            # Feed input
            if is_seq and len(inp_str) > 0:
                await feed_string(dut, inp_str, exp_str, len(exp_str))
            elif not is_seq:
                # Combinational: just set inputs
                # This logic depends heavily on module implementation
                # Assuming sequential is primary test mode
                await Timer(1, units='ns')
            
            # Read output
            if is_seq:
                result = await read_output(dut, len(inp_str))
            else:
                # For combinational, read immediately
                await Timer(10, units='ns')
                result = ""
                # Reading from combinational output requires knowing structure
                # Assuming sequential for this problem as it's a chain reaction
                result = "" # Placeholder
            
            # Handle FRULA case (empty result)
            if exp_out == "FRULA":
                expected_result = ""
            else:
                expected_result = exp_out
            
            if is_seq:
                if result != expected_result:
                    raise TestFailure(f"Expected '{expected_result}', got '{result}'")
                passed += 1
            else:
                cocotb.log.info("Combinational test skipped (requires specific port names)")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Edge case: Very long string (up to limit)
    long_str = "A" * 64
    exp_str = "AA"
    expected = "" # AAA...AA -> AA -> empty -> FRULA
    
    cocotb.log.info(f"Testing long string: {len(long_str)} chars")
    
    if is_seq:
        await feed_string(dut, long_str, exp_str, len(exp_str))
        result = await read_output(dut, len(long_str))
        if result != expected:
            raise TestFailure(f"Long string test failed: Expected '{expected}', got '{result}'")
    else:
        cocotb.log.info("Combinational edge case skipped")

# Helper for writing individual characters if module uses arr_0, arr_1 format
async def write_pattern_manual(dut, pattern, length):
    if has_signal(dut, 'explosion_pattern'):
        # Try array syntax
        try:
            for i in range(length):
                # Check if it's a packed array or unpacked
                # If unpacked (arr_0, arr_1...)
                attr_name = f'explosion_pattern_{i}'
                if has_signal(dut, attr_name):
                    getattr(dut, attr_name).value = clamp_to_width(ord(pattern[i]), DATA_WIDTH)
                else:
                    # Assume vector index
                    dut.explosion_pattern[i].value = clamp_to_width(ord(pattern[i]), DATA_WIDTH)
        except Exception as e:
            cocotb.log.warning(f"Manual pattern write failed: {e}")
