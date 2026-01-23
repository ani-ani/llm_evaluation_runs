import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_species_intersection_area(dut):
    """Test species intersection area computation with fixed-point coordinates"""
    
    # Helper: convert float to 8-bit integer (0-255 range, 0-1000 mapped)
    def float_to_int8(val):
        scaled = (val / 1000.0) * 255.0
        return int(min(255, max(0, scaled)))
    
    # Helper: convert area to Q16.16
    def float_to_q16_16(val):
        return int(val * 65536)
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(50, units="ns")
    
    print("
=== Test 1: Sample Input (P=3, A=3) ===")
    # Pine: (0,6), (6,0), (6,6) -> triangle 18.0
    # Aspen: (4,4), (10,4), (4,10) -> triangle 18.0
    # Intersection: 4.0
    
    pine_coords = [(0.0, 6.0), (6.0, 0.0), (6.0, 6.0)]
    aspen_coords = [(4.0, 4.0), (10.0, 4.0), (4.0, 10.0)]
    
    dut.pine_count.value = 3
    dut.aspen_count.value = 3
    
    for i in range(3):
        dut.pine_x[i].value = float_to_int8(pine_coords[i][0])
        dut.pine_y[i].value = float_to_int8(pine_coords[i][1])
        dut.aspen_x[i].value = float_to_int8(aspen_coords[i][0])
        dut.aspen_y[i].value = float_to_int8(aspen_coords[i][1])
    
    # Fill unused slots
    for i in range(3, 4):
        dut.pine_x[i].value = 0
        dut.pine_y[i].value = 0
        dut.aspen_x[i].value = 0
        dut.aspen_y[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.error.value:
        print("ERROR flag raised!")
    
    result_area_q16_16 = int(dut.intersection_area.value)
    result_area = result_area_q16_16 / 65536.0
    
    expected = 4.0
    print(f"Result: {result_area:.6f}, Expected: {expected:.6f}")
    assert abs(result_area - expected) < 0.1, f"Test 1 failed: {result_area} vs {expected}"
    print("Test 1 PASSED")
    
    await Timer(100, units="ns")
    
    print("
=== Test 2: Overlapping Rectangles ===")
    # Two 2x2 squares overlapping by 1x1 = area 1.0
    pine_coords = [(0.0, 0.0), (2.0, 0.0), (2.0, 2.0), (0.0, 2.0)]
    aspen_coords = [(1.0, 1.0), (3.0, 1.0), (3.0, 3.0), (1.0, 3.0)]
    
    dut.pine_count.value = 4
    dut.aspen_count.value = 4
    
    for i in range(4):
        dut.pine_x[i].value = float_to_int8(pine_coords[i][0])
        dut.pine_y[i].value = float_to_int8(pine_coords[i][1])
        dut.aspen_x[i].value = float_to_int8(aspen_coords[i][0])
        dut.aspen_y[i].value = float_to_int8(aspen_coords[i][1])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_area_q16_16 = int(dut.intersection_area.value)
    result_area = result_area_q16_16 / 65536.0
    
    expected = 1.0
    print(f"Result: {result_area:.6f}, Expected: {expected:.6f}")
    assert abs(result_area - expected) < 0.2, f"Test 2 failed: {result_area} vs {expected}"
    print("Test 2 PASSED")
    
    await Timer(100, units="ns")
    
    print("
=== Test 3: No Intersection ===")
    pine_coords = [(0.0, 0.0), (1.0, 0.0), (0.5, 1.0)]  # Small triangle
    aspen_coords = [(5.0, 5.0), (6.0, 5.0), (5.5, 6.0)]  # Far away triangle
    
    dut.pine_count.value = 3
    dut.aspen_count.value = 3
    
    for i in range(3):
        dut.pine_x[i].value = float_to_int8(pine_coords[i][0])
        dut.pine_y[i].value = float_to_int8(pine_coords[i][1])
        dut.aspen_x[i].value = float_to_int8(aspen_coords[i][0])
        dut.aspen_y[i].value = float_to_int8(aspen_coords[i][1])
    
    # Fill unused
    dut.pine_x[3].value = 0
    dut.pine_y[3].value = 0
    dut.aspen_x[3].value = 0
    dut.aspen_y[3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_area_q16_16 = int(dut.intersection_area.value)
    result_area = result_area_q16_16 / 65536.0
    
    expected = 0.0
    print(f"Result: {result_area:.6f}, Expected: {expected:.6f}")
    assert abs(result_area - expected) < 0.1, f"Test 3 failed: {result_area} vs {expected}"
    print("Test 3 PASSED")
    
    await Timer(100, units="ns")
    
    print("
=== Test 4: Insufficient Points (P=2) ===")
    dut.pine_count.value = 2
    dut.aspen_count.value = 3
    
    # Only 2 pine points (cannot form polygon)
    dut.pine_x[0].value = float_to_int8(0.0)
    dut.pine_y[0].value = float_to_int8(0.0)
    dut.pine_x[1].value = float_to_int8(1.0)
    dut.pine_y[1].value = float_to_int8(0.0)
    
    for i in range(3):
        dut.aspen_x[i].value = float_to_int8(aspen_coords[i][0])
        dut.aspen_y[i].value = float_to_int8(aspen_coords[i][1])
    
    dut.pine_x[2].value = 0
    dut.pine_y[2].value = 0
    dut.pine_x[3].value = 0
    dut.pine_y[3].value = 0
    dut.aspen_x[3].value = 0
    dut.aspen_y[3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_area_q16_16 = int(dut.intersection_area.value)
    result_area = result_area_q16_16 / 65536.0
    
    expected = 0.0
    print(f"Result: {result_area:.6f}, Expected: {expected:.6f}")
    assert result_area == 0, f"Test 4 failed: expected 0, got {result_area}"
    print("Test 4 PASSED")
    
    await Timer(100, units="ns")
    
    print("
=== Test 5: Complex Intersection ===")
    # Diamond and rotated square intersection
    pine_coords = [(2.0, 2.0), (4.0, 2.0), (4.0, 4.0), (2.0, 4.0)]  # Square 2x2
    aspen_coords = [(3.0, 1.0), (5.0, 3.0), (3.0, 5.0), (1.0, 3.0)]  # Diamond
    # Expected intersection ~ 2.5 (approximate)
    
    dut.pine_count.value = 4
    dut.aspen_count.value = 4
    
    for i in range(4):
        dut.pine_x[i].value = float_to_int8(pine_coords[i][0])
        dut.pine_y[i].value = float_to_int8(pine_coords[i][1])
        dut.aspen_x[i].value = float_to_int8(aspen_coords[i][0])
        dut.aspen_y[i].value = float_to_int8(aspen_coords[i][1])
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_area_q16_16 = int(dut.intersection_area.value)
    result_area = result_area_q16_16 / 65536.0
    
    # Actual intersection area is 2.0
    expected = 2.0
    print(f"Result: {result_area:.6f}, Expected: {expected:.6f}")
    assert abs(result_area - expected) < 0.3, f"Test 5 failed: {result_area} vs {expected}"
    print("Test 5 PASSED")
    
    print("
=== SUMMARY: 5/5 tests passed ===")