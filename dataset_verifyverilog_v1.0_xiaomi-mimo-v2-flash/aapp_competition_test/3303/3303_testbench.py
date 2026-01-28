import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

def str_to_ascii_array(s, length):
    # Convert string to list of integers (ASCII values), right-aligned
    # Pad with '0' (ASCII 48) on the left if needed
    s = s.zfill(length)
    if len(s) > length:
        s = s[-length:]  # Truncate if too long
    arr = [ord(c) for c in s]
    return arr[::-1]  # Reverse for LSB at index 0

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

async def write_string(dut, prefix, s):
    arr = str_to_ascii_array(s, ARRAY_SIZE)
    for i, v in enumerate(arr):
        getattr(dut, f'{prefix}_{i}').value = clamp_to_width(v, DATA_WIDTH)

# Expected values for the test cases provided
# 1. "10" + "99" -> A=99, B=10. Diff=89. Need steps to make sum no carry.
#    99 + 1 = 100, 10 - 1 = 9. Sum 109 (carry). 
#    Wait, the problem asks: add 1 to one and subtract 1 from the other.
#    To avoid carry: (A + k) + (B - k) = A + B. The sum is constant.
#    We need A+k and B-k such that digit-wise sum < 10.
#    This implies (A+k) and (B-k) must have digits that don't sum to >= 10.
#    Let's look at the example: 10 + 99.
#    Digits: 1 0 + 9 9. Sum: 10 9 (carry at ones place).
#    We add to 10 (smaller) and sub from 99 (larger).
#    k=1: 11 + 98. Digits: 1 1 + 9 8 = 1 9 (carry at tens? 1+9=10 -> carry).
#    Wait, standard addition: 99 + 10 = 109. Units: 9+0=9 (ok). Tens: 9+1=10 (carry).
#    We want 0 carries. 
#    Example 1 output is 1. 
#    Let's re-read: "perform the addition by 1 to one of the numbers (and subtraction by 1 from the other)".
#    A=99, B=10.
#    k=1: A+1=100, B-1=9. Sum 109. Tens: 0+0=0, Ones: 0+9=9. Wait, 100 and 9?
#    Standard addition of 100 and 09:
#      100
#    + 009
#    -----
#      109
#    Units: 0+9=9 < 10. Tens: 0+0=0 < 10. Hundreds: 1+0=1 < 10. No carries!
#    Ah, the numbers are aligned by position. 
#    100 has digits [0, 0, 1]. 09 has digits [9, 0].
#    Sum: 0+9=9, 0+0=0, 1+0=1. No carries.
#    So 1 step works.

def expected_result(s1, s2):
    try:
        A = int(s1)
        B = int(s2)
    except ValueError:
        return 0
    
    # Ensure A >= B
    if A < B:
        A, B = B, A
    
    # We need to find smallest k such that (A - k) + (B + k) has no carries.
    # Wait, problem says: "add 1 to one... subtract 1 from the other"
    # This means we are modifying the two numbers: A' = A + delta, B' = B - delta.
    # Sum A' + B' = A + B is constant.
    # We need to find delta such that adding A' and B' has no carries.
    # This is equivalent to finding a decomposition of S = A + B into X + Y
    # such that X and Y have no digit-wise carries, and X - Y = A - B (or similar constraint).
    # Actually, it's simply: we pick one number to add to, one to subtract from.
    # Let's say we add to B and subtract from A (since B <= A usually, to keep positive).
    # k steps: B' = B + k, A' = A - k.
    # We need A' + B' = A + B to have no carries.
    # Since sum is constant, we just need to check if we can split the sum S = A + B into two numbers X, Y
    # such that X = A - k, Y = B + k.
    # This implies X + Y = A + B.
    # And X - Y = A - B - 2k.
    # This path is complex for a script.
    # Let's rely on the example logic:
    # 90 + 10 -> 100. Sum 100.
    # 100 + 0 = 100. No carries? 1+0=1, 0+0=0. Yes.
    # Wait, 90 + 10 = 100.
    # If we add 10 to 10 and sub 10 from 90:
    # 10 + 10 = 20. 90 - 10 = 80.
    # 20 + 80 = 100.
    # Digits: 2 0 + 8 0 = 1 0 0. Units 0+0=0, Tens 2+8=10 (CARRY).
    # Hmm, maybe I added to the wrong number.
    # Add to 90: 90 + 10 = 100. Sub from 10: 10 - 10 = 0.
    # 100 + 0 = 100. No carries. 
    # So k=10 works.
    # Output is 10. Matches.
    
    # Algorithm for small numbers:
    # Iterate k from 0 upwards.
    # Check if adding (A+k) and (B-k) has carries. (Assuming we add to A)
    # Check if adding (A-k) and (B+k) has carries. (Assuming we sub from A)
    # Return min k.
    
    MAX_K = 1000000 # Cap for simulation
    for k in range(MAX_K):
        # Case 1: Add to A, Sub from B
        A1 = A + k
        B1 = B - k
        if B1 >= 0:
            if not has_carry(A1, B1):
                return k
        
        # Case 2: Sub from A, Add to B
        A2 = A - k
        B2 = B + k
        if A2 >= 0:
            if not has_carry(A2, B2):
                return k
                
    return 0

def has_carry(x, y):
    while x > 0 or y > 0:
        d1 = x % 10
        d2 = y % 10
        if d1 + d2 >= 10:
            return True
        x //= 10
        y //= 10
    return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_petra_add(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from prompt
    test_cases = [
        ("10", "99", 1),
        ("90", "10", 10),
        ("23425", "487915", 12085)
    ]
    
    passed = 0
    failed = 0
    
    for i, (s1, s2, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {s1} + {s2} -> {exp}")
        try:
            await write_string(dut, 'a_str', s1)
            await write_string(dut, 'b_str', s2)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")