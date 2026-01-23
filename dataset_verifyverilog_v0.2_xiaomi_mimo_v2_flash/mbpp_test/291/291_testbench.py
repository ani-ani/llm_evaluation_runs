import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Modulo constant
MOD = 1000000007

def count_no_of_ways_py(n, k):
    """Reference Python implementation."""
    if n == 0:
        return 0
    if n == 1:
        return k
    if n == 2:
        return k * k
    
    dp_prev_prev = k  # dp[1]
    dp_prev = k * k   # dp[2]
    
    for i in range(3, n + 1):
        dp_curr = ((k - 1) * (dp_prev + dp_prev_prev)) % MOD
        dp_prev_prev = dp_prev
        dp_prev = dp_curr
    
    return dp_prev

@cocotb.test()
async def test_fence_painter(dut):
    """Test the fence_painter module."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, k, expected)
    test_cases = [
        (2, 4, 16),   # Test 1
        (3, 2, 6),    # Test 2
        (4, 4, 228),  # Test 3
        (1, 5, 5),    # Edge: n=1
        (8, 8, 577920), # Scale: n=8, k=8
        (0, 5, 0),    # Edge: n=0
        (5, 3, 48)    # Additional
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"Running {total} tests...")
    
    for n_val, k_val, expected in test_cases:
        # Load inputs
        dut.n.value = n_val
        dut.k.value = k_val
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            
        # Check result
        actual = int(dut.result.value)
        
        # Allow 1 cycle tolerance for propagation if strictly needed, 
        # but done usually aligns with valid result.
        
        if actual == expected:
            print(f"PASS: n={n_val}, k={k_val}, result={actual}")
            passed += 1
        else:
            print(f"FAIL: n={n_val}, k={k_val}, expected={expected}, got={actual}")
            
        # Small delay before next test
        await Timer(50, units='ns')
        
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Some tests failed ({passed}/{total})"