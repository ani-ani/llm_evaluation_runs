import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_palindrome_counter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Helper function
    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    # Test cases (original scaled to 8-bits)
    test_cases = [
        (3, (1, 2)),
        (12, (4, 6)),
        (25, (5, 6)),
        (63, (6, 8)),
        (123, (8, 13)),
        (1, (0, 1))
    ]

    passed = 0
    total = len(test_cases)
    
    await reset()

    for n_val, (expected_even, expected_odd) in test_cases:
        # Start the operation
        dut.start.value = 1
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        even = dut.even_count.value.integer
        odd = dut.odd_count.value.integer
        
        if even == expected_even and odd == expected_odd:
            dut._log.info(f"PASS: n={n_val} got ({even},{odd})")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n_val} got ({even},{odd}), expected ({expected_even},{expected_odd})")
        
        # Reset for next test
        await reset()
    
    dut._log.info(f"{passed}/{total} test cases passed")