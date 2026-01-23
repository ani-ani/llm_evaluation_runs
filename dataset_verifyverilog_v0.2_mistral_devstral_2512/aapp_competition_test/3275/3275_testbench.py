import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

MODULO = 10007

def calculate_expected(a_list, b_list, C):
    """Calculate expected result for original problem"""
    n = len(a_list)
    
    # Calculate total configurations
    total = 1
    for i in range(n):
        total = (total * ((a_list[i] + b_list[i]) % MODULO)) % MODULO
    
    # Calculate configurations with 0 colored
    zero_colored = 1
    for i in range(n):
        zero_colored = (zero_colored * (b_list[i] % MODULO)) % MODULO
    
    # Calculate configurations with exactly 1 colored
    one_colored = 0
    for i in range(n):
        prod = 1
        for j in range(n):
            if j == i:
                continue
            prod = (prod * (b_list[j] % MODULO)) % MODULO
        one_colored = (one_colored + (a_list[i] % MODULO) * prod) % MODULO
    
    # Result for C=2: total - zero - one
    # For C=2, we need at least 2 colored
    result = (total - zero_colored - one_colored) % MODULO
    return result

@cocotb.test()
async def test_art_dealer(dut):
    """Test art_dealer_count module with N=8, C=2"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.client_idx.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down to 8 clients)
    test_cases = [
        # Case 1: 2 clients, both limited
        {
            'a': [1, 1, 1, 1, 1, 1, 1, 1],
            'b': [1, 1, 1, 1, 1, 1, 1, 1],
            'expected': calculate_expected([1, 1], [1, 1], 2)
        },
        # Case 2: 2 clients, different limits
        {
            'a': [1, 2, 1, 1, 1, 1, 1, 1],
            'b': [2, 3, 1, 1, 1, 1, 1, 1],
            'expected': calculate_expected([1, 2], [2, 3], 2)
        },
        # Case 3: 4 clients
        {
            'a': [1, 2, 3, 4, 1, 1, 1, 1],
            'b': [1, 2, 3, 4, 1, 1, 1, 1],
            'expected': calculate_expected([1, 2, 3, 4], [1, 2, 3, 4], 2)
        },
        # Case 4: Edge case with larger values
        {
            'a': [5, 3, 2, 1, 4, 2, 3, 5],
            'b': [2, 4, 3, 5, 1, 3, 2, 4],
            'expected': calculate_expected([5, 3, 2, 1, 4, 2, 3, 5], [2, 4, 3, 5, 1, 3, 2, 4], 2)
        },
        # Case 5: All same values
        {
            'a': [10, 10, 10, 10, 10, 10, 10, 10],
            'b': [5, 5, 5, 5, 5, 5, 5, 5],
            'expected': calculate_expected([10]*8, [5]*8, 2)
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}/{total}")
        
        # Load data for all 8 clients
        for client in range(8):
            dut.client_idx.value = client
            dut.a_in.value = tc['a'][client]
            dut.b_in.value = tc['b'][client]
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 20:
            dut._log.error(f"Test case {i+1}: Timeout waiting for done signal")
            continue
        
        # Read result
        actual = int(dut.result.value)
        expected = tc['expected']
        
        if actual == expected:
            dut._log.info(f"Test case {i+1}: PASS (result={actual})")
            passed += 1
        else:
            dut._log.error(f"Test case {i+1}: FAIL - Expected {expected}, got {actual}")
            # Debug: print intermediate values
            dut._log.info(f"  Input: a={tc['a'][:2]}, b={tc['b'][:2]}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
