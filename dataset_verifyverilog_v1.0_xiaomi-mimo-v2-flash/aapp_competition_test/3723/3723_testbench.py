import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_max_subset_gcd(dut):
    """Test finding max subset with gcd > 1"""
    # Setup
    CLK_NS = 10
    clock = Clock(dut.clk, CLK_NS, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple example
    # Input: [2, 3, 4] -> mapped to [2, 3, 4]
    # Divisors: 2 -> {2, 4} count=2. 3 -> {3} count=1. 4 -> {4} count=1.
    # Max = 2
    n = 3
    inputs = [2, 3, 4]
    
    dut.start.value = 1
    dut.n.value = n
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    for val in inputs:
        dut.s_i.value = val
        await RisingEdge(dut.clk)
    
    # Wait for done
    done = False
    for _ in range(100):
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 1: Result {result} (Expected 2)")
    if result != 2:
        raise TestFailure(f"Expected 2, got {result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: Multiple occurrences
    # Input: [2, 4, 6, 8] -> {2,4,6,8}
    # 2 -> 4 multiples. 4 -> 2 multiples. 8 -> 1 multiple.
    # Max = 4
    n = 4
    inputs = [2, 4, 6, 8]
    
    dut.start.value = 1
    dut.n.value = n
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for val in inputs:
        dut.s_i.value = val
        await RisingEdge(dut.clk)
    
    done = False
    for _ in range(100):
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 2: Result {result} (Expected 4)")
    if result != 4:
        raise TestFailure(f"Expected 4, got {result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: All 1s (or primes)
    # Input: [1, 5, 7] -> No common divisor > 1 across them.
    # But we take at least 1. Max count for any divisor is 1.
    n = 3
    inputs = [1, 5, 7]
    
    dut.start.value = 1
    dut.n.value = n
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for val in inputs:
        dut.s_i.value = val
        await RisingEdge(dut.clk)
    
    done = False
    for _ in range(100):
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 3: Result {result} (Expected 1)")
    # The problem says k > 1, but output is usually 1 if no valid subset > 1
    # OR 1 if input is empty/single. Given constraints, if no subset gcd > 1, 
    # usually implies taking 0 or 1. In CP, usually max(1, count).
    if result != 1:
        raise TestFailure(f"Expected 1, got {result}")
