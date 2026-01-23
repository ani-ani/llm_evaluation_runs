import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_strictly_increasing_subsegment(dut):
    """Test the max_strictly_increasing_subsegment module"""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.index_in.value = 0
    dut.value_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to load data
    async def load_data(values):
        dut.start.value = 1
        # In this design, we might need a specific load state. 
        # Assuming the module expects 16 cycles of data input after start or during load state.
        # Let's assume the prompt specified start pulses high, then we enter LOAD state.
        # To be safe, we will pulse start, then feed data.
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for i, val in enumerate(values):
            dut.index_in.value = i
            dut.value_in.value = val
            await RisingEdge(dut.clk)
    
    # Helper to wait for done
    async def wait_for_done():
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure("Timeout waiting for done")

    # Test Case 1: Example from problem - 7 2 3 1 5 6 (adapted to N=16)
    # Values: [7, 2, 3, 1, 5, 6] -> Max len is 5.
    # We need 16 inputs. We'll fill with 0s or extend pattern.
    # Let's put the sequence at the start and fill rest with large increasing numbers to see if logic holds.
    # Sequence: 7, 2, 3, 1, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
    # Expected behavior: The 'dip' at index 1 (2) and index 3 (1) should be handled.
    # The solution usually checks: max(left) + 1, or left[i-1] + right[i+1] + 1.
    # Let's use a simpler check case.
    
    # Case 1: Strictly increasing. Expect N + 1? No, problem says change at most 1.
    # If strictly increasing, max subsegment is N (no change needed) or N (change one element doesn't help much unless strictly N+1?).
    # Actually, if strictly increasing, the answer is N (or N if we can extend, but usually N).
    # Wait, the problem allows changing ONE number. If strictly increasing, answer is N.
    
    # Let's run a custom set:
    # [1, 2, 3, 1, 2, 3] -> Max is 6 (change the middle 1 to 4).
    
    values = [1, 2, 3, 1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    await load_data(values)
    await wait_for_done()
    
    # The module calculates DP. 
    # For this input, strictly increasing subsegments are [1,2,3] (len 3), [1,2,3] (len 3).
    # Can we merge? 1,2,3,1,2,3. Gap between 3 and 1. 
    # Changing the '1' (index 3) to 4 connects [1,2,3] and [4,2,3] -> no.
    # Changing the '1' to 4 connects [1,2,3] and [4,2,3]. 
    # Wait, strict increasing means a[i] < a[i+1].
    # Left array: 1,2,3,1,2,3...
    # Right array: 3,2,1,3,2,1...
    # At index 3 (value 1): left[2]=3, right[4]=2. Can we bridge? 
    # Original: 3, 1, 2. Change 1 to 4. Result: 3, 4, 2 (bad).
    # Change 1 to something between 3 and 2? No integer.
    # Change 3 (index 2) to something? 
    # Actually, standard solution: ans = max(left) + 1 OR left[i-1] + 1 + right[i+1] if gap allows.
    # Here, max(left)=3. ans=4? No, [1,2,3,1,2,3] can be 6? 
    # Wait, 1,2,3,1,2,3. Change the middle 1 to 4. Result: 1,2,3,4,2,3. Still not strictly increasing.
    # Change 3 (index 2) to 0? 1,2,0,1,2,3. No.
    # Change 3 (index 2) to 4? 1,2,4,1,2,3. No.
    # Change 1 (index 3) to 4? 1,2,3,4,2,3. No.
    # Change 2 (index 4) to 5? 1,2,3,1,5,3. No.
    # Wait, example 7 2 3 1 5 6 -> output 5.
    # Sequence: 7, 2, 3, 1, 5, 6.
    # Subsegment: 2,3,1,5,6. Change 1 to 4 -> 2,3,4,5,6. Length 5.
    
    # My test case: 1 2 3 1 2 3.
    # Can we make 1 2 3 4 5 6? 
    # Change index 3 (value 1) to 4 -> 1,2,3,4,2,3. No.
    # Change index 2 (value 3) to 0 -> 1,2,0,1,2,3. No.
    # Change index 4 (value 2) to 4 -> 1,2,3,1,4,3. No.
    # Maybe my test case is actually max 3 or 4?
    # Let's use a known working case.
    
    # Case A: [1, 2, 6, 4, 5] -> Max 5 (change 6 to 3).
    # Left: 1,2,3,1,2. Right: 3,2,2,2,1.
    # At index 2 (val 6): left[1]=2, right[3]=2. Gap between 2 and 4? 2, 4. Change 6 to 3. 2,3,4. Valid. Length 2+1+2=5.
    
    # Case B: [1, 5, 9, 6, 10] -> Max 4? 
    # Left: 1,2,3,1,2. Right: 3,2,2,2,1.
    # Index 2 (9): left[1]=2, right[3]=2. Gap 5 and 6? 5, 6. Change 9 to 6. 5,6,6 (fail). Change to 5.5 (fail int). 
    # Gap must be > 1. 6-5 = 1. Cannot. So max is max(3, 3) + 1 = 4.
    
    # Case C: [1, 2, 3, 1, 5, 6] -> Max 5. (Change 1 to 4).
    # Left: 1,2,3,1,2,3. Right: 3,2,1,3,2,1.
    # Index 3 (val 1): left[2]=3, right[4]=2. Gap 3 and 5? 3, 5. Change 1 to 4. Valid. Length 3+1+2=6.
    # Wait, output says 5 for 7 2 3 1 5 6.
    # 7, 2, 3, 1, 5, 6.
    # Subsegment 2,3,1,5,6. Change 1 to 4 -> 2,3,4,5,6. Length 5.
    # My Case C is 1,2,3,1,5,6. Subsegment 1,2,3,1,5,6. Change 1 to 4 -> 1,2,3,4,5,6. Length 6.
    
    # Let's use a mix of these.
    # We need 16 elements. We'll create 3 groups.
    
    # Group 1: [1, 2, 3] (strictly inc)
    # Group 2: [1] (dip)
    # Group 3: [5, 6] (strictly inc)
    # Gap between 3 and 5 is 2. Change the middle 1 to 4. Connects to length 6.
    
    # Let's try to break it. Gap 3 and 4? 3, 4. Change 1 to 3.5? Fail int. So gap must be > 1.
    
    # Test 1: Gap > 1 (Expect merge)
    # [1, 2, 3, 1, 5, 6, 0...0]
    # Expected: 6
    values = [1, 2, 3, 1, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    await load_data(values)
    await wait_for_done()
    res = int(dut.result.value)
    if res != 6:
        dut._log.error(f"Test 1 Failed: Expected 6, Got {res}")
        raise TestFailure(f"Expected 6, got {res}")

    # Test 2: Gap == 1 (Expect no merge, only max segment + 1)
    # [1, 2, 3, 1, 4, 5, 0...0]
    # Gap 3 and 4 is 1. Cannot insert integer.
    # Max segment len is 3. +1 = 4.
    values = [1, 2, 3, 1, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    await load_data(values)
    await wait_for_done()
    res = int(dut.result.value)
    if res != 4:
        dut._log.error(f"Test 2 Failed: Expected 4, Got {res}")
        raise TestFailure(f"Expected 4, got {res}")

    # Test 3: Full array strictly increasing
    # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
    # Answer is 16 (no change needed) or 16 (change one doesn't make it 17).
    # Actually, strictly increasing subsegment of length 16. Change one element -> still strictly increasing? Yes.
    # So max is 16.
    values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
    await load_data(values)
    await wait_for_done()
    res = int(dut.result.value)
    if res != 16:
        dut._log.error(f"Test 3 Failed: Expected 16, Got {res}")
        raise TestFailure(f"Expected 16, got {res}")

    # Test 4: Two large segments separated by 1
    # [1,2,3,4,5, 1, 6,7,8,9,10, ...]
    # Left len 5. Right len 5 (from 6 to 10). Gap 5 and 6 is 1.
    # Max is 5+1 = 6.
    values = [1, 2, 3, 4, 5, 1, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    await load_data(values)
    await wait_for_done()
    res = int(dut.result.value)
    if res != 6:
        dut._log.error(f"Test 4 Failed: Expected 6, Got {res}")
        raise TestFailure(f"Expected 6, got {res}")

    # Test 5: All 1s (non-increasing)
    # [1, 1, 1, 1, 1, ...]
    # Max strictly increasing len is 1. +1 = 2.
    values = [1]*16
    await load_data(values)
    await wait_for_done()
    res = int(dut.result.value)
    if res != 2:
        dut._log.error(f"Test 5 Failed: Expected 2, Got {res}")
        raise TestFailure(f"Expected 2, got {res}")
        
    dut._log.info("All tests passed!")
