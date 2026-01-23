import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_right_triangle_counter(dut):
    """Test right triangle counter with fixed 8 points"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.points[i].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3 points forming 1 right triangle
    # (4,2), (2,1), (1,3) + 5 dummy points
    points1 = [4, 2, 2, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    for i, val in enumerate(points1):
        dut.points[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 256 cycles)
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within expected cycles")
    
    if dut.count.value != 1:
        raise TestFailure(f"Test 1: Expected 1 right triangle, got {dut.count.value}")
    
    print("Test 1 passed: 1 right triangle detected")
    
    # Test Case 2: 4 points with no right triangle
    # (5,0), (2,6), (8,6), (5,7) + 4 dummy points
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    points2 = [5, 0, 2, 6, 8, 6, 5, 7, 0, 0, 0, 0, 0, 0, 0, 0]
    for i, val in enumerate(points2):
        dut.points[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    if dut.count.value != 0:
        raise TestFailure(f"Test 2: Expected 0 right triangles, got {dut.count.value}")
    
    print("Test 2 passed: 0 right triangles detected")
    
    # Test Case 3: L-shape with multiple right triangles
    # (-1,1), (-1,0), (0,0), (1,0), (1,1) + 3 dummy points
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    points3 = [-1, 1, -1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0]
    for i, val in enumerate(points3):
        dut.points[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    # This should find 7 right triangles
    if dut.count.value != 7:
        raise TestFailure(f"Test 3: Expected 7 right triangles, got {dut.count.value}")
    
    print("Test 3 passed: 7 right triangles detected")
    
    # Test Case 4: Vertical and horizontal points forming right angles
    # (0,0), (0,1), (1,0), (1,1) + 4 dummy points
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    points4 = [0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
    for i, val in enumerate(points4):
        dut.points[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    # (0,0),(0,1),(1,0) = 1, (0,0),(0,1),(1,1) = 0, (0,0),(1,0),(1,1) = 0, (0,1),(1,0),(1,1) = 1
    # Plus triangles with dummy points... Let's verify expected
    # With 4 points, C(4,3)=4 triangles. Check each:
    # (0,0),(0,1),(1,0): right angle at (0,0) ✓
    # (0,0),(0,1),(1,1): right angle at (0,1) ✓ (vertical to (0,0), diagonal to (1,1)? No, dot at (0,1): vec to (0,0)=(0,-1), to (1,1)=(1,0) dot=0 ✓)
    # (0,0),(1,0),(1,1): right angle at (1,0) ✓ (vec to (0,0)=(-1,0), to (1,1)=(0,1) dot=0 ✓)
    # (0,1),(1,0),(1,1): check angles: at (0,1): vec to (1,0)=(1,-1), to (1,1)=(1,0) dot=1*1+(-1)*0=1≠0; at (1,0): vec to (0,1)=(-1,1), to (1,1)=(0,1) dot=(-1)*0+1*1=1≠0; at (1,1): vec to (0,1)=(-1,0), to (1,0)=(0,-1) dot=0 ✓
    # Total: 4 right triangles from the 4 points.
    if dut.count.value != 4:
        raise TestFailure(f"Test 4: Expected 4 right triangles, got {dut.count.value}")
    
    print("Test 4 passed: 4 right triangles detected")
    
    print("Summary: 4/4 tests passed")
}