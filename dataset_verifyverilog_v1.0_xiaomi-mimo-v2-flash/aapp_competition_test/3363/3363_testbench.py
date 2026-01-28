import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

# Compute expected result for verification
def compute_expected(m, calories):
    n = len(calories)
    # DP table: dp[i][streak][skip] = max calories up to hour i
    # streak: 0,1,2 (2 means rate was reset)
    # skip: 0,1 (0 means ate previous, 1 means skipped previous)
    dp = [[[-1 for _ in range(2)] for _ in range(3)] for _ in range(n+1)]
    dp[0][0][0] = 0  # Initial state before any hour
    
    for i in range(n):
        for streak in range(3):
            for skip in range(2):
                if dp[i][streak][skip] == -1:
                    continue
                base = dp[i][streak][skip]
                
                # Calculate current rate
                if i == 0:
                    rate = m
                else:
                    if skip == 1:
                        # Skipped previous hour
                        if streak == 2:
                            # Already reset, full rate
                            rate = m
                        else:
                            # Continue previous streak rate
                            rate = m
                            for _ in range(streak):
                                rate = (rate * 171) >> 8  # floor(2/3 * rate)
                    else:
                        # Ate previous hour
                        if streak == 2:
                            # After reset
                            rate = m
                        else:
                            rate = m
                            for _ in range(streak):
                                rate = (rate * 171) >> 8
                
                # Option 1: Eat this hour
                eat_val = min(calories[i], rate)
                new_streak = min(streak + 1, 2)
                if new_streak == 2 and skip == 1:
                    # Two consecutive skips after reset? No, if ate, streak increases
                    new_streak = 1  # Actually need careful tracking
                # Simpler: track consecutive eats
                if skip == 1:
                    # Just ate after skip
                    new_consecutive = 1
                else:
                    new_consecutive = streak + 1
                if new_consecutive > 2:
                    new_consecutive = 2
                
                # Update DP for eat
                eat_total = base + eat_val
                if eat_total > dp[i+1][new_consecutive][0]:
                    dp[i+1][new_consecutive][0] = eat_total
                
                # Option 2: Skip this hour
                new_skip = 1
                new_streak_skip = streak
                if skip == 1:
                    # Two skips in a row
                    new_streak_skip = 2
                
                if base > dp[i+1][new_streak_skip][new_skip]:
                    dp[i+1][new_streak_skip][new_skip] = base
    
    # Find maximum at end
    result = 0
    for streak in range(3):
        for skip in range(2):
            if dp[n][streak][skip] > result:
                result = dp[n][streak][skip]
    return result

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, f'{name}_{i}').value = clamp_to_width(v, width)

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

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_calorie_optimizer(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (m, calories_list)
    test_cases = [
        (900, [800, 700, 400, 300, 200]),  # Expected: 2243
        (900, [800, 700, 40, 300, 200]),   # Expected: 1900
    ]
    
    passed = 0
    failed = 0
    
    for i, (m, calories) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: m={m}, calories={calories}")
        
        try:
            expected = compute_expected(m, calories)
            cocotb.log.info(f"Expected result: {expected}")
            
            # Set inputs
            if has_signal(dut, 'm'):
                dut.m.value = clamp_to_width(m, 8)
            
            # Write calories array
            for j, cal in enumerate(calories):
                if has_signal(dut, f'calories_{j}'):
                    getattr(dut, f'calories_{j}').value = clamp_to_width(cal, 8)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"Computed result: {result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"Test case {i+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test case {i+1} FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"All tests passed: {passed} out of {passed+failed}")