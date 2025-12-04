import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_max(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (padded to 8 elements with zeros)
    test_cases = [
        ([2,4,1,3,5,7,0,0],  (128,  1)),
        ([1,3,2,4,5,6,-2,0], (-2,   1)),
        ([-1,-3,-5,-6,0,0,0,0], (-1, 127)),
        ([-6,-4,-4,-3,1,0,0,0], (-3, 1)),
        ([0,0,0,0,0,0,0,0], (128, 127))
    ]

    passed = 0
    dut.start.value = 0

    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    for data, (exp_a, exp_b) in test_cases:
        # Load test data
        for i in range(8):
            dut.data_in[i].value = data[i]

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (8 cycles)
        await ClockCycles(dut.clk, 8)

        # Check results
        a_val = dut.a.value.signed_integer
        b_val = dut.b.value.signed_integer
        
        assert dut.done.value == 1, f"Done not asserted!"

        if a_val == exp_a and b_val == exp_b:
            passed += 1
            dut._log.info(f"PASS: Data={data} => ({a_val}, {b_val})")
        else:
            dut._log.error(f"FAIL: Data={data} => ({a_val}, {b_val}), expected ({exp_a}, {exp_b})")

        # Wait for next test
        await ClockCycles(dut.clk, 2)

    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")