import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_yahtzee_solver(dut):
    """Test Sequential Yahtzee solver with sample inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_rolls.value = 0
    for i in range(65):
        dut.dice_in[i].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: All 1's (65 rolls of 1)
    # Expected: 70 points
    # Round 1: 1's category → 5 points
    # Round 2: 2's category → 0 points
    # ... Round 6: 6's category → 0 points
    # Round 7: 3-of-a-Kind → 5 points
    # Round 8: 4-of-a-Kind → 5 points
    # Round 9: Full House → 0 points
    # Round 10: Small Straight → 0 points
    # Round 11: Long Straight → 0 points
    # Round 12: Chance → 5 points
    # Round 13: Yahtzee → 50 points
    # Total: 5 + 0 + 0 + 0 + 0 + 0 + 5 + 5 + 0 + 0 + 0 + 5 + 50 = 70
    
    dut.num_rolls.value = 65
    for i in range(65):
        dut.dice_in[i].value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (allow up to 2500 cycles)
    timeout = 2500
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 1: Did not complete within {timeout} cycles")
    
    result1 = int(dut.max_score.value)
    print(f"Test 1 (All 1's): Score = {result1} (Expected 70)")
    assert result1 == 70, f"Test 1 failed: got {result1}, expected 70"
    
    # Reset for Test Case 2
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Mixed sequence (76 rolls)
    # Expected: 340 points
    # This tests optimal re-roll strategy across multiple categories
    
    test2_rolls = [
        3, 1, 1, 1, 1, 1, 4, 2, 5, 2, 6, 1, 3, 5, 2, 2, 2,
        3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6,
        6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 1, 1, 1, 2, 2, 1, 2, 3, 4, 5,
        1, 2, 3, 4, 5, 1, 1, 6, 1, 6, 6, 6, 6, 1, 1, 1, 1, 1, 4
    ]
    # Only use first 65 rolls as per constraints
    dut.num_rolls.value = 65
    for i in range(65):
        dut.dice_in[i].value = test2_rolls[i]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 2500
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 2: Did not complete within {timeout} cycles")
    
    result2 = int(dut.max_score.value)
    print(f"Test 2 (Mixed rolls): Score = {result2} (Expected 340)")
    assert result2 == 340, f"Test 2 failed: got {result2}, expected 340"
    
    # Reset for Test Case 3: Minimal input
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: Minimum 65 rolls, all 6's
    # Expected: 50 (Yahtzee) + 30 (3-of-a-kind) + 30 (4-of-a-kind) + 5*6 (6's) = 140
    # Actually: 6's=30, 3-of=30, 4-of=30, Yahtzee=50, others 0 = 140
    # Wait, 6's: 6*5=30. 3-of-a-kind: 30. 4-of-a-kind: 30. Yahtzee: 50. Total: 140
    
    dut.num_rolls.value = 65
    for i in range(65):
        dut.dice_in[i].value = 6
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2500
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 3: Did not complete within {timeout} cycles")
    
    result3 = int(dut.max_score.value)
    print(f"Test 3 (All 6's): Score = {result3} (Expected 140)")
    assert result3 == 140, f"Test 3 failed: got {result3}, expected 140"
    
    # Test Case 4: Alternating pattern
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Pattern: 1,2,3,4,5,6,1,2,3,4,5,6,...
    dut.num_rolls.value = 65
    for i in range(65):
        dut.dice_in[i].value = (i % 6) + 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2500
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 4: Did not complete within {timeout} cycles")
    
    result4 = int(dut.max_score.value)
    print(f"Test 4 (Alternating 1-6): Score = {result4}")
    # Expected: Can get straights, some matches
    # 1's: 11, 2's: 22, 3's: 33, 4's: 44, 5's: 55, 6's: 66
    # Straights possible, Yahtzee impossible
    # Reasonable lower bound is 100+
    assert result4 >= 100, f"Test 4 failed: got {result4}, expected >= 100"
    
    print("
All tests passed!")
    print(f"Summary: 4/4 tests passed")