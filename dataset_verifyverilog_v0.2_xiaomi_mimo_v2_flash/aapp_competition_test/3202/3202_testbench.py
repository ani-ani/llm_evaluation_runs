import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to compute expected result using Python DP
def compute_expected(marbles, K):
    N = len(marbles)
    if N == 0:
        return 0
    
    # dp[i][j] = min insertions to eliminate range [i,j]
    dp = [[0] * N for _ in range(N)]
    
    # Base case: length 1
    for i in range(N):
        dp[i][i] = max(0, K - 1)
    
    # Length from 2 to N
    for length in range(2, N + 1):
        for i in range(N - length + 1):
            j = i + length - 1
            
            # If ends are same color
            if marbles[i] == marbles[j]:
                if length == 2:
                    dp[i][j] = max(0, K - 2)
                else:
                    # Option 1: eliminate middle then connect ends
                    dp[i][j] = dp[i+1][j-1] + max(0, K - length)
            else:
                dp[i][j] = float('inf')
            
            # Option 2: split at any point
            for k in range(i, j):
                dp[i][j] = min(dp[i][j], dp[i][k] + dp[k+1][j])
    
    return dp[0][N-1]

@cocotb.test()
async def test_marble_insertion(dut):
    """Test marble insertion DP module with various cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    for i in range(16):
        dut.marble_colors[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, K, marbles, expected_insertions)
    test_cases = [
        (2, 5, [1, 1], 3),
        (5, 3, [2, 2, 3, 2, 2], 2),
        (10, 4, [3, 3, 3, 3, 2, 3, 1, 1, 1, 3], 4),
        (1, 3, [5], 2),  # Single marble needs 2 more
        (3, 2, [1, 2, 1], 0),  # Alternating, K=2 means pairs vanish after insertion
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, k_val, marbles, expected in test_cases:
        print(f"Testing N={n_val}, K={k_val}, marbles={marbles}, expected={expected}")
        
        # Load inputs
        dut.N.value = n_val
        dut.K.value = k_val
        for i in range(16):
            if i < n_val:
                dut.marble_colors[i].value = marbles[i]
            else:
                dut.marble_colors[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 1500 cycles for safety)
        timeout = 1500
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            print(f"  FAILED: Timeout waiting for done")
            continue
        
        # Check result
        actual = int(dut.min_insertions.value)
        if actual == expected:
            print(f"  PASSED: Got {actual}")
            passed += 1
        else:
            print(f"  FAILED: Expected {expected}, got {actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
