import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    q_value = int(value * 65536)
    # Handle negative values with proper 32-bit representation
    if q_value < 0:
        q_value = (1 << 32) + q_value
    return q_value

def q16_16_to_float(q_value):
    """Convert Q16.16 to float"""
    if q_value >= (1 << 31):
        q_value = q_value - (1 << 32)
    return q_value / 65536.0

@cocotb.test()
async def test_matrix_row_average(dut):
    """Test matrix row average calculation"""
    
    # Test Case 1: Basic positive numbers
    # Original: ((10, 10, 10, 12), (30, 45, 56, 45), (81, 80, 39, 32), (1, 2, 3, 4))
    # Expected averages: [30.5, 34.25, 27.0, 23.25]
    
    dut.matrix_data[0][0].value = float_to_q16_16(10.0)
    dut.matrix_data[0][1].value = float_to_q16_16(10.0)
    dut.matrix_data[0][2].value = float_to_q16_16(10.0)
    dut.matrix_data[0][3].value = float_to_q16_16(12.0)
    
    dut.matrix_data[1][0].value = float_to_q16_16(30.0)
    dut.matrix_data[1][1].value = float_to_q16_16(45.0)
    dut.matrix_data[1][2].value = float_to_q16_16(56.0)
    dut.matrix_data[1][3].value = float_to_q16_16(45.0)
    
    dut.matrix_data[2][0].value = float_to_q16_16(81.0)
    dut.matrix_data[2][1].value = float_to_q16_16(80.0)
    dut.matrix_data[2][2].value = float_to_q16_16(39.0)
    dut.matrix_data[2][3].value = float_to_q16_16(32.0)
    
    dut.matrix_data[3][0].value = float_to_q16_16(1.0)
    dut.matrix_data[3][1].value = float_to_q16_16(2.0)
    dut.matrix_data[3][2].value = float_to_q16_16(3.0)
    dut.matrix_data[3][3].value = float_to_q16_16(4.0)
    
    await Timer(10, units='ns')
    
    expected = [30.5, 34.25, 27.0, 23.25]
    
    for i in range(4):
        actual_q = int(dut.averages[i].value)
        actual_float = q16_16_to_float(actual_q)
        if abs(actual_float - expected[i]) > 0.01:
            raise TestFailure(f"Test 1 Row {i}: Expected {expected[i]}, got {actual_float}")
    
    print("Test 1: PASS")
    
    # Test Case 2: Mixed positive and negative numbers
    # Original: ((1, 1, -5), (30, -15, 56), (81, -60, -39), (-10, 2, 3))
    # Note: Original has 3 elements per tuple, but we need 4. We'll pad with zeros
    # Expected averages: [25.5, -18.0, 3.75, -1.67]
    
    dut.matrix_data[0][0].value = float_to_q16_16(1.0)
    dut.matrix_data[0][1].value = float_to_q16_16(1.0)
    dut.matrix_data[0][2].value = float_to_q16_16(-5.0)
    dut.matrix_data[0][3].value = float_to_q16_16(0.0)  # Pad
    
    dut.matrix_data[1][0].value = float_to_q16_16(30.0)
    dut.matrix_data[1][1].value = float_to_q16_16(-15.0)
    dut.matrix_data[1][2].value = float_to_q16_16(56.0)
    dut.matrix_data[1][3].value = float_to_q16_16(0.0)  # Pad
    
    dut.matrix_data[2][0].value = float_to_q16_16(81.0)
    dut.matrix_data[2][1].value = float_to_q16_16(-60.0)
    dut.matrix_data[2][2].value = float_to_q16_16(-39.0)
    dut.matrix_data[2][3].value = float_to_q16_16(0.0)  # Pad
    
    dut.matrix_data[3][0].value = float_to_q16_16(-10.0)
    dut.matrix_data[3][1].value = float_to_q16_16(2.0)
    dut.matrix_data[3][2].value = float_to_q16_16(3.0)
    dut.matrix_data[3][3].value = float_to_q16_16(0.0)  # Pad
    
    await Timer(10, units='ns')
    
    # Recalculating with 4 elements:
    # Row 0: (1 + 1 + -5 + 0) / 4 = -3/4 = -0.75
    # Row 1: (30 + -15 + 56 + 0) / 4 = 71/4 = 17.75
    # Row 2: (81 + -60 + -39 + 0) / 4 = -18/4 = -4.5
    # Row 3: (-10 + 2 + 3 + 0) / 4 = -5/4 = -1.25
    expected2 = [-0.75, 17.75, -4.5, -1.25]
    
    for i in range(4):
        actual_q = int(dut.averages[i].value)
        actual_float = q16_16_to_float(actual_q)
        if abs(actual_float - expected2[i]) > 0.01:
            raise TestFailure(f"Test 2 Row {i}: Expected {expected2[i]}, got {actual_float}")
    
    print("Test 2: PASS")
    
    # Test Case 3: Larger numbers
    # Original: ((100, 100, 100, 120), (300, 450, 560, 450), (810, 800, 390, 320), (10, 20, 30, 40))
    # Expected averages: [305.0, 342.5, 270.0, 232.5]
    
    dut.matrix_data[0][0].value = float_to_q16_16(100.0)
    dut.matrix_data[0][1].value = float_to_q16_16(100.0)
    dut.matrix_data[0][2].value = float_to_q16_16(100.0)
    dut.matrix_data[0][3].value = float_to_q16_16(120.0)
    
    dut.matrix_data[1][0].value = float_to_q16_16(300.0)
    dut.matrix_data[1][1].value = float_to_q16_16(450.0)
    dut.matrix_data[1][2].value = float_to_q16_16(560.0)
    dut.matrix_data[1][3].value = float_to_q16_16(450.0)
    
    dut.matrix_data[2][0].value = float_to_q16_16(810.0)
    dut.matrix_data[2][1].value = float_to_q16_16(800.0)
    dut.matrix_data[2][2].value = float_to_q16_16(390.0)
    dut.matrix_data[2][3].value = float_to_q16_16(320.0)
    
    dut.matrix_data[3][0].value = float_to_q16_16(10.0)
    dut.matrix_data[3][1].value = float_to_q16_16(20.0)
    dut.matrix_data[3][2].value = float_to_q16_16(30.0)
    dut.matrix_data[3][3].value = float_to_q16_16(40.0)
    
    await Timer(10, units='ns')
    
    expected3 = [305.0, 342.5, 270.0, 232.5]
    
    for i in range(4):
        actual_q = int(dut.averages[i].value)
        actual_float = q16_16_to_float(actual_q)
        if abs(actual_float - expected3[i]) > 0.1:
            raise TestFailure(f"Test 3 Row {i}: Expected {expected3[i]}, got {actual_float}")
    
    print("Test 3: PASS")
    
    # Test Case 4: Edge case - all zeros
    for i in range(4):
        for j in range(4):
            dut.matrix_data[i][j].value = float_to_q16_16(0.0)
    
    await Timer(10, units='ns')
    
    for i in range(4):
        actual_q = int(dut.averages[i].value)
        actual_float = q16_16_to_float(actual_q)
        if abs(actual_float - 0.0) > 0.01:
            raise TestFailure(f"Test 4 Row {i}: Expected 0.0, got {actual_float}")
    
    print("Test 4: PASS")
    
    print("All 4 tests passed!")