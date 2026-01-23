import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_elastic_band_area(dut):
    """Test elastic band area computation with point removals"""
    
    # Clock generation
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper: Convert float to Q16.16 fixed-point
    def to_q16_16(value):
        return int(value * 65536)
    
    # Helper: Convert Q16.16 to float
    def from_q16_16(value):
        if value >= 0x80000000:
            value = value - 0x100000000
        return value / 65536.0
    
    # Test Case 1: Original example
    # Points: (1,4), (2,2), (4,1), (3,5), (5,3)
    # Removals: L, U, R
    dut.num_points.value = 5
    dut.num_removals.value = 3
    
    points_x = [1, 2, 4, 3, 5]
    points_y = [4, 2, 1, 5, 3]
    for i in range(5):
        dut.points_x[i].value = points_x[i]
        dut.points_y[i].value = points_y[i]
    
    # L=0, U=2, R=1
    removals = [0, 2, 1]
    for i in range(3):
        dut.removals[i].value = removals[i]
    
    # Expected areas (Q16.16): 9.0, 6.5, 2.5
    expected = [9.0, 6.5, 2.5]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = []
    timeout = 20000
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.area_valid.value == 1:
            area_val = from_q16_16(int(dut.area_out.value))
            results.append(area_val)
            print(f"Area {len(results)}: {area_val:.1f}")
        
        if dut.done.value == 1:
            break
    
    # Verify results
    assert len(results) == len(expected), f"Expected {len(expected)} areas, got {len(results)}"
    for i, (got, exp) in enumerate(zip(results, expected)):
        assert abs(got - exp) < 0.1, f"Area {i}: expected {exp}, got {got:.1f}"
    
    print(f"
Test 1: {len(results)}/{len(expected)} tests passed")
    
    # Test Case 2: Second example from problem
    # Reset first
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Points: (1,6), (2,4), (3,1), (4,2), (5,7), (6,5), (7,9), (8,3)
    # Removals: U,R,D,U,U,L (6 removals)
    dut.num_points.value = 8
    dut.num_removals.value = 6
    
    points_x = [1, 2, 3, 4, 5, 6, 7, 8]
    points_y = [6, 4, 1, 2, 7, 5, 9, 3]
    for i in range(8):
        dut.points_x[i].value = points_x[i]
        dut.points_y[i].value = points_y[i]
    
    # U=2, R=1, D=3, U=2, U=2, L=0
    removals = [2, 1, 3, 2, 2, 0]
    for i in range(6):
        dut.removals[i].value = removals[i]
    
    # Expected areas: 34.0, 24.0, 16.5, 14.0, 9.5, 5.0
    expected2 = [34.0, 24.0, 16.5, 14.0, 9.5, 5.0]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results2 = []
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.area_valid.value == 1:
            area_val = from_q16_16(int(dut.area_out.value))
            results2.append(area_val)
            print(f"Area {len(results2)}: {area_val:.1f}")
        
        if dut.done.value == 1:
            break
    
    assert len(results2) == len(expected2), f"Expected {len(expected2)} areas, got {len(results2)}"
    for i, (got, exp) in enumerate(zip(results2, expected2)):
        assert abs(got - exp) < 0.1, f"Area {i}: expected {exp}, got {got:.1f}"
    
    print(f"
Test 2: {len(results2)}/{len(expected2)} tests passed")
    
    # Test Case 3: Triangle (minimal case)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Points: (0,0), (4,0), (0,3)
    # Area before removal: 6.0
    # Removal: D (bottommost is (0,0))
    dut.num_points.value = 3
    dut.num_removals.value = 1
    
    dut.points_x[0].value = 0
    dut.points_y[0].value = 0
    dut.points_x[1].value = 4
    dut.points_y[1].value = 0
    dut.points_x[2].value = 0
    dut.points_y[2].value = 3
    
    dut.removals[0].value = 3  # D
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results3 = []
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.area_valid.value == 1:
            area_val = from_q16_16(int(dut.area_out.value))
            results3.append(area_val)
            print(f"Area: {area_val:.1f}")
        
        if dut.done.value == 1:
            break
    
    assert len(results3) == 1
    assert abs(results3[0] - 6.0) < 0.1, f"Triangle area: expected 6.0, got {results3[0]:.1f}"
    print(f"
Test 3: 1/1 tests passed")
    
    print("
=== ALL TESTS PASSED ===")
