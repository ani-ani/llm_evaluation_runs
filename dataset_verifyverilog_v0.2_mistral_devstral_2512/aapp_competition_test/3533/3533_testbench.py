import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_toll_optimizer(dut):
    """Test toll optimizer with 8 trucks for minimum toll calculation."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.entrance_0.value = 0
    dut.exit_0.value = 0
    dut.entrance_1.value = 0
    dut.exit_1.value = 0
    dut.entrance_2.value = 0
    dut.exit_2.value = 0
    dut.entrance_3.value = 0
    dut.exit_3.value = 0
    dut.entrance_4.value = 0
    dut.exit_4.value = 0
    dut.entrance_5.value = 0
    dut.exit_5.value = 0
    dut.entrance_6.value = 0
    dut.exit_6.value = 0
    dut.entrance_7.value = 0
    dut.exit_7.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample from problem
    # Trucks: (3,65), (45,10), (60,25), (1,2), (4,5), (6,7), (8,9), (10,11)
    # We added 5 more simple pairs to reach 8 trucks
    # Original answer for 3 trucks: 32
    # Full 8-truck: We need to compute manually
    # Entrances: 3,45,60,1,4,6,8,10
    # Exits: 65,10,25,2,5,7,9,11
    # Optimal assignment (no fixed points):
    # Let's assign: 3->10 (7), 45->25 (20), 60->2 (58), 1->5 (4), 4->7 (3), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 7+20+58+4+3+3+3+55 = 153
    # Better: 3->2 (1), 45->10 (35), 60->25 (35), 1->5 (4), 4->7 (3), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 1+35+35+4+3+3+3+55 = 139
    # Actually, we need to verify this is minimal
    
    # Let's use simpler test cases
    
    # Test Case 1: Simple 3-truck equivalent scaled to 8
    # Trucks: (1,2), (2,3), (3,4), (4,5), (5,6), (6,7), (7,8), (8,1)
    # Entrances: 1,2,3,4,5,6,7,8
    # Exits: 2,3,4,5,6,7,8,1
    # Optimal: rotate exits: 1->2(1), 2->3(1), 3->4(1), 4->5(1), 5->6(1), 6->7(1), 7->8(1), 8->1(7)
    # Sum = 1+1+1+1+1+1+1+7 = 14
    
    dut.entrance_0.value = 1
    dut.exit_0.value = 2
    dut.entrance_1.value = 2
    dut.exit_1.value = 3
    dut.entrance_2.value = 3
    dut.exit_2.value = 4
    dut.entrance_3.value = 4
    dut.exit_3.value = 5
    dut.entrance_4.value = 5
    dut.exit_4.value = 6
    dut.entrance_5.value = 6
    dut.exit_5.value = 7
    dut.entrance_6.value = 7
    dut.exit_6.value = 8
    dut.entrance_7.value = 8
    dut.exit_7.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (allow up to 60000 cycles)
    cycles = 0
    while not dut.done.value and cycles < 60000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, f"Test 1 failed: did not complete in {cycles} cycles"
    expected = 14
    actual = int(dut.min_toll_sum.value)
    print(f"Test 1: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 1 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test Case 2: Original sample adapted to 8 trucks
    # Trucks: (3,65), (45,10), (60,25), (1,2), (4,5), (6,7), (8,9), (10,11)
    # We need to find optimal assignment
    # Let's try assignment:
    # 3->10 (7), 45->2 (43), 60->25 (35), 1->5 (4), 4->7 (3), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 7+43+35+4+3+3+3+55 = 153
    # Another: 3->2 (1), 45->10 (35), 60->25 (35), 1->5 (4), 4->7 (3), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 1+35+35+4+3+3+3+55 = 139
    # Another: 3->1 (2), 45->2 (43), 60->25 (35), 1->5 (4), 4->7 (3), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 2+43+35+4+3+3+3+55 = 148
    # Another: 3->1 (2), 45->2 (43), 60->10 (50), 1->5 (4), 4->7 (3), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 2+43+50+4+3+3+3+55 = 163
    # Another: 3->1 (2), 45->2 (43), 60->10 (50), 1->7 (6), 4->5 (1), 6->9 (3), 8->11 (3), 10->65 (55)
    # Sum = 2+43+50+6+1+3+3+55 = 163
    # Another: 3->1 (2), 45->2 (43), 60->10 (50), 1->9 (8), 4->5 (1), 6->7 (1), 8->11 (3), 10->65 (55)
    # Sum = 2+43+50+8+1+1+3+55 = 163
    # Let's try 3->1 (2), 45->2 (43), 60->10 (50), 1->7 (6), 4->9 (5), 6->5 (1), 8->11 (3), 10->65 (55)
    # Sum = 2+43+50+6+5+1+3+55 = 165
    # It seems 139 might be the minimum
    # Let's verify with a programmatic approach for small N
    # Actually, let's use a simpler test case where we know the answer exactly
    
    # Test Case 2: (1,2), (2,1), (3,4), (4,3), (5,6), (6,5), (7,8), (8,7)
    # Entrances: 1,2,3,4,5,6,7,8
    # Exits: 2,1,4,3,6,5,8,7
    # Optimal: swap in pairs: 1->2(1), 2->1(1), 3->4(1), 4->3(1), 5->6(1), 6->5(1), 7->8(1), 8->7(1)
    # Sum = 8
    
    dut.entrance_0.value = 1
    dut.exit_0.value = 2
    dut.entrance_1.value = 2
    dut.exit_1.value = 1
    dut.entrance_2.value = 3
    dut.exit_2.value = 4
    dut.entrance_3.value = 4
    dut.exit_3.value = 3
    dut.entrance_4.value = 5
    dut.exit_4.value = 6
    dut.entrance_5.value = 6
    dut.exit_5.value = 5
    dut.entrance_6.value = 7
    dut.exit_6.value = 8
    dut.entrance_7.value = 8
    dut.exit_7.value = 7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, f"Test 2 failed: did not complete in {cycles} cycles"
    expected = 8
    actual = int(dut.min_toll_sum.value)
    print(f"Test 2: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 2 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test Case 3: Random test with known optimal assignment
    # Trucks: (10,20), (20,30), (30,10), (1,2), (2,3), (3,4), (4,5), (5,1)
    # Entrances: 10,20,30,1,2,3,4,5
    # Exits: 20,30,10,2,3,4,5,1
    # Optimal rotation: 10->30(20), 20->10(10), 30->20(10), 1->2(1), 2->3(1), 3->4(1), 4->5(1), 5->1(4)
    # Sum = 20+10+10+1+1+1+1+4 = 48
    # Check for fixed points: None in this assignment
    
    dut.entrance_0.value = 10
    dut.exit_0.value = 20
    dut.entrance_1.value = 20
    dut.exit_1.value = 30
    dut.entrance_2.value = 30
    dut.exit_2.value = 10
    dut.entrance_3.value = 1
    dut.exit_3.value = 2
    dut.entrance_4.value = 2
    dut.exit_4.value = 3
    dut.entrance_5.value = 3
    dut.exit_5.value = 4
    dut.entrance_6.value = 4
    dut.exit_6.value = 5
    dut.entrance_7.value = 5
    dut.exit_7.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, f"Test 3 failed: did not complete in {cycles} cycles"
    expected = 48
    actual = int(dut.min_toll_sum.value)
    print(f"Test 3: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 3 failed: expected {expected}, got {actual}"
    
    # Test Case 4: Edge case where all trucks are paired
    # Trucks: (1,2), (3,4), (5,6), (7,8), (2,1), (4,3), (6,5), (8,7)
    # This is similar to Test Case 2 but in different order
    # Expected sum: 8 (swap all pairs)
    
    dut.entrance_0.value = 1
    dut.exit_0.value = 2
    dut.entrance_1.value = 3
    dut.exit_1.value = 4
    dut.entrance_2.value = 5
    dut.exit_2.value = 6
    dut.entrance_3.value = 7
    dut.exit_3.value = 8
    dut.entrance_4.value = 2
    dut.exit_4.value = 1
    dut.entrance_5.value = 4
    dut.exit_5.value = 3
    dut.entrance_6.value = 6
    dut.exit_6.value = 5
    dut.entrance_7.value = 8
    dut.exit_7.value = 7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, f"Test 4 failed: did not complete in {cycles} cycles"
    expected = 8
    actual = int(dut.min_toll_sum.value)
    print(f"Test 4: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 4 failed: expected {expected}, got {actual}"
    
    # Test Case 5: Verify original problem intent (3 trucks) using first 3 entries
    # Trucks: (3,65), (45,10), (60,25) + dummy trucks
    # For 3 trucks, answer is 32
    # Let's add dummy trucks (1,2), (2,3), (3,4), (4,5), (5,1) to make 8
    # But wait, we need to verify the 3-truck answer is achievable in 8-truck context
    # Original 3-truck optimal: 3->10 (7), 45->65 (20), 60->25 (35) = 62? No, 32
    # Wait: 3->25 (22), 45->10 (35), 60->65 (5) = 62? No
    # Let's recalculate: 3->65 (62), 45->25 (20), 60->10 (50) = 132
    # 3->25 (22), 45->10 (35), 60->65 (5) = 62
    # 3->10 (7), 45->25 (20), 60->65 (5) = 32
    # So: 3->10, 45->25, 60->65
    # Check fixed points: 3 != 10, 45 != 25, 60 != 65 - OK
    # For 8 trucks: add (1,2), (2,3), (3,4), (4,5), (5,1)
    # Entrances: 3,45,60,1,2,3,4,5
    # Exits: 65,10,25,2,3,4,5,1
    # We need to assign:
    # Keep 3->10, 45->25, 60->65 (cost 32)
    # For remaining: (1,2), (2,3), (3,4), (4,5), (5,1)
    # We have exits: 2,3,4,5 and entrances: 1,2,3,4,5 (but 1 is duplicate entrance? No, 1,2,3,4,5 are distinct)
    # Wait: entrances are 3,45,60,1,2,3,4,5 - 3 is duplicated!
    # That's invalid. Trucks must have distinct entrances.
    # Let's fix: use (1,2), (4,5), (6,7), (7,8), (8,9) as additional trucks
    # Entrances: 3,45,60,1,4,6,7,8
    # Exits: 65,10,25,2,5,7,8,9
    # We want: 3->10, 45->25, 60->65 (cost 32)
    # Remaining: (1,2), (4,5), (6,7), (7,8), (8,9)
    # We need to assign exits {2,5,7,8,9} to entrances {1,4,6,7,8} with no fixed points
    # Optimal: 1->2 (1), 4->5 (1), 6->7 (1), 7->8 (1), 8->9 (1) but 7->7 is fixed point! Need to adjust
    # 7->8 (1) is OK, 8->9 (1) is OK
    # So 1->2 (1), 4->5 (1), 6->7 (1), 7->8 (1), 8->9 (1) = 5 (but we need 5 exits and 5 entrances)
    # We have 5 exits: 2,5,7,8,9 and 5 entrances: 1,4,6,7,8
    # Wait, 7 is in both entrance and exit lists, which could cause fixed point
    # Let's assign: 1->2 (1), 4->5 (1), 6->7 (1), 7->8 (1), 8->9 (1) - this uses all exits
    # But entrance 7 is assigned exit 8, entrance 8 is assigned exit 9 - OK
    # No entrance 7->7 or 8->8, so sum = 5
    # Total = 32 + 5 = 37
    
    dut.entrance_0.value = 3
    dut.exit_0.value = 65
    dut.entrance_1.value = 45
    dut.exit_1.value = 10
    dut.entrance_2.value = 60
    dut.exit_2.value = 25
    dut.entrance_3.value = 1
    dut.exit_3.value = 2
    dut.entrance_4.value = 4
    dut.exit_4.value = 5
    dut.entrance_5.value = 6
    dut.exit_5.value = 7
    dut.entrance_6.value = 7
    dut.exit_6.value = 8
    dut.entrance_7.value = 8
    dut.exit_7.value = 9
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 60000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, f"Test 5 failed: did not complete in {cycles} cycles"
    expected = 37
    actual = int(dut.min_toll_sum.value)
    print(f"Test 5: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 5 failed: expected {expected}, got {actual}"
    
    print(f"All 5 tests passed!")
