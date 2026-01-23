import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_stone_game(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_piles.value = 0
    for i in range(8):
        dut.piles[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    async def run_test(piles_vals, num_piles, expected_valid, expected_winner, test_name):
        dut._log.info(f"Running test: {test_name}")
        dut.num_piles.value = num_piles
        # Set input array (padded to 8 elements with 0s)
        padded_piles = piles_vals + [0] * (8 - len(piles_vals))
        for i in range(8):
            dut.piles[i].value = padded_piles[i]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
            
        # Check results
        assert dut.valid.value == expected_valid, f"Valid mismatch: expected {expected_valid}, got {dut.valid.value}"
        if expected_valid:
            assert dut.winner.value == expected_winner, f"Winner mismatch: expected {expected_winner}, got {dut.winner.value}"
        
        await RisingEdge(dut.clk)

    # Test Cases (Adapted from examples)
    
    # 1. Example 1: n=1, [0]
    # No moves possible. Player 1 loses (cslnb -> winner 0).
    # However, current player (P1) cannot move -> Lose. So P1 loses. Output winner=0.
    # Wait, if P1 cannot move, P1 loses immediately. Output should be 'cslnb' (P2 wins).
    # Python output: cslnb. So Winner should be 0 (P2 wins).
    await run_test([0], 1, 1, 0, "Single Zero")

    # 2. Example 2: n=2, [1, 0]
    # Sorted: [0, 1]. 
    # P1 must pick from pile 1 (value 1). -> [0, 0]. Duplicate 0. P1 loses immediately after move.
    # Wait. If P1 moves and loses immediately, then P1 loses. 
    # In this specific game rule: "if after removing the stone, two piles... contain the same number of stones".
    # So P1 moves [1,0] -> [0,0]. P1 loses. Result: cslnb (P2 wins). Winner=0.
    # Let's check our logic: 
    # Start state [1,0] is valid. 
    # Calculated moves: 
    # We don't calculate total moves. We calculate winner based on parity of valid moves if game is "clean".
    # This specific case is a "trap" move. 
    # My HW logic: Check invalid states FIRST. [1,0] is valid state. 
    # Then calc parity: sum(1-0 + 0-1) = 0. Parity 0 -> P2 wins. 
    # So our logic outputs Winner=0 (cslnb). Matches expected.
    await run_test([1, 0], 2, 1, 0, "Two Piles 1 0")

    # 3. Example 3: n=2, [2, 2]
    # Sorted: [2, 2].
    # P1 picks from pile 1 -> [1, 2]. Valid.
    # P2 picks from pile 2 -> [1, 1]. Duplicate 1. P2 loses. P1 wins.
    # Python output: sjfnb (P1 wins). Winner=1.
    # Our logic: Check invalid states. [2,2]. 1 duplicate. Value 2 != 0. Check 2-1=1 in array? No.
    # So Valid. 
    # Calc: sum(2-0 + 2-1) = 2 + 1 = 3. Odd -> P1 wins. Winner=1. Matches.
    await run_test([2, 2], 2, 1, 1, "Two Piles 2 2")

    # 4. Example 4: n=3, [2, 3, 1]
    # Sorted: [1, 2, 3].
    # Valid start. No duplicates.
    # Calc: sum(1-0 + 2-1 + 3-2) = 1. Odd -> P1 wins. Winner=1.
    await run_test([2, 3, 1], 3, 1, 1, "Three Piles 1 2 3")

    # 5. Invalid State: n=3, [3, 3, 3]
    # Sorted: [3, 3, 3].
    # 3 duplicates > 1. Invalid.
    # Output valid=0.
    await run_test([3, 3, 3], 3, 0, 0, "Invalid Triple")

    # 6. Invalid State: n=3, [0, 0, 5]
    # Sorted: [0, 0, 5].
    # Duplicate 0. Invalid.
    await run_test([0, 0, 5], 3, 0 0,, 0, "Invalid Zero Dupe")

    # 7. Invalid State: n=3, [3, 4, 4]
    # Sorted: [3, 4, 4].
    # Duplicate 4. Check 3 in array. Yes. Invalid.
    await run_test([3, 4, 4], 3, 0, 0, "Invalid Sequential Dupe")

    # 8. Valid Trap (derived from check): [1, 1, 2] is valid? 
    # Sorted [1, 1, 2]. 
    # Dupe 1. 0 in array? No. So valid.
    # Calc: 1-0 + 1-1 + 2-2 = 1. P1 wins.
    await run_test([1, 1, 2], 3, 1, 1, "Valid Dupe Non-Zero")

    # 9. Large values test (fit in 4 bits, i.e. 0-15)
    # [5, 6, 7] -> Sorted [5, 6, 7]. Valid.
    # Calc: 5-0 + 6-1 + 7-2 = 5+5+5=15 (odd). P1 wins.
    await run_test([5, 6, 7], 3, 1, 1, "Large Values")

    # 10. Case [0, 5, 6, 7, 8] (Adapted from 5th input)
    # Python says sjfnb (P1 wins).
    # Sorted: [0, 5, 6, 7, 8]. Valid.
    # Calc: (0-0) + (5-1) + (6-2) + (7-3) + (8-4) = 0 + 4 + 4 + 4 + 4 = 16. Even. P2 wins.
    # Wait, python output says sjfnb. 
    # Let's re-read python logic. 
    # Python: `bal += a[i] - i`. Then `if bal%2 else cslnb`.
    # My calc for [0, 5, 6, 7, 8]:
    # i=0: 0-0=0
    # i=1: 5-1=4
    # i=2: 6-2=4
    # i=3: 7-3=4
    # i=4: 8-4=4
    # Sum=16. Even. Output cslnb.
    # Python example output for `5
0 5 6 7 8` is `cslnb`.
    # Ah, the provided list has `5
0 5 6 7 8` -> Output `cslnb`. 
    # The provided list `5
0 5 6 7 9` -> Output `sjfnb`.
    # My calc for [0, 5, 6, 7, 9]:
    # i=4: 9-4=5. Sum=17. Odd. sjfnb. 
    # Matches! 
    await run_test([0, 5, 6, 7, 9], 5, 1, 1, "Sum Odd 17")

    dut._log.info("All tests passed!")
