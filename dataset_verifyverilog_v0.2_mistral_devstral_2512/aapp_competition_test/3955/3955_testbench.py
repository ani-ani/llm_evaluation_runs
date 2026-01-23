import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_or_k_operations(dut):
    """Test the max_or_k_operations module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.x.value = 0
    for i in range(8):
        dut.a[i].value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to calculate expected result
    def calc_expected(n_val, k_val, x_val, a_vals):
        if n_val == 0:
            return 0
        mul = x_val ** k_val
        if n_val == 1:
            return a_vals[0] * mul
        
        # Build prefix and suffix arrays
        prefix = [0] * n_val
        suffix = [0] * n_val
        
        prefix[0] = a_vals[0]
        for i in range(1, n_val):
            prefix[i] = prefix[i-1] | a_vals[i]
        
        suffix[n_val-1] = a_vals[n_val-1]
        for i in range(n_val-2, -1, -1):
            suffix[i] = suffix[i+1] | a_vals[i]
        
        max_val = 0
        for i in range(n_val):
            left = prefix[i-1] if i > 0 else 0
            right = suffix[i+1] if i < n_val-1 else 0
            candidate = left | (a_vals[i] * mul) | right
            if candidate > max_val:
                max_val = candidate
        
        return max_val
    
    # Test cases
    test_cases = [
        # n, k, x, [a0, a1, a2, a3, a4, a5, a6, a7]
        (3, 1, 2, [1, 1, 1, 0, 0, 0, 0, 0]),  # Expected: 3
        (4, 2, 3, [1, 2, 4, 8, 0, 0, 0, 0]),  # Expected: 79
        (2, 1, 2, [12, 9, 0, 0, 0, 0, 0, 0]),  # Expected: 30
        (2, 1, 2, [12, 7, 0, 0, 0, 0, 0, 0]),  # Expected: 31
        (3, 1, 3, [3, 2, 0, 0, 0, 0, 0, 0]),  # Expected: 11
        (1, 1, 2, [1, 0, 0, 0, 0, 0, 0, 0]),  # Expected: 2
        (1, 1, 2, [0, 0, 0, 0, 0, 0, 0, 0]),  # Expected: 0
        (3, 1, 2, [17, 18, 4, 0, 0, 0, 0, 0]),  # Expected: 54
        (2, 2, 2, [60, 59, 0, 0, 0, 0, 0, 0]),  # Expected: 252
        (3, 1, 2, [10, 12, 5, 0, 0, 0, 0, 0]),  # Expected: 31
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, k_val, x_val, a_vals in test_cases:
        # Setup inputs
        dut.n.value = n_val
        dut.k.value = k_val
        dut.x.value = x_val
        for i in range(8):
            dut.a[i].value = a_vals[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Get result
        actual = int(dut.result.value)
        expected = calc_expected(n_val, k_val, x_val, a_vals)
        
        # Verify
        if actual == expected:
            passed += 1
            print(f"Test passed: n={n_val}, k={k_val}, x={x_val}, result={actual}")
        else:
            print(f"Test FAILED: n={n_val}, k={k_val}, x={x_val}")
            print(f"  Expected: {expected}, Got: {actual}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
