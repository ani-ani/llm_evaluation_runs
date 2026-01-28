import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Helper to convert string '0101' to int
def str_to_int(s):
    return int(s, 2)

def int_to_str(i, k):
    return format(i, f'0{k}b')

# Helper to compute similarity (k - hamming distance)
def compute_similarity(k, cand, vec):
    xor_val = cand ^ vec
    hamming = bin(xor_val).count('1')
    return k - hamming

# Test Module
@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_tira_character(dut):
    # Setup Clock and Reset
    clk_period = 10  # ns
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    
    if has_signal(dut, 'clk'):
        await ClockCycles(dut.clk, 2)
    else:
        await Timer(20, units='ns')
        
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')

    # Test Case 1: Example from prompt
    # Input: n=3, k=5
    # 01001 -> 9
    # 11100 -> 28
    # 10111 -> 23
    # Expected Output: 00010 -> 2
    
    n = 3
    k = 5
    inputs = [0b01001, 0b11100, 0b10111]
    expected_output = 0b00010
    
    # Send configuration
    if has_signal(dut, 'n_in'):
        dut.n_in.value = n
    if has_signal(dut, 'k_in'):
        dut.k_in.value = k
        
    # Start pulse
    dut.start.value = 1
    await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
    dut.start.value = 0
    
    # Stream in data
    if has_signal(dut, 'data_valid'):
        for vec in inputs:
            dut.data_in.value = vec
            dut.data_valid.value = 1
            await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
            dut.data_valid.value = 0
            await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
    
    # Wait for done
    done_found = False
    for _ in range(5000): # Large timeout for exhaustive search
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
    
    if not done_found:
        raise TestFailure("Did not see done signal within timeout")
        
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
        
    result_val = int(dut.result.value)
    # Mask result to k bits
    result_val = result_val & ((1 << k) - 1)
    
    # Verification
    # We calculate expected max similarity for the found result
    # The problem asks to minimize the max similarity.
    # Let's verify manually for the specific input
    
    # For input 01001 (9), 11100 (28), 10111 (23)
    # Check candidate 00010 (2)
    # Dist to 01001: 00010 ^ 01001 = 01011 (2 ints) -> Hamming 3 -> Sim 2
    # Dist to 11100: 00010 ^ 11100 = 11110 (30) -> Hamming 4 -> Sim 1
    # Dist to 10111: 00010 ^ 10111 = 10101 (21) -> Hamming 3 -> Sim 2
    # Max similarity = 2
    
    # Is there a better one? 
    # 00000: Dist to 01001 (3 sim), 11100 (2 sim), 10111 (2 sim) -> Max 3
    # 11111: Dist to 01001 (3 sim), 11100 (2 sim), 10111 (2 sim) -> Max 3
    # 00010: Max 2. This is likely optimal.
    
    if result_val != expected_output:
        # Allow for non-determinism if multiple answers exist, but check max similarity
        # Calculate max similarity for the result found
        max_sim = 0
        for inp in inputs:
            sim = compute_similarity(k, result_val, inp)
            if sim > max_sim:
                max_sim = sim
        
        # Calculate max similarity for expected
        exp_max_sim = 0
        for inp in inputs:
            sim = compute_similarity(k, expected_output, inp)
            if sim > exp_max_sim:
                exp_max_sim = sim
                
        # If our result has higher max similarity, it's a fail
        if max_sim > exp_max_sim:
             raise TestFailure(f"Result {int_to_str(result_val, k)} has max sim {max_sim}, expected {int_to_str(expected_output, k)} with max sim {exp_max_sim}")
        # If they are equal, it's just a different valid answer
        
    # Test Case 2: 1 4, 0000 -> Output 1111 (or 0000)
    # Reset for second test
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2) if has_signal(dut, 'clk') else Timer(20, units='ns')
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
    
    n = 1
    k = 4
    inputs = [0b0000]
    # Any output is valid with max similarity 4? 
    # 0000 vs 0000 -> Sim 4
    # 1111 vs 0000 -> Sim 0. This minimizes max similarity (0 < 4).
    # So 1111 is better.
    
    if has_signal(dut, 'n_in'):
        dut.n_in.value = n
    if has_signal(dut, 'k_in'):
        dut.k_in.value = k
        
    dut.start.value = 1
    await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
    dut.start.value = 0
    
    if has_signal(dut, 'data_valid'):
        for vec in inputs:
            dut.data_in.value = vec
            dut.data_valid.value = 1
            await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
            dut.data_valid.value = 0
            await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
            
    done_found = False
    for _ in range(5000):
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        await ClockCycles(dut.clk, 1) if has_signal(dut, 'clk') else Timer(10, units='ns')
        
    if not done_found:
        raise TestFailure("Did not see done signal within timeout for test 2")
        
    result_val = int(dut.result.value) & ((1 << k) - 1)
    
    # Verify max similarity is 0 for this case
    max_sim = 0
    for inp in inputs:
        sim = compute_similarity(k, result_val, inp)
        if sim > max_sim:
            max_sim = sim
    
    if max_sim != 0:
         raise TestFailure(f"Result {int_to_str(result_val, k)} has max sim {max_sim}, expected 0")
