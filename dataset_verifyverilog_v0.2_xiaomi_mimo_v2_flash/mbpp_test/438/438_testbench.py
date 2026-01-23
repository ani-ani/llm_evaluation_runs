import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_bidirectional_counter(dut):
    """Test bidirectional tuple pair counting"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.tuple_first.value = 0
    dut.tuple_second.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [(5, 6), (1, 2), (6, 5), (9, 1), (6, 5), (2, 1)] -> Expected 3
    # Pairs: (5,6)-(6,5), (5,6)-(6,5) (second), (1,2)-(2,1)
    dut._log.info("Running Test Case 1")
    dut.tuple_first.value = [5, 1, 6, 9, 6, 2, 0, 0]
    dut.tuple_second.value = [6, 2, 5, 1, 5, 1, 0, 0]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (29 cycles total for 8 items)
    cycles = 0
    while dut.done.value == 0 and cycles < 50:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value == 0:
        raise TestFailure("Test Case 1: Module did not finish in time")
        
    if dut.result.value != 3:
        raise TestFailure(f"Test Case 1: Expected 3, got {int(dut.result.value)}")
    dut._log.info(f"Test Case 1 Passed: Result {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: [(5, 6), (1, 3), (6, 5), (9, 1), (6, 5), (2, 1)] -> Expected 2
    # Pairs: (5,6)-(6,5), (5,6)-(6,5)
    dut._log.info("Running Test Case 2")
    dut.tuple_first.value = [5, 1, 6, 9, 6, 2, 0, 0]
    dut.tuple_second.value = [6, 3, 5, 1, 5, 1, 0, 0]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 50:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.result.value != 2:
        raise TestFailure(f"Test Case 2: Expected 2, got {int(dut.result.value)}")
    dut._log.info(f"Test Case 2 Passed: Result {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: [(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)] -> Expected 4
    # Pairs: (5,6)-(6,5), (5,6)-(6,5), (1,2)-(2,1), (9,2)-(2,9) (not present) - Wait.
    # Re-evaluating Test 3 from prompt: [(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)]
    # Indices: 0:(5,6), 1:(1,2), 2:(6,5), 3:(9,2), 4:(6,5), 5:(2,1)
    # Pairs:
    # (0,2): 5==5, 6==6 -> Match
    # (0,4): 5==5, 6==6 -> Match
    # (1,5): 1==1, 2==2 -> Match
    # (3,5): 9==9? No, 9 != 1. 
    # Wait, check prompt again: Test 3 result is 4.
    # List: (5,6), (1,2), (6,5), (9,2), (6,5), (2,1)
    # (0,2) -> (5,6) vs (6,5) -> Match
    # (0,4) -> (5,6) vs (6,5) -> Match
    # (1,5) -> (1,2) vs (2,1) -> Match
    # (3,5) -> (9,2) vs (2,1) -> 9!=1. No match.
    # (2,4) -> (6,5) vs (6,5) -> No (6 != 5).
    # Did I miss something? Let's check (3,5) again. (9,2) and (2,1). 9!=1. 
    # Wait, is (9,2) paired with (2,9)? No (2,9) is not present.
    # Maybe the prompt has a typo or I'm miscounting.
    # Let's run the Python code from prompt to be sure.
    # def count_bidirectional(test_list):
    #   res = 0
    #   for idx in range(0, len(test_list)):
    #     for iidx in range(idx + 1, len(test_list)):
    #       if test_list[iidx][0] == test_list[idx][1] and test_list[idx][1] == test_list[iidx][0]:
    #         res += 1
    #   return res
    # test_list = [(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)]
    # idx=0: (5,6) -> iidx=1 (1,2): 1!=6. iidx=2 (6,5): 6==6 and 5==5 -> True (res=1). iidx=3 (9,2): 9!=6. iidx=4 (6,5): 6==6 and 5==5 -> True (res=2). iidx=5 (2,1): 2!=6.
    # idx=1: (1,2) -> iidx=2 (6,5): 6!=2. iidx=3 (9,2): 9!=2. iidx=4 (6,5): 6!=2. iidx=5 (2,1): 2==2 and 1==1 -> True (res=3).
    # idx=2: (6,5) -> iidx=3 (9,2): 9!=5. iidx=4 (6,5): 6!=5. iidx=5 (2,1): 2!=5.
    # idx=3: (9,2) -> iidx=4 (6,5): 6!=2. iidx=5 (2,1): 2==2 and 1==9 -> False.
    # idx=4: (6,5) -> iidx=5 (2,1): 2!=5.
    # Result: 3.
    # The prompt says 4. Let's re-read the prompt list carefully.
    # Test 3: [(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)]
    # Maybe (9,2) and (2,1) is considered bidirectional? No, 9 != 1.
    # Maybe there is a mistake in my manual check or the prompt.
    # Let's check if (9, 2) is supposed to be (1, 2) or something?
    # Wait, looking at Test 1: result 3. Test 2: result 2. Test 3: result 4.
    # List for Test 3: (5,6), (1,2), (6,5), (9,2), (6,5), (2,1)
    # If (9,2) was (2,9), then (9,2)-(2,9) would match. But it is (9,2).
    # If (9,2) was (1,9)? No.
    # Let's assume the prompt is correct and I am missing a valid pair.
    # Let's re-evaluate (9,2) and (2,1). The condition is `test_list[iidx][0] == test_list[idx][1] and test_list[idx][1] == test_list[iidx][0]`.
    # Wait, the condition is `test_list[iidx][0] == test_list[idx][1] AND test_list[idx][1] == test_list[iidx][0]`.
    # This is redundant. It is just `test_list[iidx][0] == test_list[idx][1]` because `a == b and b == a` is `a == b`.
    # Let's re-re-check (9,2) and (2,1).
    # idx=3: (9, 2). 
    # iidx=5: (2, 1).
    # Condition: test_list[5][0] (2) == test_list[3][1] (2) -> True.
    # AND test_list[3][1] (2) == test_list[5][0] (2) -> True.
    # So (9,2) and (2,1) IS a match? No. Wait. The code is:
    # `if test_list[iidx][0] == test_list[idx][1] and test_list[idx][1] == test_list[iidx][0]:`
    # This is indeed just checking if the first of second tuple equals second of first tuple.
    # It checks: `tuple_B[0] == tuple_A[1]`.
    # It does NOT check `tuple_B[1] == tuple_A[0]` in the condition (unless it's implicitly satisfied by the OR logic I'm imagining).
    # Wait, the problem description says: "if test_list[iidx][0] == test_list[idx][1] and test_list[idx][1] == test_list[iidx][0]"
    # This IS checking both directions effectively if `a == b` is the check.
    # If `A=(x,y)` and `B=(w,z)`. 
    # Condition: `w == y` AND `y == w`. This is just `w == y`.
    # Is there a typo in the prompt's Python code?
    # Usually "bidirectional" means `w == y` AND `z == x`.
    # The provided code checks `w == y` AND `y == w`. 
    # That is just `w == y`.
    # If the prompt meant `test_list[iidx][0] == test_list[idx][1] and test_list[iidx][1] == test_list[idx][0]`, then it checks both.
    # Let's assume the prompt's logic is correct as written, or there's a typo in the prompt's code snippet vs the description.
    # However, the test cases imply a specific logic.
    # Let's trace Test 1 again with the code `if A[0]==B[1] and A[1]==B[0]` (Standard definition) vs `A[0]==B[1] and A[1]==B[0]` (Prompt's text).
    # Prompt text: `test_list[iidx][0] == test_list[idx][1] and test_list[idx][1] == test_list[iidx][0]`.
    # Let's assume the prompt meant `test_list[iidx][0] == test_list[idx][1] and test_list[iidx][1] == test_list[idx][0]`.
    # If I use the standard definition:
    # Test 1: (5,6)-(6,5), (1,2)-(2,1). That's 2 pairs? No wait, (6,5) appears twice.
    # Indices 0,2: (5,6) vs (6,5) -> Match.
    # Indices 0,4: (5,6) vs (6,5) -> Match.
    # Indices 1,5: (1,2) vs (2,1) -> Match.
    # Total 3. Correct.
    # Test 2: (5,6) vs (6,5) twice. 2 matches. Correct.
    # Test 3: (5,6) vs (6,5) twice. (1,2) vs (2,1) once. (9,2) vs (2,1)? No. (9,2) vs (2,9)? No.
    # Where does the 4th come from?
    # List: (5,6), (1,2), (6,5), (9,2), (6,5), (2,1)
    # If we check (9,2) vs (2,1): 2==2 (first of second equals second of first). 
    # The prompt's code: `test_list[iidx][0] == test_list[idx][1]`.
    # For idx=3 (9,2) and iidx=5 (2,1): 
    # test_list[5][0] (2) == test_list[3][1] (2) -> True.
    # The second part: `test_list[3][1] == test_list[5][0]` -> 2 == 2 -> True.
    # So it IS a match according to the literal code provided.
    # But it's not symmetric. 
    # Let's check the reverse: idx=5 (2,1) and iidx=3 (9,2).
    # `test_list[3][0] (9) == test_list[5][1] (1) -> False.
    # So the order matters in the prompt's code.
    # In Test 3: (9,2) and (2,1) are present.
    # (9,2) -> (2,1): 2==2 (True).
    # Is this considered a bidirectional pair? It matches the provided code exactly.
    # So Test 3 has:
    # (5,6)-(6,5): 2 occurrences -> 2 matches
    # (1,2)-(2,1): 1 occurrence -> 1 match
    # (9,2)-(2,1): 1 occurrence -> 1 match (Check: 9,2 then 2,1).
    # Total 4. 
    # Okay, I will implement the logic exactly as the prompt code:
    # `if test_list[iidx][0] == test_list[idx][1] and test_list[idx][1] == test_list[iidx][0]`
    # Wait, `test_list[iidx][0] == test_list[idx][1]` is w == y.
    # `test_list[idx][1] == test_list[iidx][0]` is y == w. (Redundant)
    # I will assume there is a typo in the prompt's logic text vs the test cases.
    # IF the test cases are right, the logic might be `test_list[iidx][0] == test_list[idx][1] AND test_list[iidx][1] == test_list[idx][0]`.
    # But using the prompt's strict text logic (w == y) gives 4 for Test 3. 
    # Let's stick to the prompt's text for the testbench, but comment on the ambiguity.
    # However, to make it a good "bidirectional" problem (usually symmetric), I should probably implement the symmetric version `w == y AND z == x`.
    # But Test 3 Result 4 ONLY holds if we count (9,2)-(2,1) as a hit.
    # (9,2)-(2,1): 2==2 (True). 2==2 (True). 
    # (2,1)-(9,2): 9==1 (False). 
    # So the count is 3 if we require symmetry (or iterate all pairs but check direction).
    # Wait, the nested loop `for idx in range... for iidx in range(idx+1...)` ensures uniqueness.
    # So we check pair (3,5) once.
    # Condition: `test_list[5][0] == test_list[3][1]` (2==2) True.
    # `test_list[3][1] == test_list[5][0]` (2==2) True.
    # So it counts.
    # Okay, I will implement exactly this redundant check.
    
    dut._log.info("Running Test Case 3")
    dut.tuple_first.value = [5, 1, 6, 9, 6, 2, 0, 0]
    dut.tuple_second.value = [6, 2, 5, 2, 5, 1, 0, 0]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 50:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.result.value != 4:
        raise TestFailure(f"Test Case 3: Expected 4, got {int(dut.result.value)}")
    dut._log.info(f"Test Case 3 Passed: Result {int(dut.result.value)}")
    
    dut._log.info("All tests passed successfully!")
