import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

async def feed_sequence(dut, accesses, lookahead_depth=16):
    """
    Feeds the sequence of accesses to the DUT.
    """
    dut.valid_i.value = 0
    dut.access_i.value = 0
    
    # Reset handling
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start the process
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # We need to feed data. The DUT might need initial fill of lookahead.
    # We assume the DUT requests data or we just pump it in.
    # Let's assume we pump it in continuously while valid_i is high.
    # However, the DUT logic will stall if internal FIFO is full.
    
    # The cocotb testbench needs to mimic the 'valid_i' protocol.
    # The prompt implies 'valid_i' is high when data is valid.
    
    for access in accesses:
        # Wait for DUT to be ready (if it has a ready signal, but prompt doesn't specify one).
        # Assuming DUT accepts data when valid_i is high.
        # We might need to insert delays based on DUT's internal state, but without a ready signal,
        # we just drive data.
        # To avoid overrunning the lookahead buffer, we should check if the DUT is stalling.
        # Since we don't have a full backpressure signal in the spec, we'll try to drive data every cycle
        # but pause if the DUT's internal counters indicate it's processing.
        
        # However, strictly following the prompt's 'valid_i' logic:
        dut.access_i.value = access
        dut.valid_i.value = 1
        await RisingEdge(dut.clk)
        
        # If the sequence ends, stop valid_i
    dut.valid_i.value = 0
    
    # Wait for processing to complete (done signal)
    timeout_count = 0
    while not dut.done.value and timeout_count < 2000: # Safety timeout
        await RisingEdge(dut.clk)
        timeout_count += 1
        
    if timeout_count >= 2000:
        raise TestFailure("DUT did not assert done within 2000 cycles")

@cocotb.test()
async def test_introspective_cache(dut):
    """
    Test the Introspective Cache Algorithm.
    """
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Wait for a small amount of time to start
    await Timer(5, units="ns")
    
    # Test Case 1: Sample Input 1
    # Cache Size 1, Objects 2, Accesses 3: 0, 0, 1
    # Expected reads: 2 (read 0, hit 0, read 1)
    # We need to scale this to Cache Size 8. 
    # Let's scale the input: Use objects 0, 1, 2... but keep cache size 8.
    # Actually, to test the algorithm properly with size 8, we need a sequence that forces evictions.
    # Let's construct a test case that works with c=8.
    
    # Custom Test Case for c=8:
    # Access pattern: 0, 1, 2, 3, 4, 5, 6, 7 (fill cache - 8 reads)
    # Then access 8 (evict 0? No, look ahead. Let's say 0 is accessed far in future or never).
    # Let's make a pattern: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    # Then access 0 again. 
    # Wait, the prompt says we need to handle 'a' accesses. The DUT processes one per cycle (mostly).
    
    # Let's use a simplified sequence that mimics the logic:
    # 1. Fill cache with 0..7 (8 reads)
    # 2. Access 8. Lookahead: 0 is NOT in immediate future (say next 16), 1 is NOT. 
    #    Actually, let's look at the sample input logic scaled.
    #    Sample 2: 3 4 8 ... 0 1 2 3 3 2 1 0. Output 5.
    #    This is hard to map to 8. 
    #    Let's design a verifiable sequence for c=8.
    #    Sequence: 0, 1, 2, 3, 4, 5, 6, 7 (8 reads)
    #    Then 8. Next use of 0..7? Let's say we access 0 again immediately after.
    #    Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 8, 0
    #    At access 8: Cache has 0..7. 
    #    Future 16 accesses: 0. 
    #    Next use of 0 is index 1 (relative) or 9 (absolute).
    #    Next use of 1..7 is infinity (not in next 16).
    #    Evict 1..7. Let's say evict 1 (lowest ID or arbitrary). Read count 9.
    #    Then access 0 (hit).
    
    # Let's stick to a predictable sequence:
    accesses = []
    # Fill cache: 0, 1, 2, 3, 4, 5, 6, 7
    for i in range(8):
        accesses.append(i)
    # Now evict someone. Let's say we want to evict 0.
    # To evict 0, we need a future where 0 is used LATER or NEVER compared to others.
    # If we access 1 again soon, but 0 never again, we evict 0.
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 8 (miss, look ahead)
    #    Lookahead (next 16): Let's say we keep 0 in cache but it's not used.
    #    Wait, if 0 is not used in lookahead, it's a candidate for eviction.
    #    Let's verify the algorithm logic in hardware:
    #    If an object is not used in the lookahead window, its 'next use' is infinity.
    #    So it should be evicted first.
    
    # Constructed Sequence:
    # 1. 0, 1, 2, 3, 4, 5, 6, 7 (8 reads)
    # 2. 8. Lookahead: 0..7 are NOT present in next 16 (assuming we fill buffer).
    #    Actually, we need to feed enough data so the lookahead is full or sequence ends.
    #    Let's feed 0..7, then 8, then 9... 24.
    #    Reads: 0..7 (8 reads). 8 (9th read). 9 (10th read)...
    #    This saturates the cache.
    #    Let's do something smarter.
    #    Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 0, 8
    #    At 0 (access 8): Hit (0 is in cache). 
    #    At 8 (access 9): Miss. Cache: 0,1,2,3,4,5,6,7.
    #    Lookahead: none (or empty). 
    #    If we only feed 10 accesses, lookahead after 8 is empty.
    #    So all cached items have 'next use' = infinity.
    #    The hardware needs a rule for tie-breaking (e.g., LRU or lowest ID).
    #    Let's assume the spec implies it picks one. 
    #    We'll set the test to verify the count. 9 reads total.
    
    # Let's try to trigger the 'future' logic.
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
    # Then access 0 again.
    # Reads: 0-16 (17 reads).
    # Access 0 again (hit).
    # This tests the buffer.
    
    # Let's use a simple verifiable sequence that fits the 'Lookahead' requirement.
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 8, 0
    # Reads: 0-7 (8). 8 (9). 0 (hit).
    # Total 9.
    
    # Let's implement the test for 9 reads.
    test_accesses = [0, 1, 2, 3, 4, 5, 6, 7, 8, 0]
    
    await feed_sequence(dut, test_accesses)
    
    # Expected reads: 9
    # (0, 1, 2, 3, 4, 5, 6, 7, 8 are all misses because cache is initially empty, then fills up, then 8 evicts one).
    # Wait, cache size is 8. 
    # 0 (miss, load), 1 (miss, load)... 7 (miss, load). Cache full.
    # 8 (miss). Lookahead: 0 is at index 9. 
    # 1..7 are not in lookahead (if we stop the sequence there).
    # Wait, the sequence is 0, 1, 2, 3, 4, 5, 6, 7, 8, 0.
    # At access 8: 
    #   Cache: {0, 1, 2, 3, 4, 5, 6, 7}
    #   Lookahead (buffer): {0}
    #   Next use of 0: 1 cycle away (or index 1 in lookahead).
    #   Next use of 1..7: Infinity (not in lookahead).
    #   Evict one of 1..7. Read 8.
    #   Count = 9.
    #   Access 0 (hit).
    
    if dut.read_count.value != 9:
        raise TestFailure(f"Expected read count 9, got {int(dut.read_count.value)}")
        
    # Print success
    dut._log.info("Test 1 passed: 9 reads")
    
    # Test Case 2: Second Sample adapted
    # 3 4 8 ... 0 1 2 3 3 2 1 0. Output 5.
    # Scaled to c=8 is trivial (read 0, 1, 2, 3, ... then hits).
    # To test lookahead benefit:
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 8
    # At 8: Cache {0,1,2,3,4,5,6,7}
    # Lookahead: (Empty, assuming sequence ends)
    # Reads: 0-7 (8), 8 (9). 
    # Let's try: 0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 8, 9, 10, 11, 12, 13, 14, 15
    # Then 2.
    # At 2: Cache {0,1,8,9,10,11,12,13} (assuming FIFO eviction if lookahead is equal).
    # Actually, with lookahead, 0 and 1 are used in the past, but not future.
    # Wait, at access 8 (index 8), lookahead is 9..15. None are 0..7.
    # So eviction is random/LRU.
    # The prompt says 'Introspective Caching' is OPTIMAL.
    # Optimal = Evict item used FARTHEST in future.
    # If no item is used in future, evict anyone.
    
    # Let's verify with a case where future knowledge matters.
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 0, 8
    # Wait, 0 is in lookahead at index 8.
    # At index 8 (access 8): Cache {0..7}. Lookahead {0}.
    # Next use of 0 = 1. Next use of 1..7 = inf.
    # Evict 1..7.
    # Reads = 9.
    
    # Let's add a test where we evict something used recently but not soon.
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 0, 8, 1, 9
    # At index 9 (access 9): 
    #   We had: 0 (hit), 8 (miss, evict say 1), 1 (miss, evict say 2).
    #   This depends on ties.
    
    # Let's go with the first test case which is robust enough to verify the 'miss' logic and 'hit' logic.
    # 0..7 fills cache. 8 misses. 0 hits.
    
    # Run a second test to be sure.
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Sequence: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    # All miss. 16 reads.
    seq2 = list(range(16))
    await feed_sequence(dut, seq2)
    
    if dut.read_count.value != 16:
        raise TestFailure(f"Test 2 Failed: Expected 16, got {int(dut.read_count.value)}")
        
    dut._log.info("All tests passed")
