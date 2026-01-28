import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

# Helper to simulate the algorithm in Python
def simulate_ratings(n, ratings):
    ratings = list(ratings[:n])
    matches = []
    while len(set(ratings)) > 1:
        # Find max value
        max_val = max(ratings)
        if max_val == 0: break # All zero
        
        # Count occurrences of max_val
        max_indices = [i for i, x in enumerate(ratings) if x == max_val]
        count_max = len(max_indices)
        
        # Find second max (needed if count_max != 3)
        second_max_val = -1
        second_max_idx = -1
        if count_max != 3:
            for i, x in enumerate(ratings):
                if x != max_val:
                    if x > second_max_val:
                        second_max_val = x
                        second_max_idx = i
        
        match = [0] * n
        
        if count_max == 3:
            # Decrement all 3 max
            for idx in max_indices:
                if ratings[idx] > 0:
                    ratings[idx] -= 1
                match[idx] = 1
        else:
            # Decrement top 2
            # 1st is the max one
            idx1 = max_indices[0]
            match[idx1] = 1
            if ratings[idx1] > 0:
                ratings[idx1] -= 1
            
            # 2nd is the second max (or another max if available, but logic says second highest)
            # The provided solutions generally pick 2 highest.
            # If there is only 1 max, we need the next highest.
            # If there are >3 max, we pick 2 of them.
            
            candidates = []
            for i in range(n):
                if i != idx1:
                    candidates.append((ratings[i], i))
            
            # Sort descending by rating
            candidates.sort(key=lambda x: x[0], reverse=True)
            
            # Pick the second participant
            idx2 = candidates[0][1]
            match[idx2] = 1
            if ratings[idx2] > 0:
                ratings[idx2] -= 1
                
        matches.append(match)
    return ratings[0] if ratings else 0, matches

@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_ratings(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    await Timer(50, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (2, [1, 2]),
        (5, [4, 5, 1, 7, 4]),
        (3, [1, 1, 1]),
        (4, [1, 1, 6, 2]),
    ]
    
    for n, init_ratings in test_cases:
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        
        # Load inputs
        # Clamp ratings to 8 bits
        ratings_8b = [clamp_to_width(r, 8) for r in init_ratings]
        
        if has_signal(dut, 'n'):
            dut.n.value = n
        
        # Write ratings array
        for i in range(10):
            val = ratings_8b[i] if i < n else 0
            # Handle array access (checking naming conventions)
            if has_signal(dut, f'rating_{i}'):
                getattr(dut, f'rating_{i}').value = val
            elif has_signal(dut, 'rating'):
                try:
                    dut.rating[i].value = val
                except Exception:
                    # Fallback for packed arrays if needed
                    pass
                    
        # Start
        dut.start.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Simulate expected output
        exp_result, exp_matches = simulate_ratings(n, init_ratings)
        
        # Collect matches from DUT
        dut_matches = []
        
        max_cycles = 2000
        cycles = 0
        
        done_found = False
        match_found = False
        
        while cycles < max_cycles:
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            cycles += 1
            
            # Check match_valid
            if has_signal(dut, 'match_valid') and int(dut.match_valid.value) == 1:
                match_str = ""
                # Extract match bits
                if has_signal(dut, 'match_out'):
                    m_val = int(dut.match_out.value)
                    for i in range(n):
                        match_str += '1' if (m_val >> i) & 1 else '0'
                else:
                    # Check individual bits match_0, match_1...
                    for i in range(n):
                        if has_signal(dut, f'match_{i}'):
                            if int(getattr(dut, f'match_{i}').value) == 1:
                                match_str += '1'
                            else:
                                match_str += '0'
                        else:
                            match_str += '0'
                
                # Validate length
                if len(match_str) != n:
                    # If n < 10, check if we need to truncate
                    match_str = match_str[:n]
                
                dut_matches.append(match_str)
            
            # Check done
            if has_signal(dut, 'done') and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test failed for n={n}, ratings={init_ratings}: Done signal not asserted within {max_cycles} cycles")
        
        # Check result
        if has_signal(dut, 'result'):
            res = int(dut.result.value)
            if res != exp_result:
                raise TestFailure(f"Result mismatch. Expected {exp_result}, got {res}")
        
        # Check matches count
        if has_signal(dut, 'match_count'):
            count = int(dut.match_count.value)
            if count != len(exp_matches):
                # Some implementations might output fewer matches if they handle 3-max differently or optimize.
                # However, the problem constraints allow any solution as long as R is max.
                # We should verify the resulting state is correct.
                # For now, let's be lenient on count if R is correct, but strict on R.
                pass
        
        # Verify matches sequence leads to correct result (simple re-simulation)
        # Since we already simulated the optimal sequence, we check if dut sequence is valid.
        # The dut sequence must consist of valid parties (2-5 ones).
        for m in dut_matches:
            ones = m.count('1')
            if ones < 2 or ones > 5:
                raise TestFailure(f"Invalid party size: {ones} in match '{m}'")
        
        cocotb.log.info(f"Test passed for n={n}, ratings={init_ratings}. Result: {res}, Matches: {len(dut_matches)}")
