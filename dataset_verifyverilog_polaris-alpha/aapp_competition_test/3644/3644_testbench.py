import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_hr_scheduler(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(5, units="ns")

    # Reset and initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Sample input 4 days
    test1_fi = [0, 1, 2, 2] + [0]*4
    test1_hi = [3, 1, 1, 0] + [0]*4
    for i in range(8):
        dut.fi[i].value = test1_fi[i]
        dut.hi[i].value = test1_hi[i]
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion (4 cycles + 1 processing)
    for _ in range(6):
        await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Test1: Done not asserted"
    assert dut.min_hr_count.value == 3, f"Test1: Expected min_hr=3, got {dut.min_hr_count.value}"
    expected_assign = [1, 2, 3, 2]
    for i in range(4):
        assert dut.hr_assign[i].value == expected_assign[i], f"Test1: Day {i} HR mismatch, expected {expected_assign[i]} got {dut.hr_assign[i].value}"

    # Test case 2: Sample input 6 days
    test2_fi = [0,0,2,0,0,50] + [0]*2
    test2_hi = [10,5,0,0,100,100] + [0]*2
    for i in range(8):
        dut.fi[i].value = test2_fi[i]
        dut.hi[i].value = test2_hi[i]
    dut.n.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion (6 cycles + 1 processing)
    for _ in range(8):
        await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Test2: Done not asserted"
    assert dut.min_hr_count.value == 2, f"Test2: Expected min_hr=2, got {dut.min_hr_count.value}"
    expected_assign2 = [1,2,1,2,1,2]
    for i in range(6):
        assert dut.hr_assign[i].value == expected_assign2[i], f"Test2: Day {i} HR mismatch, expected {expected_assign2[i]} got {dut.hr_assign[i].value}"

    # Test case 3: All hires
    dut.n.value = 3
    test3_fi = [0,0,0] + [0]*5
    test3_hi = [5,5,5] + [0]*5
    for i in range(8):
        dut.fi[i].value = test3_fi[i]
        dut.hi[i].value = test3_hi[i]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    assert dut.min_hr_count.value == 1, "Test3: All hires should need only 1 HR"
    for i in range(3):
        assert dut.hr_assign[i].value == 1, f"Test3: Day {i} should be HR 1"

    dut._log.info("3/3 tests passed")