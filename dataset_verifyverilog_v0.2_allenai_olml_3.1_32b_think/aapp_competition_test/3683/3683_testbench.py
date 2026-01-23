import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def write_score(dut, addr, val):
    dut.score_addr.value = addr
    dut.score_in.value = val
    dut.score_write.value = 1
    await RisingEdge(dut.clk)
    dut.score_write.value = 0

async def get_results(dut, p):
    results = []
    dut._log.info("Waiting for result_valid...")
    for _ in range(10000): # Timeout
        if dut.result_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.result_valid.value != 1:
        raise TimeoutError("Result valid never went high")
        
    dut._log.info("Result valid high. Reading results...")
    # Assumes results are available on the bus or need to be read
    # The spec says: 'Output results sequentially when result_addr changes.'
    # We will iterate addr from 0 to p-1 and read result_data
    
    # Note: The spec implies result_data is driven based on result_addr input
    # OR the module drives result_addr sequentially.
    # Let's assume the testbench drives result_addr to fetch results.
    for i in range(p):
        dut.result_addr.value = i
        await RisingEdge(dut.clk)
        await Timer(1, units='ns') # Small delta for propagation
        results.append(int(dut.result_data.value))
    return results

@cocotb.test()
async def test_miniature_golf_rank(dut):
    """Test Miniature Golf Rank Calculator"""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.score_write.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("Test Case 1: Small Example (3 players, 3 holes)")
    # Input:
    # 2 2 2 (Total 6)
    # 4 2 1 (Total 7)
    # 4 4 1 (Total 9)
    # Scaled? No, fits in 8 bits.
    # Scores: [2,2,2], [4,2,1], [4,4,1]
    
    p = 3
    h = 3
    dut.p.value = p
    dut.h.value = h
    
    scores = [
        [2, 2, 2],
        [4, 2, 1],
        [4, 4, 1]
    ]
    
    # Load scores
    addr = 0
    for row in scores:
        for val in row:
            await write_score(dut, addr, val)
            addr += 1
            
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait and get results
    results = await get_results(dut, p)
    
    # Expected output: 1, 2, 2
    # Explanation:
    # If l=1: Scores [1,1,1], [1,1,1], [1,1,1]. Totals [3,3,3]. Ranks [1,1,1].
    # If l=2: Scores [2,2,2], [2,2,1], [2,2,1]. Totals [6,5,5]. Ranks [3,1,1].
    # If l=4: (Original) Totals [6,7,9]. Ranks [1,2,3].
    # Minimums: P0 min(1,3,1)=1. P1 min(1,1,2)=1? Wait.
    # Let's re-check problem logic.
    # P0 (2,2,2): l=1 -> 3, l=2 -> 6, l=3 -> 6... min rank 1.
    # P1 (4,2,1): l=1 -> 3, l=2 -> 5, l=3 -> 6... min rank 1 (at l=1 or l=2).
    # P2 (4,4,1): l=1 -> 3, l=2 -> 5, l=3 -> 6... min rank 1 (at l=1).
    # Wait, the problem says "number of players who achieved an equal or lower total score".
    # Rank 1: Count players <= P0. 
    # l=1: Totals [3,3,3]. Ranks: 3,3,3.
    # l=2: Totals [6,5,5]. 
    #  P0: 6. P1: 5. P2: 5.
    #  Rank P0: Count(<=6) = 3. Rank P1: Count(<=5) = 2. Rank P2: Count(<=5) = 2.
    # l=3: Totals [6,6,6]. Ranks: 3,3,3.
    # l=4: Totals [6,7,9]. 
    #  P0: 6. (P1=7, P2=9). Count(<=6)=1. Rank 1.
    #  P1: 7. Count(<=7)=2. Rank 2.
    #  P2: 9. Count(<=9)=3. Rank 3.
    # Min P0: 1. Min P1: 1 (l=1,2,3 gave 3,2,3... wait l=2 gave 2). Let's check l=2 again. P1=5, P2=5. Count(<=5)=2. Rank 2.
    #  Let's re-read problem statement. "Rank is number of players with equal or lower score".
    #  Example: "3,5,5,4,3". Ranks "2,5,5,3,2".
    #  3: Two 3s <= 3. -> Rank 2.
    #  5: All 5 numbers <= 5. -> Rank 5.
    #  4: 3,3,4 <= 4. -> Rank 3.
    #  So yes, count <=.
    #  P0 l=2: 6. P1=5, P2=5. Count <= 6 is 3. Rank 3.
    #  P1 l=2: 5. Count <= 5 is 2. Rank 2.
    #  P2 l=2: 5. Rank 2.
    #  Wait, sample output is 1, 2, 2.
    #  P1 needs rank 2. P2 needs rank 2.
    #  Maybe I missed a better 'l'.
    #  What if l=3? Totals [6,6,6]. All ranks 3.
    #  What if l=1? [3,3,3]. All ranks 3.
    #  What if l=0? Not allowed (positive integer). 
    #  Let's re-read sample output explanation.
    #  Maybe I messed up the example interpretation.
    #  Input: 
    #  2 2 2 (Total raw 6)
    #  4 2 1 (Total raw 7)
    #  4 4 1 (Total raw 9)
    #  Sample Output: 1 2 2.
    #  Let's check l=4 (original). Ranks 1,2,3.
    #  Let's check l=3. 
    #  P0: min(2,2,2)=2 -> 6. P1: min(4,2,1)=2 -> 5? Wait min(4,3,1) -> 3,2,1 -> 6? No.
    #  P1 scores: 4,2,1. With l=3 -> min(4,3)=3, min(2,3)=2, min(1,3)=1. Total 6.
    #  P2 scores: 4,4,1. With l=3 -> 3,3,1. Total 7.
    #  So Totals: [6,6,7].
    #  Ranks: P0: 2 (<=6: P0, P1). P1: 2. P2: 3.
    #  Check l=2.
    #  P0: min(2,2,2)=2 -> 6.
    #  P1: min(4,2,1)=2 -> 2+2+1=5.
    #  P2: min(4,4,1)=2 -> 2+2+1=5.
    #  Totals: [6,5,5].
    #  Rank P0: Count(<=6) = 3.
    #  Rank P1: Count(<=5) = 2.
    #  Rank P2: Count(<=5) = 2.
    #  This gives ranks 3, 2, 2. Not 1,2,2.
    #  Wait, sample output says 1, 2, 2.
    #  Is there an 'l' where P0 gets 1? Yes, l=4. P0=6. P1=7. P2=9. Rank P0=1.
    #  Is there an 'l' where P1 gets 1? P1 needs strictly lowest score.
    #  P1 total < P0 and < P2.
    #  P0 raw: 2,2,2. P1 raw: 4,2,1.
    #  Can P1 be < P0?
    #  P0 sum: 6. P1 sum: 7 - (number of holes > l).
    #  P1 needs sum <= 5 (strictly less than 6).
    #  Reduction needed: 2.
    #  P1 has holes 4 and 4. (Holes > l).
    #  Need l such that (4-l) + (4-l) >= 2? 
    #  Need (8 - 2l) >= 2 -> 6 >= 2l -> l <= 3.
    #  Try l=3: P1 sum = 3+2+1=6. P0=6. Tie. Rank 2.
    #  Try l=2: P1 sum = 2+2+1=5. P0=6. P1 < P0.
    #  Check P2 vs P1. P2 raw: 4,4,1. 
    #  P2 at l=2: 2+2+1=5. Tie with P1. Rank 2.
    #  Wait, why sample output 1 for P0? And 2 for P1/P2?
    #  Maybe my manual calc is wrong.
    #  Let's look at sample explanation provided in problem? No.
    #  Let's re-read problem statement carefully. "Rank of a player is the number of players who achieved an equal or lower total score".
    #  Example: 3, 5, 5, 4, 3 -> Ranks 2, 5, 5, 3, 2.
    #  Sorted: 3, 3, 4, 5, 5.
    #  Rank 2: Two 3s. (Indices 0, 1 in sorted).
    #  Rank 3: 4.
    #  Rank 5: 5s.
    #  So Rank = 1 + count of players with strictly lower score.
    #  Wait, for 3: count strictly lower = 0. Rank 1? No, example says 2.
    #  So definition: Rank = count of players with score <= mine.
    #  For 3: count(<=3) = 2. Correct.
    #  For 5: count(<=5) = 5. Correct.
    #  So Rank = count(score <= my_score).
    
    #  Sample 1: 
    #  P0: (2,2,2). 
    #  P1: (4,2,1).
    #  P2: (4,4,1).
    #  Output: 1, 2, 2.
    #  P0 rank 1 means P0 has strictly lowest score (or tied for lowest, but count=1).
    #  P1 rank 2 means P1 is tied or just above lowest.
    #  P2 rank 2.
    
    #  Let's re-evaluate l=2.
    #  P0: 2+2+2 = 6.
    #  P1: min(4,2)+min(2,2)+min(1,2) = 2+2+1 = 5.
    #  P2: min(4,2)+min(4,2)+min(1,2) = 2+2+1 = 5.
    #  Counts <= 6: 3. Rank P0=3.
    #  Counts <= 5: 2. Rank P1=2.
    #  Counts <= 5: 2. Rank P2=2.
    #  This yields 3,2,2. 
    #  Why sample output 1,2,2?
    #  Maybe I made a mistake in l=4?
    #  l=4: 
    #  P0: 2+2+2=6.
    #  P1: 4+2+1=7.
    #  P2: 4+4+1=9.
    #  P0 rank: 1 (6 <= 6). (7>6, 9>6).
    #  P1 rank: 2 (6<=7, 7<=7).
    #  P2 rank: 3.
    #  So l=4 gives 1,2,3.
    #  l=2 gives 3,2,2.
    #  What about l=3?
    #  P0: 2+2+2=6.
    #  P1: min(4,3)+min(2,3)+min(1,3)=3+2+1=6.
    #  P2: min(4,3)+min(4,3)+min(1,3)=3+3+1=7.
    #  P0 rank: 2 (P0=6, P1=6). 2 players <= 6.
    #  P1 rank: 2.
    #  P2 rank: 3.
    #  This gives 2,2,3.
    #  Wait, sample output is 1, 2, 2.
    #  Is there an l that makes P0 rank 1 AND P1, P2 rank 2?
    #  P0 rank 1 implies P0 < P1 and P0 < P2.
    #  P0 sum = 6.
    #  Need P1 sum > 6 and P2 sum > 6.
    #  But P1 sum at l=4 is 7. P2 sum at l=4 is 9.
    #  So l=4 gives P0=1. P1=2. P2=3. 
    #  Wait, P2=3 is the problem.
    #  We need P2 rank 2. That means P2 <= P1 (or P2 tied with P1) AND P2 < P0? No.
    #  Rank 2 for P2 means exactly 2 players have score <= P2.
    #  That implies P2 is either the lowest or the second lowest.
    #  If P2 is lowest, Rank 1. If P2 is second lowest, Rank 2 (tied with lowest).
    #  If P2 is third lowest, Rank 3.
    #  So we need P2 to be in top 2.
    #  P0=6. P1=7. P2=9 -> P2 is 3rd. Rank 3.
    #  P0=6. P1=6. P2=7 -> P2 is 3rd. Rank 3.
    #  P0=6. P1=5. P2=5 -> P2 is 2nd (tied). Rank 2.
    #  So we need P0=6, P1=5, P2=5. 
    #  That was l=2.
    #  l=2: 
    #  P0=6.
    #  P1=5.
    #  P2=5.
    #  P0 rank: Count(<=6) = 3. 
    #  P1 rank: Count(<=5) = 2.
    #  P2 rank: Count(<=5) = 2.
    #  This gives 3, 2, 2. 
    #  Why does sample say 1, 2, 2?
    #  Is it possible P0 score can be reduced?
    #  P0 scores are 2,2,2. Max is 2. l=1 -> P0=3. l=2 -> P0=6. l>=2 -> P0=6.
    #  So P0 is either 3 or 6.
    #  If P0=3 (l=1):
    #  P1: min(4,1)+min(2,1)+min(1,1)=1+1+1=3.
    #  P2: min(4,1)+min(4,1)+min(1,1)=1+1+1=3.
    #  All 3. All ranks 3.
    #  So P0 rank is either 3 (l=1) or 3 (l=2) or 2 (l=3) or 1 (l=4).
    #  Min P0 rank is 1.
    #  P1 rank: 
    #  l=1: 3. Rank 3.
    #  l=2: 5. Rank 2.
    #  l=3: 6. Rank 2 (tied with P0). 
    #  l=4: 7. Rank 2.
    #  Min P1 rank is 2.
    #  P2 rank:
    #  l=1: 3. Rank 3.
    #  l=2: 5. Rank 2.
    #  l=3: 7. Rank 3.
    #  l=4: 9. Rank 3.
    #  Min P2 rank is 2.
    #  So output should be 1, 2, 2. 
    #  Wait, if P0=1 (l=4), P1=2 (l=4), P2=3 (l=4). 
    #  If P2=2 (l=2), P0=3 (l=2), P1=2 (l=2).
    #  We want MIN rank per player.
    #  P0 min(1,3,3,1) = 1.
    #  P1 min(3,2,2,2) = 2.
    #  P2 min(3,2,3,3) = 2.
    #  So answer 1, 2, 2. 
    #  My manual check for l=2 gave P0=3, which matches. 
    #  Why did I doubt? I thought P0=1 was impossible. It is possible at l=4.
    #  So the logic holds.
    
    assert results[0] == 1, f"Player 0 rank should be 1, got {results[0]}"
    assert results[1] == 2, f"Player 1 rank should be 2, got {results[1]}"
    assert results[2] == 2, f"Player 2 rank should be 2, got {results[2]}"
    dut._log.info("Test Case 1 Passed")

    # Test Case 2 (Provided)
    # 6 players, 4 holes.
    # We will skip full manual verification due to size, but will test run.
    dut._log.info("Test Case 2: 6 Players, 4 Holes (Complex)")
    p = 6
    h = 4
    dut.p.value = p
    dut.h.value = h
    
    # Scaled inputs? No, provided inputs seem within reasonable range (small ints).
    # 3 1 2 2
    # 4 3 2 2
    # 6 6 3 2
    # 7 3 4 3
    # 3 4 2 4
    # 2 3 3 5
    
    scores_2 = [
        [3, 1, 2, 2],
        [4, 3, 2, 2],
        [6, 6, 3, 2],
        [7, 3, 4, 3],
        [3, 4, 2, 4],
        [2, 3, 3, 5]
    ]
    
    addr = 0
    for row in scores_2:
        for val in row:
            await write_score(dut, addr, val)
            addr += 1
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = await get_results(dut, p)
    
    # Expected output: 1 2 5 5 4 3
    expected = [1, 2, 5, 5, 4, 3]
    
    for i in range(p):
        assert results[i] == expected[i], f"Player {i} rank should be {expected[i]}, got {results[i]}"
    
    dut._log.info("Test Case 2 Passed")
    dut._log.info("All tests passed")
