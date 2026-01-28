import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# --- Reference Function ---
def sum_digits(x):
    s = 0
    while x > 0:
        s += x % 10
        x //= 10
    return s

def reference_max_sum(n):
    max_val = 0
    # Check a=0
    max_val = max(max_val, sum_digits(0) + sum_digits(n))
    # Check candidates 9, 19, 99, 199, ...
    # We generate strings "9", "19", "99", "199", ...
    # But simpler: iterate powers of 10
    candidate_str = "9"
    while True:
        a = int(candidate_str)
        if a > n:
            break
        b = n - a
        s = sum_digits(a) + sum_digits(b)
        if s > max_val:
            max_val = s
        
        # Generate next candidate
        # If candidate is all 9s (e.g. 9, 99, 999), next is 1 followed by n 9s
        # If not all 9s (e.g. 19, 29...), next is +10? 
        # Actually, the set of candidates is:
        # 9, 19, 29, 39, 49, 59, 69, 79, 89, 99, 199, 299...
        # Or just: d*10^k - 1 for d=1..9, k=1..
        # Let's just do a simple generation for the testbench:
        if all(c == '9' for c in candidate_str):
            candidate_str = '1' + candidate_str
        else:
            # It is of form x99...9
            # Increment the non-9 part
            # Example: 19 -> 29
            # 199 -> 299
            # 299 -> 399
            # 999 -> 1999
            # Let's just use the known mathematical property:
            # Max is achieved at a = (d * 10^k) - 1 where d is first digit of n, or similar.
            # For the testbench, we can brute force small n or use the logic:
            # Iterate a = 0, 9, 19, 29, ..., 99, 199, ...
            pass
        
        # Let's just generate candidates properly:
        # Next after 9 is 19? (2*10-1)
        # Next after 19 is 29? (3*10-1)
        # ...
        # Next after 89 is 99 (10*10-1)
        # Next after 99 is 199 (2*100-1)
        
        # It's easier to iterate integers a in [0, n] but that's too slow for large n.
        # The testbench here runs on Python, so it can handle n up to 10^12 easily.
        # Just brute force for n < 1000, and specific candidates for larger n.
        pass
    
    # Brute force for correctness verification in testbench
    # Since Python is fast, we can iterate a subset.
    # The optimal a is always of the form d * 10^k - 1 (e.g. 9, 19, 99, 199, 999...)
    # or simply a = 0.
    candidates = [0]
    # Generate candidates
    # 9, 19, 29, ..., 99 -> 9, 19, 29, 39, 49, 59, 69, 79, 89, 99
    # 199, 299, ..., 999
    # 1999, ...
    
    # Let's just generate all numbers of the form (d * 10^k) - 1
    # for d in 1..9, k in 1..(digits of n)
    num_digits = len(str(n))
    for k in range(1, num_digits + 2): # +2 to be safe
        power = 10**k
        for d in range(1, 10):
            cand = d * power - 1
            if cand <= n:
                candidates.append(cand)
    
    # Also check n itself (a=n, b=0)
    candidates.append(n)
    
    # Unique and sort
    candidates = sorted(list(set(candidates)))
    
    mx = 0
    for a in candidates:
        b = n - a
        s = sum_digits(a) + sum_digits(b)
        if s > mx:
            mx = s
    return mx

# --- Testbench ---
@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_max_digit_sum(dut):
    """
    Test the Max Digit Sum module.
    """
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    else:
        # Combinational logic assumption
        await Timer(10, units='ns')

    # Test cases
    # We include a range of values to cover edge cases and normal cases
    test_values = [
        0, 1, 8, 9, 10, 15, 20, 35, 39, 89, 90, 99, 100, 
        199, 299, 399, 999, 1000, 9999, 10000, 99999, 100000, 
        999999, 1000000, 9999999, 10000000, 99999999, 100000000,
        999999999, 1000000000, 9999999999, 10000000000
    ]

    # If the module has no 'start' or 'done' signals (combinational), 
    # we just feed inputs and read outputs.
    is_sequential = has_signal(dut, 'start') and has_signal(dut, 'done')

    passed = 0
    failed = 0

    for n in test_values:
        # Setup input
        if is_sequential:
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational: just assign and wait a bit
            dut.n.value = n
            await Timer(10, units='ns')

        # Read result
        try:
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined for n={n}")
            
            result = int(dut.result.value)
            expected = reference_max_sum(n)

            if result != expected:
                raise TestFailure(f"For n={n}: Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: n={n}, result={result}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

    cocotb.log.info(f"All {passed} tests passed!")
