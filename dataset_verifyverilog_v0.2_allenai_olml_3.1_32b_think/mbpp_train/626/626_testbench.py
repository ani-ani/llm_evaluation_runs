import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_semicircle_triangle_area(dut):
    """Test the semicircle triangle area module"""
    
    # Initialize inputs
    dut.radius.value = 0
    dut.valid.value = 0
    
    await Timer(10, units='ns')
    
    # Test 1: radius = -1 (not applicable for unsigned, test valid=0 instead)
    # Testing invalid input case
    dut.radius.value = 1
    dut.valid.value = 0
    await Timer(10, units='ns')
    
    if dut.area_valid.value != 0:
        raise TestFailure(f"Test 1 failed: area_valid should be 0 when valid=0, got {dut.area_valid.value}")
    
    if dut.area.value != 0:
        raise TestFailure(f"Test 1 failed: area should be 0 when valid=0, got {dut.area.value}")
    
    print("Test 1 passed: Invalid input (valid=0) handled correctly")
    
    # Test 2: radius = 0
    dut.radius.value = 0
    dut.valid.value = 1
    await Timer(10, units='ns')
    
    expected_area = 0  # 0^2 in Q16.16 is 0
    
    if dut.area_valid.value != 1:
        raise TestFailure(f"Test 2 failed: area_valid should be 1, got {dut.area_valid.value}")
    
    if dut.area.value != expected_area:
        raise TestFailure(f"Test 2 failed: expected {expected_area}, got {dut.area.value}")
    
    print(f"Test 2 passed: radius=0, area={dut.area.value} (expected {expected_area})")
    
    # Test 3: radius = 2
    dut.radius.value = 2
    dut.valid.value = 1
    await Timer(10, units='ns')
    
    # r^2 = 4, in Q16.16 format: 4 * 65536 = 262144 = 0x00040000
    expected_area = 4 * 65536
    
    if dut.area_valid.value != 1:
        raise TestFailure(f"Test 3 failed: area_valid should be 1, got {dut.area_valid.value}")
    
    if dut.area.value != expected_area:
        raise TestFailure(f"Test 3 failed: expected {expected_area}, got {dut.area.value}")
    
    print(f"Test 3 passed: radius=2, area={dut.area.value} (expected {expected_area} = 4.0 in Q16.16)")
    
    # Additional Test 4: radius = 5 (r^2 = 25)
    dut.radius.value = 5
    dut.valid.value = 1
    await Timer(10, units='ns')
    
    expected_area = 25 * 65536
    
    if dut.area.value != expected_area:
        raise TestFailure(f"Test 4 failed: expected {expected_area}, got {dut.area.value}")
    
    print(f"Test 4 passed: radius=5, area={dut.area.value} (expected {expected_area} = 25.0 in Q16.16)")
    
    # Additional Test 5: radius = 255 (max test, r^2 = 65025)
    dut.radius.value = 255
    dut.valid.value = 1
    await Timer(10, units='ns')
    
    expected_area = 65025 * 65536
    
    if dut.area.value != expected_area:
        raise TestFailure(f"Test 5 failed: expected {expected_area}, got {dut.area.value}")
    
    print(f"Test 5 passed: radius=255, area={dut.area.value} (expected {expected_area} = 65025.0 in Q16.16)")
    
    print("
All 5 tests passed!")
