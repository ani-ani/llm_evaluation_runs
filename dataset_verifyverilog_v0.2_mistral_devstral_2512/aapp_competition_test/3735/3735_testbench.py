import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def digit_sum(num):
    """Helper to compute digit sum in Python"""
    s = 0
    while num > 0:
        s += num % 10
        num //= 10
    return s

@cocotb.test()
async def test_digit_sum_optimizer(dut):
    """Test the digit sum optimizer module"""
    # Create a clock
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

    # Test cases
    # We scale down inputs to fit the 12-bit range of the module
    # Original n=35 -> fits in 12 bits
    # Original n=10000000000 -> too big, we test with n=3000 (max 4095)
    # Original n=4394826 -> too big, we test with n=2047
    # We will use n values up to 4000
    
    test_cases = [
        (35, 17),
        (100, 19),
        (255, 27),
        (432, 42),
        (999, 27),
        (1000, 28),
        (2047, 28),
        (3000, 33),
        (4095, 36),
        (15, 15),
        (8, 8),
        (1, 1)
    ]

    passed = 0
    total = len(test_cases)

    for n_val, expected_sum in test_cases:
        # Load input
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        # The module iterates a from 0 to n. For n=4095, this takes ~4100 cycles.
        # We add some buffer.
        timeout = n_val + 100
        
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for n={n_val}. Did not finish in {timeout} cycles")

        # Check result
        result = int(dut.result.value)
        if result == expected_sum:
            passed += 1
            dut._log.info(f"Test n={n_val}: Expected {expected_sum}, Got {result} - PASS")
        else:
            dut._log.error(f"Test n={n_val}: Expected {expected_sum}, Got {result} - FAIL")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
