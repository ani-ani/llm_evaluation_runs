import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_perimeter_rectangle(dut):
    """Test the max_perimeter_rectangle module with various grid configurations"""
    
    # Test Case 1: All free cells (8x8 grid)
    # Expected: 30 (7x8 rectangle: 2*(7+8)=30)
    dut.grid[0] = 0b00000000
    dut.grid[1] = 0b00000000
    dut.grid[2] = 0b00000000
    dut.grid[3] = 0b00000000
    dut.grid[4] = 0b00000000
    dut.grid[5] = 0b00000000
    dut.grid[6] = 0b00000000
    dut.grid[7] = 0b00000000
    await Timer(1, units='ns')
    assert dut.max_perimeter.value == 30, f"Test 1 failed: expected 30, got {dut.max_perimeter.value}"
    print("Test 1 passed: All free cells -> perimeter 30")
    
    # Test Case 2: Single free cell in corner
    # Expected: 4 (1x1 rectangle)
    dut.grid[0] = 0b10000000
    dut.grid[1] = 0b11111111
    dut.grid[2] = 0b11111111
    dut.grid[3] = 0b11111111
    dut.grid[4] = 0b11111111
    dut.grid[5] = 0b11111111
    dut.grid[6] = 0b11111111
    dut.grid[7] = 0b11111111
    await Timer(1, units='ns')
    assert dut.max_perimeter.value == 4, f"Test 2 failed: expected 4, got {dut.max_perimeter.value}"
    print("Test 2 passed: Single free cell -> perimeter 4")
    
    # Test Case 3: 2x2 free block
    # Expected: 8 (2x2 rectangle: 2*(2+2)=8)
    dut.grid[0] = 0b00000000
    dut.grid[1] = 0b00000000
    dut.grid[2] = 0b11111111
    dut.grid[3] = 0b11111111
    dut.grid[4] = 0b11111111
    dut.grid[5] = 0b11111111
    dut.grid[6] = 0b11111111
    dut.grid[7] = 0b11111111
    await Timer(1, units='ns')
    assert dut.max_perimeter.value == 8, f"Test 3 failed: expected 8, got {dut.max_perimeter.value}"
    print("Test 3 passed: 2x2 free block -> perimeter 8")
    
    # Test Case 4: All blocked cells
    # Expected: 0
    dut.grid[0] = 0b11111111
    dut.grid[1] = 0b11111111
    dut.grid[2] = 0b11111111
    dut.grid[3] = 0b11111111
    dut.grid[4] = 0b11111111
    dut.grid[5] = 0b11111111
    dut.grid[6] = 0b11111111
    dut.grid[7] = 0b11111111
    await Timer(1, units='ns')
    assert dut.max_perimeter.value == 0, f"Test 4 failed: expected 0, got {dut.max_perimeter.value}"
    print("Test 4 passed: All blocked -> perimeter 0")
    
    # Test Case 5: 3x3 free block in middle with obstacles around
    # Expected: 12 (3x3 rectangle: 2*(3+3)=12)
    dut.grid[0] = 0b11111111
    dut.grid[1] = 0b11000011
    dut.grid[2] = 0b11000011
    dut.grid[3] = 0b11000011
    dut.grid[4] = 0b11111111
    dut.grid[5] = 0b11111111
    dut.grid[6] = 0b11111111
    dut.grid[7] = 0b11111111
    await Timer(1, units='ns')
    assert dut.max_perimeter.value == 12, f"Test 5 failed: expected 12, got {dut.max_perimeter.value}"
    print("Test 5 passed: 3x3 free block -> perimeter 12")
    
    # Test Case 6: 4x2 free block
    # Expected: 12 (4x2 rectangle: 2*(4+2)=12)
    dut.grid[0] = 0b00001111
    dut.grid[1] = 0b00001111
    dut.grid[2] = 0b00001111
    dut.grid[3] = 0b00001111
    dut.grid[4] = 0b11111111
    dut.grid[5] = 0b11111111
    dut.grid[6] = 0b11111111
    dut.grid[7] = 0b11111111
    await Timer(1, units='ns')
    assert dut.max_perimeter.value == 12, f"Test 6 failed: expected 12, got {dut.max_perimeter.value}"
    print("Test 6 passed: 4x2 free block -> perimeter 12")
    
    print(f"
Summary: 6/6 tests passed")