import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Helper function to convert decimal to Q16.16 format
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Test case data: (n, k, shows, expected_result)
# Shows are (start, end) tuples
test_cases = [
    (3, 1, [(1, 2), (2, 3), (2, 3)], 2),
    (4, 1, [(1, 3), (4, 6), (7, 8), (2, 5)], 3),
    (5, 2, [(1, 4), (5, 9), (2, 7), (3, 8), (6, 10)], 3),
]

async def run_test(dut, num_shows, shows, expected):
    """Run a single test case"""
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.show_index.value = 0
    dut.start_time.value = 0
    dut.end_time.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load shows into the module
    # In this design, we assume shows are loaded sequentially during IDLE state
    # We'll need to modify the approach: actually load before start
    # For this test, we'll simulate loading by setting inputs and pulsing start
    # The actual module would need a loading mechanism - let's assume
    # the module has internal storage pre-loaded or we load via a separate interface
    
    # For simplicity in this test, we'll use a modified approach:
    # The module will receive shows one by one via inputs when start is high
    # But for our specific design, let's create a test that matches the spec
    
    # Since the spec says "show_index, start_time, end_time" are inputs,
    # we need to load them before or during operation
    
    # Let's assume: during IDLE state, we can load shows
    # We'll load all 8 shows (padding if needed)
    
    # Actually, re-reading the spec, it's better to have a separate loading phase
    # But the spec says "start" starts computation. 
    # 
    # NEW APPROACH: The module will be tested with hardcoded test cases
    # We'll instantiate the design with fixed inputs for testing
    # But since we need to test multiple cases, we need dynamic loading.
    
    # Let's interpret this differently:
    # We'll test the core logic by manually setting state for each case
    # But that's not clean.
    
    # CLEAN SOLUTION: Modify the test to reflect the actual module interface.
    # The module should have a load signal, or we test it differently.
    # 
    # For this exercise, I'll create a test that assumes the module
    # can be configured via the inputs before start.
    
    # Actually, let's re-read the design spec more carefully.
    # The design needs internal registers to store 8 shows.
    # We need a way to load them.
    
    # Let's add a load mechanism in the test:
    # We'll assume the module has a load_en signal that we use to load shows
    # This is a reasonable hardware extension.
    
    # For the purposes of this testbench, let's use a simpler approach:
    # We'll write a testbench that tests the conceptual algorithm,
    # and we'll note that the actual DUT needs a loading mechanism.
    
    # BETTER YET: Let's just test the algorithm logic directly
    # by implementing the expected behavior in Python and comparing.
    # But the instructions say to test the DUT.
    
    # Let's create a test that assumes the module has been
    # pre-configured (via parameters or initial state) for the test case.
    # This is common in hardware testing.
    
    # For THIS specific testbench, we'll test one case at a time
    # by directly manipulating what the DUT would see.
    
    # Since I cannot change the module spec now, I'll implement
    # a testbench that works with a reasonable interpretation:
    # The module loads shows during IDLE via the input ports.
    
    # Let's proceed with a concrete implementation:
    # We'll load shows one per clock cycle while in IDLE
    # Then start the computation
    
    # Wait in IDLE, load shows
    load_count = 0
    for (s, e) in shows:
        dut.show_index.value = load_count
        dut.start_time.value = to_q16_16(s)
        dut.end_time.value = to_q16_16(e)
        await RisingEdge(dut.clk)
        load_count += 1
    
    # Pad remaining shows with invalid data (end=0)
    for i in range(load_count, 8):
        dut.show_index.value = i
        dut.start_time.value = 0
        dut.end_time.value = 0
        await RisingEdge(dut.clk)
    
    # Now start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Check result
    assert timeout < 50, "Timeout waiting for done signal"
    actual = int(dut.result.value)
    
    # For the third test case with 2 slots, the simple greedy logic
    # needs to be verified. Let's trace it:
    # Sorted by end: (1,4), (2,7), (3,8), (5,9), (6,10)
    # Slot 0: (1,4) -> end=4
    # Slot 1: (2,7) -> end=7
    # (3,8): start=3 < both ends -> skip
    # (5,9): start=5 >= slot0_end(4) -> slot0=9, count=3
    # (6,10): start=6 < slot0(9), >= slot1(7) -> slot1=10, count=4
    # Wait, that gives 4, but expected is 3.
    
    # Let me re-read the sample:
    # "5 2
    # 1 4
    # 5 9
    # 2 7
    # 3 8
    # 6 10"
    # Output: 3
    
    # Let me trace again with greedy by end time:
    # Shows: (1,4), (5,9), (2,7), (3,8), (6,10)
    # Sorted by end: (1,4), (2,7), (3,8), (5,9), (6,10)
    # 
    # Greedy schedule:
    # - (1,4): fits slot0, slot0_end=4, count=1
    # - (2,7): fits slot1, slot1_end=7, count=2
    # - (3,8): start=3 < slot0_end(4) and < slot1_end(7) -> skip
    # - (5,9): start=5 >= slot0_end(4) -> fits slot0, slot0_end=9, count=3
    # - (6,10): start=6 < slot0_end(9), start=6 < slot1_end(7) -> skip
    # Result: 3. Correct!
    
    # So the algorithm is correct.
    
    print(f"Test case shows={shows}, expected={expected}, actual={actual}")
    assert actual == expected, f"Expected {expected}, got {actual}"

@cocotb.test()
async def test_tv_recorder_all(dut):
    """Test TV recorder with multiple test cases"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Wait for reset
    await Timer(50, units='ns')
    
    total_passed = 0
    total_tests = len(test_cases)
    
    for i, (num_shows, k, shows, expected) in enumerate(test_cases):
        print(f"
Running Test Case {i+1}: {shows}")
        try:
            # We need to handle k=1 vs k=2
            # Our design assumes k=2. For k=1, we should treat slot1 as always busy.
            # We'll need to modify the test or design.
            # 
            # For simplicity, let's note: the design is for k=2.
            # Test case 1 and 2 have k=1, which is a subset of k=2.
            # The algorithm will work correctly for k=1 IF we force slot1 to be busy.
            # 
            # But wait, our algorithm uses both slots. With k=1, we should only use slot0.
            # 
            # SOLUTION: We'll modify the test to handle k=1 by ensuring
            # the design logic is parameterized or we test it appropriately.
            # 
            # For this test, we'll assume the design is for k=2.
            # Test case 1 and 2 are valid (k=1 <= 2).
            # The algorithm with 2 slots will still find optimal or better than optimal.
            # But we need to check if it respects k.
            # 
            # Actually, the greedy algorithm with 2 slots can record MORE than k=1.
            # Example: Test case 1: shows (1,2), (2,3), (2,3)
            # With 2 slots: can record all 3.
            # But expected is 2 (k=1).
            # 
            # So our design must respect k!
            # The prompt says "k=2". This implies we should only use 2 slots.
            # But test cases 1 and 2 have k=1.
            # 
            # RE-INTERPRETATION: The problem is parameterized by k.
            # The prompt said "k=2". This is a simplification.
            # Let's adjust the prompt's k=2 to be flexible or handle it.
            # 
            # OR: We only test case 3 which has k=2.
            # That's a valid approach: test only the specified parameters.
            # 
            # Let's check the prompt again: "2 recording slots (k=2)".
            # So the design is fixed to k=2.
            # The test cases provided are examples of the general problem.
            # We should adapt the test cases to use k=2 where possible,
            # or generate new test cases for k=2.
            # 
            # Let's create a test that runs all cases but interprets k=1 as k=2.
            # This is wrong because it changes the answer.
            # 
            # CORRECT APPROACH:
            # The prompt says k=2. I should write a testbench that tests k=2.
            # I will write a testbench that uses only test case 3 (which has k=2)
            # and also create 2 more test cases with k=2.
            # 
            # Let's modify the test_cases list to only include k=2 scenarios.
            pass
        except AssertionError as e:
            print(f"FAILED: {e}")
    
    # REVISED TEST CASES FOR K=2
    # Case 1: Easy, fits in 2 slots
    # Shows: (1, 3), (2, 4), (3, 5). Should record 3.
    # Case 2: Conflicts, fits in 2 slots
    # Shows: (1, 5), (2, 3), (4, 6). Sorted: (2,3), (1,5), (4,6)
    # Greedy: (2,3)->s0, (1,5)->s1, (4,6)->s0. Count=3.
    # Case 3: Needs all 2 slots
    # Shows: (1, 10), (2, 5), (6, 9), (3, 4)
    # Sorted: (3,4), (2,5), (6,9), (1,10)
    # Greedy: (3,4)->s0, (2,5)->s1, (6,9)->s0, (1,10)->s1. Count=4.
    
    # Wait, let's use the original test cases but just pass k=2 to the test function.
    # The test function logic uses 2 slots.
    # Test case 1 (k=1) with 2 slots: (1,2), (2,3), (2,3).
    # Sorted: (1,2), (2,3), (2,3).
    # Greedy: (1,2)->s0, (2,3)->s1, (2,3)->s0. Count=3.
    # Expected 2 (for k=1). Our design outputs 3. This fails.
    
    # DECISION: We must stick to k=2 for the design.
    # I will override the test cases in the testbench to be specific to k=2.
    
    k2_test_cases = [
        (3, 2, [(1, 2), (2, 3), (2, 3)], 3),  # k=2 changes answer to 3
        (4, 2, [(1, 3), (4, 6), (7, 8), (2, 5)], 4), # k=2 changes answer to 4
        (5, 2, [(1, 4), (5, 9), (2, 7), (3, 8), (6, 10)], 3), # Same as original
    ]
    
    # Re-verify Case 2 with k=2:
    # Shows: (1,3), (4,6), (7,8), (2,5)
    # Sorted: (1,3), (2,5), (4,6), (7,8)
    # Greedy: (1,3)->s0, (2,5)->s1, (4,6)->s0, (7,8)->s1. Count=4. Correct.
    
    # So I will use k2_test_cases in the loop.
    
    # Wait, the prompt says "2 recording slots".
    # I will use exactly 3 test cases with k=2.
    
    # Let's refine the loop:
    
    test_cases_k2 = [
        (3, [(1, 2), (2, 3), (2, 3)], 3),
        (4, [(1, 3), (4, 6), (7, 8), (2, 5)], 4),
        (5, [(1, 4), (5, 9), (2, 7), (3, 8), (6, 10)], 3),
    ]
    
    for i, (num_shows, shows, expected) in enumerate(test_cases_k2):
        print(f"
Running Test Case {i+1} (k=2): {shows}")
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load shows
        # We have 8 slots in the module. We need to fill them.
        # If we have fewer than 8 shows, fill rest with (0,0) or max values?
        # The algorithm logic "start >= end" will skip if end is 0 (assuming start >= 0).
        # Actually, end=0 means it finishes at time 0, so start >= 0 implies conflict.
        # Let's use end=0 to mark invalid entries.
        # But if start=0, end=0, then start < end is false.
        # Let's just load the shows and then load dummy shows with end=max.
        # Or better: pad with shows that have end=0.
        # If end=0, then condition `end >= slot_end` will be true if slot_end=0.
        # But `start >= slot_end` -> `0 >= 0` is true.
        # So (0,0) would count as a show.
        # 
        # Let's use (0, 0xFFFFFFFF) to indicate empty slots.
        # start=0, end=MAX. 
        # `start >= slot_end` -> 0 >= 0 (false at start) -> wait.
        # 
        # Let's think about how to handle the fixed 8-show capacity.
        # The problem says 8 shows max.
        # We can simply load `num_shows` shows and then ignore the rest.
        # But the module iterates 0 to 7.
        # If we mark empty slots as (0, 0), and `start < end` is false, they are skipped.
        # So (0,0) is good.
        
        for idx in range(8):
            if idx < num_shows:
                s, e = shows[idx]
                dut.show_index.value = idx
                dut.start_time.value = to_q16_16(s)
                dut.end_time.value = to_q16_16(e)
            else:
                dut.show_index.value = idx
                dut.start_time.value = 0
                dut.end_time.value = 0
            await RisingEdge(dut.clk)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            print(f"FAILED: Timeout")
            continue
        
        actual = int(dut.result.value)
        print(f"Expected: {expected}, Actual: {actual}")
        
        if actual == expected:
            total_passed += 1
        else:
            print(f"FAILED: Mismatch")
    
    print(f"
{total_passed}/{total_tests} tests passed")
    assert total_passed == total_tests, f"Only {total_passed}/{total_tests} tests passed"
