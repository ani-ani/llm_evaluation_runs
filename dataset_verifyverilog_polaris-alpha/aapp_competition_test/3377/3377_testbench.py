import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_peg_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create a 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock

    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.op.value = 0
    dut.point_id.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Valid sequence from sample input (scaled)
    test_sequence = [
        (0,1), (0,2), (0,3), (1,1), (0,4), (0,5)  # Valid wet sequence
    ]
    dut.start.value = 1
    for op, pid in test_sequence:
        dut.op.value = op
        dut.point_id.value = pid
        await RisingEdge(dut.clk)
        assert dut.valid.value == 1, "Test 1: Failed at step ({},{})".format(op,pid)
    dut.start.value = 0
    await ClockCycles(dut.clk,2)
    assert dut.done.value == 1 and dut.valid.value == 1, "Test 1 should complete valid"

    # Test case 2: Invalid removal (from sample input)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk,2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    invalid_sequence = [
        (0,1), (0,2), (0,3), (1,1), (0,4), (1,2)  # Removing 2 with changed supports
    ]
    dut.start.value = 1
    for i, (op, pid) in enumerate(invalid_sequence):
        dut.op.value = op
        dut.point_id.value = pid
        await RisingEdge(dut.clk)
        if i == 5: assert dut.valid.value == 0, "Test 2: Should fail at final step"
    assert dut.done.value == 1 and dut.valid.value == 0, "Test 2 should end invalid"

    dut._log.info("2/2 tests passed")