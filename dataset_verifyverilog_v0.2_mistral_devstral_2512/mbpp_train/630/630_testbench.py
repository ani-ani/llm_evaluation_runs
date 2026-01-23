import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_adjacent_coords_basic(dut):
    """Test adjacent coordinates generation for basic inputs"""
    
    # Test case 1: (3, 4) should produce 9 coordinates
    dut.x_coord.value = 3
    dut.y_coord.value = 4
    await Timer(10, units='ns')
    
    expected_x = [2, 2, 2, 3, 3, 3, 4, 4, 4]
    expected_y = [3, 4, 5, 3, 4, 5, 3, 4, 5]
    
    actual_x = [int(dut.x_out[i].value) for i in range(9)]
    actual_y = [int(dut.y_out[i].value) for i in range(9)]
    
    print(f"Test 1: Input (3,4)")
    print(f"Expected X: {expected_x}")
    print(f"Actual X:   {actual_x}")
    print(f"Expected Y: {expected_y}")
    print(f"Actual Y:   {actual_y}")
    
    assert actual_x == expected_x, f"X mismatch: expected {expected_x}, got {actual_x}"
    assert actual_y == expected_y, f"Y mismatch: expected {expected_y}, got {actual_y}"
    print("Test 1 PASSED
")

@cocotb.test()
async def test_adjacent_coords_case2(dut):
    """Test adjacent coordinates for (4, 5)"""
    
    dut.x_coord.value = 4
    dut.y_coord.value = 5
    await Timer(10, units='ns')
    
    expected_x = [3, 3, 3, 4, 4, 4, 5, 5, 5]
    expected_y = [4, 5, 6, 4, 5, 6, 4, 5, 6]
    
    actual_x = [int(dut.x_out[i].value) for i in range(9)]
    actual_y = [int(dut.y_out[i].value) for i in range(9)]
    
    print(f"Test 2: Input (4,5)")
    print(f"Expected X: {expected_x}")
    print(f"Actual X:   {actual_x}")
    print(f"Expected Y: {expected_y}")
    print(f"Actual Y:   {actual_y}")
    
    assert actual_x == expected_x, f"X mismatch: expected {expected_x}, got {actual_x}"
    assert actual_y == expected_y, f"Y mismatch: expected {expected_y}, got {actual_y}"
    print("Test 2 PASSED
")

@cocotb.test()
async def test_adjacent_coords_case3(dut):
    """Test adjacent coordinates for (5, 6)"""
    
    dut.x_coord.value = 5
    dut.y_coord.value = 6
    await Timer(10, units='ns')
    
    expected_x = [4, 4, 4, 5, 5, 5, 6, 6, 6]
    expected_y = [5, 6, 7, 5, 6, 7, 5, 6, 7]
    
    actual_x = [int(dut.x_out[i].value) for i in range(9)]
    actual_y = [int(dut.y_out[i].value) for i in range(9)]
    
    print(f"Test 3: Input (5,6)")
    print(f"Expected X: {expected_x}")
    print(f"Actual X:   {actual_x}")
    print(f"Expected Y: {expected_y}")
    print(f"Actual Y:   {actual_y}")
    
    assert actual_x == expected_x, f"X mismatch: expected {expected_x}, got {actual_x}"
    assert actual_y == expected_y, f"Y mismatch: expected {expected_y}, got {actual_y}"
    print("Test 3 PASSED
")

@cocotb.test()
async def test_adjacent_coords_corner(dut):
    """Test edge case: (0, 0) with wraparound behavior"""
    
    dut.x_coord.value = 0
    dut.y_coord.value = 0
    await Timer(10, units='ns')
    
    # For unsigned arithmetic, 0-1 = 255 (256-1)
    expected_x = [255, 255, 255, 0, 0, 0, 1, 1, 1]
    expected_y = [255, 0, 1, 255, 0, 1, 255, 0, 1]
    
    actual_x = [int(dut.x_out[i].value) for i in range(9)]
    actual_y = [int(dut.y_out[i].value) for i in range(9)]
    
    print(f"Test 4: Input (0,0) - unsigned wraparound")
    print(f"Expected X: {expected_x}")
    print(f"Actual X:   {actual_x}")
    print(f"Expected Y: {expected_y}")
    print(f"Actual Y:   {actual_y}")
    
    assert actual_x == expected_x, f"X mismatch: expected {expected_x}, got {actual_x}"
    assert actual_y == expected_y, f"Y mismatch: expected {expected_y}, got {actual_y}"
    print("Test 4 PASSED
")

@cocotb.test()
async def test_adjacent_coords_max(dut):
    """Test edge case: (255, 255) with wraparound behavior"""
    
    dut.x_coord.value = 255
    dut.y_coord.value = 255
    await Timer(10, units='ns')
    
    # 255+1 = 0 (256), 255+0 = 255, 255-1 = 254
    expected_x = [254, 254, 254, 255, 255, 255, 0, 0, 0]
    expected_y = [254, 255, 0, 254, 255, 0, 254, 255, 0]
    
    actual_x = [int(dut.x_out[i].value) for i in range(9)]
    actual_y = [int(dut.y_out[i].value) for i in range(9)]
    
    print(f"Test 5: Input (255,255) - unsigned wraparound")
    print(f"Expected X: {expected_x}")
    print(f"Actual X:   {actual_x}")
    print(f"Expected Y: {expected_y}")
    print(f"Actual Y:   {actual_y}")
    
    assert actual_x == expected_x, f"X mismatch: expected {expected_x}, got {actual_x}"
    assert actual_y == expected_y, f"Y mismatch: expected {expected_y}, got {actual_y}"
    print("Test 5 PASSED
")

@cocotb.test()
async def test_adjacent_coords_parity(dut):
    """Test parity property: verify count and self-position"""
    
    dut.x_coord.value = 100
    dut.y_coord.value = 150
    await Timer(10, units='ns')
    
    # Count should be 9
    # Center (index 4) should be (100, 150)
    
    actual_x = [int(dut.x_out[i].value) for i in range(9)]
    actual_y = [int(dut.y_out[i].value) for i in range(9)]
    
    print(f"Test 6: Input (100,150) - parity check")
    print(f"Actual X: {actual_x}")
    print(f"Actual Y: {actual_y}")
    print(f"Center (index 4): ({actual_x[4]}, {actual_y[4]})")
    
    # Check center is correct
    assert actual_x[4] == 100, f"Center X should be 100, got {actual_x[4]}"
    assert actual_y[4] == 150, f"Center Y should be 150, got {actual_y[4]}"
    
    # Check all are in order
    for i in range(9):
        dx = i // 3  # 0, 0, 0, 1, 1, 1, 2, 2, 2
        dy = i % 3   # 0, 1, 2, 0, 1, 2, 0, 1, 2
        exp_x = 100 + (dx - 1)
        exp_y = 150 + (dy - 1)
        assert actual_x[i] == exp_x, f"Index {i}: expected X={exp_x}, got {actual_x[i]}"
        assert actual_y[i] == exp_y, f"Index {i}: expected Y={exp_y}, got {actual_y[i]}"
    
    print("Test 6 PASSED
")

print("=" * 50)
print("All tests completed!")
print("=" * 50)
