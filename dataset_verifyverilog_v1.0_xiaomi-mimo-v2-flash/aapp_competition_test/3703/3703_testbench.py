import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 32
CLK_NS = 10
MOD = 1000000007

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

# Reference Python implementation for validation
def phi_py(n):
    if n == 1:
        return 1
    res = n
    i = 2
    while i * i <= n:
        if n % i == 0:
            while n % i == 0:
                n //= i
            res -= res // i
        i += 1
    if n > 1:
        res -= res // n
    return res

def compute_F(n, k):
    m = (k + 1) // 2
    cur = n
    for _ in range(m):
        if cur == 1:
            break
        cur = phi_py(cur)
    return cur % MOD

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_totient_module(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    dut.k_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down for speed)
    test_cases = [
        (7, 1, 6),
        (10, 2, 4),
        (1, 100, 1),
        (2, 100, 1),
        (17, 1, 16),
        (30, 1, 8),
        (100, 2, 40),
        (1, 1, 1),
        (999999999937, 1, 999992943),  # Large prime
    ]
    
    passed = 0
    failed = 0
    
    for n, k, expected in test_cases:
        cocotb.log.info(f"Test: n={n}, k={k}, expected={expected}")
        
        # Verify with Python reference
        py_result = compute_F(n, k)
        if py_result != expected:
            cocotb.log.error(f"Python reference mismatch: expected {expected}, got {py_result}")
            failed += 1
            continue
        
        # Assign inputs
        dut.n_in.value = n
        dut.k_in.value = k
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for cycle in range(1000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"Timeout for n={n}, k={k}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Result undefined for n={n}, k={k}")
            failed += 1
            continue
            
        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"FAIL: n={n}, k={k}. Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: n={n}, k={k}, result={result}")
            passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed} tests")