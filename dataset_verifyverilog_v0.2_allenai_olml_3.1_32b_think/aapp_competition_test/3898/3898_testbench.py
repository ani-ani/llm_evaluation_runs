import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_puzzle_rearrangement(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper tasks
    async def run_test(n_val, a_val, b_val, expected):
        dut.n.value = n_val
        dut.a_in.value = a_val
        dut.b_in.value = b_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 20:
            raise TestFailure("Timeout waiting for done signal")
            
        if dut.result.value != expected:
            raise TestFailure(f"Test failed for n={n_val}, a={a_val}, b={b_val}. Expected {expected}, got {dut.result.value}")
        
        await RisingEdge(dut.clk) # Buffer between tests

    # Test Case 1: n=3, YES
    # Input: 1 0 2 -> 2 0 1
    # Non-zero seq A: [1, 2], B: [2, 1]. Bitmask A: 0b101 (bit 0=1, bit 2=1) -> Indices 0 and 2. 
    # Wait, bit 0 is island 1 (value 1). Bit 1 is island 2 (value 0). Bit 2 is island 3 (value 2).
    # A mask: 1, 0, 1 -> 101b = 5.
    # B: 2 0 1 -> Island 1=2, Island 2=0, Island 3=1.
    # Non-zero seq B: [2, 1]. But we use masks. 
    # B mask: Island 1 has statue, Island 3 has statue. So bits 0 and 2. Mask 101b = 5.
    # A = 5, B = 5. Rotation matches.
    await run_test(3, 0b101, 0b101, 1)

    # Test Case 2: n=2, YES
    # Input: 1 0 -> 0 1
    # A: Island 1 has statue. Mask 01b = 1.
    # B: Island 2 has statue. Mask 10b = 2.
    # Wait. 
    # Input arrays: a = [1, 0], b = [0, 1]
    # Indices: 0->val 1, 1->val 0. Mask A: 1 (bit 0 set).
    # Indices: 0->val 0, 1->val 1. Mask B: 2 (bit 1 set).
    # Non-zero sequences: A=[1], B=[1].
    # Rotating A (single bit) matches B (single bit). YES.
    # 0b01 rotated by 1 is 0b10. So A=1, B=2. Check: (1 >> 1) | (1 << (2-1)) = (0) | (1<<1) = 2. Matches B. YES.
    await run_test(2, 0b01, 0b10, 1)

    # Test Case 3: n=4, NO
    # Input: 1 2 3 0 -> 0 3 2 1
    # A: [1, 2, 3]. Mask: 0b111 = 7.
    # B: [3, 2, 1]. Mask: Island 1=0, 2=3, 3=2, 4=1 -> Bits 1,2,3 set. Mask 0b1110 = 14.
    # A=7, B=14. 
    # Rotations of 7 (0b0111):
    # Offset 0: 0111 (7)
    # Offset 1: 1110 (14) -> Matches B!
    # Wait, the answer is NO. 
    # Why? The Python solution removes 0s and checks sequence.
    # A non-zero: [1, 2, 3]
    # B non-zero: [3, 2, 1]
    # Are these rotations? 
    # A: 1-2-3. B: 3-2-1. 
    # B is the reverse of A, not a rotation.
    # Ah, wait. The mask approach might be too simple if the order of statues matters in the mask?
    # Wait. The mask represents *which* islands have statues. It does not encode *which* statue is there.
    # But the Python code removes 0s and checks equality of *values*.
    # However, the problem states statues are uniquely colored.
    # The mapping of statues to islands changes.
    # Let's look at the Python code again.
    # a = [1, 2, 3], b = [0, 3, 2, 1]
    # Remove 0: a=[1,2,3], b=[3,2,1]
    # a.index(b[0]) -> index of 3 in a is 2.
    # a[2:] + a[:2] -> [3] + [1,2] = [3,1,2].
    # Compare with b [3,2,1]. No match. NO.
    
    # So, we cannot just use masks. We need to track the relative order of statues.
    # BUT, we are limited to n <= 8 and inputs are integers up to n-1.
    # We can store the values in arrays in the testbench, but the DUT needs to verify.
    # However, the problem is purely about permutation reachability on a circle.
    # The answer is YES iff the sequence of non-zero statues in 'a' is a rotation of the sequence in 'b'.
    # 
    # How to verify this in hardware?
    # Inputs 'a_in' and 'b_in' in the prompt are defined as 'packed initial config'.
    # This was ambiguous. If I passed the mask, I lost the values.
    # I need to pass the values. 
    # But a Verilog module has fixed width inputs. 
    # With n=8 and values 0-7, I need 3 bits per element. 
    # 8 elements * 3 bits = 24 bits. Acceptable.
    # Let's redefine inputs in the prompt to be packed arrays of values, 3 bits each.
    # Input vector: {a[7], a[6], ..., a[0]} where a[i] is value at island i+1.
    # 0 represents empty.
    
    # Let's correct the module specification in the prompt to accept packed values.
    # Module needs to compare the cyclic shift of non-zero elements.
    # 
    # Logic for DUT:
    # 1. Extract non-zero sequences from A and B.
    #    - Store A and B values.
    # 2. Find start index of A (where first non-zero is). Let's say index 0 is always start for simplicity if we iterate.
    #    Actually, we need to check if B is a rotation of A.
    #    We can iterate offset 0 to n-1.
    #    For each offset k:
    #      Check if the sequence of non-zero elements in A rotated by k matches B's sequence.
    #      
    #    Wait, A and B are fixed on islands. Rotating the *islands* means shifting the values.
    #    But the empty island moves.
    #    The constraint is: we can only move statues into the empty spot.
    #    This implies that the sequence of statues (ignoring empty) must be the same, just rotated.
    
    #    Algorithm:
    #    Extract array A_nonzero (size m) and B_nonzero (size m).
    #    If m is 0, return YES.
    #    Check if B_nonzero is a rotation of A_nonzero.
    #    
    #    Since n <= 8, we can brute force.
    #    We need to extract the arrays. 
    #    This requires memory or unrolling.
    #    Let's use a sequential state machine that extracts A_nonzero and B_nonzero into small FIFOs (shift registers).
    
    #    Inputs:
    #    input [3:0][2:0] a_packed // n=4 max? No, param N.
    #    input [N-1:0][2:0] a_vals
    #    input [N-1:0][2:0] b_vals
    #    
    #    Let's update the Prompt Module spec to handle this properly.

    # Revised Prompt Logic (Internal to DUT):
    # Assume N=8 (max). 
    # Inputs: 
    # a_in: 24-bit vector {a7[2:0], ..., a0[2:0]}
    # b_in: 24-bit vector
    # n: 3-bit input (active length)
    
    # Steps:
    # 1. Unpack a_in and b_in into arrays (registers) of size N.
    # 2. Extract non-zero sequences into new arrays `seq_a` and `seq_b` (size <= N). 
    #    Since we are in hardware, we can store them in a shift register or just iterate.
    #    Let's store them in fixed size registers. Max 8 elements of 3 bits = 24 bits. 
    #    We can store seq_a and seq_b as packed vectors.
    #    But we don't know the length of seq_a ahead of time.
    #    We can use a counter.
    #    
    #    Let's use a state machine:
    #    State 0: Idle
    #    State 1: Extract A. Iterate index 0 to n-1. If val != 0, append to packed seq_a and increment counter_a.
    #    State 2: Extract B. Similar.
    #    State 3: Check if seq_a and seq_b are rotations of each other.
    #       If counters unequal, result=0.
    #       If equal 0, result=1.
    #       Else, iterate offset 0 to len-1. Check if shifting seq_a by offset matches seq_b.
    
    #    Since N=8 is small, this is feasible.
    
    #    Wait, the previous prompt asked for a_in/b_in as packed bitmasks. 
    #    I will assume the user wants a design that actually works for the problem.
    #    The problem requires checking the *order* of statues, not just their positions.
    #    So bitmask is insufficient.
    #    I will proceed with a design that takes packed values (3 bits per island).
    
    #    But the testbench needs to be consistent with the prompt.
    #    If I change the prompt, the "Prompt" field in JSON must be valid.
    #    Let's look at the Python solutions again. They look at values.
    #    `a = [1, 2, 3]` `b = [3, 2, 1]`
    #    They remove 0s.
    #    
    #    I will write the Verilog to take packed values and implement the extraction/comparison.

    #    Let's verify Test Case 3 again with the correct logic.
    #    A: [1,2,3] -> Extracted: [1,2,3].
    #    B: [0,3,2,1] -> Extracted: [3,2,1].
    #    Is [3,2,1] a rotation of [1,2,3]?
    #    No. So result should be 0.

    #    Let's run the simulation with the correct logic.
    #    For the testbench, I need to pack the values.
    #    Helper function to pack.

    print("Starting Test Run...")

    def pack_values(vals, n):
        packed = 0
        for i in range(n):
            packed |= (vals[i] << (3*i))
        return packed

    # Test 1: n=3, A=[1,0,2], B=[2,0,1]
    # Extracted A: [1,2]. Extracted B: [2,1].
    # Are they rotations? [1,2] rotated is [2,1]. YES.
    vals_a = [1, 0, 2]
    vals_b = [2, 0, 1]
    dut.n.value = 3
    dut.a_in.value = pack_values(vals_a, 3)
    dut.b_in.value = pack_values(vals_b, 3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 1:
        raise TestFailure(f"Case 1 failed. Expected 1, got {dut.result.value}")
    print("Case 1 Passed")

    # Test 2: n=2, A=[1,0], B=[0,1]
    # Extracted A: [1]. Extracted B: [1]. YES.
    vals_a = [1, 0]
    vals_b = [0, 1]
    dut.n.value = 2
    dut.a_in.value = pack_values(vals_a, 2)
    dut.b_in.value = pack_values(vals_b, 2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 1:
        raise TestFailure(f"Case 2 failed. Expected 1, got {dut.result.value}")
    print("Case 2 Passed")

    # Test 3: n=4, A=[1,2,3,0], B=[0,3,2,1]
    # Extracted A: [1,2,3]. Extracted B: [3,2,1]. NO.
    vals_a = [1, 2, 3, 0]
    vals_b = [0, 3, 2, 1]
    dut.n.value = 4
    dut.a_in.value = pack_values(vals_a, 4)
    dut.b_in.value = pack_values(vals_b, 4)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 0:
        raise TestFailure(f"Case 3 failed. Expected 0, got {dut.result.value}")
    print("Case 3 Passed")

    # Additional Test: A=[1,2,3,0], B=[3,1,2,0]
    # Extracted A: [1,2,3]. Extracted B: [3,1,2]. 
    # Rotation of A: [1,2,3] -> [2,3,1] -> [3,1,2]. YES.
    vals_a = [1, 2, 3, 0]
    vals_b = [3, 1, 2, 0]
    dut.n.value = 4
    dut.a_in.value = pack_values(vals_a, 4)
    dut.b_in.value = pack_values(vals_b, 4)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 1:
        raise TestFailure(f"Case 4 failed. Expected 1, got {dut.result.value}")
    print("Case 4 Passed")

    print(f"Tests Passed: 4/4")
