import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_cinema_seating_basic(dut):
    """Test basic case: 1 group of 2, 1 group of 3 -> X=3"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.num_groups_1.value = 0
    dut.num_groups_2.value = 0
    dut.num_groups_3.value = 0
    dut.num_groups_4.value = 0
    dut.num_groups_5.value = 0
    dut.num_groups_6.value = 0
    dut.num_groups_7.value = 0
    dut.num_groups_8.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: n=3, groups=[0,1,1] -> X=3
    # 1 pair (size 2), 1 triple (size 3)
    # X=1: row1=1 -> can't fit 2 or 3, fails
    # X=2: row1=2 -> fit pair, row2=1 -> can't fit triple, fails
    # X=3: row1=3 -> fit triple, row2=2 -> fit pair, success! 2 rows
    # X=4: would also work but we want smallest X
    dut.n.value = 3
    dut.num_groups_1.value = 0
    dut.num_groups_2.value = 1
    dut.num_groups_3.value = 1
    dut.num_groups_4.value = 0
    dut.num_groups_5.value = 0
    dut.num_groups_6.value = 0
    dut.num_groups_7.value = 0
    dut.num_groups_8.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 10000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check result
    result = int(dut.result.value)
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    print(f"Test 1 passed: result={result}")

@cocotb.test()
async def test_cinema_seating_basic2(dut):
    """Test case: 2 singles, 1 pair, 1 triple -> X=4"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 2: n=3, groups=[2,1,1] -> X=4
    dut.n.value = 3
    dut.num_groups_1.value = 2
    dut.num_groups_2.value = 1
    dut.num_groups_3.value = 1
    dut.num_groups_4.value = 0
    dut.num_groups_5.value = 0
    dut.num_groups_6.value = 0
    dut.num_groups_7.value = 0
    dut.num_groups_8.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    if result != 4:
        raise TestFailure(f"Expected 4, got {result}")
    print(f"Test 2 passed: result={result}")

@cocotb.test()
async def test_cinema_seating_impossible(dut):
    """Test impossible case: very large groups that can't fit in 12 seats"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case: one group of 13 (impossible since max seat=12)
    # We'll simulate with n=8 and one group of 8 that can't fit rows
    # Actually, with X=12, group of 8 can fit in row 12
    # Need to create case where no X <= 12 works
    # Use 10 groups of 8 people - with decreasing rows, this is impossible
    dut.n.value = 8
    dut.num_groups_1.value = 0
    dut.num_groups_2.value = 0
    dut.num_groups_3.value = 0
    dut.num_groups_4.value = 0
    dut.num_groups_5.value = 0
    dut.num_groups_6.value = 0
    dut.num_groups_7.value = 0
    dut.num_groups_8.value = 10  # 10 groups of 8 people
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    if result != 13:
        raise TestFailure(f"Expected 13 (impossible), got {result}")
    print(f"Test 3 passed: result={result} (impossible)")

@cocotb.test()
async def test_cinema_seating_edge_case(dut):
    """Test edge case: all singles that fit perfectly"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 5 single people - X=1 might work: 5 rows of 1 seat each
    dut.n.value = 1
    dut.num_groups_1.value = 5
    dut.num_groups_2.value = 0
    dut.num_groups_3.value = 0
    dut.num_groups_4.value = 0
    dut.num_groups_5.value = 0
    dut.num_groups_6.value = 0
    dut.num_groups_7.value = 0
    dut.num_groups_8.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    # X=1: rows 1,1,1,1,1 -> 5 rows, 5 seats
    # X=2: rows 2,1 -> 2 rows, 3 seats (better - fewer rows)
    # X=3: rows 3,2,1 -> 3 rows, 6 seats (more rows)
    # X=4: rows 4,3,2,1 -> 4 rows, 10 seats (more rows)
    # X=2 is optimal (minimizes rows)
    if result != 2:
        raise TestFailure(f"Expected 2, got {result}")
    print(f"Test 4 passed: result={result}")

@cocotb.test()
async def test_cinema_seating_all_groups(dut):
    """Test with multiple different group sizes"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 1 each of sizes 1,2,3,4
    dut.n.value = 4
    dut.num_groups_1.value = 1
    dut.num_groups_2.value = 1
    dut.num_groups_3.value = 1
    dut.num_groups_4.value = 1
    dut.num_groups_5.value = 0
    dut.num_groups_6.value = 0
    dut.num_groups_7.value = 0
    dut.num_groups_8.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    # With X=5: rows 5,4,3,2,1
    # Row5: fit 4 + spacing + 1 (or 3 + spacing + 1)
    # Actually let's trace:
    # X=4: row4=4, row3=3, row2=2, row1=1
    #   row4: fit 4, row3: fit 3, row2: fit 2, row1: fit 1 -> 4 rows
    # X=5: row5=5, row4=4, row3=3
    #   row5: fit 4 + spacing + 1 (4+1+1=6 > 5, can't) or 3+spacing+1 (3+1+1=5, yes)
    #   So row5 fits: 3,1. Remaining: 4,2. Next row4=4: fits 4. Remaining: 2. Row3=3: fits 2. Done in 3 rows.
    # X=6: 3 rows. X=7: 2 rows (row7: fit 4+spacing+3, row6: fit 2+spacing+1). 
    # So X=4 (4 rows), X=5 (3 rows), X=6 (3 rows), X=7 (2 rows)
    # We want smallest X with min rows -> X=7 with 2 rows
    # But wait, let's recalculate more carefully:
    # X=4: row4: 4 alone (fits). row3: 3 alone (fits). row2: 2 alone (fits). row1: 1 alone (fits). 4 rows.
    # X=5: row5: 4 + spacing + 1? 4+1+1=6 > 5, no. 4 alone? fits. Remaining 3,2,1. row4: 3 + spacing + 1? 3+1+1=5>4 no. 3 alone? fits. Remaining 2,1. row3: 2+spacing+1? 2+1+1=4>3 no. 2 alone? fits. Remaining 1. row2: 1 alone? fits. row1: empty. 4 rows still.
    # X=6: row6: 4+spacing+2? 4+1+2=7>6 no. 4+spacing+1? 4+1+1=6 fits! Remaining 3,2. row5: 3+spacing+2? 3+1+2=6>5 no. 3 alone? fits. Remaining 2. row4: 2 alone fits. 3 rows.
    # X=7: row7: 4+spacing+3? 4+1+3=8>7 no. 4+spacing+2? 4+1+2=7 fits! Remaining 1. row6: 1 alone fits. 2 rows.
    # So X=7 is optimal.
    if result != 7:
        raise TestFailure(f"Expected 7, got {result}")
    print(f"Test 5 passed: result={result}")

print("All test cases defined for cinema_seating module")