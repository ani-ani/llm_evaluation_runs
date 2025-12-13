import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rotation_tracker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Initial state check (teacher 0 in class 0)
    await do_query(dut, 0, 0)
    assert dut.class_out.value == 0, "Reset failed: teacher0 should be in class0"
    # Test Case 1: Add rotation at week 2: teachers [3,2] (0-indexed)
    await add_rotation(dut, week=2, K=2, teachers=[3,2])
    # Query teacher3 at week2 (should be class2)
    await do_query(dut, teacher=3, week=2)
    assert dut.class_out.value == 2, "Teacher3 should be in class2 after week2 rotation"
    # Test Case 2: Add week3 rotation: teachers [3,0,2]
    await add_rotation(dut, week=3, K=3, teachers=[3,0,2])
    # Query teacher3 at week4 (final position)
    await do_query(dut, teacher=3, week=4)
    assert dut.class_out.value == 0, "Teacher3 should move to class0 after week3 rotation"
    # Test Case 3: Initial mapping persistence
    await do_query(dut, teacher=1, week=1)
    assert dut.class_out.value == 1, "Teacher1 should remain in class1 before any rotations"
    dut._log.info("3/3 tests passed")

async def add_rotation(dut, week, K, teachers):
    # Write command header
    dut.cmd_type.value = 0
    dut.week.value = week
    dut.K.value = K
    for i, t in enumerate(teachers):
        dut.teacher_id_in.value = t
        dut.wr_en.value = 1
        await RisingEdge(dut.clk)
        dut.wr_en.value = 0
        if i < len(teachers)-1:  # Wait between entries except last
            await RisingEdge(dut.clk)

async def do_query(dut, teacher, week):
    dut.cmd_type.value = 1
    dut.week.value = week
    dut.teacher_id_in.value = teacher
    dut.wr_en.value = 1
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)  # Processing cycle 1
    await RisingEdge(dut.clk)  # Processing cycle 2
    await RisingEdge(dut.clk)  # Processing cycle 3 (result ready)
    return