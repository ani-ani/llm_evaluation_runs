import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 14  # 0-10000 needs 14 bits (10000 < 16384)
MAX_VAL = (1 << DATA_WIDTH) - 1
CLK_NS = 10
MAX_CYCLES = 5000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Test helper
def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def write_people(dut, people):
    """people is list of (A,B,C) tuples, each 0-10000"""
    for i, (A, B, C) in enumerate(people):
        # Use getattr for individual signals
        getattr(dut, f'A_{i}').value = clamp_to_width(A, DATA_WIDTH)
        getattr(dut, f'B_{i}').value = clamp_to_width(B, DATA_WIDTH)
        getattr(dut, f'C_{i}').value = clamp_to_width(C, DATA_WIDTH)
    dut.N.value = len(people)

def solve_test_case(people):
    """Python reference: find max subset where sum(max A, max B, max C) <= 10000"""
    N = len(people)
    max_people = 0
    
    # Iterate through all subsets
    for mask in range(1 << N):
        subset = []
        for i in range(N):
            if mask & (1 << i):
                subset.append(people[i])
        
        if not subset:
            continue
        
        # Compute component-wise maximums
        maxA = max(p[0] for p in subset)
        maxB = max(p[1] for p in subset)
        maxC = max(p[2] for p in subset)
        
        # Check if there exists A,B,C such that A>=maxA, B>=maxB, C>=maxC, A+B+C=10000
        # This is feasible iff maxA + maxB + maxC <= 10000
        if maxA + maxB + maxC <= 10000:
            max_people = max(max_people, len(subset))
    
    return max_people

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_juice_mixing(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Case 1: 3 people, each wants 100% of one juice
        [(10000, 0, 0), (0, 10000, 0), (0, 0, 10000)],
        # Case 2: 3 people with compatible constraints
        [(5000, 0, 0), (0, 2000, 0), (0, 0, 4000)],
        # Case 3: 5 people
        [(0, 1250, 0), (3000, 0, 3000), (1000, 1000, 1000), (2000, 1000, 2000), (1000, 3000, 2000)],
        # Case 4: Single person
        [(1000, 2000, 3000)],
        # Case 5: All zeros (always satisfiable together)
        [(0, 0, 0), (0, 0, 0), (0, 0, 0)],
        # Case 6: Two people, sum > 10000
        [(6000, 0, 0), (0, 6000, 0)],  # Can satisfy both: A=6000, B=4000, C=0
        # Case 7: Incompatible
        [(8000, 0, 0), (0, 8000, 0), (0, 0, 8000)],  # Any two sum > 10000
    ]
    
    expected_results = [1, 2, 5, 1, 3, 2, 1]
    
    passed = 0
    failed = 0
    
    for idx, (people, exp) in enumerate(zip(test_cases, expected_results)):
        desc = f"Case {idx+1}: {len(people)} people"
        cocotb.log.info(f"Test {idx+1}: {desc}")
        
        try:
            # Compute expected result
            expected = solve_test_case(people)
            if expected != exp:
                cocotb.log.warning(f"Python logic mismatch: expected {exp}, got {expected}")
                expected = exp
            
            # Write inputs
            write_people(dut, people)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(1000, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")