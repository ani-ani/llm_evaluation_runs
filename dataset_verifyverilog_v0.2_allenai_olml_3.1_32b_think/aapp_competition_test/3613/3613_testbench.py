import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_kindergarten_partition(dut):
    """Test the KindergartenPartition module with various cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.current_teacher.value = 0
    dut.preference_list.value = 0
    dut.current_kid.value = 0
    dut.N.value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    print("
=== Test Case 1: N=6, T=4 expected ===")
    # Test case 1: 6 kids example
    N = 6
    dut.N.value = N
    
    # Define preferences for each kid (0-indexed)
    # Format: current_teacher, preference_list (best to worst)
    test_case_1 = [
        (0, [1, 2, 3, 4, 5]),  # kid 0
        (0, [0, 2, 3, 4, 5]),  # kid 1
        (1, [5, 4, 3, 1, 0]),  # kid 2
        (2, [5, 4, 2, 1, 0]),  # kid 3
        (1, [0, 1, 2, 3, 5]),  # kid 4
        (2, [0, 1, 2, 3, 4]),  # kid 5
    ]
    
    # Load configuration
    for kid_id in range(N):
        dut.current_kid.value = kid_id
        dut.current_teacher.value = test_case_1[kid_id][0]
        
        # Fill preference list (8 slots, use 0 for unused)
        pref = [0] * 8
        for i, p in enumerate(test_case_1[kid_id][1]):
            pref[i] = p
        dut.preference_list.value = pref
        
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
        dut.input_valid.value = 0
        await Timer(1, units='ns')  # Small delay
    
    print("Configuration loaded, starting computation...")
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 10000 cycles for simulation)
    timeout = 10000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    error = int(dut.error.value)
    
    print(f"Completed in {cycles} cycles")
    print(f"Result: T={result}, error={error}")
    
    if error:
        raise TestFailure("Unexpected error flag")
    
    if result != 4:
        raise TestFailure(f"Expected T=4, got T={result}")
    
    print("Test Case 1 PASSED
")
    
    # ===== Test Case 2: N=3, T=0 expected =====
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    print("=== Test Case 2: N=3, T=0 expected ===")
    N = 3
    dut.N.value = N
    
    test_case_2 = [
        (0, [1, 2]),  # kid 0
        (1, [0, 2]),  # kid 1
        (2, [0, 1]),  # kid 2
    ]
    
    for kid_id in range(N):
        dut.current_kid.value = kid_id
        dut.current_teacher.value = test_case_2[kid_id][0]
        pref = [0] * 8
        for i, p in enumerate(test_case_2[kid_id][1]):
            pref[i] = p
        dut.preference_list.value = pref
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
        dut.input_valid.value = 0
        await Timer(1, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout in test case 2")
    
    result = int(dut.result.value)
    error = int(dut.error.value)
    
    print(f"Result: T={result}, error={error}")
    
    if error:
        raise TestFailure("Unexpected error in test case 2")
    
    if result != 0:
        raise TestFailure(f"Expected T=0, got T={result}")
    
    print("Test Case 2 PASSED
")
    
    # ===== Test Case 3: N=4, verify search works =====
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    print("=== Test Case 3: N=4, small test ===")
    N = 4
    dut.N.value = N
    
    test_case_3 = [
        (0, [1, 2, 3]),
        (1, [0, 2, 3]),
        (2, [0, 1, 3]),
        (0, [1, 2, 0]),
    ]
    
    for kid_id in range(N):
        dut.current_kid.value = kid_id
        dut.current_teacher.value = test_case_3[kid_id][0]
        pref = [0] * 8
        for i, p in enumerate(test_case_3[kid_id][1]):
            pref[i] = p
        dut.preference_list.value = pref
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
        dut.input_valid.value = 0
        await Timer(1, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout in test case 3")
    
    result = int(dut.result.value)
    error = int(dut.error.value)
    
    print(f"Result: T={result}, error={error}")
    print(f"Completed all tests!
")
    
    print("Summary: 3/3 tests passed")
