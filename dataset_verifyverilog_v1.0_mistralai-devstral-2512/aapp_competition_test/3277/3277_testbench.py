import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on adapted constraints
N = 16
K = 4
S = 255
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

def calculate_expected(arr):
    # Python reference implementation for the adapted problem
    # We need to find a pattern P[0..K-1] summing to S that minimizes changes.
    # Brute force is possible for K=4 and S=255, but let's use a greedy approximation
    # to match likely hardware behavior, or exact search for verification.
    
    # Since N is small (16) and K=4, we can do an exact search for the testbench.
    # Groups: 0, 1, 2, 3
    # We need to assign values v0, v1, v2, v3 such that v0+v1+v2+v3 = S (255).
    # Cost = sum of (arr[i] != v_{i%K})
    
    # Optimization: The values must be 0-255.
    # Since S=255, the average is ~63.75. 
    # We will iterate a limited range around the average or use frequency analysis.
    
    # Let's use a simplified heuristic logic often used in hardware:
    # 1. Identify the most frequent value in each modulo class.
    # 2. Adjust these values to sum to S.
    
    groups = {0: [], 1: [], 2: [], 3: []}
    for i in range(N):
        groups[i % K].append(arr[i])
    
    # Find mode for each group
    modes = {}
    for g in range(K):
        if not groups[g]: continue
        counts = {}
        for v in groups[g]:
            counts[v] = counts.get(v, 0) + 1
        # Mode
        mode_val = max(counts, key=counts.get)
        modes[g] = mode_val
    
    # Current sum of modes
    current_sum = sum(modes.values())
    diff = S - current_sum
    
    # Adjust modes to sum to S
    # We will distribute the difference to the groups.
    # This is a heuristic. For the testbench, we assume a simple distribution.
    # (Hardware might do this iteratively)
    for i in range(K):
        # Distribute diff across groups (rounding)
        adj = diff // (K - i)
        modes[i] = clamp_to_width(modes[i] + adj, DATA_WIDTH)
        diff -= adj
        
    # Calculate changes
    changes = 0
    for i in range(N):
        if arr[i] != modes[i % K]:
            changes += 1
            
    return changes

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_smooth_array(dut):
    # Setup clock and reset
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_changes)
    test_cases = [
        # Case 1: Input is [1, 2, 3, 1, 2, 3, ...] -> Pattern [1,2,3,x]. Sum=6. Need sum=255. Large changes.
        # Note: Constraints say S <= 5000, but we adapted to S=255. Input values are <= S.
        # Sample 1: 3 3 5 -> 1,2,3. Adapted N=16, K=4, S=255. 
        # Let's create an array that roughly follows a pattern summing to 255.
        # Pattern: [60, 65, 65, 65] -> Sum 255.
        # Array: 16 elements of this pattern.
        ([60, 65, 65, 65] * 4, 0, "Perfectly smooth"),
        
        # Array with 1 error
        ([61, 65, 65, 65] * 4, 4, "One value wrong per period"), # 4 errors because position 0 is wrong in all 4 periods? No, N=16, K=4, 4 periods.
        # Position 0 is 61 (should be 60). Position 4 is 61 (should be 60). etc. 
        # Wait, N=16, K=4. There are 4 periods. 
        # So 1 error in pattern * 4 periods = 4 errors.
        
        # Random array (heuristic check)
        ([1, 2, 3, 4] * 4, 16, "Random sequence"), # Sum of period 1+2+3+4=10. Target 255. 
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} Input: {inp}")
        
        try:
            # Pack input into signal if it's a bus, or sequential
            # Assuming sequential input 'data_in' and 'load' signal, or parallel array.
            # Let's assume parallel array access for simplicity as per adapted constraints.
            # If the module expects a packed input, we pack it.
            
            # Check if 'arr' exists as an array of signals
            if has_signal(dut, 'arr'):
                # Assume arr[0] to arr[15] exists
                for idx, val in enumerate(inp):
                    if hasattr(dut.arr, '__getitem__'):
                        dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                    else:
                        # If it's a packed bus, we calculate the whole value
                        pass
            elif has_signal(dut, 'data_in'):
                 # Packed bus assumption
                 packed_val = 0
                 for idx, val in enumerate(inp):
                     packed_val |= (clamp_to_width(val, DATA_WIDTH) << (idx * DATA_WIDTH))
                 dut.data_in.value = packed_val
            
            # Set target sum
            if has_signal(dut, 'target_sum'):
                dut.target_sum.value = S
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.min_changes.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.min_changes.value)
            
            # Verify against Python logic (which implements the heuristic)
            expected = calculate_expected(inp)
            
            # If the prompt specified a different logic, we might tolerate deviation,
            # but here we use the heuristic as ground truth.
            
            if result != expected:
                 # Note: The hardware might implement a slightly different heuristic
                 # (e.g. round-robin adjustment vs frequency).
                 # We allow some tolerance or check if it's a valid solution.
                 # For strictness, we check against expected.
                 # However, if the hardware algorithm is specified differently in the prompt,
                 # we must rely on that.
                 
                 # Given the prompt says "Implementation Hint: ... Accumulate... most frequent... adjust..."
                 # We expect the result to match the Python implementation of that hint.
                 
                 # If result is 0 for perfectly smooth, that's good.
                 # Let's calculate the true minimum for verification.
                 # True minimum for [60, 65, 65, 65]*4 is 0.
                 # True minimum for [61...]*4 is 4.
                 
                 # If the hardware uses a different heuristic, it might produce a different (valid) number.
                 # e.g. for [1,2,3,4]*4, sum=10. Target 255.
                 # Hardware might adjust to [63, 64, 64, 64] (sum 255).
                 # Python might adjust to [64, 64, 64, 63].
                 # Both result in 16 changes (all elements changed).
                 
                 # We will check if the result is logically valid (0 <= res <= 16).
                 # And check for the specific cases where the answer is unique or obvious.
                 
                 if result == 0 and expected > 0:
                      # 0 changes only valid if already smooth
                      raise TestFailure(f"Result 0 but array not smooth")
                 
                 # For the test, we accept the heuristic result or the calculated one.
                 # But let's try to match the calculated one closely.
                 if result != expected:
                     cocotb.log.warning(f"Mismatch: Got {result}, Calc {expected}. Checking validity...")
                     # Check if result is plausible (e.g. if exp is 16, result 16 is good)
                     if expected == 16 and result == 16:
                         pass # OK
                     elif expected == 4 and result == 4:
                         pass # OK
                     elif expected == 0 and result == 0:
                         pass # OK
                     else:
                         # Strict check for this benchmark
                        
                        raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
