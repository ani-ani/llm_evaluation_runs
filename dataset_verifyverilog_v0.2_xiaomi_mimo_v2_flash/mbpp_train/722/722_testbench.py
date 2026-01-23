import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def name_to_bytes(name_str):
    """Convert 8-char string to 64-bit value"""
    padded = name_str.ljust(8)[:8]
    result = 0
    for i, char in enumerate(padded):
        result |= ord(char) << (8 * (7 - i))
    return result

@cocotb.test()
async def test_student_filter_basic(dut):
    """Test basic filtering with 4 students"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.min_height.value = 0
    dut.min_weight.value = 0
    dut.student_count.value = 0
    
    # Initialize all student inputs
    for i in range(4):
        getattr(dut, f'student{i}_valid').value = 0
        getattr(dut, f'student{i}_name').value = 0
        getattr(dut, f'student{i}_height').value = 0
        getattr(dut, f'student{i}_weight').value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Filter with min_height=6.0, min_weight=70
    # Expected: only Cierra Vega (6.2, 70)
    dut.min_height.value = float_to_q16_16(6.0)
    dut.min_weight.value = float_to_q16_16(70.0)
    dut.student_count.value = 4
    
    # Setup students
    dut.student0_name.value = name_to_bytes('Cierra')
    dut.student0_height.value = float_to_q16_16(6.2)
    dut.student0_weight.value = float_to_q16_16(70.0)
    dut.student0_valid.value = 1
    
    dut.student1_name.value = name_to_bytes('Alden')
    dut.student1_height.value = float_to_q16_16(5.9)
    dut.student1_weight.value = float_to_q16_16(65.0)
    dut.student1_valid.value = 1
    
    dut.student2_name.value = name_to_bytes('Kierra')
    dut.student2_height.value = float_to_q16_16(6.0)
    dut.student2_weight.value = float_to_q16_16(68.0)
    dut.student2_valid.value = 1
    
    dut.student3_name.value = name_to_bytes('Pierre')
    dut.student3_height.value = float_to_q16_16(5.8)
    dut.student3_weight.value = float_to_q16_16(66.0)
    dut.student3_valid.value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(8):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted after 8 cycles")
    
    # Check results
    if dut.result_count.value != 1:
        raise TestFailure(f"Test 1 failed: Expected 1 match, got {dut.result_count.value}")
    
    expected_name = name_to_bytes('Cierra')
    if dut.result_name_0.value != expected_name:
        raise TestFailure(f"Test 1 failed: Expected Cierra, got name mismatch")
    
    print("Test 1 passed: Filter (6.0, 70) -> 1 student")
    
    # Test 2: Filter with min_height=5.9, min_weight=67
    # Expected: Cierra (6.2, 70) and Kierra (6.0, 68)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.min_height.value = float_to_q16_16(5.9)
    dut.min_weight.value = float_to_q16_16(67.0)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.result_count.value != 2:
        raise TestFailure(f"Test 2 failed: Expected 2 matches, got {dut.result_count.value}")
    
    # Check first two names are present (order may vary)
    cierra_name = name_to_bytes('Cierra')
    kierra_name = name_to_bytes('Kierra')
    
    matches = [dut.result_name_0.value, dut.result_name_1.value]
    if cierra_name not in matches or kierra_name not in matches:
        raise TestFailure("Test 2 failed: Expected Cierra and Kierra")
    
    print("Test 2 passed: Filter (5.9, 67) -> 2 students")
    
    # Test 3: Filter with min_height=5.7, min_weight=64
    # Expected: all 4 students
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.min_height.value = float_to_q16_16(5.7)
    dut.min_weight.value = float_to_q16_16(64.0)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.result_count.value != 4:
        raise TestFailure(f"Test 3 failed: Expected 4 matches, got {dut.result_count.value}")
    
    print("Test 3 passed: Filter (5.7, 64) -> 4 students")
    print("All tests passed!")

@cocotb.test()
async def test_student_filter_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test with only 2 valid students
    dut.min_height.value = float_to_q16_16(6.0)
    dut.min_weight.value = float_to_q16_16(68.0)
    dut.student_count.value = 2
    
    dut.student0_name.value = name_to_bytes('Alpha')
    dut.student0_height.value = float_to_q16_16(6.2)
    dut.student0_weight.value = float_to_q16_16(70.0)
    dut.student0_valid.value = 1
    
    dut.student1_name.value = name_to_bytes('Beta')
    dut.student1_height.value = float_to_q16_16(5.8)
    dut.student1_weight.value = float_to_q16_16(65.0)
    dut.student1_valid.value = 1
    
    dut.student2_valid.value = 0
    dut.student3_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.result_count.value != 1:
        raise TestFailure(f"Edge case failed: Expected 1 match, got {dut.result_count.value}")
    
    # Test no matches
    dut.min_height.value = float_to_q16_16(10.0)
    dut.min_weight.value = float_to_q16_16(100.0)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.result_count.value != 0:
        raise TestFailure(f"Edge case failed: Expected 0 matches, got {dut.result_count.value}")
    
    print("Edge case tests passed!")

@cocotb.test()
async def test_student_filter_boundary(dut):
    """Test boundary conditions with exact matches"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Student exactly at threshold (should match since >=)
    dut.min_height.value = float_to_q16_16(6.0)
    dut.min_weight.value = float_to_q16_16(70.0)
    dut.student_count.value = 1
    
    dut.student0_name.value = name_to_bytes('Exact')
    dut.student0_height.value = float_to_q16_16(6.0)  # Exactly at threshold
    dut.student0_weight.value = float_to_q16_16(70.0) # Exactly at threshold
    dut.student0_valid.value = 1
    
    for i in range(1, 4):
        getattr(dut, f'student{i}_valid').value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.result_count.value != 1:
        raise TestFailure(f"Boundary test failed: Exact threshold should match, got {dut.result_count.value}")
    
    print("Boundary test passed: exact threshold values match")
    print("
=== SUMMARY: All 5 tests passed! ===")
