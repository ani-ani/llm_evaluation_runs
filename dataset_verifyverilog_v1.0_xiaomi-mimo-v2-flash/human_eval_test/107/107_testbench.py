import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 10
MAX_ITER = 1000
CLK_NS = 10
MAX_CYCLES = 1500

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Palindrome reference implementation
def is_palindrome(num):
    if num < 1:
        return False
    s = str(num)
    return s == s[::-1]

def count_palindromes(n):
    even = 0
    odd = 0
    for i in range(1, n + 1):
        if is_palindrome(i):
            if i % 2 == 0:
                even += 1
            else:
                odd += 1
    return even, odd

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_palindrome_counter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (input_n, expected_even, expected_odd, description)
    test_cases = [
        (1, 0, 1, "n=1: only 1 (odd)"),
        (3, 1, 2, "n=3: 1,2,3 (even=2, odd=1,3)"),
        (9, 4, 5, "n=9: 1-9 palindromes, even:2,4,6,8"),
        (10, 1, 5, "n=10: even:2,4,6,8; odd:1,3,5,7,9"),
        (12, 4, 6, "n=12: add 11 (odd)"),
        (19, 4, 6, "n=19: palindromes up to 11 only"),
        (25, 5, 6, "n=25: add 22 (even)"),
        (63, 6, 8, "n=63: palindromes 1-9,11-66 range"),
        (100, 13, 13, "n=100: 1-9,11-99 palindromes"),
        (123, 8, 13, "n=123: add 101,111,121"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, exp_even, exp_odd, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n})")
        try:
            if is_seq:
                # Calculate expected using Python
                python_even, python_odd = count_palindromes(n)
                if python_even != exp_even or python_odd != exp_odd:
                    cocotb.log.warning(f"Python reference mismatch for n={n}: got ({python_even}, {python_odd}) vs expected ({exp_even}, {exp_odd})")
                
                # Set input
                dut.n_in.value = clamp_to_width(n, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read outputs
                if not is_value_defined(dut.even_count.value):
                    raise TestFailure("even_count undefined")
                if not is_value_defined(dut.odd_count.value):
                    raise TestFailure("odd_count undefined")
                
                hw_even = int(dut.even_count.value)
                hw_odd = int(dut.odd_count.value)
                
                # For debugging
                expected_even = python_even
                expected_odd = python_odd
                
                if hw_even != expected_even or hw_odd != expected_odd:
                    raise TestFailure(f"Expected ({expected_even}, {expected_odd}), got ({hw_even}, {hw_odd})")
                
            else:
                # Combinational version
                dut.n_in.value = clamp_to_width(n, DATA_WIDTH)
                await Timer(100, units='ns')
                
                hw_even = safe_int(dut.even_count.value)
                hw_odd = safe_int(dut.odd_count.value)
                
                expected_even, expected_odd = count_palindromes(n)
                
                if hw_even != expected_even or hw_odd != expected_odd:
                    raise TestFailure(f"Expected ({expected_even}, {expected_odd}), got ({hw_even}, {hw_odd})")
            
            passed += 1
            cocotb.log.info(f"PASS: n={n} -> ({hw_even}, {hw_odd})")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (n={n}): {e}")
            failed += 1
    
    # Test edge case n=0 (should handle gracefully)
    cocotb.log.info("Test edge case: n=0")
    try:
        if is_seq:
            dut.n_in.value = 0
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            hw_even = int(dut.even_count.value)
            hw_odd = int(dut.odd_count.value)
            if hw_even != 0 or hw_odd != 0:
                raise TestFailure(f"n=0 should give (0,0), got ({hw_even}, {hw_odd})")
        else:
            dut.n_in.value = 0
            await Timer(100, units='ns')
            hw_even = safe_int(dut.even_count.value)
            hw_odd = safe_int(dut.odd_count.value)
            if hw_even != 0 or hw_odd != 0:
                raise TestFailure(f"n=0 should give (0,0), got ({hw_even}, {hw_odd})")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL (n=0): {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed!")