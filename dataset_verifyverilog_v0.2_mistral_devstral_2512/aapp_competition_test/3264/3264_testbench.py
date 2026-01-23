import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper to check gcd
def gcd(a, b):
    while b: a, b = b, a % b
    return a

@cocotb.test()
async def test_mirko_wins(dut):
    """Test Mirko Wins Logic"""
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        (2, 1),
        (3, 5),
        (4, 21),
        # Additional edge cases
        (1, 1), # N=1: 1 pair? No pairs. 1 empty set. 2^0 = 1. No partitions. Ans 1.
    ]

    for n_val, expected in test_cases:
        print(f"Testing N={n_val}, expecting {expected}")
        
        # Start signal
        dut.N.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        print(f"Got result: {actual}")
        assert actual == expected, f"Mismatch for N={n_val}: expected {expected}, got {actual}"

    print("All tests passed")