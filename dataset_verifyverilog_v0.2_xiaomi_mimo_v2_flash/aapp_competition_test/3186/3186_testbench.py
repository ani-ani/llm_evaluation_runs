import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MOD = 1000007

def python_solve(N, M, K):
    # Python reference for the recurrence relation
    # We use 1D DP array and update it in place using the recurrence
    # C(n, k) = C(n, k-1) + C(n-1, k) - C(n-1, k-m-1)
    # Since we iterate N, we need to store previous row values.
    # Actually, the recurrence is:
    # dp[n][k] = dp[n][k-1] + dp[n-1][k] - dp[n-1][k-M-1]
    # We want to compute dp[N][K].
    # We can do this with O(K) space using two rows.
    
    if K > N * M:
        return 0
    if K == 0:
        return 1
    
    # prev_dp[k] stores dp[n-1][k]
    # curr_dp[k] stores dp[n][k]
    prev_dp = [0] * (K + 1)
    curr_dp = [0] * (K + 1)
    
    # Base case: 0 items selected from 0 types is 1 way
    prev_dp[0] = 1
    
    # Iterate for each type
    for n in range(1, N + 1):
        curr_dp[0] = 1 # dp[n][0] is always 1
        for k in range(1, K + 1):
            term1 = curr_dp[k-1]
            term2 = prev_dp[k]
            term3 = prev_dp[k - M - 1] if (k - M - 1 >= 0) else 0
            
            val = (term1 + term2 - term3) % MOD
            curr_dp[k] = val
        
        # Update prev_dp for next iteration
        prev_dp = list(curr_dp)
        
    return prev_dp[K]

@cocotb.test()
async def test_ways_calculator(dut):
    """Test the ways_calculator module"""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N_in.value = 0
    dut.M_in.value = 0
    dut.K_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled down from original)
    # Original: 10 1 2 -> 45
    # Original: 3 3 3 -> 10
    # Original: 3 2 7 -> 0 (impossible, K > N*M)
    
    test_cases = [
        (10, 1, 2, 45),
        (3, 3, 3, 10),
        (3, 2, 7, 0),
        (5, 3, 4, 35), # Additional case: 5 types, 3 copies, pick 4
        (1, 10, 1, 1), # Edge case
        (2, 2, 4, 1),  # Edge case: 2 types * 2 copies = 4, pick all
        (2, 2, 5, 0)   # Edge case: impossible
    ]

    for N, M, K, expected in test_cases:
        dut._log.info(f"Running test: N={N}, M={M}, K={K}, Expected={expected}")
        
        # Check if K > N*M, python_solve handles it but let's ensure hardware constraints
        # The hardware design assumes K <= 64. If K > 64, we skip or map to 0 if impossible.
        # But here K is small.
        
        if K > 64:
             dut._log.info(f"Skipping test K={K} > 64 (HW constraint)")
             continue

        dut.N_in.value = N
        dut.M_in.value = M
        dut.K_in.value = K
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        cycles = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > timeout:
                raise TestFailure(f"Timeout waiting for done for N={N}, M={M}, K={K}")
        
        # Check result
        received = int(dut.result.value)
        if received != expected:
            raise TestFailure(f"Mismatch for N={N}, M={M}, K={K}: Expected {expected}, Got {received}")
        
        dut._log.info(f"Success: Result {received}")
        await RisingEdge(dut.clk) # Wait gap

    dut._log.info("All tests passed!")