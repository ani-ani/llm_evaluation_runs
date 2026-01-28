import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers from spec
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

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_decode_shift(dut):
    CLK_NS = 10
    DATA_WIDTH = 8
    NUM_CHARS = 16
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: encoding then decoding
    # encode_shift: shift +5 forward
    # decode: shift -5 backward (or equivalently, encode with 21, but we'll compute directly)
    
    test_cases = []
    for _ in range(20):
        length = random.randint(10, 16)
        chars = [chr(random.randint(97, 122)) for __ in range(length)]
        original = "".join(chars)
        # Encode manually
        encoded = []
        for ch in original:
            shifted = ((ord(ch) - 97 + 5) % 26) + 97
            encoded.append(chr(shifted))
        encoded_str = "".join(encoded)
        test_cases.append((original, encoded_str))
    
    passed = failed = 0
    
    for i, (original, encoded_str) in enumerate(test_cases):
        # Prepare input array (pad with 'a' or something, but spec says valid letters only)
        # We'll just fill unused positions with 'a' (97) but actually test harness should handle
        # However, spec expects 16 chars, so pad with 'a' (decoded stays 'a' if encoded 'a')
        input_vals = []
        for j in range(NUM_CHARS):
            if j < len(encoded_str):
                input_vals.append(ord(encoded_str[j]))
            else:
                input_vals.append(97)  # 'a'
        
        # Expected output (padded)
        expected_vals = []
        for j in range(NUM_CHARS):
            if j < len(original):
                expected_vals.append(ord(original[j]))
            else:
                expected_vals.append(97)
        
        cocotb.log.info(f"Test {i+1}: Encoded='{encoded_str[:len(original)]}', Original='{original}'")
        
        try:
            # Write input string
            for idx in range(NUM_CHARS):
                dut.input_string[idx].value = clamp_to_width(input_vals[idx], DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Read result
            if not is_value_defined(dut.result[0].value):
                raise TestFailure("Result undefined")
            
            # Check all 16 characters
            for idx in range(NUM_CHARS):
                actual = int(dut.result[idx].value)
                expected = expected_vals[idx]
                if actual != expected:
                    raise TestFailure(f"Char {idx}: expected {expected} ({chr(expected)}), got {actual} ({chr(actual)})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
