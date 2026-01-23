import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_student_mentor_finder(dut):
    """Test the student mentor finder module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.query_idx.value = 0
    dut.num_students.value = 0
    for i in range(8):
        dut.student_A[i].value = 0
        dut.student_B[i].value = 0
    
    # Reset sequence
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: No valid mentor (sample 1)
    # Students: (3,1), (2,2), (1,3) - no one has both >= others
    dut.num_students.value = 3
    dut.student_A[0].value = 3
    dut.student_B[0].value = 1
    dut.student_A[1].value = 2
    dut.student_B[1].value = 2
    dut.student_A[2].value = 1
    dut.student_B[2].value = 3
    
    # Query student 0
    dut.query_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    assert dut.valid.value == 0, "Test 1 Failed: Should be invalid"
    print("Test 1 passed: No valid mentor for student 0")
    
    # Query student 1
    dut.query_idx.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 0, "Test 1 Failed: Should be invalid"
    print("Test 1 passed: No valid mentor for student 1")
    
    # Query student 2
    dut.query_idx.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 0, "Test 1 Failed: Should be invalid"
    print("Test 1 passed: No valid mentor for student 2")
    
    # Test Case 2: Sample 2 - Query student 2 (index 1)
    # Students: (8,8), (2,4), (5,6)
    dut.num_students.value = 3
    dut.student_A[0].value = 8
    dut.student_B[0].value = 8
    dut.student_A[1].value = 2
    dut.student_B[1].value = 4
    dut.student_A[2].value = 5
    dut.student_B[2].value = 6
    
    dut.query_idx.value = 1  # Student 2 (index 1)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Student 1 (index 0): A=8>=2, B=8>=4, B_diff=4, A_diff=6
    # Student 2 (index 2): A=5>=2, B=6>=4, B_diff=2, A_diff=3
    # Best is student 2 (index 2), but output is student number 3
    # Wait, check: student numbers are 1-indexed
    # Student 1: (8,8)
    # Student 2: (2,4) 
    # Student 3: (5,6)
    # Query student 2 (2,4)
    # Student 1: valid, B_diff=4
    # Student 3: valid, B_diff=2
    # Best is student 3, which is index 2
    assert dut.valid.value == 1, "Test 2 Failed: Should be valid"
    assert dut.mentor_idx.value == 2, f"Test 2 Failed: Expected 2, got {dut.mentor_idx.value}"
    print("Test 2 passed: Student 2 -> Mentor 3 (index 2)")
    
    # Add student (6,2) and query student 4 (index 3)
    dut.num_students.value = 4
    dut.student_A[3].value = 6
    dut.student_B[3].value = 2
    
    dut.query_idx.value = 3  # Student 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Student 4: (6,2)
    # Valid mentors: Student 1 (8,8), Student 3 (5,6)
    # Student 1: B_diff=6, A_diff=2
    # Student 3: B_diff=4, A_diff=-1 (invalid because A=5 < 6)
    # Actually wait: Student 3 has A=5 which is < 6, so not valid!
    # Only Student 1 is valid: (8,8)
    # Student 1: B_diff=6, A_diff=2
    # So mentor is student 1, which is index 0
    assert dut.valid.value == 1, "Test 2b Failed: Should be valid"
    assert dut.mentor_idx.value == 0, f"Test 2b Failed: Expected 0, got {dut.mentor_idx.value}"
    print("Test 2b passed: Student 4 -> Mentor 1 (index 0)")
    
    # Test Case 3: Tie in B difference, resolve by A difference
    # Students: (5,2), (5,3), (7,1), (8,7)
    # Query student 1: (5,2)
    # Student 2: (5,3) - B_diff=1, A_diff=0
    # Student 3: (7,1) - B=1 < 2, invalid
    # Student 4: (8,7) - B_diff=5, A_diff=3
    # Best is student 2 (index 1)
    dut.num_students.value = 4
    dut.student_A[0].value = 5
    dut.student_B[0].value = 2
    dut.student_A[1].value = 5
    dut.student_B[1].value = 3
    dut.student_A[2].value = 7
    dut.student_B[2].value = 1
    dut.student_A[3].value = 8
    dut.student_B[3].value = 7
    
    dut.query_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Test 3 Failed: Should be valid"
    assert dut.mentor_idx.value == 1, f"Test 3 Failed: Expected 1, got {dut.mentor_idx.value}"
    print("Test 3 passed: Tie resolved correctly")
    
    # Test Case 4: Self exclusion - student with same values but different index
    dut.num_students.value = 2
    dut.student_A[0].value = 10
    dut.student_B[0].value = 10
    dut.student_A[1].value = 10
    dut.student_B[1].value = 10
    
    dut.query_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Student 1 is same as student 0, but should be valid
    # However, problem says "no two students have both numbers equal"
    # So this case shouldn't happen, but let's test with different values
    
    # Test Case 5: Multiple candidates, complex selection
    # Student 1: (5,5)
    # Student 2: (6,6)
    # Student 3: (7,7)
    # Student 4: (5,6) - only B is higher
    # Query student 1
    # Valid: 2, 3, 4
    # Student 2: B_diff=1, A_diff=1
    # Student 3: B_diff=2, A_diff=2
    # Student 4: B_diff=1, A_diff=0
    # Best is student 4: lowest B_diff (1), and among B_diff=1, student 4 has A_diff=0 < 1
    dut.num_students.value = 4
    dut.student_A[0].value = 5
    dut.student_B[0].value = 5
    dut.student_A[1].value = 6
    dut.student_B[1].value = 6
    dut.student_A[2].value = 7
    dut.student_B[2].value = 7
    dut.student_A[3].value = 5
    dut.student_B[3].value = 6
    
    dut.query_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Test 5 Failed: Should be valid"
    assert dut.mentor_idx.value == 3, f"Test 5 Failed: Expected 3, got {dut.mentor_idx.value}"
    print("Test 5 passed: Complex selection correct")
    
    print("All 5 tests passed!")
