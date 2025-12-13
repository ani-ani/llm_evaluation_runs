import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_sort_even(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (padded to 8 elements)
    test_cases = [
        # Original: [1,2,3] => [1,2,3]
        {"input": [1,0,2,0,3,0,0,0], "expect": [1,0,2,0,3,0,0,0]},
        # Original: [5,3,-5,2,-3,3,9,0,123,1,-10] (truncated)
        {"input": [5,3,-5,2,-3,3,9,0], "expect": [-5,3,-3,2,5,3,9,0]},
        # Original: [5,8,-12,4,23,2,3,11,12,-10] (truncated)
        {"input": [5,8,-12,4,23,2,3,11], "expect": [-12,8,3,4,5,2,23,11]},
        # Edge case: max/min values
        {"input": [127,-128,127,-128,0,0,0,0], "expect": [0,-128,0,-128,127,0,127,0]},
        # All negatives
        {"input": [-5,-4,-3,-2,-1,-6,-7,-8], "expect": [-7,-4,-5,-2,-3,-6,-1,-8]}
    ]

    passed = 0
    for case in test_cases:
        # Load input
        for i, val in enumerate(case["input"]):
            # Convert Python int to signed 8-bit representation
            if val < 0:
                val = (1 << 8) + val
            dut.data_in[7-i].value = val

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        await ClockCycles(dut.clk, 5)
        assert dut.done.value == 1, "Done signal not asserted"

        # Verify output
        expected = case["expect"]
        mismatch = False
        result = []
        for i in range(8):
            val = dut.data_out[7-i].value.signed_integer
            result.append(val)
            if val != expected[i]:
                dut._log.error(f"Mismatch at index {i}: Got {val}, expected {expected[i]}")
                mismatch = True

        if not mismatch:
            passed += 1
            dut._log.info(f"PASS: Input {case['input']} -> Result {result}")
        else:
            dut._log.error(f"FAIL: Input {case['input']} -> Result {result}, Expected {expected}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)