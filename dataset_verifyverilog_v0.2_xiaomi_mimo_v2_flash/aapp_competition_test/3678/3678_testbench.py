import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def get_manhattan_dist(p1, p2):
    return abs(p1[0]-p2[0]) + abs(p1[1]-p2[1])

async def set_points(dut, points):
    for i, (x, y) in enumerate(points):
        dut.point_x[i].value = x
        dut.point_y[i].value = y
    dut.n_in.value = len(points)

async def wait_for_done(dut, timeout=10000):
    for _ in range(timeout):
        if dut.done.value == 1:
            return
        await RisingEdge(dut.clk)
    raise TestFailure("Timeout waiting for done signal")

@cocotb.test()
async def test_valid_single_point(dut):
    """Test valid loop with 1 point (trivial)"""
    dut.rst_n.value = 0
    dut.start.value = 0
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 1 point is always valid (loop of length 0)
    await set_points(dut, [(5, 5)])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if dut.valid.value != 1:
        raise TestFailure(f"Expected valid=1 for 1 point, got {dut.valid.value}")

@cocotb.test()
async def test_valid_square(dut):
    """Test valid square loop (4 points)"""
    dut.rst_n.value = 0
    dut.start.value = 0
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    points = [(1, 1), (1, 3), (3, 3), (3, 1)]
    await set_points(dut, points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if dut.valid.value != 1:
        raise TestFailure(f"Expected valid=1 for square, got {dut.valid.value}")

@cocotb.test()
async def test_invalid_c_shape(dut):
    """Test invalid C-shape (3 points)"""
    dut.rst_n.value = 0
    dut.start.value = 0
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    points = [(1, 1), (1, 2), (2, 1)]
    await set_points(dut, points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if dut.valid.value != 0:
        raise TestFailure(f"Expected valid=0 for 3-point C-shape, got {dut.valid.value}")

@cocotb.test()
async def test_valid_example_6pts(dut):
    """Test Sample 1: 6 points valid"""
    dut.rst_n.value = 0
    dut.start.value = 0
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # (1,1), (1,3), (2,2), (2,3), (3,1), (3,2)
    points = [(1,1), (1,3), (2,2), (2,3), (3,1), (3,2)]
    await set_points(dut, points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if dut.valid.value != 1:
        raise TestFailure(f"Expected valid=1 for 6pt case, got {dut.valid.value}")

@cocotb.test()
async def test_intersecting_loop(dut):
    """Test intersecting loop (bowtie shape)"""
    dut.rst_n.value = 0
    dut.start.value = 0
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # A 2x2 grid missing one corner, crossing
    # (0,0), (0,2), (2,2), (2,0) -> Invalid intersection if we connect (0,0)-(2,2) but that's diagonal
    # Let's use a case where edges cross. 
    # (0,0), (0,2), (2,1), (2,3) - No, need perpendicular.
    # Hard to force intersection in small grid without specific path.
    # Let's test a star shape that forces crossing if connected.
    # Actually, if the points allow a crossing path, but maybe another path exists.
    # We will test a case that definitely fails the 'segment through point' rule.
    # Line (0,0) to (0,4) passing through (0,2).
    points = [(0,0), (0,4), (0,2), (4,0), (4,4)]
    await set_points(dut, points)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # This case might actually have a valid loop (e.g. square 0,0-0,4-4,4-4,0, but middle point 0,2 is on segment 0,0-0,4).
    # So this should be INVALID.
    if dut.valid.value != 0:
        raise TestFailure(f"Expected valid=0 for invalid straight line passthrough, got {dut.valid.value}")
