import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

# Convert integer average to Q16.16
# For binary search, we search on the integer scale 0..255 and convert to fixed point
# Actually, we search directly on fixed point: low = 0, high = 255 << 16 = 0x00FF0000
# The check condition uses fixed point arithmetic.

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def compute_max_avg_py(arr, K):
    # Exact Python computation for verification
    # Scaled to handle fractions
    max_avg = 0.0
    N = len(arr)
    for i in range(N):
        for j in range(i + K - 1, N):
            s = sum(arr[i:j+1])
            l = j - i + 1
            avg = s / l
            if avg > max_avg:
                max_avg = avg
    return max_avg

def binary_search_check(arr, mid_fixed):
    # Check if any subarray of length >= K has avg >= mid (fixed point)
    # mid is Q16.16
    # Condition: sum(a[j..i]) >= mid * L where L = i-j+1
    # Use Q16.16 for mid, but sum(a) is integer. Let's scale sum(a) to Q16.16 by shifting left 16
    N = len(arr)
    K = len(arr) # In this helper, we assume K is known globally or passed, but here we just check existence for avg >= mid
    # Actually, we need to implement the check: transform a[i] -> a[i] - mid (Q16.16)
    # But a[i] is integer. So b[i] = (a[i] << 16) - mid
    # Prefix sums P[0] = 0. P[i+1] = P[i] + b[i]
    # Check if P[i+1] - min(P[j]) >= 0 for i-j >= K-1 (so i >= j+K-1, so j <= i-K+1)
    b = [(x << 16) - mid_fixed for x in arr]
    P = [0]
    curr = 0
    for x in b:
        curr += x
        P.append(curr)
    
    min_prefix = 0 # P[0]
    for i in range(K-1, N):
        # Update min_prefix from P[0] to P[i-K+1]
        if i - K + 1 >= 0:
            min_prefix = min(min_prefix, P[i - K + 1])
        # Check P[i+1] - min_prefix >= 0
        if P[i+1] - min_prefix >= 0:
            return True
    return False

def find_max_avg(arr, K):
    # Binary search for max avg in Q16.16
    low = 0
    high = 255 << 16  # Max possible average is max element value
    # 32 iterations for precision
    for _ in range(32):
        mid = (low + high) >> 1
        if binary_search_check(arr, mid):
            low = mid
        else:
            high = mid
    return low

# Testbench
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_max_avg_subarray(dut):
    # Setup clock and reset
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational? Assume sequential for this problem.
        # If strictly combinational, we skip clock/reset logic.
        pass

    # Test cases
    # We scale N to max 8, K to at least 2
    test_cases = [
        ([1, 2, 3, 4], 1, "N=4, K=1"), # K=1 allowed? Prompt says K>=2, but problem says K>=1. 
        # Let's stick to prompt K>=2, but original problem K>=1. 
        # To be safe, allow K=1. The algorithm works for K=1.
        # But prompt constraints: K >= 2. Let's respect prompt constraints for design.
        # However, sample input 1 has K=1. 
        # The prompt says: "K will be at least 2 and at most N". 
        # This contradicts sample 1. I will assume K can be 1 as per original problem statement for testing,
        # but the design should be robust. The prompt specifically says "K will be at least 2" for the scaled problem.
        # I will test with K=1 in the testbench because the sample inputs provided have K=1,
        # but the design module spec should handle K=1 or K>=2. 
        # The spec says K is 4-bit input, so it can be 1.
        # I will use the original sample inputs but truncate/resize them to fit N<=8.
    ]
    
    # Let's use the exact samples provided, but with N<=8 (they are small)
    raw_inputs = [
        "4 1\n1 2 3 4\n",
        "4 2\n2 4 3 4\n",
        "6 3\n7 1 2 1 3 6\n"
    ]
    
    parsed_cases = []
    for s in raw_inputs:
        lines = s.strip().split('\n')
        n_k = list(map(int, lines[0].split()))
        arr = list(map(int, lines[1].split()))
        n, k = n_k[0], n_k[1]
        # Check constraints
        if n <= 8 and k <= n and k >= 1:
            parsed_cases.append((arr, k, f"N={n}, K={k}"))
    
    # Add a random test
    random.seed(42)
    rand_n = random.randint(2, 8)
    rand_k = random.randint(1, rand_n)
    rand_arr = [random.randint(1, 50) for _ in range(rand_n)]
    parsed_cases.append((rand_arr, rand_k, f"Random N={rand_n}, K={rand_k}"))

    passed = 0
    failed = 0

    for i, (arr, k, desc) in enumerate(parsed_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Prepare expected result
        expected_avg = compute_max_avg_py(arr, k)
        expected_fixed = float_to_fixed(expected_avg)
        
        # Prepare input array for HDL (pad to 8 elements if needed)
        n = len(arr)
        padded_arr = arr + [0] * (8 - n)
        
        try:
            # Write inputs
            # Check if array is packed or unpacked
            if has_signal(dut, 'a_0') or has_signal(dut, 'a_1'):
                # Individual signals
                for idx in range(8):
                    sig_name = f'a_{idx}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = clamp_to_width(padded_arr[idx], DATA_WIDTH)
            elif has_signal(dut, 'a'):
                # Array (packed or unpacked)
                # We need to be careful with unpacked arrays in cocotb
                # Try to access as list
                try:
                    dut.a.value = [clamp_to_width(v, DATA_WIDTH) for v in padded_arr]
                except Exception:
                    # Fallback to individual element assignment if it's an unpacked array object
                    for idx in range(8):
                        dut.a[idx].value = clamp_to_width(padded_arr[idx], DATA_WIDTH)
            else:
                raise TestFailure("No input array signal found (a or a_0..a_7)")
            
            # Write N and K
            dut.n.value = clamp_to_width(n, 4)
            dut.k.value = clamp_to_width(k, 4)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X/Z)")
                
            result = int(dut.result.value)
            
            # Check result with tolerance
            # Tolerance in fixed point: ±0.001 * 2^16 ≈ ±65
            tolerance = 65
            diff = abs(result - expected_fixed)
            
            if diff <= tolerance:
                cocotb.log.info(f"PASS: Expected {expected_avg:.6f} ({expected_fixed:#x}), Got {fixed_to_float(result):.6f} ({result:#x})")
                passed += 1
            else:
                raise TestFailure(f"Expected {expected_avg:.6f} ({expected_fixed:#x}), Got {fixed_to_float(result):.6f} ({result:#x}), Diff {diff} > {tolerance}")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")