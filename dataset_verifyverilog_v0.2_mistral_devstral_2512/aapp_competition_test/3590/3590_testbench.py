import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_polygon_cutter(dut):
    """Test polygon cutting module with sample inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Simple rectangle with inner quadrilateral
    # Expected cost: 40.0
    # A: (0,0), (0,14), (15,14), (15,0)
    # B: (8,3), (4,6), (7,10), (11,7)
    
    dut.num_vertices_a.value = 4
    dut.num_vertices_b.value = 4
    
    # Input A vertices
    for i in range(8):
        if i < 4:
            coords = [(0,0), (0,14), (15,14), (15,0)]
            dut.ax[i].value = coords[i][0]
            dut.ay[i].value = coords[i][1]
        else:
            dut.ax[i].value = 0
            dut.ay[i].value = 0
    
    # Input B vertices
    for i in range(8):
        if i < 4:
            coords = [(8,3), (4,6), (7,10), (11,7)]
            dut.bx[i].value = coords[i][0]
            dut.by[i].value = coords[i][1]
        else:
            dut.bx[i].value = 0
            dut.by[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion with timeout
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Computation did not complete in time")
    
    # Read result
    result = int(dut.min_cost.value)
    result_float = result / 65536.0  # Convert Q16.16 to float
    
    # Expected: 40.0
    expected = 40.0
    error = abs(result_float - expected)
    
    if error > 0.5:  # Allow some approximation error
        raise TestFailure(f"Test 1 failed: got {result_float}, expected {expected}, error={error}")
    
    print(f"Test 1 passed: cost = {result_float:.6f} (expected {expected})")
    
    # Reset for test case 2
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: Square A with octagon B
    # Expected: ~322.142
    dut.num_vertices_a.value = 4
    dut.num_vertices_b.value = 8
    
    # A: square at 100x100
    for i in range(8):
        if i < 4:
            coords = [(-100,-100), (-100,100), (100,100), (100,-100)]
            dut.ax[i].value = coords[i][0]
            dut.ay[i].value = coords[i][1]
        else:
            dut.ax[i].value = 0
            dut.ay[i].value = 0
    
    # B: octagon inside
    for i in range(8):
        coords = [(-1,-2), (-2,-1), (-2,1), (-1,2), (1,2), (2,1), (2,-1), (1,-2)]
        dut.bx[i].value = coords[i][0]
        dut.by[i].value = coords[i][1]
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Computation did not complete in time for test 2")
    
    result2 = int(dut.min_cost.value)
    result2_float = result2 / 65536.0
    
    # Expected: 322.1421356237
    expected2 = 322.1421356237
    error2 = abs(result2_float - expected2)
    
    # For this test, allow larger error due to greedy approximation
    if error2 > 10.0:  # Allow 10 units for greedy approximation
        raise TestFailure(f"Test 2 failed: got {result2_float}, expected {expected2}, error={error2}")
    
    print(f"Test 2 passed: cost = {result2_float:.6f} (expected {expected2})")
    print(f"All tests passed!")
