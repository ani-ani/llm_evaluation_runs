import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_night_club_lighting(dut):
    """Test simplified night club lighting problem"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 1: 4x4 grid with outer ring of 3s and inner 2x2 of 0s
    # Adapted from example 1 (original 6x6 -> 4x4 for HDL)
    # B=9, H=1
    # Grid:
    # 3333
    # 3003
    # 3003
    # 3333
    # Expected: Inner 2x2 dark, perimeter = 8 edges, cost = 88
    
    B = 9
    H = 1
    R = 4
    C = 4
    
    dut.B.value = B
    dut.H.value = H
    dut.R.value = R
    dut.C.value = C
    
    # Set grid values (4x4, but module expects 8x8 inputs)
    # Row 0
    dut.g00.value = 3; dut.g01.value = 3; dut.g02.value = 3; dut.g03.value = 3
    dut.g04.value = 0; dut.g05.value = 0; dut.g06.value = 0; dut.g07.value = 0
    # Row 1
    dut.g10.value = 3; dut.g11.value = 0; dut.g12.value = 0; dut.g13.value = 3
    dut.g14.value = 0; dut.g15.value = 0; dut.g16.value = 0; dut.g17.value = 0
    # Row 2
    dut.g20.value = 3; dut.g21.value = 0; dut.g22.value = 0; dut.g23.value = 3
    dut.g24.value = 0; dut.g25.value = 0; dut.g26.value = 0; dut.g27.value = 0
    # Row 3
    dut.g30.value = 3; dut.g31.value = 3; dut.g32.value = 3; dut.g33.value = 3
    dut.g34.value = 0; dut.g35.value = 0; dut.g36.value = 0; dut.g37.value = 0
    # Rest of rows (unused but set to 0)
    for i in range(4, 8):
        for j in range(8):
            setattr(dut, f'g{i}{j}', 0)
    
    # Wait a bit for inputs to stabilize
    await Timer(10, units='ns')
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (with timeout)
    max_cycles = 1000
    cycles = 0
    while not dut.done.value and cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= max_cycles:
        raise TestFailure(f"Did not complete within {max_cycles} cycles")
    
    # Check result
    result = dut.cost.value
    print(f"Test 1: Cost = {result}")
    
    # For 4x4 with inner 2x2 dark:
    # Inner cells: (1,1), (1,2), (2,1), (2,2)
    # Each has 2 lit neighbors (from outer ring)
    # Total edges = 8
    # Cost = 8 * 11 = 88
    expected = 88
    
    if int(result) != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 1 passed: {result} = {expected}")
    
    # Test 2: All cells lit
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    B = 5
    H = 2
    R = 3
    C = 3
    
    dut.B.value = B
    dut.H.value = H
    dut.R.value = R
    dut.C.value = C
    
    # All cells have strength 9 (well above threshold)
    for i in range(8):
        for j in range(8):
            val = 9 if (i < R and j < C) else 0
            setattr(dut, f'g{i}{j}', val)
    
    await Timer(10, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= max_cycles:
        raise TestFailure(f"Test 2: Did not complete within {max_cycles} cycles")
    
    result = dut.cost.value
    print(f"Test 2: Cost = {result}")
    
    # All cells lit, no dark cells, so no fencing
    expected = 0
    
    if int(result) != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 2 passed: {result} = {expected}")
    
    # Test 3: Mixed case - 4x4, center dark
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    B = 20  # High threshold
    H = 1
    R = 4
    C = 4
    
    dut.B.value = B
    dut.H.value = H
    dut.R.value = R
    dut.C.value = C
    
    # Grid with mostly low values
    # 5555
    # 5005
    # 5005
    # 5555
    # Only corners are 5, rest 0
    dut.g00.value = 5; dut.g01.value = 5; dut.g02.value = 5; dut.g03.value = 5
    dut.g04.value = 0; dut.g05.value = 0; dut.g06.value = 0; dut.g07.value = 0
    dut.g10.value = 5; dut.g11.value = 0; dut.g12.value = 0; dut.g13.value = 5
    dut.g14.value = 0; dut.g15.value = 0; dut.g16.value = 0; dut.g17.value = 0
    dut.g20.value = 5; dut.g21.value = 0; dut.g22.value = 0; dut.g23.value = 5
    dut.g24.value = 0; dut.g25.value = 0; dut.g26.value = 0; dut.g27.value = 0
    dut.g30.value = 5; dut.g31.value = 5; dut.g32.value = 5; dut.g33.value = 5
    dut.g34.value = 0; dut.g35.value = 0; dut.g36.value = 0; dut.g37.value = 0
    for i in range(4, 8):
        for j in range(8):
            setattr(dut, f'g{i}{j}', 0)
    
    await Timer(10, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= max_cycles:
        raise TestFailure(f"Test 3: Did not complete within {max_cycles} cycles")
    
    result = dut.cost.value
    print(f"Test 3: Cost = {result}")
    
    # With high threshold and low strengths, all cells are dark
    # But borders are guaranteed lit in problem, so we expect 0 fencing
    # (since borders are lit and not fenced)
    # Actually, internal dark cells would be fenced from each other?
    # No, only edges between dark and lit matter
    # If all internal are dark, but borders are lit (problem guarantee)
    # Then perimeter of dark region is fenced
    # For 4x4 with all internal dark (2x2), perimeter = 8 edges
    # But our 4x4 has border included, so internal 2x2 dark
    # Same as test 1: 8 edges, cost = 88
    expected = 88
    
    if int(result) != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 3 passed: {result} = {expected}")
    print(f"
Summary: 3/3 tests passed")
