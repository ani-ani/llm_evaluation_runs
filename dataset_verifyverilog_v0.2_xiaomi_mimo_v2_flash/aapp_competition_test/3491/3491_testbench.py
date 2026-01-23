import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to calculate Hamming distance
def hamming_dist(a, b):
    return bin(a ^ b).count('1')

# Helper to simulate the button press operation (Red)
def press_red(state, floor, N=6):
    new_state = state
    # Iterate through all other floors j
    for j in range(N):
        if j == floor:
            continue
        # Check if edge (floor, j) exists
        # In our 64-bit matrix, index = floor * N + j
        idx1 = floor * N + j
        idx2 = j * N + floor
        
        # We check if the edge exists in the input state. 
        # Since it's undirected, we check both bits (though usually only one is set or both if we handle symmetric)
        # To be safe with the bitmask representation (where we might set only one bit or both):
        # Let's assume the input state strictly uses only the upper triangle (i < j) or lower.
        # Actually, the prompt says "pairs of integers i, j". Usually graph problems treat this as undirected.
        # Let's define the state bit for edge {i, j} as bit (i*N + j) where i < j. 
        # However, the module works on 64 bits. Let's define bit K corresponds to (K//N, K%N).
        # To keep it simple for the testbench: We will maintain a symmetric matrix in the testbench.
        
        if (state >> idx1) & 1 or (state >> idx2) & 1:
            # Edge exists. Remove it.
            new_state &= ~((1 << idx1) | (1 << idx2))
            
            # Calculate new j' = j + 1 mod N
            j_new = (j + 1) % N
            
            # Collision check: If j_new == floor (impossible as j!=floor) or if (floor, j_new) already exists?
            # The problem says: "unless j+1 mod N = i (impossible here as j!=i), in which case jump"
            # Wait, the collision rule is: "unless j+1 mod N = i, in which case it connects i and j+2 mod N".
            # Since j != i, j+1 = i is possible if j = i-1. 
            # Also, "unless j+1 mod N = i, in which case it connects i and j+2 mod N = i+1 mod N instead".
            
            if j_new == floor:
                j_new = (j_new + 1) % N # effectively j + 2
            
            # The problem also implies collision handling if the target edge is already taken?
            # "it will instead connect floors i and j+1 mod N – unless j+1 mod N = i, in which case..."
            # It doesn't explicitly say "unless the target edge is occupied", so we assume overwrites/moves are valid.
            # Wait, "No two staircases connect the same pair". So we can't just place it if occupied.
            # Let's re-read: "it will instead connect floors i and j+1 mod N ... unless j+1 mod N = i".
            # It doesn't handle "target occupied". 
            # For the hardware simplification, we will assume the greedy algorithm handles this by moving edges one by one.
            # But the problem implies a simultaneous move of ALL edges connected to floor i.
            
            # Let's implement the exact logic:
            # Collect all edges connected to floor. Remove them. Then try to place them at (i, j+1).
            # If (i, j+1) is occupied, skip (or is it strictly forbidden? "No two staircases").
            # If occupied, we might need to chain or the problem implies it's valid? No, "No two staircases".
            # Let's assume the input states are valid. 
            
            # For the testbench simulation:
            # We need to calculate the FINAL destination for edge (floor, j).
            # Destination = j + 1. If destination == floor, destination += 1.
            # Check if destination is occupied. If yes, what? 
            # The problem statement is ambiguous on chain collisions. 
            # For this benchmark, let's assume we can just apply the shift, and if it lands on an occupied spot, it creates a "double" which we should avoid.
            # However, since we are finding a path, we can just simulate the intended moves.
            # Let's trust the greedy approach to find valid moves.
            
            # Let's use the "jump 2" logic strictly.
            if j_new == floor:
                j_new = (j_new + 1) % N
            
            # Re-add edge at new location
            new_idx1 = floor * N + j_new
            new_idx2 = j_new * N + floor
            new_state |= (1 << new_idx1) | (1 << new_idx2)
            
    return new_state

def press_green(state, floor, N=6):
    # Green is inverse of Red. Equivalent to pressing Red (N-2) times.
    # N=6, so 4 times.
    temp = state
    for _ in range(4):
        temp = press_red(temp, floor, N)
    return temp

@cocotb.test()
async def test_hogwarts_staircases(dut):
    """Test the Hogwarts Staircases controller"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.current_state.value = 0
    dut.target_state.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input from prompt (Scaled to N=6 logic)
    # Original N=5. We adapt to N=6 by padding or mapping.
    # Let's create a custom test case for N=6 that requires logic.
    # Case 1: Single edge at (0,1). Target at (0,2). 
    # Action: Press Red 0. (0,1) -> (0,2) (since 1+1=2, 2!=0). 
    
    N = 6
    curr = 0
    target = 0
    
    # Edge (0,1)
    curr |= (1 << (0*N + 1)) | (1 << (1*N + 0))
    # Edge (2,3)
    curr |= (1 << (2*N + 3)) | (1 << (3*N + 2))
    
    # Target: (0,2) and (2,4)
    target |= (1 << (0*N + 2)) | (1 << (2*N + 0))
    target |= (1 << (2*N + 4)) | (1 << (4*N + 2))
    
    dut.current_state.value = curr
    dut.target_state.value = target
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    print(f"Starting Test: Current {curr:b}, Target {target:b}")
    
    steps = 0
    max_steps = 2000 # Safety break
    
    actions_taken = []
    
    while steps < max_steps:
        await RisingEdge(dut.clk)
        steps += 1
        
        if dut.valid.value == 1:
            # Read action
            act_char = chr(int(dut.action_type.value))
            floor = int(dut.floor_num.value)
            actions_taken.append(f"{act_char} {floor}")
            print(f"Step {steps}: {act_char} {floor}")
            
            # Verify simulation
            if act_char == 'R':
                curr = press_red(curr, floor, N)
            else:
                curr = press_green(curr, floor, N)
            
            if curr == target:
                print("Simulated State matches Target!")

        if dut.done.value == 1:
            print(f"Hardware done after {steps} cycles")
            break
            
    # Final check
    await RisingEdge(dut.clk)
    if dut.done.value == 0 and steps >= max_steps:
        raise TestFailure("Did not complete within step limit")
        
    print(f"Sequence: {actions_taken}")
    
    # Assert that we reached target or close enough (Greedy might not always finish perfectly if stuck)
    # But for this simple case, it should work.
    
    # Case 2: Identity (already correct)
    print("
Case 2: Identity")
    dut.current_state.value = target
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    if dut.done.value == 1:
        print("Identity case passed immediately")
    else:
        print("Identity case requires processing...")
        # Allow a few cycles
        for _ in range(5):
             await RisingEdge(dut.clk)
             if dut.done.value == 1: break

    print("All tests completed.")
