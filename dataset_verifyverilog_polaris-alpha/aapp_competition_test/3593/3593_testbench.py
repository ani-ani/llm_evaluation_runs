import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_domino(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reduced test cases (N up to 4, K=2)
    test_inputs = [
        # Scaled first test case (N=4 of original 5 rows, K=2)
        {
            'n': 4,
            'rows': [ 
                [2, 1, -1], 
                [1, 3, 2], 
                [0, 2, 3], 
                [2, 1, 1] 
            ],
            'expected_sum': 1+3 + 3+2 + 0
        },
        # Original second test case fits new constraints (N=2, K=2)
        {
            'n': 2,
            'rows': [ 
                [0, 4, 1], 
                [3, 5, 1] 
            ],
            'expected_sum': 4+5 + 3+1
        },
        # Additional edge case: single row possibilities
        {
            'n': 1,
            'rows': [ 
                [100, 200, 300] 
            ],
            'expected_sum': 200+300 # Only valid domino
        }
    ]

    passed = 0
    test_count = len(test_inputs)

    for test in test_inputs:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load input values (convert to 20-bit 2's complement)
        rows = test['rows']
        for row_idx in range(4):
            if row_idx < test['n']:
                vals = rows[row_idx]
            else:
                vals = [0, 0, 0]  # pad unused rows \
            # Assign row values with proper bit packing (sign extension to 20 bits)
            eval(f'dut.row{row_idx}_col0.value').value = int(np.int32(vals[0])) & 0xFFFFF
            eval(f'dut.row{row_idx}_col1.value').value = int(np.int32(vals[1])) & 0xFFFFF
            eval(f'dut.row{row_idx}_col2.value').value = int(np.int32(vals[2])) & 0xFFFFF

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal (max 15 cycles)
        timeout = 15
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        if timeout == 0:
            dut._log.error("Test timed out waiting for done signal")
        else:
            # Verify result (signed interpretation)
            result = dut.max_sum.value.signed_integer
            expected = test['expected_sum']
            if result == expected:
                passed += 1
            else:
                dut._log.error(f"N={test['n']} Test failed. Got {result}, expected {expected}")

    dut._log.info(f"{passed}/{test_count} tests passed")
    assert passed == test_count, "Some tests failed"