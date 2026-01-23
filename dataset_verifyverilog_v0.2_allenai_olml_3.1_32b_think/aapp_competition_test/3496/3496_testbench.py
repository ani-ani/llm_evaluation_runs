import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_atom_explodification(dut):
    """Test the atom explodification module with scaled test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.n.value = 0
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    dut.a_8.value = 0
    dut.a_9.value = 0
    dut.a_10.value = 0
    dut.a_11.value = 0
    dut.a_12.value = 0
    dut.a_13.value = 0
    dut.a_14.value = 0
    dut.a_15.value = 0
    dut.a_16.value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=4, a=[2,3,5,7], queries
    # k=2: base case, output 3
    await run_test_case(dut, n=4, k=2, a=[2,3,5,7], expected=3)
    
    # k=3: base case, output 5  
    await run_test_case(dut, n=4, k=3, a=[2,3,5,7], expected=5)
    
    # k=5: splits as 2+3 = 3+5 = 8, output 8
    await run_test_case(dut, n=4, k=5, a=[2,3,5,7], expected=8)
    
    # k=6: splits as 3+3 = 6, 2+4 = 9, etc. Min is 6 (3+3) but wait, 3+3=6 but a_3=5, so 5+5=10? Let me recalculate
    # For k=6, splits: 1+5=2+8=10, 2+4=3+7=10, 3+3=5+5=10. So 10
    await run_test_case(dut, n=4, k=6, a=[2,3,5,7], expected=10)
    
    # k=8: 4+4=7+7=14, 3+5=5+8=13, 2+6=3+10=13, 1+7=2+10=12... min is 12? Wait recheck
    # Actually: 2+6 needs computation. Let's compute properly:
    # dp[1]=2, dp[2]=3, dp[3]=5, dp[4]=7
    # dp[5]: min(1+4=2+7=9, 2+3=3+5=8) = 8
    # dp[6]: min(1+5=2+8=10, 2+4=3+7=10, 3+3=5+5=10) = 10  
    # dp[7]: min(1+6=2+10=12, 2+5=3+8=11, 3+4=5+7=12) = 11
    # dp[8]: min(1+7=2+11=13, 2+6=3+10=13, 3+5=5+8=13, 4+4=7+7=14) = 13
    await run_test_case(dut, n=4, k=8, a=[2,3,5,7], expected=13)
    
    # Test Case 2: n=1, a=[10]
    # k=1: 10
    await run_test_case(dut, n=1, k=1, a=[10], expected=10)
    
    # k=2: 1+1 = 10+10 = 20
    await run_test_case(dut, n=1, k=2, a=[10], expected=20)
    
    # k=10: splits into 10 atoms of 1 neutron = 10*10 = 100
    await run_test_case(dut, n=1, k=10, a=[10], expected=100)
    
    # Test edge cases
    # Minimum n and k
    await run_test_case(dut, n=1, k=1, a=[5], expected=5)
    
    # Maximum values within range
    await run_test_case(dut, n=16, k=16, a=[1]*16, expected=1)
    
    dut._log.info("All tests passed!")

async def run_test_case(dut, n, k, a, expected):
    """Helper to run a single test case"""
    # Set inputs
    dut.n.value = n
    dut.k.value = k
    
    # Set all a values (fill with 0 if not provided)
    for i in range(1, 17):
        val = a[i-1] if i-1 < len(a) else 0
        setattr(dut, f'a_{i}').value = val
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (check done signal)
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure(f"Timeout waiting for done signal")
    
    # Read result
    result = int(dut.min_energy.value)
    
    if result != expected:
        raise TestFailure(f"Test failed: k={k}, n={n}. Expected {expected}, got {result}")
    
    dut._log.info(f"Test passed: k={k}, n={n}, result={result}")
    
    # Wait for idle
    await RisingEdge(dut.clk)
