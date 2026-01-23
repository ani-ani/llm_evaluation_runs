import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_capacity(m, consecutive):
    """Calculate capacity for consecutive eating hours"""
    cap = m
    for _ in range(consecutive - 1):
        cap = int(cap * 2 / 3)
    return cap

def calculate_optimal(m, courses):
    """Calculate optimal calories using DP (reference model)"""
    n = len(courses)
    # dp[hour][streak][skip][cap_idx] = max calories
    # streak: 0-4 (consecutive eats so far)
    # skip: 0-2 (consecutive skips)
    # cap_idx: 0-3 (which capacity level we're at)
    
    # Precompute capacities
    caps = [0] * 4
    caps[0] = m
    for i in range(1, 4):
        caps[i] = int(caps[i-1] * 2 / 3)
    
    # Initialize DP table
    dp = [[[[0] * 4 for _ in range(3)] for _ in range(5)] for _ in range(n + 1)]
    
    # Base case: before any hours
    dp[0][0][0][0] = 0
    
    for hour in range(n):
        for streak in range(5):
            for skip in range(3):
                for cap_idx in range(4):
                    if dp[hour][streak][skip][cap_idx] == 0 and not (streak == 0 and skip == 0 and cap_idx == 0 and hour == 0):
                        continue
                    
                    current_val = dp[hour][streak][skip][cap_idx]
                    
                    # Option 1: Eat
                    if streak == 0:
                        # No current streak - start fresh
                        if skip <= 1:  # 0 or 1 skip, use current cap_idx
                            capacity = caps[cap_idx]
                        else:  # 2+ skips, reset to m
                            capacity = m
                    else:
                        # In a streak - use capacity based on streak count
                        capacity = calculate_capacity(m, streak)
                    
                    if capacity >= courses[hour]:
                        # Determine new state
                        if streak == 4:
                            new_streak = 4
                            new_cap_idx = min(3, cap_idx + 1)
                        else:
                            new_streak = streak + 1 if streak > 0 else 1
                            new_cap_idx = cap_idx
                        
                        new_val = current_val + courses[hour]
                        if new_val > dp[hour + 1][new_streak][0][new_cap_idx]:
                            dp[hour + 1][new_streak][0][new_cap_idx] = new_val
                    
                    # Option 2: Skip
                    if skip < 2:
                        new_skip = skip + 1
                    else:
                        new_skip = 2
                    
                    new_val = current_val
                    # After 2 skips, reset cap_idx to 0
                    new_cap_idx = 0 if skip == 1 else cap_idx
                    
                    if new_val > dp[hour + 1][0][new_skip][new_cap_idx]:
                        dp[hour + 1][0][new_skip][new_cap_idx] = new_val
    
    # Find max over all final states
    max_calories = 0
    for streak in range(5):
        for skip in range(3):
            for cap_idx in range(4):
                if dp[n][streak][skip][cap_idx] > max_calories:
                    max_calories = dp[n][streak][skip][cap_idx]
    
    return max_calories

@cocotb.test()
async def test_calorie_optimizer(dut):
    """Test calorie optimizer with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    for i in range(10):
        setattr(dut, f'courses_{i}', 0)
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (m, n, courses, expected)
        (900, 5, [800, 700, 400, 300, 200], 2243),
        (900, 5, [800, 700, 40, 300, 200], 1900),
        (500, 4, [400, 400, 400, 400], 1400),  # Force skips due to capacity
        (100, 3, [100, 100, 100], 267),  # Consecutive reduction
        (1000, 2, [500, 500], 1000),  # Simple case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (m, n, courses, expected) in enumerate(test_cases):
        print(f"
Test case {idx + 1}: m={m}, n={n}, courses={courses}, expected={expected}")
        
        # Load inputs
        dut.m.value = m
        dut.n.value = n
        for i in range(n):
            setattr(dut, f'courses_{i}', courses[i])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 1000:
            print(f"  FAILED: Timeout waiting for done signal")
            continue
        
        # Read result
        result = int(dut.result.value)
        print(f"  Result: {result}")
        
        if result == expected:
            print(f"  PASSED")
            passed += 1
        else:
            print(f"  FAILED: Expected {expected}, got {result}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
