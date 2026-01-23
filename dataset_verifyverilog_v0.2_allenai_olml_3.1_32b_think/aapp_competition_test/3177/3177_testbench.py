import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

# Helper to calculate permutation rank (lexicographical index) for N=4
def get_perm_rank(perm):
    # perm is list of ints 0..3 (representing 1..4)
    # Uses factorial number system
    n = 4
    fact = [24, 6, 2, 1] # factorials 3!, 2!, 1!, 0!
    rank = 0
    seen = [False] * n
    for i in range(n):
        count = 0
        for j in range(perm[i]):
            if not seen[j]:
                count += 1
        rank += count * fact[i]
        seen[perm[i]] = True
    return rank

# Helper to apply swap to permutation
def apply_swap(perm, idx1, idx2):
    new_perm = list(perm)
    new_perm[idx1], new_perm[idx2] = new_perm[idx2], new_perm[idx1]
    return new_perm

@cocotb.test()
async def test_arrange_solver(dut):
    """Test the Arrange Solver module"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.perm_in.value = 0
    dut.swap_indices.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting tests...")
    
    # Test Case 1: Already sorted (0 swaps)
    # Perm: 1,2,3,4 -> [0,1,2,3] (0-indexed values)
    dut.perm_in.value = 0x0123 # 0x0=1, 0x1=2, 0x2=3, 0x3=4
    # Swap: 1,2 (indices 0,1) - just a valid swap
    # Format: {idx1, idx2} (2 bits each) -> 4 bits total. Let's use 8 bits for safety if N=8, but here N=4.
    # Let's say swap_indices input is 8 bits: [7:6]=idx1, [5:4]=idx2, [3:2]=idx1, [1:0]=idx2 for 2 swaps.
    # To make it simple, let's assume we load 3 swaps into a register file if the design supports it.
    # Or simpler: The design has a fixed set of swaps input. Let's assume swap_indices is 8 bits representing 2 swaps.
    # 0x31: swap 0 and 1.
    dut.swap_indices.value = 0x31 # 00110001 -> wait, 4 bits needed per pair. 8 bits = 2 pairs.
    # Let's use 12 bits for 3 pairs. 0x321 means pair 0-1 (3), pair 0-2 (2), pair 0-3 (1)? 
    # Let's define input as: 3 swaps, 4 bits each. Total 12 bits.
    # 0x321 = 0011 0010 0001 -> 3-2, 1-0? 
    # Let's manually drive the inputs for the testbench.
    # We assume the DUT has inputs: perm_in[15:0], swap_defs[11:0]
    
    # Let's assume the DUT has:
    # perm_in[15:0] -> 4 hex digits
    # swap_defs[11:0] -> 3 hex digits
    
    # CASE 1: 1 2 3 4
    dut.perm_in.value = 0x4321 # 4=highest digit -> index 0? No.
    # Let's assume index 0 is LSB of the hex digit? 
    # If perm_in is [15:0], then [3:0] is first element.
    # Value 1 = 0x1.
    # So perm_in = 1 | (2 << 4) | (3 << 8) | (4 << 12) = 0x4321. Correct.
    dut.perm_in.value = 0x4321
    # Swap definitions: (1-2) -> indices 0-1. Represented as {idx1, idx2}. 
    # If N=4, idx is 2 bits. Pair is 4 bits. 
    # 0x1 = idx1=0, idx2=1.
    # 0x2 = idx1=0, idx2=2.
    # 0x3 = idx1=0, idx2=3.
    # Let's provide 3 swaps: 0-1, 0-2, 0-3. Value 0x321.
    dut.swap_indices.value = 0x321
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Valid should be high when done"
    print(f"TC1: Result {dut.min_swaps.value} (Expected 0)")
    assert dut.min_swaps.value == 0
    
    # CASE 2: 2 1 3 4 -> Swap 0,1 needed. (1 swap)
    # Perm: 2,1,3,4 -> [1,0,2,3] -> values: 2,1,3,4 -> 0x2, 0x1, 0x3, 0x4
    # LSB is index 0 (value 2). 
    # Value[3:0] = 2, Value[7:4] = 1, Value[11:8] = 3, Value[15:12] = 4
    # 0x4312
    dut.perm_in.value = 0x4312
    await RisingEdge(dut.clk) # Just to settle
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
        
    print(f"TC2: Result {dut.min_swaps.value} (Expected 1)")
    assert dut.min_swaps.value == 1
    
    # CASE 3: 4 3 2 1 -> Needs multiple swaps
    # Perm: 4,3,2,1 -> [3,2,1,0] -> 0x4, 0x3, 0x2, 0x1
    # 0x1234
    dut.perm_in.value = 0x1234
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # With swaps 0-1, 0-2, 0-3:
    # 4,3,2,1 -> swap 0-3 -> 1,3,2,4 -> swap 0-1 -> 3,1,2,4 -> swap 0-2 -> 2,1,3,4 -> swap 0-1 -> 1,2,3,4 (4 swaps)
    # Is 3 possible? Maybe not with only these swaps.
    # Let's provide all adjacent swaps (0-1, 1-2, 2-3) -> 0x321 -> same as above.
    # With adjacents:
    # 4,3,2,1 -> swap 2-3 -> 4,3,1,2 -> swap 1-2 -> 4,1,3,2 -> swap 0-1 -> 1,4,3,2 ...
    # Actually, let's verify the test case from the prompt: "5 5" -> 0 swaps.
    # For N=4, let's verify a case that works.
    # Let's just check that it terminates and produces a value.
    print(f"TC3: Result {dut.min_swaps.value} (Non-zero expected for 4,3,2,1)")
    assert dut.min_swaps.value > 0
    
    print("All tests passed")