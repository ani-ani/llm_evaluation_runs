import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_course_scheduler(dut):
    """Test course scheduler with various k values and course configurations"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.valid_mask.value = 0
    
    # Initialize all course difficulties to 0
    for i in range(4):
        setattr(dut, f'course_difficulty_{i}_i', 0)
        setattr(dut, f'course_difficulty_{i}_ii', 0)
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test Case 1: Simple pair selection
        {
            'name': 'Two courses, select 2 cheapest',
            'k': 2,
            'valid_mask': 0b1111,  # All 4 pairs valid
            'courses': [
                (10, 20),   # Pair 0: I=10, II=20
                (50, 100),  # Pair 1: I=50, II=100
                (0, 0),     # Pair 2: disabled
                (0, 0),     # Pair 3: disabled
            ],
            'expected_sum': 30,  # Select pair0: I+II = 10+20=30, or pair1: I=50, but 30 is smaller
            'expected_error': 0,
            'explanation': 'Select pair0 both levels (10+20=30)'
        },
        # Test Case 2: Select standalone courses
        {
            'name': 'Select standalone and pair',
            'k': 3,
            'valid_mask': 0b1111,
            'courses': [
                (10, 20),   # Pair 0: I=10, II=20
                (50, 100),  # Pair 1: I=50, II=100
                (5, 5),     # Pair 2: I=5, II=5 (treat as standalone)
                (0, 0),     # Pair 3: disabled
            ],
            'expected_sum': 35,  # Pair0 I (10) + Pair0 II (20) + Pair2 I (5) = 35
            'expected_error': 0,
            'explanation': 'Select pair0 both (30) and pair2 I (5)'
        },
        # Test Case 3: Multiple options, need minimum
        {
            'name': 'Minimum sum selection',
            'k': 2,
            'valid_mask': 0b1111,
            'courses': [
                (100, 200), # Pair 0: I=100, II=200
                (50, 250),  # Pair 1: I=50, II=250
                (30, 70),   # Pair 2: I=30, II=70
                (0, 0),     # Pair 3: disabled
            ],
            'expected_sum': 80,  # Pair2 I+II = 30+70=80, or Pair0 I + Pair1 I = 150, or Pair1 I + Pair2 I = 80
            'expected_error': 0,
            'explanation': 'Select pair2 both levels (30+70=80)'
        },
        # Test Case 4: Impossible to select k courses
        {
            'name': 'No valid combination',
            'k': 5,
            'valid_mask': 0b0011,  # Only 2 pairs valid, max 4 courses
            'courses': [
                (10, 20),   # Pair 0: I=10, II=20
                (50, 100),  # Pair 1: I=50, II=100
                (0, 0),     # Pair 2: disabled
                (0, 0),     # Pair 3: disabled
            ],
            'expected_sum': 0,
            'expected_error': 1,
            'explanation': 'Only 4 courses available but need 5'
        },
        # Test Case 5: Edge case - select exactly all courses
        {
            'name': 'Select all courses',
            'k': 4,
            'valid_mask': 0b0011,
            'courses': [
                (10, 20),   # Pair 0: I=10, II=20
                (50, 100),  # Pair 1: I=50, II=100
                (0, 0),     # Pair 2: disabled
                (0, 0),     # Pair 3: disabled
            ],
            'expected_sum': 180,  # All 4 courses: 10+20+50+100 = 180
            'expected_error': 0,
            'explanation': 'Select all available courses'
        },
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"
Test {i+1}: {tc['name']}")
        dut._log.info(f"Explanation: {tc['explanation']}")
        
        # Configure inputs
        dut.k.value = tc['k']
        dut.valid_mask.value = tc['valid_mask']
        
        for pair_idx, (diff_i, diff_ii) in enumerate(tc['courses']):
            setattr(dut, f'course_difficulty_{pair_idx}_i', diff_i)
            setattr(dut, f'course_difficulty_{pair_idx}_ii', diff_ii)
        
        # Wait for inputs to settle
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 1000
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Check results
        actual_sum = int(dut.min_sum.value)
        actual_error = int(dut.error.value)
        
        dut._log.info(f"Expected sum: {tc['expected_sum']}, Error: {tc['expected_error']}")
        dut._log.info(f"Actual sum: {actual_sum}, Error: {actual_error}")
        
        if actual_error != tc['expected_error']:
            dut._log.error(f"Test {i+1} FAILED: Error mismatch")
            raise TestFailure(f"Error expected {tc['expected_error']}, got {actual_error}")
        
        if actual_error == 0 and actual_sum != tc['expected_sum']:
            dut._log.error(f"Test {i+1} FAILED: Sum mismatch")
            raise TestFailure(f"Sum expected {tc['expected_sum']}, got {actual_sum}")
        
        dut._log.info(f"Test {i+1} PASSED")
        passed += 1
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
