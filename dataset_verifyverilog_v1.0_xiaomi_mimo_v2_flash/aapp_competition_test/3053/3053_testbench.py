import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

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
    return min(max_val, max(0, value))

def int_to_str(val, length):
    s = ''
    for i in range(length):
        char_code = (val >> (8*i)) & 0xFF
        s += chr(char_code)
    return s

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rarity_finder(dut):
    test_cases = [
        (2, 2, 2, None, "Impossible: N=2,K=2,P=2"),
        (5, 3, 5, "madam", "Palindrome of length 5"),
        (6, 5, 3, "rarity", "Example 1"),
        (8, 8, 1, "abcdefgh", "Distinct chars, LPS=1"),
    ]
    
    for N, K, P, expected, desc in test_cases:
        dut.N.value = N
        dut.K.value = K
        dut.P.value = P
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Test {desc}: valid signal undefined")
        
        valid = int(dut.valid.value)
        
        if expected is None:
            if valid != 0:
                raise TestFailure(f"Test {desc}: expected invalid, got valid={valid}")
            dut._log.info(f"Test {desc}: PASS (invalid as expected)")
        else:
            if valid != 1:
                raise TestFailure(f"Test {desc}: expected valid, got valid={valid}")
            
            if not is_value_defined(dut.str.value):
                raise TestFailure(f"Test {desc}: str signal undefined")
            
            str_val = int(dut.str.value)
            actual_str = int_to_str(str_val, N)
            
            if actual_str != expected:
                raise TestFailure(f"Test {desc}: expected '{expected}', got '{actual_str}'")
            else:
                dut._log.info(f"Test {desc}: PASS")