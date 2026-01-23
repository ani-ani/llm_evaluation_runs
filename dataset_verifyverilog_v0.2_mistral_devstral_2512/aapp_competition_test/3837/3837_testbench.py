import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_bug_fix_scheduler_basic(dut):
    """Test basic bug fixing scenario"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3 students, 4 bugs, budget 9 (from sample)
    # Bugs: [1, 3, 1, 2] -> sorted [3,2,1,1]
    # Students: [2,1,3], Costs: [4,3,6]
    # Expected: 2 days, assignment [2,3,2,3] (student indices 1,2,1,2 in 0-index)
    
    dut.bug_complexity[0].value = 1
    dut.bug_complexity[1].value = 3
    dut.bug_complexity[2].value = 1
    dut.bug_complexity[3].value = 2
    # Pad remaining
    for i in range(4, 8):
        dut.bug_complexity[i].value = 0
        
    dut.student_ability[0].value = 2
    dut.student_ability[1].value = 1
    dut.student_ability[2].value = 3
    # Pad remaining
    for i in range(3, 8):
        dut.student_ability[i].value = 0
        
    dut.student_cost[0].value = 4
    dut.student_cost[1].value = 3
    dut.student_cost[2].value = 6
    for i in range(3, 8):
        dut.student_cost[i].value = 65535
        
    dut.budget.value = 9
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 300 cycles)
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test timed out after 300 cycles")
    
    # Check results
    if not dut.feasible.value:
        raise TestFailure(f"Expected feasible=1, got {dut.feasible.value}")
        
    if dut.min_days.value != 2:
        raise TestFailure(f"Expected min_days=2, got {dut.min_days.value}")
    
    # Check assignment (check a few key indices)
    # Student 1 (index 1) should handle bugs with complexity <= 1
    # Student 2 (index 2) should handle bugs with complexity 2-3
    print(f"Min days: {dut.min_days.value}")
    print(f"Assignment: {[int(dut.assignment[i].value) for i in range(8)]}")
    print("Test 1 Passed!")

@cocotb.test()
async def test_bug_fix_scheduler_no_solution(dut):
    """Test scenario where budget is too low"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: Budget 5, costs [5,3,6] -> no solution
    # Bugs: [1,3,1,2]
    dut.bug_complexity[0].value = 1
    dut.bug_complexity[1].value = 3
    dut.bug_complexity[2].value = 1
    dut.bug_complexity[3].value = 2
    for i in range(4, 8):
        dut.bug_complexity[i].value = 0
        
    dut.student_ability[0].value = 2
    dut.student_ability[1].value = 1
    dut.student_ability[2].value = 3
    for i in range(3, 8):
        dut.student_ability[i].value = 0
        
    dut.student_cost[0].value = 5
    dut.student_cost[1].value = 3
    dut.student_cost[2].value = 6
    for i in range(3, 8):
        dut.student_cost[i].value = 65535
        
    dut.budget.value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test timed out")
    
    if dut.feasible.value:
        raise TestFailure(f"Expected feasible=0, got {dut.feasible.value}")
        
    print(f"Feasible: {dut.feasible.value}")
    print("Test 2 Passed!")

@cocotb.test()
async def test_bug_fix_scheduler_min_days(dut):
    """Test that minimum days is correctly found"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 3 students, 4 bugs, budget 10
    # Bugs: [2,3,1,2] -> sorted [3,2,2,1]
    # Students: [2,1,3], Costs: [4,3,6]
    # Expected: 1 day, assignment [1,3,1,3] (student indices 0,2,0,2 in 0-index)
    
    dut.bug_complexity[0].value = 2
    dut.bug_complexity[1].value = 3
    dut.bug_complexity[2].value = 1
    dut.bug_complexity[3].value = 2
    for i in range(4, 8):
        dut.bug_complexity[i].value = 0
        
    dut.student_ability[0].value = 2
    dut.student_ability[1].value = 1
    dut.student_ability[2].value = 3
    for i in range(3, 8):
        dut.student_ability[i].value = 0
        
    dut.student_cost[0].value = 4
    dut.student_cost[1].value = 3
    dut.student_cost[2].value = 6
    for i in range(3, 8):
        dut.student_cost[i].value = 65535
        
    dut.budget.value = 10
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test timed out")
    
    if not dut.feasible.value:
        raise TestFailure(f"Expected feasible=1, got {dut.feasible.value}")
        
    # With budget 10, student 3 (ability 3, cost 6) can handle all bugs in 1 day
    # Cost = 6 <= 10
    if dut.min_days.value != 1:
        raise TestFailure(f"Expected min_days=1, got {dut.min_days.value}")
        
    print(f"Min days: {dut.min_days.value}")
    print(f"Assignment: {[int(dut.assignment[i].value) for i in range(8)]}")
    print("Test 3 Passed!")

@cocotb.test()
async def test_bug_fix_scheduler_all_students(dut):
    """Test with multiple students, single student can handle all"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 bugs, 2 students, budget 100
    # Bugs: [1, 1, 3] -> sorted [3,1,1]
    # Students: [1, 2] (ability), [5, 10] (cost)
    # Student 2 (ability 2) can handle all
    
    dut.bug_complexity[0].value = 1
    dut.bug_complexity[1].value = 1
    dut.bug_complexity[2].value = 3
    for i in range(3, 8):
        dut.bug_complexity[i].value = 0
        
    dut.student_ability[0].value = 1
    dut.student_ability[1].value = 2
    for i in range(2, 8):
        dut.student_ability[i].value = 0
        
    dut.student_cost[0].value = 5
    dut.student_cost[1].value = 10
    for i in range(2, 8):
        dut.student_cost[i].value = 65535
        
    dut.budget.value = 100
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure("Test timed out")
    
    if not dut.feasible.value:
        raise TestFailure(f"Expected feasible=1, got {dut.feasible.value}")
    
    if dut.min_days.value != 1:
        raise TestFailure(f"Expected min_days=1, got {dut.min_days.value}")
    
    print(f"Min days: {dut.min_days.value}")
    print(f"Assignment: {[int(dut.assignment[i].value) for i in range(8)]}")
    print("Test 4 Passed!")
