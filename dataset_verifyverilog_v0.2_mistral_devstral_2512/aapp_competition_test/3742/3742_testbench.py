import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to convert test case to binary format for Verilog
def format_input(n, arr):
    # Pad to 16 positions
    padded = arr + [0] * (16 - len(arr))
    return padded

# Reference solution in Python (adapted for small N)
def solve_python(n, arr):
    # Count fixed odds/evens
    fixed_odd = 0
    fixed_even = 0
    missing = 0
    for x in arr:
        if x != 0:
            if x % 2 == 1:
                fixed_odd += 1
            else:
                fixed_even += 1
        else:
            missing += 1
    
    total_odd = (n + 1) // 2
    total_even = n // 2
    
    need_odd = total_odd - fixed_odd
    need_even = total_even - fixed_even
    
    # Simple DP for small N
    # dp[i][used_odd][last_parity] = min complexity
    INF = 1000
    # We need to fill missing positions
    
    # Extract positions and types
    positions = []
    for i, x in enumerate(arr):
        if x == 0:
            positions.append(i)
    
    # Try all assignments of missing positions (brute force for small missing)
    # Since missing <= 8, 2^8 = 256 max
    min_complex = INF
    
    # Instead of brute force, use DP
    # dp[pos_idx][used_odd][last_parity] = min cost
    m = len(positions)
    if m == 0:
        # Just calculate complexity of fixed array
        cost = 0
        prev_parity = -1
        for i in range(n):
            if arr[i] != 0:
                curr_parity = arr[i] % 2
                if prev_parity != -1 and prev_parity != curr_parity:
                    cost += 1
                prev_parity = curr_parity
        return cost
    
    # DP for filling missing positions
    # We need to track original indices to compute adjacent costs
    # Let's use a simpler approach: simulate the array
    
    # Pre-compute the structure
    # positions = indices where 0 exists
    # We need to decide 0 -> odd (1) or even (0)
    
    # dp[used_odd][last_parity] = min cost up to current position
    dp = {}
    dp[(0, -1)] = 0
    
    # Iterate through all positions 0 to n-1
    for i in range(n):
        new_dp = {}
        if arr[i] != 0:
            curr_parity = arr[i] % 2
            for (used_odd, last_parity), cost in dp.items():
                add_cost = 0
                if last_parity != -1 and last_parity != curr_parity:
                    add_cost = 1
                key = (used_odd, curr_parity)
                if key not in new_dp or new_dp[key] > cost + add_cost:
                    new_dp[key] = cost + add_cost
        else:
            # Try odd and even if available
            for (used_odd, last_parity), cost in dp.items():
                # Try placing odd
                if used_odd < need_odd:
                    add_cost = 0
                    if last_parity != -1 and last_parity != 1:
                        add_cost = 1
                    key = (used_odd + 1, 1)
                    if key not in new_dp or new_dp[key] > cost + add_cost:
                        new_dp[key] = cost + add_cost
                # Try placing even
                if (len(positions) - used_odd - sum(1 for x in arr[:i] if x == 0)) < need_even:
                    # Calculate remaining evens needed - this is tricky dynamically
                    pass
            
            # Better: count how many evens we need to place
            # actually easier: just try both if counts allow
            for (used_odd, last_parity), cost in dp.items():
                used_even = sum(1 for x in arr[:i] if x == 0) - used_odd
                # Try odd
                if used_odd < need_odd:
                    add = 1 if (last_parity != -1 and last_parity != 1) else 0
                    k = (used_odd + 1, 1)
                    if k not in new_dp or new_dp[k] > cost + add:
                        new_dp[k] = cost + add
                # Try even
                if used_even < need_even:
                    add = 1 if (last_parity != -1 and last_parity != 0) else 0
                    k = (used_odd, 0)
                    if k not in new_dp or new_dp[k] > cost + add:
                        new_dp[k] = cost + add
        dp = new_dp
    
    return min(v for k, v in dp.items())

@cocotb.test()
async def test_garland_complexity(dut):
    """Test garland complexity computation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(16):
        dut.p[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (5, [0, 5, 0, 2, 3]),
        (7, [1, 0, 0, 5, 0, 0, 2]),
        (1, [0]),
        (8, [0, 1, 0, 3, 0, 2, 0, 4]),
        (10, [1, 2, 0, 0, 5, 6, 0, 0, 9, 10]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, arr in test_cases:
        dut._log.info(f"Testing N={n}, arr={arr}")
        
        # Calculate expected
        expected = solve_python(n, arr)
        
        # Set inputs
        dut.n.value = n
        padded = arr + [0] * (16 - len(arr))
        for i in range(16):
            dut.p[i].value = padded[i]
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            dut._log.error(f"Timeout for N={n}")
            continue
        
        # Get result
        result = int(dut.result.value)
        
        if result == expected:
            dut._log.info(f"PASS: N={n} result={result}")
            passed += 1
        else:
            dut._log.error(f"FAIL: N={n} expected={expected}, got={result}")
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
