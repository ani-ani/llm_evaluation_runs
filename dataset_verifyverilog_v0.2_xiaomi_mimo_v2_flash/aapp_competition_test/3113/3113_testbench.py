import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to create triangle input values
def create_triangle(x1, y1, x2, y2, x3, y3):
    """Convert triangle coordinates to 3-bit binary values (0-7)"""
    return (
        (x1 & 0x7) << 12 | (y1 & 0x7) << 9 |
        (x2 & 0x7) << 6 | (y2 & 0x7) << 3 |
        (x3 & 0x7) << 0 | (y3 & 0x7)  # This is wrong, need separate signals
    )

# Better approach: Each coordinate is a separate 3-bit input
def coord_to_bits(val):
    return val & 0x7

@cocotb.test()
async def test_triangle_coverage_same(dut):
    """Test case where Garry and Jerry see same coverage"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 1 triangle each, same coverage
    # Garry: triangle (2,0)-(2,4)-(4,2)
    # Jerry: two triangles (2,0)-(2,2)-(4,2) and (2,2)-(4,2)-(2,4)
    # These should produce identical coverage
    
    dut.garry_tri_count.value = 1
    dut.jerry_tri_count.value = 2
    
    # Garry triangle 0
    dut.garry_tri_0_x1.value = 2
    dut.garry_tri_0_y1.value = 0
    dut.garry_tri_0_x2.value = 2
    dut.garry_tri_0_y2.value = 4
    dut.garry_tri_0_x3.value = 4
    dut.garry_tri_0_y3.value = 2
    
    # Jerry triangle 0
    dut.jerry_tri_0_x1.value = 2
    dut.jerry_tri_0_y1.value = 0
    dut.jerry_tri_0_x2.value = 2
    dut.jerry_tri_0_y2.value = 2
    dut.jerry_tri_0_x3.value = 4
    dut.jerry_tri_0_y3.value = 2
    
    # Jerry triangle 1
    dut.jerry_tri_1_x1.value = 2
    dut.jerry_tri_1_y1.value = 2
    dut.jerry_tri_1_x2.value = 4
    dut.jerry_tri_1_y2.value = 2
    dut.jerry_tri_1_x3.value = 2
    dut.jerry_tri_1_y3.value = 4
    
    # Other triangles unused
    dut.garry_tri_1_x1.value = 0
    dut.garry_tri_1_y1.value = 0
    dut.garry_tri_1_x2.value = 0
    dut.garry_tri_1_y2.value = 0
    dut.garry_tri_1_x3.value = 0
    dut.garry_tri_1_y3.value = 0
    dut.garry_tri_2_x1.value = 0
    dut.garry_tri_2_y1.value = 0
    dut.garry_tri_2_x2.value = 0
    dut.garry_tri_2_y2.value = 0
    dut.garry_tri_2_x3.value = 0
    dut.garry_tri_2_y3.value = 0
    dut.garry_tri_3_x1.value = 0
    dut.garry_tri_3_y1.value = 0
    dut.garry_tri_3_x2.value = 0
    dut.garry_tri_3_y2.value = 0
    dut.garry_tri_3_x3.value = 0
    dut.garry_tri_3_y3.value = 0
    
    dut.jerry_tri_2_x1.value = 0
    dut.jerry_tri_2_y1.value = 0
    dut.jerry_tri_2_x2.value = 0
    dut.jerry_tri_2_y2.value = 0
    dut.jerry_tri_2_x3.value = 0
    dut.jerry_tri_2_y3.value = 0
    dut.jerry_tri_3_x1.value = 0
    dut.jerry_tri_3_y1.value = 0
    dut.jerry_tri_3_x2.value = 0
    dut.jerry_tri_3_y2.value = 0
    dut.jerry_tri_3_x3.value = 0
    dut.jerry_tri_3_y3.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (up to 300 cycles for safety)
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check result
    assert dut.done.value == 1, "done signal not raised"
    if dut.same.value != 1:
        raise TestFailure(f"Expected same=1, got {int(dut.same.value)}")
    print("Test 1 passed: Same coverage detected")

@cocotb.test()
async def test_triangle_coverage_different(dut):
    """Test case where Garry and Jerry see different coverage"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Garry: 1 triangle
    dut.garry_tri_count.value = 1
    dut.garry_tri_0_x1.value = 2
    dut.garry_tri_0_y1.value = 0
    dut.garry_tri_0_x2.value = 2
    dut.garry_tri_0_y2.value = 4
    dut.garry_tri_0_x3.value = 4
    dut.garry_tri_0_y3.value = 2
    
    # Jerry: 3 small triangles that don't fully cover
    dut.jerry_tri_count.value = 3
    
    # Triangle 0: (2,0)-(2,1)-(3,1)
    dut.jerry_tri_0_x1.value = 2
    dut.jerry_tri_0_y1.value = 0
    dut.jerry_tri_0_x2.value = 2
    dut.jerry_tri_0_y2.value = 1
    dut.jerry_tri_0_x3.value = 3
    dut.jerry_tri_0_y3.value = 1
    
    # Triangle 1: (2,1)-(3,2)-(3,1)
    dut.jerry_tri_1_x1.value = 2
    dut.jerry_tri_1_y1.value = 1
    dut.jerry_tri_1_x2.value = 3
    dut.jerry_tri_1_y2.value = 2
    dut.jerry_tri_1_x3.value = 3
    dut.jerry_tri_1_y3.value = 1
    
    # Triangle 2: (3,2)-(4,2)-(3,3)
    dut.jerry_tri_2_x1.value = 3
    dut.jerry_tri_2_y1.value = 2
    dut.jerry_tri_2_x2.value = 4
    dut.jerry_tri_2_y2.value = 2
    dut.jerry_tri_2_x3.value = 3
    dut.jerry_tri_2_y3.value = 3
    
    # Unused
    dut.garry_tri_1_x1.value = 0
    dut.garry_tri_1_y1.value = 0
    dut.garry_tri_1_x2.value = 0
    dut.garry_tri_1_y2.value = 0
    dut.garry_tri_1_x3.value = 0
    dut.garry_tri_1_y3.value = 0
    dut.garry_tri_2_x1.value = 0
    dut.garry_tri_2_y1.value = 0
    dut.garry_tri_2_x2.value = 0
    dut.garry_tri_2_y2.value = 0
    dut.garry_tri_2_x3.value = 0
    dut.garry_tri_2_y3.value = 0
    dut.garry_tri_3_x1.value = 0
    dut.garry_tri_3_y1.value = 0
    dut.garry_tri_3_x2.value = 0
    dut.garry_tri_3_y2.value = 0
    dut.garry_tri_3_x3.value = 0
    dut.garry_tri_3_y3.value = 0
    
    dut.jerry_tri_3_x1.value = 0
    dut.jerry_tri_3_y1.value = 0
    dut.jerry_tri_3_x2.value = 0
    dut.jerry_tri_3_y2.value = 0
    dut.jerry_tri_3_x3.value = 0
    dut.jerry_tri_3_y3.value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal not raised"
    if dut.same.value != 0:
        raise TestFailure(f"Expected same=0, got {int(dut.same.value)}")
    print("Test 2 passed: Different coverage detected")

@cocotb.test()
async def test_empty_clouds(dut):
    """Test case: both have no triangles"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.garry_tri_count.value = 0
    dut.jerry_tri_count.value = 0
    
    # Fill with zeros
    for prefix in ['garry_tri', 'jerry_tri']:
        for i in range(4):
            setattr(dut, f'{prefix}_{i}_x1', 0)
            setattr(dut, f'{prefix}_{i}_y1', 0)
            setattr(dut, f'{prefix}_{i}_x2', 0)
            setattr(dut, f'{prefix}_{i}_y2', 0)
            setattr(dut, f'{prefix}_{i}_x3', 0)
            setattr(dut, f'{prefix}_{i}_y3', 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal not raised"
    if dut.same.value != 1:
        raise TestFailure(f"Expected same=1 for empty clouds, got {int(dut.same.value)}")
    print("Test 3 passed: Empty clouds match")

@cocotb.test()
async def test_single_pixel_difference(dut):
    """Test case: only one pixel differs"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Garry: triangle covering (2,2)-(3,3)
    dut.garry_tri_count.value = 1
    dut.garry_tri_0_x1.value = 2
    dut.garry_tri_0_y1.value = 2
    dut.garry_tri_0_x2.value = 2
    dut.garry_tri_0_y2.value = 3
    dut.garry_tri_0_x3.value = 3
    dut.garry_tri_0_y3.value = 3
    
    # Jerry: same triangle but tiny shift
    dut.jerry_tri_count.value = 1
    dut.jerry_tri_0_x1.value = 2
    dut.jerry_tri_0_y1.value = 2
    dut.jerry_tri_0_x2.value = 2
    dut.jerry_tri_0_y2.value = 3
    dut.jerry_tri_0_x3.value = 4
    dut.jerry_tri_0_y3.value = 3
    
    # Others zero
    for prefix in ['garry_tri', 'jerry_tri']:
        for i in range(1, 4):
            setattr(dut, f'{prefix}_{i}_x1', 0)
            setattr(dut, f'{prefix}_{i}_y1', 0)
            setattr(dut, f'{prefix}_{i}_x2', 0)
            setattr(dut, f'{prefix}_{i}_y2', 0)
            setattr(dut, f'{prefix}_{i}_x3', 0)
            setattr(dut, f'{prefix}_{i}_y3', 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal not raised"
    if dut.same.value != 0:
        raise TestFailure(f"Expected same=0 for pixel difference, got {int(dut.same.value)}")
    print("Test 4 passed: Single pixel difference detected")

@cocotb.test()
async def test_full_grid_coverage(dut):
    """Test case: cover all pixels with triangles"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Garry: 2 triangles covering whole 8x8 grid
    # Triangle 1: (0,0)-(0,7)-(7,7)
    # Triangle 2: (0,0)-(7,7)-(7,0)
    dut.garry_tri_count.value = 2
    dut.garry_tri_0_x1.value = 0
    dut.garry_tri_0_y1.value = 0
    dut.garry_tri_0_x2.value = 0
    dut.garry_tri_0_y2.value = 7
    dut.garry_tri_0_x3.value = 7
    dut.garry_tri_0_y3.value = 7
    
    dut.garry_tri_1_x1.value = 0
    dut.garry_tri_1_y1.value = 0
    dut.garry_tri_1_x2.value = 7
    dut.garry_tri_1_y2.value = 7
    dut.garry_tri_1_x3.value = 7
    dut.garry_tri_1_y3.value = 0
    
    # Jerry: same configuration
    dut.jerry_tri_count.value = 2
    dut.jerry_tri_0_x1.value = 0
    dut.jerry_tri_0_y1.value = 0
    dut.jerry_tri_0_x2.value = 0
    dut.jerry_tri_0_y2.value = 7
    dut.jerry_tri_0_x3.value = 7
    dut.jerry_tri_0_y3.value = 7
    
    dut.jerry_tri_1_x1.value = 0
    dut.jerry_tri_1_y1.value = 0
    dut.jerry_tri_1_x2.value = 7
    dut.jerry_tri_1_y2.value = 7
    dut.jerry_tri_1_x3.value = 7
    dut.jerry_tri_1_y3.value = 0
    
    # Others zero
    for i in range(2, 4):
        setattr(dut, f'garry_tri_{i}_x1', 0)
        setattr(dut, f'garry_tri_{i}_y1', 0)
        setattr(dut, f'garry_tri_{i}_x2', 0)
        setattr(dut, f'garry_tri_{i}_y2', 0)
        setattr(dut, f'garry_tri_{i}_x3', 0)
        setattr(dut, f'garry_tri_{i}_y3', 0)
        setattr(dut, f'jerry_tri_{i}_x1', 0)
        setattr(dut, f'jerry_tri_{i}_y1', 0)
        setattr(dut, f'jerry_tri_{i}_x2', 0)
        setattr(dut, f'jerry_tri_{i}_y2', 0)
        setattr(dut, f'jerry_tri_{i}_x3', 0)
        setattr(dut, f'jerry_tri_{i}_y3', 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal not raised"
    if dut.same.value != 1:
        raise TestFailure(f"Expected same=1 for full grid, got {int(dut.same.value)}")
    print("Test 5 passed: Full grid coverage matches")

@cocotb.test()
async def test_triangle_edge_cases(dut):
    """Test with triangles on exact boundaries"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Garry: vertical line triangle at x=4
    dut.garry_tri_count.value = 1
    dut.garry_tri_0_x1.value = 4
    dut.garry_tri_0_y1.value = 0
    dut.garry_tri_0_x2.value = 4
    dut.garry_tri_0_y2.value = 4
    dut.garry_tri_0_x3.value = 5
    dut.garry_tri_0_y3.value = 2
    
    # Jerry: exact same but in different order
    dut.jerry_tri_count.value = 1
    dut.jerry_tri_0_x1.value = 5
    dut.jerry_tri_0_y1.value = 2
    dut.jerry_tri_0_x2.value = 4
    dut.jerry_tri_0_y2.value = 0
    dut.jerry_tri_0_x3.value = 4
    dut.jerry_tri_0_y3.value = 4
    
    # Others zero
    for prefix in ['garry_tri', 'jerry_tri']:
        for i in range(1, 4):
            setattr(dut, f'{prefix}_{i}_x1', 0)
            setattr(dut, f'{prefix}_{i}_y1', 0)
            setattr(dut, f'{prefix}_{i}_x2', 0)
            setattr(dut, f'{prefix}_{i}_y2', 0)
            setattr(dut, f'{prefix}_{i}_x3', 0)
            setattr(dut, f'{prefix}_{i}_y3', 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "done signal not raised"
    if dut.same.value != 1:
        raise TestFailure(f"Expected same=1 for re-ordered triangle, got {int(dut.same.value)}")
    print("Test 6 passed: Re-ordered triangle matches")