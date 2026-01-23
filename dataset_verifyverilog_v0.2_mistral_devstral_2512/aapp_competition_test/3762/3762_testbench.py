import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

MOD = 1000000007

def reference(k):
    """Reference Python implementation for k ≤ 65535"""
    if k == 0:
        return 1
    
    bink = list(map(int, bin(k)[2:]))
    N = len(bink)
    
    dp = [[[0,0] for j in range(N+2)] for i in range(N+1)]
    dp[0][0][1] = 1
    
    for i in range(1, N+1):
        for j in range(i+1):
            # k = 0 case
            dp[i][j][0] = (dp[i][j][0] + pow(2, j, MOD) * dp[i-1][j][0]) % MOD
            if j:
                dp[i][j][0] = (dp[i][j][0] + dp[i-1][j-1][0]) % MOD
            
            # k = 1 -> 0 transition
            if j:
                odd = pow(2, j-1, MOD)
                even = (pow(2, j, MOD) - odd) % MOD
            else:
                odd = 0
                even = 1
            
            if bink[i-1] == 1:
                dp[i][j][0] = (dp[i][j][0] + even * dp[i-1][j][1]) % MOD
            
            # k = 1 -> 1 transition
            if bink[i-1] == 0:
                dp[i][j][1] = (dp[i][j][1] + even * dp[i-1][j][1]) % MOD
            else:
                dp[i][j][1] = (dp[i][j][1] + odd * dp[i-1][j][1]) % MOD
                if j:
                    dp[i][j][1] = (dp[i][j][1] + dp[i-1][j-1][1]) % MOD
    
    ans = 0
    for j in range(N+1):
        ans = (ans + dp[N][j][0] + dp[N][j][1]) % MOD
    return ans

@cocotb.test()
async def test_perfect_sets(dut):
    """Test perfect_sets module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (0, 1),
        (1, 2),
        (2, 3),
        (3, 5),
        (4, 6),
        (5, 8),
        (6, 11),
        (7, 16),
        (8, 17),
        (9, 19),
        (10, 22),
        (11, 27),
        (12, 32),
        (13, 40),
        (14, 51),
        (15, 67),
        (16, 68),
        (17, 70),
        (18, 73),
        (19, 78),
        (20, 83),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for k_val, expected in test_cases:
        # Start computation
        dut.k.value = k_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 64 cycles)
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout for k={k_val}")
        
        # Get result
        actual = int(dut.result.value)
        
        # Also compute reference for verification
        ref = reference(k_val)
        
        if actual != expected:
            raise TestFailure(f"k={k_val}: got {actual}, expected {expected} (ref={ref})")
        
        if actual != ref:
            raise TestFailure(f"k={k_val}: mismatch with reference: got {actual}, ref={ref}")
        
        passed += 1
        await Timer(100, units='ns')
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    
    # Additional edge test for larger k within range
    dut.k.value = 31  # 0x1F
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    actual = int(dut.result.value)
    ref = reference(31)
    if actual != ref:
        raise TestFailure(f"k=31: got {actual}, expected {ref}")
    passed += 1
    total += 1
    
    print(f"Final Summary: {passed}/{total} tests passed")
