import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_frog_jump(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.cmd_valid.value = 0

    # Helper function to send commands
    async def send_cmd(cmd_type, data):
        dut.cmd_type.value = cmd_type
        dut.cmd_data.value = data
        dut.cmd_valid.value = 1
        await RisingEdge(dut.clk)
        dut.cmd_valid.value = 0
        await RisingEdge(dut.clk)  # Processing cycle
        await RisingEdge(dut.clk)  # Calculation cycle

    # Test case 1: 1 frog at 0, target changes
    await reset()
    await send_cmd(2, 0)  # t 0
    assert dut.total_jumps.value == 0, "Test1-t0 fail"
    await send_cmd(2, 1)  # t 1
    assert dut.total_jumps.value == 1, "Test1-t1 fail"
    await send_cmd(2, 2)  # t 2
    assert dut.total_jumps.value == 3, "Test1-t2 fail"

    # Test case 2: Initialize with 3 frogs
    await reset()
    await send_cmd(0, 2)  # +2
    await send_cmd(0, 6)  # +6
    await send_cmd(0, 6)  # +6
    await send_cmd(2, 1)  # t 1
    assert dut.total_jumps.value == 11, "Test2-t1 fail"
    await send_cmd(2, 2)  # t 2
    assert dut.total_jumps.value == 6, "Test2-t2 fail"

    # Test case 3: Empty initial setup
    await reset()
    await send_cmd(2, 3)  # t 3
    assert dut.total_jumps.value == 0, "Test3-t3 fail"
    await send_cmd(0, 4)  # +4
    await send_cmd(2, 5)  # t 5
    assert dut.total_jumps.value == 1, "Test3-t5 fail"

    dut._log.info("3/3 test scenarios passed")