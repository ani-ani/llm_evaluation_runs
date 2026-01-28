import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
MAX_N = 16
MAX_K = 16
MAX_P = 16

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def write_inputs(dut, n, k, p):
    if has_signal(dut, 'N'):
        dut.N.value = clamp_to_width(n, 4)
    if has_signal(dut, 'K'):
        dut.K.value = clamp_to_width(k, 4)
    if has_signal(dut, 'P'):
        dut.P.value = clamp_to_width(p, 4)
    await Timer(10, units='ns')

def check_output(dut, n, k, p, expected_valid):
    valid = 0
    error = 0
    if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
        valid = int(dut.valid.value)
    if has_signal(dut, 'error') and is_value_defined(dut.error.value):
        error = int(dut.error.value)
    
    if not expected_valid:
        if valid == 1:
            raise TestFailure(f"Case N={n} K={k} P={p}: Expected error/invalid, but valid=1")
        return
    
    if valid == 0:
        raise TestFailure(f"Case N={n} K={k} P={p}: Expected valid=1, got 0")
    
    # Decode string from output array
    chars = []
    for i in range(n):
        # Check if array is unpacked (arr_0, arr_1...)
        if has_signal(dut, f'char_array_{i}'):
            s = getattr(dut, f'char_array_{i}')
            if is_value_defined(s.value):
                chars.append(chr(int(s.value)))
        # Or packed (if specified, but unlikely for 16*8=128 bits)
    
    if len(chars) != n:
        raise TestFailure(f"Case N={n} K={k} P={p}: Array length mismatch")
    
    # Validate constraints
    s = ''.join(chars)
    distinct = len(set(s))
    if distinct != k:
        raise TestFailure(f"Case N={n} K={k} P={p}: Distinct chars {distinct} != {k}, string: {s}")
    
    # Check palindrome length (simplified check)
    max_pal = 1
    for length in range(2, n + 1):
        for start in range(n - length + 1):
            sub = s[start:start+length]
            if sub == sub[::-1]:
                if length > max_pal:
                    max_pal = length
    
    if max_pal != p:
        raise TestFailure(f"Case N={n} K={k} P={p}: Max palindrome {max_pal} != {p}, string: {s}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_palindrome_generator(dut):
    # Reset (active low)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await Timer(10, units='ns')
    
    test_cases = [
        (6, 5, 3, True),   # Example 1
        (9, 8, 1, True),   # Example 2
        (5, 3, 5, True),   # Example 3
        (2, 2, 2, True),   # Example 4 (Palindrome 'aa' or 'bb')
        (10, 2, 10, True), # Valid palindrome
        (10, 2, 1, True),  # Valid distinct no palindromes
        (16, 16, 16, False), # Impossible (16 distinct chars in length 16 palindrome requires max 8 distinct)
        (1, 1, 1, True),   # Single char
        (3, 1, 2, False),  # Impossible (1 distinct char -> palindrome length 3)
        (3, 3, 1, False),  # Impossible (3 distinct chars in length 3 -> max pal 1 OK? Wait. a,b,c -> palindromes length 1. OK, should be True)
    ]
    
    # Correction for (3,3,1): a,b,c -> max pal length 1. Valid.
    test_cases[9] = (3, 3, 1, True)

    passed = 0
    failed = 0

    for n, k, p, exp_valid in test_cases:
        cocotb.log.info(f"Testing N={n} K={k} P={p} (Expected: {'Valid' if exp_valid else 'Invalid'})")
        try:
            await write_inputs(dut, n, k, p)
            await Timer(50, units='ns') # Allow propagation
            check_output(dut, n, k, p, exp_valid)
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
