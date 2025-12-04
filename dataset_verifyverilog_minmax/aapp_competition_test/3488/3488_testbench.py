import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_poly(dut):
    """Test minimal convex hull vertex count"""
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_case1 = {
        'vx': [0,0,3,3], 'vy': [0,3,3,0],  # Square vertices
        'vertex_count': 4,
        'px': [1,2], 'py': [1,2], 'point_count': 2,  # Points inside
        'expected': 4  # Must use full polygon
    }
    
    test_case2 = {
        'vx': [3,7,10,10,7,3,0,0],  # Octagon vertices
        'vy': [0,0,3,7,10,10,7,3],
        'vertex_count': 8,
        'px': [3,5,7,9,3,5,7,5,7,7], 'py': [3,3,3,3,5,5,5,7,7,9],
        'point_count': 10,  # Requires scoping to 4 points
        'expected': 4  # Minimal solution exists
    }
    
    # Modified test case2 for 4 points (scale down)
    test_case2['point_count'] = 4
    test_case2['px'] = [3,5,7,9]
    test_case2['py'] = [3,3,3,3]
    
    test_cases = [test_case1, test_case2]
    passed = 0
    
    for case in test_cases:
        # Load vertices
        for i in range(8):
            dut.vx[i].value = case['vx'][i] if i < len(case['vx']) else 0
            dut.vy[i].value = case['vy'][i] if i < len(case['vy']) else 0
        # Load points
        for i in range(4):
            dut.px[i].value = case['px'][i] if i < len(case['px']) else 0
            dut.py[i].value = case['py'][i] if i < len(case['py']) else 0
        
        dut.vertex_count.value = case['vertex_count']
        dut.point_count.value = case['point_count']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.min_vertices.value == case['expected']:
            passed += 1
        else:
            dut._log.error(
                f"Test failed: Expected {case['expected']}, got {dut.min_vertices.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")