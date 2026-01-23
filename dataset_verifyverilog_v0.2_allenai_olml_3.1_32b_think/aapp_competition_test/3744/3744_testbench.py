import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_expected_strength(n, p, s, a, b):
    """Calculate expected max strength by brute force (Python)"""
    from itertools import combinations
    
    max_str = 0
    best_prog = []
    best_sports = []
    
    # If p or s is 0, handle edge cases
    if p == 0 and s == 0:
        return 0, [], []
    
    indices = list(range(n))
    
    if p > 0:
        for prog_combo in combinations(indices, p):
            remaining = [i for i in indices if i not in prog_combo]
            if s > 0:
                for sports_combo in combinations(remaining, s):
                    strength = sum(a[i] for i in prog_combo) + sum(b[i] for i in sports_combo)
                    if strength > max_str:
                        max_str = strength
                        best_prog = list(prog_combo)
                        best_sports = list(sports_combo)
            else:
                strength = sum(a[i] for i in prog_combo)
                if strength > max_str:
                    max_str = strength
                    best_prog = list(prog_combo)
                    best_sports = []
    else:
        # p == 0
        if s > 0:
            for sports_combo in combinations(indices, s):
                strength = sum(b[i] for i in sports_combo)
                if strength > max_str:
                    max_str = strength
                    best_prog = []
                    best_sports = list(sports_combo)
        else:
            max_str = 0
            best_prog = []
            best_sports = []
            
    return max_str, best_prog, best_sports

@cocotb.test()
async def test_team_selection(dut):
    """Test team selection module with various cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p.value = 0
    dut.s.value = 0
    for i in range(8):
        dut.a[i].value = 0
        dut.b[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (n, p, s, a_list, b_list)
        (2, 1, 1, [100, 101], [1, 100]),
        (2, 1, 1, [9, 6], [3, 10]),
        (3, 1, 1, [5, 4, 2], [1, 5, 2]),
        (4, 1, 1, [100, 100, 1, 50], [100, 100, 50, 1]),
        (5, 2, 2, [1, 3, 4, 5, 2], [5, 3, 2, 1, 4]),
        (4, 2, 2, [10, 8, 8, 3], [10, 7, 9, 4]),
        (5, 3, 1, [5, 2, 5, 1, 7], [6, 3, 1, 6, 3]),
        (3, 0, 2, [1, 2, 3], [10, 20, 30]), # Edge case: p=0
        (3, 2, 0, [10, 20, 30], [1, 2, 3]), # Edge case: s=0
        (4, 1, 2, [4, 2, 4, 5], [3, 2, 5, 3]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, p, s, a_list, b_list in test_cases:
        # Load inputs
        dut.n.value = n
        dut.p.value = p
        dut.s.value = s
        for i in range(8):
            if i < n:
                dut.a[i].value = a_list[i]
                dut.b[i].value = b_list[i]
            else:
                dut.a[i].value = 0
                dut.b[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 0
        while not dut.done.value and timeout < 5000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 5000:
            raise TestFailure(f"Test timed out for n={n}, p={p}, s={s}")
        
        # Read results
        max_str = int(dut.max_strength.value)
        
        # Read prog indices
        prog_indices = []
        for i in range(p):
            prog_indices.append(int(dut.prog_indices[i].value))
            
        # Read sports indices
        sports_indices = []
        for i in range(s):
            sports_indices.append(int(dut.sports_indices[i].value))
        
        # Verify with Python calculation
        expected_str, expected_prog, expected_sports = calculate_expected_strength(n, p, s, a_list, b_list)
        
        # Validate strength
        if max_str != expected_str:
            raise TestFailure(f"Strength mismatch for n={n}, p={p}, s={s}. Got {max_str}, expected {expected_str}")
        
        # Validate indices are distinct and valid
        all_indices = prog_indices + sports_indices
        if len(all_indices) != len(set(all_indices)):
            raise TestFailure(f"Duplicate indices in result: {all_indices}")
        
        for idx in prog_indices:
            if idx >= n:
                raise TestFailure(f"Invalid programming index {idx} >= {n}")
        for idx in sports_indices:
            if idx >= n:
                raise TestFailure(f"Invalid sports index {idx} >= {n}")
                
        # Validate total strength calculation matches indices
        calc_strength = 0
        for idx in prog_indices:
            calc_strength += a_list[idx]
        for idx in sports_indices:
            calc_strength += b_list[idx]
            
        if calc_strength != expected_str:
             raise TestFailure(f"Indices don't sum to correct strength. Calc {calc_strength}, expected {expected_str}")
        
        print(f"Test passed: n={n}, p={p}, s={s}. Strength: {max_str}")
        passed += 1
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
