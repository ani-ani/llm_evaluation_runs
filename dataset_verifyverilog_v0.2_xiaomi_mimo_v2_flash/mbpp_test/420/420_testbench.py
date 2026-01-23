import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_cube_sum_even(dut):
    """Test cube sum of first n even natural numbers"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to compute expected result
    def compute_expected(n):
        total = 0
        for i in range(1, n + 1):
            total += (2 * i) ** 3
        return total
    
    # Test cases
    test_cases = [2, 3, 4, 1, 8, 5]
    
    for n in test_cases:
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        expected = compute_expected(n)
        actual = int(dut.result.value)
        
        print(f"n={n}: Expected={expected}, Got={actual}")
        assert actual == expected, f"Failed for n={n}: expected {expected}, got {actual}"
    
    print(f"All {len(test_cases)} tests passed!")
