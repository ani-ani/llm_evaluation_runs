import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_even_digits(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    test_cases = [
        (2, 10, [2,4,6,8], 4),   # Original test 1
        (10, 2, [2,4,6,8], 4),   # Original test 2
        (132, 2, [2,4,6,8], 4),  # Original test 3
        (17, 89, [0,0,0,0], 0),  # Original test 4 (no digits)
        (0, 9, [0,2,4,6,8][:4],4), # Edge case (trimmed to 4 elements)
        (5, 5, [], 0),           # Single value (non-even)
        (8, 8, [8], 1)           # Single even digit
    ]

    await reset()
    passed = 0

    for (a_val, b_val, expected, exp_count) in test_cases:
        # Apply test inputs
        dut.a.value = a_val
        dut.b.value = b_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for computation to complete
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check outputs
        valid_count = dut.valid_count.value
        results = [dut.result_array[i].value for i in range(4)]

        matched = True
        for i in range(exp_count):
            if results[i] != expected[i] if i < len(expected) else 0:
                matched = False
        
        if valid_count == exp_count and matched:
            passed += 1
            dut._log.info(f"PASS: a={a_val}, b={b_val} -> {results[:valid_count]}")
        else:
            dut._log.error(f"FAIL: a={a_val}, b={b_val} -> {results[:valid_count]} (expected {expected}), count={valid_count} (expected {exp_count})")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
