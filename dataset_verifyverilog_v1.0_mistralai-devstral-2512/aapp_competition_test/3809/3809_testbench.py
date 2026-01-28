import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_boat_crossing(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from examples and inputs provided
    # Format: (n, k, weights, expected_dist, expected_ways)
    test_cases = [
        (1, 50, [50], 1, 1),
        (3, 100, [50, 50, 100], 5, 2),
        (2, 50, [50, 50], -1, 0),
        (1, 2994, [100], 1, 1),
        (5, 188, [50]*5, 3, 30), # n=5, all 50s, k=188. Max load 150 (3 people). 
        # BFS logic check. 
    ]
    
    for i, (n, k, weights, exp_dist, exp_ways) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: n={n}, k={k}, weights={weights}")
        
        # Count 50s and 100s
        c50 = weights.count(50)
        c100 = weights.count(100)
        
        # Inputs
        dut.c50_in.value = c50
        dut.c100_in.value = c100
        dut.k_in.value = k
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check results
        if not is_value_defined(dut.result_dist.value) or not is_value_defined(dut.result_ways.value):
            raise TestFailure(f"Result signals undefined at completion")
            
        result_dist = int(dut.result_dist.value)
        result_ways = int(dut.result_ways.value)
        
        # Handle signed -1 logic if implemented, or just check raw value
        # If impossible, dist is usually max value or specific flag.
        # Based on problem: -1 for dist, 0 for ways.
        
        if exp_dist == -1:
            # Check if result indicates impossible (e.g., 255 or specific check)
            # Problem spec says print -1. 
            # If HDL returns 255 (0xFF) for infinity, we check that or compare to exp.
            # Let's assume HDL outputs -1 as 255 (8-bit signed) or check logic.
            if result_dist != 255 and result_dist != -1 and result_dist != exp_dist:
                 # Depending on how -1 is encoded in unsigned logic
                 pass
            # Strict check based on problem statement logic in HDL
            if result_dist == 0 and result_ways == 0:
                 # Might be ambiguous if 0 rides is valid, but min rides >= 1 for n>=1
                 pass
            
            if result_ways != 0:
                 raise TestFailure(f"Test {i+1} Failed: Expected ways=0, got {result_ways}")
            
            # For dist, if impossible, HDL might output 255 or max cycle count
            # Let's check if dist matches exp_dist or if exp_dist is -1
            if result_dist != exp_dist and not (exp_dist == -1 and result_dist >= 100): # Allow large number for impossible
                 # If HDL maps -1 to 255 (unsigned 8-bit)
                 if exp_dist == -1 and result_dist == 255:
                     pass # Correct mapping
                 else:
                     raise TestFailure(f"Test {i+1} Failed: Expected dist={exp_dist}, got {result_dist}")
        else:
            if result_dist != exp_dist:
                raise TestFailure(f"Test {i+1} Failed: Expected dist={exp_dist}, got {result_dist}")
            if result_ways != exp_ways:
                raise TestFailure(f"Test {i+1} Failed: Expected ways={exp_ways}, got {result_ways}")
                
        cocotb.log.info(f"Test {i+1} Passed: dist={result_dist}, ways={result_ways}")
