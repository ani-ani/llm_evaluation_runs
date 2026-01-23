import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def expected_occupancy_python(n, g, t, capacities):
    """Calculate expected occupancy using DP for verification."""
    # State: tuple of which tables are occupied (0=empty, 1=occupied)
    # For small n, use integer state encoding
    # dp[state] = (probability, expected_occupancy_sum)
    
    dp = {}
    # Initial state: all empty (0), probability 1.0, expected 0.0
    dp[0] = (1.0, 0.0)
    
    for hour in range(t):
        new_dp = {}
        for state, (prob, exp_occ) in dp.items():
            # For each possible group size
            for s in range(1, g + 1):
                # Find smallest unoccupied table that fits
                found = False
                new_state = state
                added_people = 0
                for i in range(n):
                    if not (state & (1 << i)):  # table i is empty
                        if capacities[i] >= s:  # fits
                            # Occupy this table
                            new_state = state | (1 << i)
                            added_people = s
                            found = True
                            break
                # Probability of this group size is 1/g
                prob_contribution = prob / g
                exp_contribution = exp_occ + prob_contribution * added_people
                if new_state not in new_dp:
                    new_dp[new_state] = (0.0, 0.0)
                prev_prob, prev_exp = new_dp[new_state]
                new_dp[new_state] = (prev_prob + prob_contribution, prev_exp + exp_contribution)
        dp = new_dp
    
    # Sum expected occupancy over all final states
    total_exp = 0.0
    for state, (prob, exp_occ) in dp.items():
        total_exp += exp_occ
    return total_exp

def to_fixed_point(value):
    """Convert float to Q16.16 fixed-point integer."""
    return int(value * 65536)

def from_fixed_point(value):
    """Convert Q16.16 fixed-point integer to float."""
    return value / 65536.0

@cocotb.test()
async def test_restaurant_occupancy_basic(dut):
    """Test basic functionality with small inputs."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    dut.t_in.value = 0
    dut.g_in.value = 0
    for i in range(8):
        setattr(dut, f'capacity_{i}').value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: n=3, g=3, t=2, capacities=[1,2,3]
    n, g, t = 3, 3, 2
    capacities = [1, 2, 3]
    expected = expected_occupancy_python(n, g, t, capacities)
    
    dut.n_in.value = n
    dut.t_in.value = t
    dut.g_in.value = g
    for i in range(8):
        if i < n:
            getattr(dut, f'capacity_{i}').value = capacities[i]
        else:
            getattr(dut, f'capacity_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_fixed_point(dut.expected_occupancy.value)
    print(f"Test 1: Expected={expected:.9f}, Got={result:.9f}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_restaurant_occupancy_all_same(dut):
    """Test case where all tables have same capacity."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 2: n=4, g=4, t=4, capacities=[3,3,3,3] (scaled from 10)
    n, g, t = 4, 4, 4
    capacities = [3, 3, 3, 3]
    expected = expected_occupancy_python(n, g, t, capacities)
    
    dut.n_in.value = n
    dut.t_in.value = t
    dut.g_in.value = g
    for i in range(8):
        if i < n:
            getattr(dut, f'capacity_{i}').value = capacities[i]
        else:
            getattr(dut, f'capacity_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_fixed_point(dut.expected_occupancy.value)
    print(f"Test 2: Expected={expected:.9f}, Got={result:.9f}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_restaurant_occupancy_mixed(dut):
    """Test case with mixed capacities."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 3: n=4, g=3, t=3, capacities=[4,1,3,2]
    n, g, t = 4, 3, 3
    capacities = [4, 1, 3, 2]
    expected = expected_occupancy_python(n, g, t, capacities)
    
    dut.n_in.value = n
    dut.t_in.value = t
    dut.g_in.value = g
    for i in range(8):
        if i < n:
            getattr(dut, f'capacity_{i}').value = capacities[i]
        else:
            getattr(dut, f'capacity_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_fixed_point(dut.expected_occupancy.value)
    print(f"Test 3: Expected={expected:.9f}, Got={result:.9f}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_restaurant_occupancy_edge_cases(dut):
    """Test edge cases: 1 table, 1 hour, etc."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Edge case: n=1, g=2, t=2, capacity=[2]
    n, g, t = 1, 2, 2
    capacities = [2]
    expected = expected_occupancy_python(n, g, t, capacities)
    
    dut.n_in.value = n
    dut.t_in.value = t
    dut.g_in.value = g
    for i in range(8):
        if i < n:
            getattr(dut, f'capacity_{i}').value = capacities[i]
        else:
            getattr(dut, f'capacity_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = from_fixed_point(dut.expected_occupancy.value)
    print(f"Edge Test: Expected={expected:.9f}, Got={result:.9f}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

print("Cocotb testbench loaded. Run with: pytest -s")