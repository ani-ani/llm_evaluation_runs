import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(value):
    if value & 0x80000000:  # negative
        return -((~value + 1) / 65536.0)
    return value / 65536.0

@cocotb.test()
async def test_bulkhead_planner_basic(dut):
    """Test basic rectangular boat with C=50"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: Rectangular boat 110x10 area=1100
    # Vertices: (110,10), (80,10), (80,0), (110,0)
    # min_area = 50, M = 1100/50 = 22, but we need M <= 8
    # Actually M = floor(1100/50) = 22, but max M=8 so output M=8
    # But wait, the problem scales C to be relative to total area
    # Let's scale: if total_area=1100, we want M sections
    # The test case expects M=6, meaning min_area should scale with total_area
    # For hardware test, we'll use normalized scale: total_area ~1.0
    
    # Let's use normalized coordinates: divide by 1000
    # Rect 0.110 x 0.010 = 0.00110 area
    # min_area = 0.00110 / 6 = 0.0001833
    # Or simpler: scale up to make area = 0x10000 (1.0 in Q16.16)
    
    dut.num_vertices.value = 4
    dut.min_area.value = float_to_q16_16(0.0001833)  # Scaled appropriately
    
    # Set vertices (scaled to make total area near 1.0 in Q16.16)
    dut.vertices_x[0].value = float_to_q16_16(0.110)
    dut.vertices_y[0].value = float_to_q16_16(0.010)
    dut.vertices_x[1].value = float_to_q16_16(0.080)
    dut.vertices_y[1].value = float_to_q16_16(0.010)
    dut.vertices_x[2].value = float_to_q16_16(0.080)
    dut.vertices_y[2].value = float_to_q16_16(0.000)
    dut.vertices_x[3].value = float_to_q16_16(0.110)
    dut.vertices_y[3].value = float_to_q16_16(0.000)
    
    await Timer(10, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    # Wait for completion (max 256 cycles * 8 bulkheads + overhead)
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await Timer(10, units='ns')
        timeout += 1
    
    assert dut.done.value, "Module did not complete in time"
    
    # Check results
    M = int(dut.M.value)
    print(f"Test 1: M={M} (expected: 6)")
    assert M == 6, f"Wrong M: got {M}, expected 6"
    
    # Check bulkhead count
    bc = int(dut.bulkhead_count.value)
    print(f"Bulkhead count: {bc}")
    assert bc == 5, f"Wrong bulkhead count: {bc}, expected 5"
    
    # Check bulkhead positions are in increasing order
    prev_x = 0
    for i in range(bc):
        x = q16_16_to_float(int(dut.bulkhead_x[i].value))
        print(f"Bulkhead {i+1}: {x:.6f}")
        assert x > prev_x, f"Bulkheads not in increasing order"
        prev_x = x
    
    print("Test 1 passed!")

@cocotb.test()
async def test_bulkhead_planner_triangle(dut):
    """Test triangular boat with C=24"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Triangle vertices: (0.010,0.010), (0.030,0.010), (0.020,0.020)
    # Area = 0.0001
    # min_area = 0.0001 / 4 = 0.000025
    
    dut.num_vertices.value = 3
    dut.min_area.value = float_to_q16_16(0.000025)
    
    dut.vertices_x[0].value = float_to_q16_16(0.010)
    dut.vertices_y[0].value = float_to_q16_16(0.010)
    dut.vertices_x[1].value = float_to_q16_16(0.030)
    dut.vertices_y[1].value = float_to_q16_16(0.010)
    dut.vertices_x[2].value = float_to_q16_16(0.020)
    dut.vertices_y[2].value = float_to_q16_16(0.020)
    
    await Timer(10, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await Timer(10, units='ns')
        timeout += 1
    
    assert dut.done.value, "Module did not complete in time"
    
    M = int(dut.M.value)
    print(f"Test 2: M={M} (expected: 4)")
    assert M == 4, f"Wrong M: got {M}, expected 4"
    
    bc = int(dut.bulkhead_count.value)
    print(f"Bulkhead count: {bc}")
    assert bc == 3, f"Wrong bulkhead count: {bc}, expected 3"
    
    # Expected bulkheads at approx 0.017071, 0.020, 0.022929
    # (scaled from 17.071067, 20, 22.928932 with scale factor 0.001)
    expected = [0.017071, 0.020, 0.022929]
    
    for i in range(bc):
        x = q16_16_to_float(int(dut.bulkhead_x[i].value))
        print(f"Bulkhead {i+1}: {x:.6f} (expected: {expected[i]:.6f})")
        # Allow 1% error
        assert abs(x - expected[i]) < 0.0003, f"Bulkhead {i+1} out of range"
    
    print("Test 2 passed!")

@cocotb.test()
async def test_bulkhead_planner_complex(dut):
    """Test complex polygon from sample input 3"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Sample 3 has 10 vertices, but we support max 8
    # We'll truncate to first 8 vertices and adjust expected output
    dut.num_vertices.value = 8
    
    # Scale area to be around 1.0
    # Vertices: (100,120), (97,50), (94,99), (74,97), (50,87), (29,71), (13,50), (3,26)
    # Divide by 1000 to normalize
    
    vertices_scaled = [
        (100, 120), (97, 50), (94, 99), (74, 97),
        (50, 87), (29, 71), (13, 50), (3, 26)
    ]
    
    for i, (x, y) in enumerate(vertices_scaled):
        dut.vertices_x[i].value = float_to_q16_16(x / 1000.0)
        dut.vertices_y[i].value = float_to_q16_16(y / 1000.0)
    
    # Compute approximate total area and set min_area for M=6
    # Total area ~ 0.48 (approx)
    # For M=6, min_area = 0.48/6 = 0.08
    dut.min_area.value = float_to_q16_16(0.08)
    
    await Timer(10, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await Timer(10, units='ns')
        timeout += 1
    
    assert dut.done.value, "Module did not complete in time"
    
    M = int(dut.M.value)
    print(f"Test 3: M={M} (expected: 6)")
    assert M == 6, f"Wrong M: got {M}, expected 6"
    
    bc = int(dut.bulkhead_count.value)
    print(f"Bulkhead count: {bc}")
    assert bc == 5, f"Wrong bulkhead count: {bc}, expected 5"
    
    # Check bulkheads are in increasing order
    prev_x = 0
    for i in range(bc):
        x = q16_16_to_float(int(dut.bulkhead_x[i].value))
        print(f"Bulkhead {i+1}: {x:.6f}")
        assert x > prev_x, f"Bulkheads not in increasing order"
        prev_x = x
    
    print("Test 3 passed!")

@cocotb.test()
async def test_bulkhead_planner_edge_case(dut):
    """Test edge case with minimum vertices and equal area"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Simple triangle with area exactly 1.0
    # (0,0), (2,0), (1,2) -> area = 2
    # Set min_area to 0.5 -> M=4
    
    dut.num_vertices.value = 3
    dut.min_area.value = float_to_q16_16(0.5)
    
    dut.vertices_x[0].value = float_to_q16_16(0.0)
    dut.vertices_y[0].value = float_to_q16_16(0.0)
    dut.vertices_x[1].value = float_to_q16_16(2.0)
    dut.vertices_y[1].value = float_to_q16_16(0.0)
    dut.vertices_x[2].value = float_to_q16_16(1.0)
    dut.vertices_y[2].value = float_to_q16_16(2.0)
    
    await Timer(10, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await Timer(10, units='ns')
        timeout += 1
    
    assert dut.done.value, "Module did not complete in time"
    
    M = int(dut.M.value)
    print(f"Test 4: M={M}")
    assert M == 4, f"Wrong M: got {M}, expected 4"
    
    bc = int(dut.bulkhead_count.value)
    assert bc == 3, f"Wrong bulkhead count: {bc}"
    
    # Check ordering
    prev_x = -1.0
    for i in range(bc):
        x = q16_16_to_float(int(dut.bulkhead_x[i].value))
        print(f"Bulkhead {i+1}: {x:.6f}")
        assert x > prev_x, f"Bulkheads not in increasing order"
        assert 0.0 <= x <= 2.0, f"Bulkhead {i+1} out of range"
        prev_x = x
    
    print("Test 4 passed!")

@cocotb.test()
async def test_bulkhead_planner_max_sections(dut):
    """Test when M is limited to 8"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Large area triangle: (0,0), (10,0), (5,10) -> area = 50
    # Set min_area very small (0.01) -> M would be 5000, but capped at 8
    
    dut.num_vertices.value = 3
    dut.min_area.value = float_to_q16_16(0.01)
    
    dut.vertices_x[0].value = float_to_q16_16(0.0)
    dut.vertices_y[0].value = float_to_q16_16(0.0)
    dut.vertices_x[1].value = float_to_q16_16(10.0)
    dut.vertices_y[1].value = float_to_q16_16(0.0)
    dut.vertices_x[2].value = float_to_q16_16(5.0)
    dut.vertices_y[2].value = float_to_q16_16(10.0)
    
    await Timer(10, units='ns')
    dut.start.value = 1
    await Timer(20, units='ns')
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await Timer(10, units='ns')
        timeout += 1
    
    assert dut.done.value, "Module did not complete in time"
    
    M = int(dut.M.value)
    print(f"Test 5: M={M} (capped at 8)")
    assert M == 8, f"Wrong M: got {M}, expected 8"
    
    bc = int(dut.bulkhead_count.value)
    assert bc == 7, f"Wrong bulkhead count: {bc}, expected 7"
    
    print("Test 5 passed!")

print("All tests completed. Check above for pass/fail status.")