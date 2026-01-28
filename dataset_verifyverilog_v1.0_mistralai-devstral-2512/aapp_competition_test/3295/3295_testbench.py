import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
MAX_K = 150
MAX_M = 150
MAX_START = 10000  # Scaled limit
CLK_NS = 10
MAX_CYCLES = 1000000

# Helpers
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

# Prime generator for verification
def sieve(limit):
    is_prime = [True] * (limit + 1)
    is_prime[0] = is_prime[1] = False
    for p in range(2, int(limit**0.5) + 1):
        if is_prime[p]:
            for multiple in range(p*p, limit + 1, p):
                is_prime[multiple] = False
    return is_prime

PRIME_CHECK = sieve(10000)

def calculate_happy_count(start, K, M):
    count = 0
    for n in range(start, start + K):
        if n <= M or PRIME_CHECK[n]:
            count += 1
    return count

def python_solver(K, L, M):
    for start in range(1, MAX_START + 1):
        if calculate_happy_count(start, K, M) == L:
            return start
    return -1

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_happy_numbers(dut):
    # Setup Clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Define Test Cases (Scaled down to fit simulation)
    test_cases = [
        (1, 1, 1, 1),
        (2, 0, 2, 8),
        (3, 1, 1, 4),
        (4, 1, 1, 6),
        (5, 2, 3, 4),
        (5, 0, 3, 24),
        (7, 2, 5, 6),
        (6, 1, 1, 20),
        (10, 4, 5, 5),
        (6, 2, 2, 4)
    ]
    
    passed = 0
    failed = 0
    
    for i, (K, L, M, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: K={K}, L={L}, M={M}, Expected={expected}")
        
        # Set inputs
        dut.k_in.value = K
        dut.l_in.value = L
        dut.m_in.value = M
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        try:
            await wait_for_done(dut, max_cycles=100000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Check for -1 (0xFFFFFF in 24-bit)
            if result == 0xFFFFFF:
                result = -1
                
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASSED Test {i+1}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAILED Test {i+1}: {e}")
            failed += 1
            
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
