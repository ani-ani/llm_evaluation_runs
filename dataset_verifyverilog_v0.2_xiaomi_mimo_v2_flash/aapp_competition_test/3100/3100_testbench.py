import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Modulus constant
MOD = 1000000007

# Reference Python implementation
def count_arrangements(A, C, M):
    """Count arrangements with no two consecutive same fruits"""
    if A + C + M == 0:
        return 0
    
    # dp[a][c][m][last] - last: 0=none, 1=apple, 2=cherry, 3=mango
    dp = [[[[0 for _ in range(4)] for _ in range(M+1)] for _ in range(C+1)] for _ in range(A+1)]
    dp[0][0][0][0] = 1
    
    for a in range(A+1):
        for c in range(C+1):
            for m in range(M+1):
                for last in range(4):
                    if dp[a][c][m][last] == 0:
                        continue
                    current = dp[a][c][m][last]
                    
                    # Try adding apple
                    if a < A and last != 1:
                        dp[a+1][c][m][1] = (dp[a+1][c][m][1] + current) % MOD
                    
                    # Try adding cherry
                    if c < C and last != 2:
                        dp[a][c+1][m][2] = (dp[a][c+1][m][2] + current) % MOD
                    
                    # Try adding mango
                    if m < M and last != 3:
                        dp[a][c][m+1][3] = (dp[a][c][m+1][3] + current) % MOD
    
    result = (dp[A][C][M][1] + dp[A][C][M][2] + dp[A][C][M][3]) % MOD
    return result

@cocotb.test()
async def test_fruit_arrangement(dut):
    """Test fruit arrangement module with various inputs"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.A.value = 0
    dut.C.value = 0
    dut.M.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (1, 2, 1, 6),      # Sample 1: 6 arrangements
        (2, 2, 2, 30),     # Sample 2: 30 arrangements
        (1, 1, 1, 6),      # All equal small counts
        (10, 0, 0, 0),     # Only one type - impossible
        (1, 1, 0, 2),      # Two types, 1 each: 2 arrangements
        (3, 2, 1, 60),     # Mixed counts
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a, c, m, expected in test_cases:
        # Skip if A,C,M > 10 (our hardware limit)
        if a > 10 or c > 10 or m > 10:
            print(f"Skipping ({a},{c},{m}) - exceeds hardware limit")
            total -= 1
            continue
            
        print(f"Testing A={a}, C={c}, M={m}, expected={expected}")
        
        # Set inputs
        dut.A.value = a
        dut.C.value = c
        dut.M.value = m
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 5000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for ({a},{c},{m})")
        
        # Read result
        result = int(dut.result.value)
        
        print(f"  Result: {result}")
        
        if result == expected:
            passed += 1
            print(f"  PASS")
        else:
            print(f"  FAIL: Expected {expected}, got {result}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
