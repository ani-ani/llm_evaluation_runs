import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

def py_sum_even_factors(n):
    if n % 2 != 0:
        return 0
    res = 1
    num = n
    for i in range(2, int(math.isqrt(num)) + 1):
        count = 0
        curr_sum = 1
        curr_term = 1
        while num % i == 0:
            count += 1
            num = num // i
            if i == 2 and count == 1:
                curr_sum = 0
            curr_term *= i
            curr_sum += curr_term
        res *= curr_sum
    if num >= 2:
        res *= (1 + num)
    return res

@cocotb.test()
async def test_sum_even_factors(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (original + edge cases)
    test_cases = [
        (18, 26),   # Original Test 1
        (30, 48),   # Original Test 2
        (6, 8),     # Original Test 3
        (2, 3),     # Smallest even
        (3, 0),     # Odd input
        (65534, py_sum_even_factors(65534))  # Max 16-bit even
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        try:
            assert dut.sum.value == expected, f"For n={n}, expected {expected}, got {dut.sum.value}"
            passed += 1
            dut._log.info(f"PASS: n={n} => sum={int(dut.sum.value)}")
        except AssertionError as e:
            dut._log.error(str(e))
            
    dut._log.info(f"Test summary: {passed}/{total} passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"