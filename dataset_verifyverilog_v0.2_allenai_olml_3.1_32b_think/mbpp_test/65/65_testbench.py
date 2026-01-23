import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_recursive_list_sum(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: [1, 2, [3,4],[5,6]] -> Total 21
    # Matrix representation:
    # Row 0: 1, 2, 0, 0
    # Row 1: 3, 4, 0, 0
    # Row 2: 5, 6, 0, 0
    # Row 3: 0, 0, 0, 0
    # Total sum = 1+2+3+4+5+6 = 21
    dut.data.value = 0
    dut.data[0][0].value = 1
    dut.data[0][1].value = 2
    dut.data[1][0].value = 3
    dut.data[1][1].value = 4
    dut.data[2][0].value = 5
    dut.data[2][1].value = 6
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)

    if dut.total_sum.value != 21:
        raise TestFailure(f"Test Case 1 Failed: Expected 21, Got {int(dut.total_sum.value)}")
    print("Test Case 1 Passed: Sum = 21")

    # Test Case 2: [7, 10, [15,14],[19,41]] -> Total 106
    # Matrix: 
    # Row 0: 7, 10, 0, 0 -> 17
    # Row 1: 15, 14, 0, 0 -> 29
    # Row 2: 19, 41, 0, 0 -> 60
    # Total = 106
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.data.value = 0
    dut.data[0][0].value = 7
    dut.data[0][1].value = 10
    dut.data[1][0].value = 15
    dut.data[1][1].value = 14
    dut.data[2][0].value = 19
    dut.data[2][1].value = 41

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    if dut.total_sum.value != 106:
        raise TestFailure(f"Test Case 2 Failed: Expected 106, Got {int(dut.total_sum.value)}")
    print("Test Case 2 Passed: Sum = 106")

    # Test Case 3: [10, 20, [30,40],[50,60]] -> Total 210
    # Matrix: 
    # Row 0: 10, 20, 0, 0 -> 30
    # Row 1: 30, 40, 0, 0 -> 70
    # Row 2: 50, 60, 0, 0 -> 110
    # Total = 210
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.data.value = 0
    dut.data[0][0].value = 10
    dut.data[0][1].value = 20
    dut.data[1][0].value = 30
    dut.data[1][1].value = 40
    dut.data[2][0].value = 50
    dut.data[2][1].value = 60

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    if dut.total_sum.value != 210:
        raise TestFailure(f"Test Case 3 Failed: Expected 210, Got {int(dut.total_sum.value)}")
    print("Test Case 3 Passed: Sum = 210")

    print("All 3 tests passed successfully.")