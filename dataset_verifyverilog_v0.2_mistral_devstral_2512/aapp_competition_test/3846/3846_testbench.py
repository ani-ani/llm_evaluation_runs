import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_leader_determiner_basic(dut):
    """Test basic case with 5 participants, 4 messages"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.msg_id.value = 0
    dut.msg_type.value = 0
    dut.msg_valid.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input sequence: +1, +2, -2, -1
    messages = [(1, 1), (2, 1), (2, 0), (1, 0)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for msg_id, msg_type in messages:
        dut.msg_id.value = msg_id
        dut.msg_type.value = msg_type
        dut.msg_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.msg_valid.value = 0
    
    # Wait for done
    for _ in range(20):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal did not go high")
    
    # Expected: Leaders are 1, 3, 4, 5 (bitmask 00011101 = 0x1D for N=5)
    # 1: stayed whole time, 3,4,5: never logged in
    expected = (1 << 0) | (1 << 2) | (1 << 3) | (1 << 4)  # bits 0-based
    actual = int(dut.possible_leaders.value)
    
    dut._log.info(f"Expected: {bin(expected)}, Actual: {bin(actual)}")
    if actual != expected:
        raise TestFailure(f"Expected {bin(expected)}, got {bin(actual)}")

@cocotb.test()
async def test_leader_determiner_interleaved(dut):
    """Test interleaved logins/logouts"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: +1, -1, +2, -2 (0 leaders possible)
    messages = [(1, 1), (1, 0), (2, 1), (2, 0)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for msg_id, msg_type in messages:
        dut.msg_id.value = msg_id
        dut.msg_type.value = msg_type
        dut.msg_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.msg_valid.value = 0
    
    for _ in range(20):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected: 0
    if int(dut.possible_leaders.value) != 0:
        raise TestFailure(f"Expected 0, got {int(dut.possible_leaders.value)}")

@cocotb.test()
async def test_leader_determiner_gaps(dut):
    """Test gap detection with 3 participants"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: +1, -1, -3, +3, +4, -4 (Leaders: 2, 3, 5)
    # 1: leaves first, no gap
    # 3: -3 happens when active=0, so no gap (valid)
    # 4: gaps because 4 was off when 3 was on
    messages = [(1, 1), (1, 0), (3, 0), (3, 1), (4, 1), (4, 0)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for msg_id, msg_type in messages:
        dut.msg_id.value = msg_id
        dut.msg_type.value = msg_type
        dut.msg_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.msg_valid.value = 0
    
    for _ in range(20):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected: 2, 3, 5 (0x1D = 0b10100 for 5 bits... wait, 2=bit1, 3=bit2, 5=bit4)
    expected = (1 << 1) | (1 << 2) | (1 << 4)
    actual = int(dut.possible_leaders.value)
    
    if actual != expected:
        raise TestFailure(f"Expected {bin(expected)}, got {bin(actual)}")

@cocotb.test()
async def test_leader_determiner_complex(dut):
    """Test complex interleaving"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: +1, -2, +2, -1 (0 leaders)
    messages = [(1, 1), (2, 0), (2, 1), (1, 0)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for msg_id, msg_type in messages:
        dut.msg_id.value = msg_id
        dut.msg_type.value = msg_type
        dut.msg_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.msg_valid.value = 0
    
    for _ in range(20):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if int(dut.possible_leaders.value) != 0:
        raise TestFailure(f"Expected 0, got {int(dut.possible_leaders.value)}")

@cocotb.test()
async def test_leader_determiner_single_login(dut):
    """Test single participant login"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: +1
    messages = [(1, 1)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for msg_id, msg_type in messages:
        dut.msg_id.value = msg_id
        dut.msg_type.value = msg_type
        dut.msg_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.msg_valid.value = 0
    
    for _ in range(20):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected: 1 (bit 0)
    if int(dut.possible_leaders.value) != 1:
        raise TestFailure(f"Expected 1, got {int(dut.possible_leaders.value)}")
}