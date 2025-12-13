import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def shell_sort_test(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset procedure
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define test cases (scaled to 8 elements)
    test_cases = [
        ([12, 23, 4, 5, 3, 2, 12, 81], [2, 3, 4, 5, 12, 12, 23, 81]),
        ([22, 24, 39, 34, 68, 73, 87, 0], [0, 22, 24, 34, 39, 68, 73, 87]),  # Added 0 to fill
        ([16, 30, 32, 74, 82, 83, 96, 0], [0, 16, 30, 32, 74, 82, 83, 96]),  # Added 0 to fill
        ([255, 128, 64, 32, 16, 8, 4, 2], [2, 4, 8, 16, 32, 64, 128, 255]),  # Reverse sorted
        ([1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1])  # All same
    ]

    passed = 0
    for data_in, expected_out in test_cases:
        # Load data
        for i in range(8):
            dut.data_in[i].value = data_in[i]
        
        # Start sorting
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        result = [int(dut.data_out[i].value) for i in range(8)]
        if result == expected_out:
            passed += 1
            dut._log.info(f"PASS: Input {data_in} -> Output {result}")
        else:
            dut._log.error(f"FAIL: Input {data_in} -> Output {result}, expected {expected_out}")
        
        # Wait a few cycles between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"{total-passed} tests failed"