import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
MAX_NUMBERS = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    if has_signal(dut, 'last_in'): dut.last_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Prime factors to check (small primes)
SMALL_PRIMES = [2, 3, 5, 7, 11, 13, 17, 19]

def get_prime_mask(num):
    mask = 0
    for i, p in enumerate(SMALL_PRIMES):
        if num % p == 0:
            mask |= (1 << i)
    return mask

def solve_python(arr):
    # Find unique primes across all numbers
    all_masks = [get_prime_mask(x) for x in arr]
    unique_primes = 0
    for m in all_masks:
        unique_primes |= m
    
    if unique_primes == 0:
        # No common factors, but if all numbers > 1, impossible. 
        # If all are 1, GCD is 1, but split must be non-empty. 
        # If all are 1, any split works. Assume input contains 1s.
        return 1, [1]*len(arr)
    
    # BFS for reachable masks
    from collections import deque
    # dp[mask] = prev_mask, last_index
    dp = {0: (-1, -1)}
    q = deque([0])
    
    while q:
        curr = q.popleft()
        for i, m in enumerate(all_masks):
            new_mask = curr | m
            if new_mask not in dp:
                dp[new_mask] = (curr, i)
                q.append(new_mask)
    
    # Check if full mask is reachable
    if unique_primes not in dp:
        return 0, []
    
    # Reconstruct solution
    solution = [0] * len(arr)
    curr = unique_primes
    while curr != 0:
        prev, idx = dp[curr]
        solution[idx] = 1 # Group 1
        curr = prev
    
    # Check if group 2 is non-empty and also GCD=1
    # Group 2 covers primes if union of remaining masks == unique_primes
    g2_union = 0
    g2_count = 0
    for i, m in enumerate(all_masks):
        if solution[i] == 0:
            g2_union |= m
            g2_count += 1
            
    if g2_count == 0:
        # Group 2 empty, invalid
        return 0, []
        
    if g2_union == unique_primes:
        return 1, solution
    else:
        # Try other split? 
        # For this simplified hardware version, we just report what we found.
        # Python solution might find a different split if this one fails.
        return 0, []

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_gcd_split(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([2, 3, 6, 7], [0, 0, 1, 1]), # YES
        ([6, 15, 35, 77, 22], [0, 1, 0, 1, 1]), # YES
        ([6, 10, 15, 1000, 75], []), # NO
        ([1, 1], [1, 0]), # YES
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected_sol) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input {inp}")
        try:
            if not is_seq:
                await Timer(100, units='ns')
                continue
            
            # Feed data serially
            if has_signal(dut, 'ready'):
                while not int(dut.ready.value):
                    await RisingEdge(dut.clk)
            
            for idx, val in enumerate(inp):
                dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
                dut.valid_in.value = 1
                if idx == len(inp) - 1:
                    dut.last_in.value = 1
                else:
                    dut.last_in.value = 0
                await RisingEdge(dut.clk)
                dut.valid_in.value = 0
                dut.last_in.value = 0
            
            await wait_for_done(dut)
            
            result_val = int(dut.result.value)
            
            # Check result validity
            if result_val == 0:
                if expected_sol: # Expected YES but got NO (or mismatch)
                    # Verify if Python says NO
                    py_res, _ = solve_python(inp)
                    if py_res == 1:
                        raise TestFailure(f"Expected YES, but got NO. Python says YES.")
                    # If Python also says NO, it's a valid NO
                # else: Expected NO, got NO
                cocotb.log.info(f"Result: NO (Correct)")
            else:
                if not expected_sol:
                    raise TestFailure(f"Expected NO, but got YES.")
                
                # Extract assignment
                assignment = []
                if has_signal(dut, 'assignment'):
                    assign_val = int(dut.assignment.value)
                    for idx in range(len(inp)):
                        bit = (assign_val >> idx) & 1
                        # 1 means group 1, 0 means group 2. 
                        # Python expected: 1 means group 1, 0 means group 2.
                        # Hardware output: 1 bit set if in group 1.
                        assignment.append(bit)
                
                cocotb.log.info(f"Result: YES, Assignment: {assignment}")
                
                # Validate assignment
                # 1. Both groups non-empty
                g1_count = sum(assignment)
                g2_count = len(inp) - g1_count
                if g1_count == 0 or g2_count == 0:
                    raise TestFailure("One group is empty")
                
                # 2. GCD check
                def calc_gcd(a, b):
                    while b: a, b = b, a % b
                    return a
                
                def list_gcd(nums):
                    if not nums: return 0
                    res = nums[0]
                    for n in nums[1:]:
                        res = calc_gcd(res, n)
                        if res == 1: return 1
                    return res
                
                g1_nums = [inp[j] for j in range(len(inp)) if assignment[j] == 1]
                g2_nums = [inp[j] for j in range(len(inp)) if assignment[j] == 0]
                
                if list_gcd(g1_nums) != 1:
                    raise TestFailure(f"GCD of group 1 is not 1: {g1_nums}")
                if list_gcd(g2_nums) != 1:
                    raise TestFailure(f"GCD of group 2 is not 1: {g2_nums}")
                    
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
