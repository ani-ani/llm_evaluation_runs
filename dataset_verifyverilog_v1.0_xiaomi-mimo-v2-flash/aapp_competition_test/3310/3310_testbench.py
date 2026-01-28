import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for Q16.16
FRAC_BITS = 16
INT_BITS = 16
SCALE = 1 << FRAC_BITS
MAX_FIXED = (1 << (INT_BITS + FRAC_BITS)) - 1

def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f):
    return int(f * SCALE)

def fixed_to_float(f):
    return f / SCALE

def python_expected(n, g, t, tables):
    """Pure Python reference for expected value"""
    # Scale inputs to max 16
    tables_scaled = [min(16, max(1, int(t/12.5))) for t in tables]
    g_scaled = min(16, max(1, int(g/12.5)))
    t_scaled = min(16, max(1, int(t/12.5)))
    n_scaled = min(16, n)
    tables_scaled.sort()
    
    # DP: probability of state
    # State: (mask, occupied_people)
    # mask: bitmask of occupied tables
    # For simplicity, track total people and which tables are occupied
    # Since we need to find smallest fit, we need to know which tables are occupied
    
    # State representation: (mask, last_table_used?) - actually need exact state
    # Simplified: For each table, if occupied, what group size? (1-16)
    # But 16 tables * 16 sizes = huge. Instead, track mask and total people.
    # We'll compute expected value directly via DP.
    
    # For each hour, update probability distribution
    # state: frozenset of occupied tables (by index)
    # value: expected people in those tables
    
    from collections import defaultdict
    dp = defaultdict(float)
    dp[frozenset()] = 0.0  # No people, empty
    
    for hour in range(t_scaled):
        new_dp = defaultdict(float)
        for occupied, people in dp.items():
            for size in range(1, g_scaled + 1):
                # Find smallest table that fits and is unoccupied
                assigned = None
                for i, cap in enumerate(tables_scaled):
                    if i not in occupied and cap >= size:
                        assigned = i
                        break
                
                prob = 1.0 / g_scaled
                if assigned is not None:
                    new_occupied = occupied | {assigned}
                    new_people = people + size
                else:
                    new_occupied = occupied
                    new_people = people
                new_dp[new_occupied] += prob * new_people
        dp = new_dp
    
    return sum(dp.values())  # Actually sum of people * prob, but dp stores expected people per state
    # Wait, dp stores sum of people for that state? No, we need expectation.
    # Correct: dp[state] = probability of that state, track people separately.
    # Let's recompute properly.
    
    # Proper DP: state -> (probability, total_people)
    # Actually, we can track expected people directly.
    # dp: probability of each occupancy mask
    # people: expected people in each occupancy mask
    
    dp_prob = {frozenset(): 1.0}
    dp_people = {frozenset(): 0.0}
    
    for hour in range(t_scaled):
        new_prob = defaultdict(float)
        new_people = defaultdict(float)
        for occupied, prob in dp_prob.items():
            current_people = dp_people[occupied]
            for size in range(1, g_scaled + 1):
                assigned = None
                for i, cap in enumerate(tables_scaled):
                    if i not in occupied and cap >= size:
                        assigned = i
                        break
                prob_add = prob / g_scaled
                if assigned is not None:
                    new_occupied = occupied | {assigned}
                    new_prob[new_occupied] += prob_add
                    new_people[new_occupied] += current_people + size
                else:
                    new_prob[occupied] += prob_add
                    new_people[occupied] += current_people
        dp_prob, dp_people = new_prob, new_people
    
    total = 0.0
    for occupied in dp_prob:
        total += dp_people[occupied] * 1.0  # Already sum of people * prob
    return total

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, name)[i].value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_restaurant(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (3, 3, 2, [1, 2, 3]),
        (4, 11, 4, [10, 10, 10, 10]),
        (4, 3, 3, [4, 1, 3, 2]),
    ]
    
    for i, (n, g, t, tables) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={n}, g={g}, t={t}, tables={tables}")
        
        # Scale inputs
        n_scaled = min(16, n)
        g_scaled = min(16, max(1, int(g/12.5)))
        t_scaled = min(16, max(1, int(t/12.5)))
        tables_scaled = [min(16, max(1, int(c/12.5))) for c in tables]
        tables_sorted = sorted(tables_scaled)
        
        # Write inputs
        dut.n.value = n_scaled
        dut.g.value = g_scaled
        dut.t.value = t_scaled
        for j in range(16):
            val = tables_sorted[j] if j < len(tables_sorted) else 0
            dut.c[j].value = val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result_fp = int(dut.result.value)
        result_f = fixed_to_float(result_fp)
        
        # Compute expected
        expected = python_expected(n, g, t, tables)
        
        # Compare
        error = abs(result_f - expected)
        rel_error = error / expected if expected > 0 else error
        
        if rel_error > 1e-3 and error > 1e-3:
            raise TestFailure(f"Test {i+1}: Expected {expected:.6f}, got {result_f:.6f}, error {error:.6f}")
        
        cocotb.log.info(f"Test {i+1}: Pass - Expected {expected:.6f}, Got {result_f:.6f}")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_edge_cases(dut):
    # Single table, single group, single hour
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    n, g, t = 1, 1, 1
    tables = [10]
    
    dut.n.value = 1
    dut.g.value = 1
    dut.t.value = 1
    dut.c[0].value = 16  # Scaled to max
    for j in range(1, 16):
        dut.c[j].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    result_fp = int(dut.result.value)
    result_f = fixed_to_float(result_fp)
    expected = python_expected(n, g, t, tables)
    
    if abs(result_f - expected) > 1e-3:
        raise TestFailure(f"Edge case: Expected {expected:.6f}, got {result_f:.6f}")
    cocotb.log.info(f"Edge case: Pass - Expected {expected:.6f}, Got {result_f:.6f}")