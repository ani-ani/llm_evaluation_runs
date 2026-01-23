import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to compute sum of even factors in Python
def sumofFactors(n):
    if (n % 2 != 0):
        return 0
    res = 1
    i = 2
    while i * i <= n:
        count = 0
        curr_sum = 1
        curr_term = 1
        while (n % i == 0):
            count = count + 1
            n = n // i
            if (i == 2 and count == 1):
                curr_sum = 0
            curr_term = curr_term * i
            curr_sum = curr_sum + curr_term
        res = res * curr_sum
        i += 1
    if (n >= 2):
        res = res * (1 + n)
    return res

@cocotb.test()
async def test_sum_even_factors(dut):
    """Test sum of even factors module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test cases
    test_cases = [
        (6, 8),
        (18, 26),
        (30, 48),
        (2, 2),
        (4, 6),
        (8, 14),
        (15, 0),
        (1, 0),
        (60, 108),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Start computation
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        actual = int(dut.result.value)
        dut._log.info(f"n={n_val}, expected={expected}, actual={actual}")
        assert actual == expected, f"Failed for n={n_val}: expected {expected}, got {actual}"
        passed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    print(f"
=== Test Summary: {passed}/{total} tests passed ===")
    assert passed == total
