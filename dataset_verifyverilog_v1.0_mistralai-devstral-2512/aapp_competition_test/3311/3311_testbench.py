import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

# Helper to compute exponial(n) mod m in Python for verification
def exponial_mod(n, m):
    if m == 1:
        return 0
    if n == 1:
        return 1 % m
    if n == 2:
        return 2 % m
    if n == 3:
        return 9 % m
    if n == 4:
        return 262144 % m
    # For n >= 5, exponial(n) = n^(exponial(n-1)) mod m
    # We need Euler's theorem
    phi_m = totient(m)
    # Compute exponent e = exponial(n-1) mod phi_m + phi_m
    # Since for n>=5, exponial(n-1) > phi_m (phi_m <= m <= 1e9)
    e = exponial_mod(n-1, phi_m) + phi_m
    return pow(n, e, m)

def totient(n):
    result = n
    p = 2
    while p * p <= n:
        if n % p == 0:
            while n % p == 0:
                n //= p
            result -= result // p
        p += 1
    if n > 1:
        result -= result // n
    return result

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_exponial(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clk = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clk.start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        else:
            await Timer(20, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')
    
    test_cases = [
        (2, 42, 2),
        (5, 123456789, 16317634),
        (94, 265, 39),
        (1, 1000, 1),
        (3, 45, 9),
        (4, 1000000, 262144),
        (6, 1000, None),  # Will compute dynamically
        (10, 50, None),   # Large n
    ]
    
    passed = 0
    failed = 0
    
    for n, m, expected in test_cases:
        # Compute expected if None
        if expected is None:
            try:
                expected = exponial_mod(n, m)
                cocotb.log.info(f"Calculated exponial({n}) mod {m} = {expected}")
            except Exception as e:
                cocotb.log.error(f"Failed to compute expected: {e}")
                expected = -1
        
        cocotb.log.info(f"Test: n={n}, m={m}, expected={expected}")
        
        # Set inputs
        if has_signal(dut, 'n'):
            dut.n.value = n
        if has_signal(dut, 'm'):
            dut.m.value = m
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            dut.start.value = 0
        else:
            await Timer(10, units='ns')
        
        # Wait for done
        if has_signal(dut, 'done'):
            max_cycles = 10000
            for _ in range(max_cycles):
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(10, units='ns')
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                cocotb.log.error(f"Timeout waiting for done")
                failed += 1
                continue
        else:
            await Timer(1000, units='ns')
        
        # Check result
        if has_signal(dut, 'result'):
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"Result undefined")
                failed += 1
                continue
            result = int(dut.result.value)
            if m > 0:
                result = result % m
            if result == expected:
                cocotb.log.info(f"PASS: got {result}")
                passed += 1
            else:
                cocotb.log.error(f"FAIL: got {result}, expected {expected}")
                failed += 1
        else:
            cocotb.log.error(f"No result signal found")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")