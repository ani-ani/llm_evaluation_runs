import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_mst_weight(dut):
    """Test MST weight calculation for various point configurations"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_points.value = 0
    for i in range(8):
        dut.points[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 4 points forming a square
    # Points: (0,0), (0,1), (1,0), (1,1)
    # Expected MST weight: 3
    dut.n_points.value = 4
    dut.points[0].value = (0 << 5) | 0   # (0,0)
    dut.points[1].value = (0 << 5) | 1   # (0,1)
    dut.points[2].value = (1 << 5) | 0   # (1,0)
    dut.points[3].value = (1 << 5) | 1   # (1,1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 1: Timeout - computation did not complete")
    
    if dut.mst_weight.value != 3:
        raise TestFailure(f"Test 1 failed: Expected 3, got {dut.mst_weight.value}")
    
    print(f"Test 1 passed: MST weight = {dut.mst_weight.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 3 colinear points
    # Points: (0,0), (10,0), (20,0) -> scaled to (0,0), (5,0), (10,0)
    # Expected: connect adjacent = 5 + 5 = 10
    dut.n_points.value = 3
    dut.points[0].value = (0 << 5) | 0   # (0,0)
    dut.points[1].value = (5 << 5) | 0   # (5,0)
    dut.points[2].value = (10 << 5) | 0  # (10,0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 2: Timeout")
    
    if dut.mst_weight.value != 10:
        raise TestFailure(f"Test 2 failed: Expected 10, got {dut.mst_weight.value}")
    
    print(f"Test 2 passed: MST weight = {dut.mst_weight.value}")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: 5 points with duplicates
    # Points: (0,0), (10,0), (10,0), (11,1), (12,2)
    # Scaled: (0,0), (5,0), (5,0), (6,1), (7,2)
    dut.n_points.value = 5
    dut.points[0].value = (0 << 5) | 0
    dut.points[1].value = (5 << 5) | 0
    dut.points[2].value = (5 << 5) | 0
    dut.points[3].value = (6 << 5) | 1
    dut.points[4].value = (7 << 5) | 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 3: Timeout")
    
    # Manual calculation:
    # Distances: (0,0)-(5,0)=5, (0,0)-(5,0)=5, (0,0)-(6,1)=7, (0,0)-(7,2)=9
    # (5,0)-(5,0)=0, (5,0)-(6,1)=2, (5,0)-(7,2)=4, (6,1)-(7,2)=2
    # MST: edges of weight 0, 2, 2, 5 = 9
    expected = 9
    if dut.mst_weight.value != expected:
        raise TestFailure(f"Test 3 failed: Expected {expected}, got {dut.mst_weight.value}")
    
    print(f"Test 3 passed: MST weight = {dut.mst_weight.value}")
    
    # Test case 4: Single point
    # Should be 0
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_points.value = 1
    dut.points[0].value = (5 << 5) | 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 4: Timeout")
    
    if dut.mst_weight.value != 0:
        raise TestFailure(f"Test 4 failed: Expected 0, got {dut.mst_weight.value}")
    
    print(f"Test 4 passed: MST weight = {dut.mst_weight.value}")
    
    # Test case 5: 2 points
    # (0,0) and (5,5) -> distance 10
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_points.value = 2
    dut.points[0].value = (0 << 5) | 0
    dut.points[1].value = (5 << 5) | 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 5: Timeout")
    
    if dut.mst_weight.value != 10:
        raise TestFailure(f"Test 5 failed: Expected 10, got {dut.mst_weight.value}")
    
    print(f"Test 5 passed: MST weight = {dut.mst_weight.value}")
    print("
All 5 tests passed!")
