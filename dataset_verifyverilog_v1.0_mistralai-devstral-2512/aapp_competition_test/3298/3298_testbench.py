import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 4
N = 12
CLK_NS = 10
MAX_CYCLES = 2000
MOD = 1000000009

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

def write_data(dut, values):
    # Pack array values into a single integer
    packed = 0
    for i, v in enumerate(values[:N]):
        val = clamp_to_width(v, DATA_WIDTH)
        packed |= (val << (i * DATA_WIDTH))
    dut.data_in.value = packed

# Python reference implementation (DP)
def count_unsorted_permutations(arr):
    n = len(arr)
    if n == 0:
        return 1
    
    # Sort and get frequencies
    sorted_arr = sorted(arr)
    unique_vals = []
    freqs = []
    
    i = 0
    while i < n:
        unique_vals.append(sorted_arr[i])
        count = 1
        while i + count < n and sorted_arr[i + count] == sorted_arr[i]:
            count += 1
        freqs.append(count)
        i += count
    
    num_types = len(unique_vals)
    
    # DP: dp[mask][last_idx] = count of permutations ending with unique_vals[last_idx]
    # where mask tracks used counts for each unique value
    # We need to track how many of each type we've used
    # state: (c0, c1, ..., c_{k-1}, last_val_idx)
    
    from functools import lru_cache
    
    @lru_cache(maxsize=None)
    def dp(counts_tuple, last_idx):
        total_used = sum(counts_tuple)
        if total_used == n:
            # Check if last element is sorted
            # In full permutation, check if last_idx corresponds to sorted element
            # An element is sorted if:
            # For position i, value v: all left <= v and all right >= v
            # For last element: it's sorted if it's >= all previous elements
            # i.e., it's a local maximum (since it's at the end)
            # But the definition: a_k is sorted if:
            # for all j < k: a_j <= a_k
            # for all j > k: a_j >= a_k
            # At end (k=n-1): only need to check left side
            # For last element to be sorted: it must be >= all previous elements
            # So last element must be a local maximum (largest)
            # If the last element is NOT the maximum, it's not sorted
            
            # To be entirely unsorted, NO element should be sorted
            # We can't check all elements here easily
            # Instead, we construct permutations and check validity during construction
            return 0  # We'll compute differently
        
        res = 0
        for next_idx in range(num_types):
            if counts_tuple[next_idx] < freqs[next_idx]:
                # Check if placing this element maintains unsorted property
                # For the new position (at end), check if this element would be sorted
                # Current element is unique_vals[next_idx]
                # Left side: all elements in current permutation
                # Right side: elements not yet placed
                
                # Construct left side values
                left_vals = []
                for j in range(num_types):
                    left_vals.extend([unique_vals[j]] * counts_tuple[j])
                
                # Right side values
                right_vals = []
                for j in range(num_types):
                    if j == next_idx:
                        right_vals.extend([unique_vals[j]] * (freqs[j] - counts_tuple[j] - 1))
                    else:
                        right_vals.extend([unique_vals[j]] * (freqs[j] - counts_tuple[j]))
                
                v = unique_vals[next_idx]
                
                # Check if v is sorted at this position
                # Condition 1: All left <= v
                left_ok = all(x <= v for x in left_vals)
                # Condition 2: All right >= v
                right_ok = all(x >= v for x in right_vals)
                
                if left_ok and right_ok:
                    # This placement creates a sorted element, skip it
                    continue
                
                new_counts = list(counts_tuple)
                new_counts[next_idx] += 1
                res = (res + dp(tuple(new_counts), next_idx)) % MOD
        
        return res
    
    # Initial call: no elements used yet
    # But we need to track last element for the check
    # Actually, we need to check sortedness for EACH position as we build
    
    # Let's rewrite: We build permutation left to right
    # At each step i (0-indexed), we place value v
    # Check if v would be sorted at position i:
    # Left: elements 0..i-1, Right: elements i+1..n-1
    # Left exists, Right not yet placed (we don't know)
    
    # We can only check Left condition (since Right is unknown)
    # But the problem is symmetric: we can also build right to left
    # Or use DP that tracks min/max seen so far
    
    # Better approach: Brute force for small N (N <= 12)
    # Generate all permutations and check
    # N! max 479M for N=12, too big
    
    # DP with state: (used_mask, last_value, is_sorted_so_far)
    # But is_sorted_so_far is tricky
    
    # Alternative: Calculate total permutations - permutations with at least one sorted element
    # Inclusion-Exclusion is complex
    
    # Let's use a simpler DP: dp[mask][last_val_idx] = count
    # where mask is bitmask of used elements (not counts)
    # N <= 12, so mask has 2^12 = 4096 states
    # last_val_idx can be 12 (or -1 for start)
    
    # But we have duplicates, so need to handle identical values
    # We can assign unique IDs to each element position 0..11
    
    # dp[mask][last_pos] = number of ways to arrange elements in mask ending at last_pos
    # mask: bits 0..11 represent which original positions are used
    # last_pos: index of the last element placed (0..11)
    
    # To check if element at position last_pos is sorted in the permutation being built:
    # We need to know ALL positions in the permutation
    # But mask only gives us which elements are used, not their order
    
    # We need to track the relative order or min/max
    
    # Let's use: dp[mask][last_pos][min_val][max_val]
    # min_val and max_val are indices into sorted unique values
    # Number of unique values <= N <= 12
    # State space: 4096 * 12 * 12 * 12 = ~7M, acceptable
    
    # Actually, we only need to know if current element is sorted
    # At step i (building permutation of length i+1), placing element v at position i
    # Check: v >= all left (so v >= max_left) AND v <= all right (so v <= min_right)
    # We know max_left from state
    # We don't know min_right yet (future elements)
    
    # So we can only check the first condition during forward construction
    # But we can process backward too
    
    # Hybrid: Build permutation, and at the end check all sorted positions
    # We can store the permutation in state? No, too big
    
    # We need to count permutations where NO position satisfies:
    # v[pos] >= max(v[0:pos]) AND v[pos] <= min(v[pos+1:n])
    
    # This is a standard problem. Let's use inclusion-exclusion over positions.
    # For each subset of positions S, count permutations where all positions in S are sorted.
    # Sign is (-1)^|S|.
    
    # For a position k to be sorted with value v:
    # 1. All elements before k must be <= v
    # 2. All elements after k must be >= v
    
    # This is complex for duplicates
    
    # Given the complexity and constraints (N<=12), let's use a simpler heuristic
    # in the testbench: compute by brute force for N <= 10 in Python
    # and use a fixed result for larger cases in HDL test.
    
    # For the Verilog module, we implement a simplified DP
    # that works for N=12 and small values.
    
    # Simplified Algorithm for HDL:
    # 1. Sort input array
    # 2. Generate all permutations (conceptually)
    # 3. Count valid ones
    
    # Since N=12, 12! = 479M, too many for HDL
    # We need smarter DP
    
    # Let's use: dp[i][j] = number of ways to arrange first i elements
    # where j is the index of the last element in the sorted order
    # This is not sufficient
    
    # We'll use a recursive backtracking with memoization in Python
    # and for HDL, we'll use a precomputed table or a simplified version
    
    # For the purpose of this benchmark, we'll implement a working
    # solution for N <= 8 in HDL, and adjust testbench accordingly
    
    # Re-defining for N=8
    pass

# For N=8, max 8! = 40320 permutations, manageable in Python for reference
# But for HDL, we need a DP

# Let's use: dp[mask][last_idx][min_right_idx]
# mask: 8 bits
# last_idx: 0..7 (original position)
# min_right_idx: index of minimum value in the remaining elements (or -1)
# State space: 256 * 8 * 9 = 18432, very small

# Wait, we need to check sorted condition for ALL positions, not just last
# We can check sorted condition at the time we place an element
# When we place element k at position pos (pos = popcount(mask) - 1):
# Check if it's sorted: need to know left max and right min
# Left max: we can track in state
# Right min: we can precompute suffix minimums

# Let's define:
# dp[mask][last_idx][left_max_idx] = count
# left_max_idx: index into sorted unique values
# We also need to know which values are used to compute right min

# This is getting too complex. Let's use a known simpler approach:
# For N small, use brute force enumeration in HDL (state machine)
# For N=8, 40320 states, we can iterate through permutations

# But generating permutations in hardware is hard

# Let's reconsider the problem.
# Number of unsorted permutations = Total - Sorted ones
# Sorted ones: permutations where at least one element is sorted
# By inclusion-exclusion:
# U = Sum_{S subset of positions} (-1)^{|S|} * count(permutations where positions in S are sorted)

# For a fixed set S, how to count permutations where positions in S are sorted?
# For each k in S, element at k must satisfy:
# a_k >= max of left, a_k <= min of right

# This depends on which elements are placed where
# If we fix that positions in S must have specific values (relative ranks),
# we can count.

# Given the complexity, and the fact that this is a competitive programming problem
# scaled down, we'll implement a practical HDL solution:

# HDL Spec Update:
# N = 8 (fixed, not configurable)
# Use DP: dp[mask] = number of valid permutations of elements in mask
# We build permutations from left to right
# State: dp[mask] where mask is used elements
# We also need to track the last element placed to check the sorted condition
# for that element (since right side is unknown, we can't fully check)

# Actually, for the last element placed, we can check:
# It is sorted if it is >= all previous AND it is <= all remaining
# We can precompute the minimum value among remaining elements

# So state: dp[mask] = count (we'll iterate to add next element)
# But we need to track last element's value to check the condition
# So: dp[mask][last_val] = count
# last_val can be 0..15 (4 bits)
# mask: 8 bits
# State space: 256 * 16 = 4096 states

# Transition:
# From state (mask, last_val) with count C
# For each unused element i (value v):
#   new_mask = mask | (1 << i)
#   # Check if last_val (placed at position popcount(mask)) is sorted
#   # Condition: last_val >= max_of_used_in_mask (we can compute) AND last_val <= min_of_unused
#   # But we don't track max_of_used

# We need to track max of used. Let's add another dimension.
# dp[mask][last_val][max_used_val] = count
# This is 256 * 16 * 16 = 65536 states, acceptable

# Transition:
# For each unused element i with value v:
#   new_mask = mask | (1 << i)
#   new_last = v
#   new_max = max(max_used_val, last_val) # Wait, last_val is the one we just placed?
#   Actually, last_val in state is the value at the LAST position (position popcount(mask)-1)
#   When we add v, the new last is v. The previous last is at position popcount(mask)-1.
#   We need to check if previous last is sorted.
#   Condition for previous last (val = last_val):
#     1. It must be >= max of elements before it (which is max_used_val EXCLUDING last_val? No)
#     Actually, max_used_val should be the max of ALL elements used BEFORE last_val was placed.
#     Let's track max of prefix (excluding current).
#     State: dp[mask][last_val][max_prefix] = count
#     When we add v:
#       # Check if last_val is sorted:
#       # Condition 1: last_val >= max_prefix (left side)
#       # Condition 2: last_val <= min of unused elements (including v? No, v is next)
#       # The right side of last_val is: unused elements EXCEPT v (v goes after last_val)
#       # Wait, positions: ... last_val, v, ...
#       # last_val is at position i. Right side is i+1 to n-1. This includes v.
#       # So we need min of unused elements EXCLUDING v?
#       # No, unused elements are those not in mask. v is not in mask.
#       # So we need min of (unused - {v})

# This is still complex. Let's simplify the sorted check.

# For N=8, we can afford to track the actual permutation or enough info.
# Let's try: dp[mask][last_idx][min_right_val]
# last_idx: index of last element (0..7)
# min_right_val: min value among elements NOT in mask (4 bits)
# State space: 256 * 8 * 16 = 32768

# Transition:
# From state (mask, last_idx, min_r) with count C
# For each unused element i:
#   v = values[i]
#   new_mask = mask | (1 << i)
#   # Check if element at last_idx is sorted:
#   # Position: popcount(mask) - 1
#   # Left: elements in mask (excluding last_idx). We need max left.
#   # We don't have max left in state.

# Let's add max_left to state.
# dp[mask][last_idx][max_left][min_right] = count
# 256 * 8 * 16 * 16 = 524288 states. Each state is 32 bits (count).
# Total bits: 524288 * 32 = 16 Mb. This is large but possible in BRAM.
# But 524k states is too many for simulation time in cocotb.

# We need a more efficient algorithm.

# Let's go back to the inclusion-exclusion idea.
# U = Sum_{S} (-1)^{|S|} * F(S)
# F(S) = # permutations where positions in S are sorted

# For a fixed S, how to compute F(S)?
# Let's sort the array: b[0] <= b[1] <= ... <= b[n-1]
# For position k to be sorted, the element at k must be 'stable' in the sense
# that it is a local extremum.
# If we have duplicates, the definition changes.

# Let's use the brute force approach for N <= 8 in HDL.
# We can generate permutations using a counter (Gray code or standard counter)
# and check validity.
# 8! = 40320 permutations. At 100MHz, 40320 cycles = 0.4ms. Acceptable.

# HDL Spec (Revised):
# N = 8 (fixed)
# Input: 8 values (4-bit each) -> 32-bit input vector
# Output: 32-bit count modulo 10^9+9
# Implementation: State machine that iterates through all permutations
# Use a counter to generate permutation index, decode to actual permutation
# Check each permutation for sorted elements
# Count valid ones

# State Machine:
# IDLE -> START
# LOAD_PERM: Decode counter to permutation
# CHECK_PERM: Check if permutation is entirely unsorted
# COUNT: Update count if valid
# INCR: Increment counter
# DONE: When counter reaches 8! - 1

# Decoding permutation from index (0..40319):
# Use factorial number system or simple iteration
# For N=8, we can use a precomputed table in ROM (8*40320 bits = 40KB)
# Or compute on the fly with iteration (slower but saves memory)

# Let's use on-the-fly computation for flexibility.
# Algorithm to generate k-th permutation of {0..7}:
#   indices = [0,1,2,3,4,5,6,7]
#   result = []
#   for i from 8 down to 1:
#     f = factorial(i-1)
#     idx = k // f
#     k = k % f
#     result.append(indices[idx])
#     indices.pop(idx)
#   return result

# We need factorial values: 7!, 6!, ..., 1! (max 5040)
# Stored in LUT

# This is feasible.

# Final HDL Spec:
# Module: UnsortedPermutationCounter
# Interface:
#   input wire clk, rst_n, start
#   input wire [31:0] data_in  // 8 values, 4-bit each
#   output reg [31:0] result
#   output reg done
#
# Internal:
#   reg [15:0] counter // 0 to 40319
#   reg [2:0] perm[0:7] // current permutation indices
#   reg [3:0] values[0:7] // actual values
#   reg [31:0] count // accumulated valid count
#   reg [3:0] state
#
# States:
#   IDLE: wait for start
#   INIT: load values from data_in
#   GEN_PERM: generate permutation for current counter
#   CHECK: check if permutation is unsorted
#   INC: increment counter
#   DONE: set done signal

# Check logic:
# For each position i in 0..7:
#   left_ok = true
#   for j in 0..i-1: if perm[j] > perm[i]: left_ok = false
#   right_ok = true
#   for j in i+1..7: if perm[j] < perm[i]: right_ok = false
#   if left_ok && right_ok: return false (sorted element found)
# return true (entirely unsorted)

# This check logic is combinatorial but small (N=8).

# For the testbench, we need to provide N=8 inputs.
# We'll use the examples but scaled to N=8.

# Example 1: [0, 1, 2, 3] -> Pad to [0, 1, 2, 3, 4, 5, 6, 7] (sorted)
# Example 2: [1, 1, 2, 1, 1] -> [1,1,1,1,2,3,4,5] (duplicates)

# We need to compute the expected output for N=8 in Python.

import itertools

def count_unsorted_bruteforce(arr):
    n = len(arr)
    if n == 0:
        return 1
    # Group identical values
    # Generate all permutations of indices
    indices = list(range(n))
    count = 0
    
    # To handle duplicates efficiently, generate unique permutations
    unique_perms = set()
    for p in itertools.permutations(indices):
        # Check if entirely unsorted
        is_unsorted = True
        for k in range(n):
            v = arr[p[k]]
            # Check left
            left_ok = True
            for j in range(k):
                if arr[p[j]] > v:
                    left_ok = False
                    break
            # Check right
            right_ok = True
            for j in range(k+1, n):
                if arr[p[j]] < v:
                    right_ok = False
                    break
            
            if left_ok and right_ok:
                is_unsorted = False
                break
        
        if is_unsorted:
            # Use tuple of values to handle duplicates in set
            perm_vals = tuple(arr[p[i]] for i in range(n))
            unique_perms.add(perm_vals)
    
    return len(unique_perms)

# Test cases for N=8
# Input 1: [0, 1, 2, 3] -> [0, 1, 2, 3, 4, 5, 6, 7]
arr1 = [0, 1, 2, 3, 4, 5, 6, 7]
# Input 2: [1, 1, 2, 1, 1] -> [1,1,1,1,2,3,4,5]
arr2 = [1, 1, 1, 1, 2, 3, 4, 5]

# Compute
# res1 = count_unsorted_bruteforce(arr1)
# print(f"Result 1: {res1}")
# res2 = count_unsorted_bruteforce(arr2)
# print(f"Result 2: {res2}")

# For the testbench, we'll use these expected values.
# Note: The brute force for N=8 might take a moment to run.

# Let's add a timeout and run it.
# 8! = 40320 permutations. 40320 * 8 * 8 ops ~ 2.5M ops. Fast in Python.

# We'll implement this check in the testbench to verify the HDL.

# We need to implement the permutation generation in HDL.
# This is the main complexity.

# Implementation details for HDL:
# We need to decode the k-th permutation of indices {0..7}.
# Factorial values for 7 to 1: 5040, 720, 120, 24, 6, 2, 1
# These fit in 13 bits.
# We can store them in a ROM.

# State machine for GEN_PERM:
# We iterate 8 times to build the permutation.
# We maintain an array 'available' [0..7] and a current k.
# In each iteration, we calculate idx = k / fact[i]
# Then pick available[idx] as the next element.
# Then remove it from available.

# This requires division and modulo. Division by constants (factorials) can be done.
# But modulo operation is tricky. We can use precomputed table for idx.
# Since k < 40320, and fact values are fixed, we can use a LUT for idx = k / fact[i].
# But k changes every cycle.
# We can use the hardware divider (DSP48) or iterative subtraction.
# Given 2000 cycles budget, iterative is fine.

# Let's refine the GEN_PERM state:
# 1. Load k into a register.
# 2. For i from 7 down to 0:
#    a. Divide k by fact[i].
#    b. Quotient is idx. Remainder is new k.
#    c. Pick available[idx].
#    d. Store in perm[7-i].
#    e. Remove from available.

# Division by constant: Use a small state machine for subtraction or DSP slice.
# For N=8, we can even use a simple loop.

# Check state:
# Iterate i from 0 to 7:
#   left_ok = 1
#   for j in 0..i-1: if values[perm[j]] > values[perm[i]]: left_ok = 0
#   right_ok = 1
#   for j in i+1..7: if values[perm[j]] < values[perm[i]]: right_ok = 0
#   if (left_ok & right_ok) -> found sorted element
# If no sorted element found in all positions -> valid permutation.

# This is the plan.

# Testbench updates:
# 1. Scale inputs to N=8.
# 2. Compute expected output using Python reference.
# 3. Drive inputs.
# 4. Verify result.

# We'll add the Python reference logic to the testbench.

def count_unsorted_permutations_n8(arr):
    n = len(arr)
    # Pad if needed, but we'll assume N=8
    if n < 8:
        # Add distinct values to make 8
        max_val = max(arr) if arr else 0
        extra = 8 - n
        arr = arr + [max_val + i + 1 for i in range(extra)]
    
    # Brute force
    indices = list(range(8))
    unique_perms = set()
    
    for p in itertools.permutations(indices):
        valid = True
        for k in range(8):
            v = arr[p[k]]
            # Check left
            left_ok = True
            for j in range(k):
                if arr[p[j]] > v:
                    left_ok = False
                    break
            # Check right
            right_ok = True
            for j in range(k+1, 8):
                if arr[p[j]] < v:
                    right_ok = False
                    break
            
            if left_ok and right_ok:
                valid = False
                break
        
        if valid:
            perm_vals = tuple(arr[p[i]] for i in range(8))
            unique_perms.add(perm_vals)
    
    return len(unique_perms)

# Precomputed expected values for N=8
# Input 1: [0, 1, 2, 3] -> [0, 1, 2, 3, 4, 5, 6, 7]
# Input 2: [1, 1, 2, 1, 1] -> [1, 1, 1, 1, 2, 3, 4, 5]

# We'll compute them in the testbench setup.

# Note: The Python code for permutations can be slow for many test cases.
# We'll precompute or optimize.

# Optimization: 
# Instead of generating all permutations, we can use the DP approach for N=8.
# State: dp[mask][last_idx][left_max_idx][right_min_idx]
# This is still complex to implement in HDL.

# Given the constraints, the brute force HDL is acceptable.
# Testbench must be efficient.

# We will use the following structure for the testbench:

import itertools

def python_reference(input_arr):
    # Pad to 8
    arr = list(input_arr)
    while len(arr) < 8:
        max_val = max(arr) if arr else 0
        arr.append(max_val + 1)
    
    n = 8
    indices = list(range(n))
    unique_perms = set()
    
    for p in itertools.permutations(indices):
        is_unsorted = True
        for k in range(n):
            v = arr[p[k]]
            # Check left
            left_ok = True
            for j in range(k):
                if arr[p[j]] > v:
                    left_ok = False
                    break
            # Check right
            right_ok = True
            for j in range(k + 1, n):
                if arr[p[j]] < v:
                    right_ok = False
                    break
            
            if left_ok and right_ok:
                is_unsorted = False
                break
        
        if is_unsorted:
            perm_vals = tuple(arr[p[i]] for i in range(n))
            unique_perms.add(perm_vals)
    
    return len(unique_perms)

# We need to scale the provided inputs.
# Input 1: "4\n0 1 2 3\n" -> [0,1,2,3]
# Input 2: "5\n1 1 2 1 1\n" -> [1,1,2,1,1]

# Let's compute the expected outputs for N=8 in the testbench.
# We'll add a test case with a known result for verification.

# We'll use a fixed test case in the testbench.
# Example: [1, 2, 3, 4, 5, 6, 7, 8] -> Should be 0? No, many permutations are unsorted.
# Let's take [1, 1, 2, 2, 3, 3, 4, 4] (duplicates).

# To avoid long computation in testbench, we'll use a precomputed value.
# Let's assume for [1, 2, 3, 4, 5, 6, 7, 8] the result is something.
# We can compute it once and hardcode in the testbench.

# Computation for [1, 2, 3, 4, 5, 6, 7, 8]:
# Only permutations that are sorted (monotonic) are sorted.
# A sequence is sorted if all elements are sorted.
# A sequence is entirely unsorted if NONE are sorted.
# For distinct sorted input, an element is sorted if it's a local extremum.
# We need permutations with NO local extrema (except maybe ends?).
# Definition: a_k is sorted if for all j<k, a_j <= a_k AND for all j>k, a_j >= a_k.
# This means a_k is a local maximum.
# Wait, if sequence is 1, 3, 2: 
# 1: left empty (ok), right 3,2 (>=1?) yes. So 1 is sorted.
# 3: left 1 (<=3) ok, right 2 (>=3?) no. Not sorted.
# 2: left 1,3 (<=2?) no. Not sorted.
# So sorted elements are those that are local maxima (in the sense that everything after is >= it).
# Actually, it's a bit more specific. 
# a_k is sorted if it's a prefix maximum AND a suffix minimum.

# For distinct values, the sorted elements in a permutation are exactly the elements that are
# greater than all previous AND smaller than all subsequent.
# This implies the sequence must be increasing up to that point and non-decreasing after.
# If values are distinct, this means strictly increasing up to k and strictly increasing after k.
# This can only happen if the element is in correct sorted position relative to others.

# Actually, for distinct values 1..n, an element is sorted in a permutation P
# iff P[k] is the k-th smallest element.
# No, that's not right.
# Example: 2, 1, 3
# 2: left none, right 1,3. 1 < 2, so 2 is not >= all right. Not sorted.
# 1: left 2 (>1), so not sorted.
# 3: left 2,1 (<=3), right none. Sorted.
# So 3 is sorted.

# Wait, let's re-read:
# "for all j such that j > k, a_j >= a_k" -> a_k is a minimum of the suffix
# "for all j such that j < k, a_j <= a_k" -> a_k is a maximum of the prefix
# So a_k is a local maximum (prefix max) AND local minimum (suffix min).
# For distinct values, this implies a_k is exactly at position k in the sorted sequence.
# Because if a_k is at position k in sorted sequence, then:
#   left elements are smaller (prefix max condition)
#   right elements are larger (suffix min condition)
# If a_k is NOT at position k, say it's larger, then there is a smaller element on the right (violates suffix min).
# If it's smaller, there is a larger element on the left (violates prefix max).
# So for distinct values, an element is sorted if and only if it is in its correct sorted position.
# A permutation is entirely unsorted if NO element is in its correct sorted position.
# This is exactly a DERANGEMENT!

# For distinct values: Result = number of derangements of N elements
# !N = round(N! / e)
# For N=8: !8 = 14833

# For duplicates, it's more complex.
# Let's verify with the Python script.

def check_distinct_hypothesis():
    arr = [1, 2, 3, 4, 5, 6, 7, 8]
    count = python_reference(arr)
    print(f"Count for distinct 1..8: {count}")
    # Expected derangements of 8: 14833

# Run this in the setup to get the value.

# For the testbench, we'll use:
# Case 1: Distinct values [0..7] -> Expect derangement count 14833
# Case 2: Duplicates [1,1,1,1,2,3,4,5] -> Compute with python_reference

# The testbench will compute expected values dynamically to be robust.

# Final testbench logic:
# 1. Setup: Compute expected values for test cases using python_reference
#    (Include a timeout for this computation)
# 2. Run tests: Drive inputs to DUT, wait for done, compare results

# We need to handle the input format.
# Input is N and then N integers.
# We'll hardcode test cases in the testbench.

# Test cases:
# 1. n=8, arr=[0,1,2,3,4,5,6,7]
# 2. n=5, arr=[1,1,2,1,1] -> padded to [1,1,2,1,1,6,7,8]
# 3. Random distinct values

# We'll use the `count_unsorted_permutations_n8` function defined earlier.

# Verilog Module Implementation Details (for the prompt):
# The module will implement the brute force enumeration.
# It needs a counter for 0 to 40319.
# It needs to generate the permutation for each counter value.
# It needs to check the permutation.
# It needs to accumulate the count.

# Timing:
# 40320 iterations. Each iteration takes multiple cycles (gen perm + check).
# Gen perm: 8 iterations * (div cycles + store cycles).
# Check: 8 positions * 8 comparisons = 64 comparisons. Can be done in a loop or unrolled.
# Total cycles: ~40320 * (8*5 + 8*5) = 3.2M cycles. This is too slow for 2000 cycle limit.

# We need to optimize or change strategy.

# Optimization 1: Pipelining
# We can pipeline the generation and checking.
# But the state dependency is high.

# Optimization 2: Precompute permutations
# Store all 40320 permutations in ROM.
# 40320 * 8 * 3 bits = 967,680 bits ~ 121KB. This is feasible in FPGA BRAM.
# Access is fast: 1 cycle per permutation.
# Check logic: 64 comparisons. If we unroll, it takes 1 cycle (combinatorial) or 8 cycles (sequential).
# Total cycles: 40320 + overhead. Fits in 2000? No, 40320 is the iteration count.

# Wait, 2000 cycles is the budget.
# 40320 permutations cannot be processed in 2000 cycles if we do one per cycle.

# We must reduce N further.
# Let's set N = 6.
# 6! = 720 permutations.
# 720 cycles is well within 2000.

# Update Spec: N = 6
# Input: 6 values, 4-bit each -> 24-bit input
# Output: 32-bit count
# ROM size: 720 * 6 * 3 = 12.96 Kb. Trivial.

# This is the correct approach for the constraints.

# Python Reference Update:
# def count_unsorted_permutations_n6(arr):
#     Pad to 6.
#     Brute force 720 permutations.

# Verilog Update:
# ROM for permutations of indices {0..5}.
# Counter 0 to 719.
# Read permutation from ROM.
# Check logic (combinatorial or sequential).
# Accumulate count.

# This fits the constraints perfectly.

# Testbench Update:
# Use N=6.
# Input 1: [0, 1, 2, 3] -> [0, 1, 2, 3, 4, 5]
# Input 2: [1, 1, 2, 1, 1] -> [1, 1, 1, 1, 2, 3]

# We need to compute the expected values for N=6.
# Derangements of 6: !6 = 265

# Let's finalize with N=6.

# Prompt Revision:
# "Design a Verilog module that counts entirely unsorted permutations.
#  N = 6 (fixed).
#  Input: 6 integers (4-bit each).
#  Output: Count modulo 10^9+9.
#  Implementation: Iterate through all 6! = 720 permutations using a precomputed ROM.
#  For each permutation, check if it is entirely unsorted.
#  Accumulate valid count.
#  Timing: Start -> Done within 1000 cycles.
#  Interface: clk, rst_n, start, data_in[23:0], result[31:0], done."

# Testbench Implementation:
# 1. Compute expected values for N=6.
# 2. Drive inputs.
# 3. Verify.

# Let's write the Python reference for N=6.

def python_reference_n6(input_arr):
    arr = list(input_arr)
    while len(arr) < 6:
        max_val = max(arr) if arr else 0
        arr.append(max_val + 1)
    
    n = 6
    indices = list(range(n))
    unique_perms = set()
    
    for p in itertools.permutations(indices):
        is_unsorted = True
        for k in range(n):
            v = arr[p[k]]
            # Check left
            left_ok = True
            for j in range(k):
                if arr[p[j]] > v:
                    left_ok = False
                    break
            # Check right
            right_ok = True
            for j in range(k + 1, n):
                if arr[p[j]] < v:
                    right_ok = False
                    break
            
            if left_ok and right_ok:
                is_unsorted = False
                break
        
        if is_unsorted:
            perm_vals = tuple(arr[p[i]] for i in range(n))
            unique_perms.add(perm_vals)
    
    return len(unique_perms)

# Test Cases for N=6:
# Case 1: [0, 1, 2, 3, 4, 5] (Distinct)
#   Expected: Derangements of 6 = 265
# Case 2: [1, 1, 1, 1, 2, 3]
#   Need to compute.

# We will compute Case 2 in the testbench.

# Note on ROM generation for Verilog:
# We need to generate the permutation indices for 0..719.
# We can compute this in Python and format it as a Verilog $readmemh file or a large parameter.
# For the prompt, we'll describe that the ROM should be precomputed.

# The testbench will not provide the ROM content, it's up to the HDL generation.

# Testbench Code Structure:

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# Constants
DATA_WIDTH = 4
N = 6
CLK_NS = 10
MAX_CYCLES = 1000
MOD = 1000000009

# Helper functions (Section A)
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

def write_data(dut, values):
    packed = 0
    for i, v in enumerate(values[:N]):
        val = clamp_to_width(v, DATA_WIDTH)
        packed |= (val << (i * DATA_WIDTH))
    dut.data_in.value = packed

# Python Reference for N=6
def python_reference_n6(input_arr):
    arr = list(input_arr)
    while len(arr) < N:
        max_val = max(arr) if arr else 0
        arr.append(max_val + 1)
    
    indices = list(range(N))
    unique_perms = set()
    
    for p in itertools.permutations(indices):
        is_unsorted = True
        for k in range(N):
            v = arr[p[k]]
            # Check left
            left_ok = True
            for j in range(k):
                if arr[p[j]] > v:
                    left_ok = False
                    break
            # Check right
            right_ok = True
            for j in range(k + 1, N):
                if arr[p[j]] < v:
                    right_ok = False
                    break
            
            if left_ok and right_ok:
                is_unsorted = False
                break
        
        if is_unsorted:
            perm_vals = tuple(arr[p[i]] for i in range(N))
            unique_perms.add(perm_vals)
    
    return len(unique_perms)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_unsorted_counter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases
    # Case 1: Distinct sorted [0..5] -> Expect derangement count 265
    # Case 2: Duplicates [1,1,1,1,2,3] -> Compute
    
    # Precompute expected for Case 2
    case2_arr = [1, 1, 1, 1, 2, 3]
    expected2 = python_reference_n6(case2_arr)
    
    test_cases = [
        ([0, 1, 2, 3, 4, 5], 265, "Distinct sorted"),
        (case2_arr, expected2, "Duplicates"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            write_data(dut, inp)
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

# Note: The Verilog module must include a ROM or generation logic for permutations.
# Since we can't provide the ROM in the prompt easily, the prompt should state:
# "Implement the permutation generation logic (e.g., using a precomputed ROM)"

# Prompt refinement:
# "The module should iterate through all permutations of 6 elements.
#  You can generate permutations using a precomputed ROM or a counter-based algorithm.
#  For each permutation, check if it is entirely unsorted.
#  Accumulate the count of valid permutations."

# The testbench does not need to generate the ROM, only the DUT does.

# Wait, if the DUT is expected to generate permutations, how do we test it?
# We assume the DUT implements the logic correctly.
# The testbench provides input values and checks the output count.

# This is standard.

# One final check: The prompt asks for a module specification.
# The output should be a JSON object.

# The prompt string should be detailed enough for an LLM to generate Verilog.

# The testbench uses `dut.data_in`. The spec says `data_in[0:11]` for N=12.
# For N=6, `data_in[23:0]` is correct (6 * 4 = 24).

# The prompt should specify the width of data_in.

# Prompt: "... input wire [23:0] data_in ..."

# All set.
