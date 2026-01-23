import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to calculate gcd
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def gcd_list(lst):
    if not lst: return 0
    res = lst[0]
    for i in range(1, len(lst)):
        res = gcd(res, lst[i])
    return res

def is_reachable(dr, dc, owned_moves):
    # Simplified reachability check based on GCD logic
    if dr == 0 and dc == 0:
        return True
    if not owned_moves:
        return False
    
    # Collect all a and b values
    vals = []
    for (a, b) in owned_moves:
        vals.append(abs(a))
        vals.append(abs(b))
    
    g = gcd_list(vals)
    if g == 0:
        return False
        
    return (dr % g == 0) and (dc % g == 0)

def get_permutation(idx):
    # Generate permutation of [1, 2, 3] based on index 0..23
    items = [1, 2, 3]
    if idx < 0 or idx >= 6:
        # Wait, 3 items have 6 permutations
        # 4 items have 24 permutations.
        # But we always start at 0.
        # So we permute [1, 2, 3].
        pass
    
    # Implementation of permutation generation
    # Factorial 3 = 6
    # Factorial 4 = 24 (if we included 0, but 0 is fixed start)
    # So only 6 permutations for 3 remaining cards.
    # Wait, the prompt says 24 permutations. 
    # Ah, the prompt implies we might permute all 4 cards if we consider start point selection? 
    # "Iteration through permutations of card purchase orders (up to 4! = 24 permutations)."
    # "Card 0 is start". 
    # If Card 0 is fixed start, then we permute 1,2,3 -> 6 permutations.
    # However, the prompt implies 24. Maybe we assume we can visit a subset.
    # Let's assume we permute [1, 2, 3] (6 orders) and try skipping cards.
    # Actually, let's stick to 6 permutations of 1,2,3 for simplicity in the testbench.
    # But the prompt says "24 permutations". 
    # Maybe it considers the set {0, 1, 2, 3} minus the start? No.
    # Let's assume the hardware tries all 6 orderings of 1, 2, 3.
    # To match the prompt's '24' hint, maybe the hardware iterates 0..23 and uses a logic to select 3 items from 4? No.
    # Let's stick to 6 permutations for the testbench to verify the logic.
    # But wait, if the prompt wants 24, the testbench should support 24.
    # Actually, 3 items have 6 permutations. 4 items (1,2,3) has 6 permutations.
    # The prompt might be slightly over-specified on the number 24. 
    # Let's assume the hardware iterates index 0 to 5.
    # Wait, if we permute 1,2,3 -> 6 permutations.
    # Let's look at the prompt again: "Iterate through permutations of {1,2,3}".
    # Okay, 6 permutations.
    # "Update Costs" says "Iterate through permutations of card purchase orders (up to 4! = 24 permutations)".
    # This is likely a copy-paste error in the prompt generation. 3 items is 6.
    # However, to be safe, let's assume the prompt wants us to handle the case where we might permute 1, 2, 3.
    # I will implement the testbench for 6 permutations. If the prompt insists on 24, I will adjust.
    # But the logic of permuting 3 items is 6. 
    # Let's assume the hardware index runs 0 to 5.
    
    # Standard permutation generation
    base = [1, 2, 3]
    if idx == 0: return [1, 2, 3]
    if idx == 1: return [1, 3, 2]
    if idx == 2: return [2, 1, 3]
    if idx == 3: return [2, 3, 1]
    if idx == 4: return [3, 1, 2]
    if idx == 5: return [3, 2, 1]
    return []

@cocotb.test()
async def test_tarot_knight(dut):
    # Initialize Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(4):
        dut.card_r[i].value = 0
        dut.card_c[i].value = 0
        dut.card_a[i].value = 0
        dut.card_b[i].value = 0
        dut.card_p[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test Case 1 ---
    # Input:
    # 2
    # 3 3 2 2 100
    # 1 1 1 1 500
    # We have 2 cards. Hardware expects 4 inputs. We pad.
    # Card 0 (Start): r=3, c=3, a=2, b=2, p=100
    # Card 1: r=1, c=1, a=1, b=1, p=500
    # Card 2, 3: dummy (unreachable or self-loop)
    
    dut.card_r[0].value = 3
    dut.card_c[0].value = 3
    dut.card_a[0].value = 2
    dut.card_b[0].value = 2
    dut.card_p[0].value = 100

    dut.card_r[1].value = 1
    dut.card_c[1].value = 1
    dut.card_a[1].value = 1
    dut.card_b[1].value = 1
    dut.card_p[1].value = 500

    # Dummy cards (set to unreachable positions, e.g., far away)
    dut.card_r[2].value = 127
    dut.card_c[2].value = 127
    dut.card_a[2].value = 1
    dut.card_b[2].value = 1
    dut.card_p[2].value = 999 # High cost
    
    dut.card_r[3].value = -128
    dut.card_c[3].value = -128
    dut.card_a[3].value = 1
    dut.card_b[3].value = 1
    dut.card_p[3].value = 999

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    # Logic: 6 permutations, each takes some cycles. 
    # Let's wait a safe amount.
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not finish in time")
    
    # Expected logic:
    # Start (3,3) with (2,2).
    # To (0,0): Dr=-3, Dc=-3. 
    # GCD of owned {2,2} is 2. 
    # -3 % 2 != 0. So cannot go directly to (0,0).
    # Check card 1 (1,1).
    # Dr = 1-3 = -2. Dc = 1-3 = -2. 
    # GCD(2,2)=2. -2%2=0. Reachable.
    # Buy card 1 (cost 500). Total 600.
    # Owned: (2,2), (1,1).
    # GCD of {1,1,2,2} is 1.
    # From (1,1) to (0,0): Dr=-1, Dc=-1. 
    # 1 divides everything. Reachable.
    # Total Cost 600.
    
    print(f"Test 1 Result: {int(dut.min_cost.value)}")
    if int(dut.min_cost.value) != 600:
        raise TestFailure(f"Expected 600, got {int(dut.min_cost.value)}")

    # --- Test Case 2 ---
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Input:
    # 2
    # 2 0 2 1 100
    # 6 0 8 1 1
    # Card 0: r=2, c=0, a=2, b=1, p=100
    # Card 1: r=6, c=0, a=8, b=1, p=1
    # Goal (0,0).

    dut.card_r[0].value = 2
    dut.card_c[0].value = 0
    dut.card_a[0].value = 2
    dut.card_b[0].value = 1
    dut.card_p[0].value = 100

    dut.card_r[1].value = 6
    dut.card_c[1].value = 0
    dut.card_a[1].value = 8
    dut.card_b[1].value = 1
    dut.card_p[1].value = 1
    
    # Dummies
    dut.card_r[2].value = 127
    dut.card_c[2].value = 127
    dut.card_a[2].value = 1
    dut.card_b[2].value = 1
    dut.card_p[2].value = 999
    
    dut.card_r[3].value = 127
    dut.card_c[3].value = 127
    dut.card_a[3].value = 1
    dut.card_b[3].value = 1
    dut.card_p[3].value = 999

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    print(f"Test 2 Result: {int(dut.min_cost.value)}")
    # Logic:
    # Start (2,0) with (2,1). 
    # To (0,0): Dr=-2, Dc=0.
    # Moves (2,1) -> Lattice generated includes (2,1) and (1,2). 
    # GCD of {2,1} is 1. 
    # So (-2,0) is reachable (since 1 divides everything).
    # Cost = 100.
    
    if int(dut.min_cost.value) != 100:
        raise TestFailure(f"Expected 100, got {int(dut.min_cost.value)}")

    # --- Test Case 3 ---
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Input:
    # 3
    # 1 0 100 50 100
    # 1 50 50 25 100
    # 26 0 20 30 123
    # Card 0: (1,0), (100,50), p=100
    # Card 1: (1,50), (50,25), p=100
    # Card 2: (26,0), (20,30), p=123
    # Goal: (0,0)

    dut.card_r[0].value = 1
    dut.card_c[0].value = 0
    dut.card_a[0].value = 100
    dut.card_b[0].value = 50
    dut.card_p[0].value = 100

    dut.card_r[1].value = 1
    dut.card_c[1].value = 50
    dut.card_a[1].value = 50
    dut.card_b[1].value = 25
    dut.card_p[1].value = 100

    dut.card_r[2].value = 26
    dut.card_c[2].value = 0
    dut.card_a[2].value = 20
    dut.card_b[2].value = 30
    dut.card_p[2].value = 123

    # Dummy
    dut.card_r[3].value = 127
    dut.card_c[3].value = 127
    dut.card_a[3].value = 1
    dut.card_b[3].value = 1
    dut.card_p[3].value = 999

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    print(f"Test 3 Result: {int(dut.min_cost.value)}")
    # Logic:
    # Start (1,0) with (100,50). GCD=50.
    # To (0,0): Dr=-1, Dc=0. Not divisible by 50. Cannot go directly.
    # Try path 0->1->2->0:
    #   0->1: (1,50)-(1,0) = (0,50). GCD(50)=50. 50%50=0. Reachable. Cost 100.
    #   Now at (1,50), moves (100,50), (50,25). GCD of 100,50,50,25 = 25.
    #   1->2: (26,0)-(1,50) = (25,-50). 25%25=0, -50%25=0. Reachable. Cost 123. Total 223.
    #   Now at (26,0). Moves: (20,30) added. GCD of all = 5 (GCD of 100,50,20,30 = 5).
    #   2->0: (0,0)-(26,0) = (-26,0). -26%5 != 0. Not reachable.
    # Try path 0->2->...:
    #   0->2: (26,0)-(1,0) = (25,0). GCD(100,50)=50. 25%50 != 0. Not reachable.
    # Try path 0->1->... then try to go to 0 directly:
    #   0->1->0: 0->1 (reachable), then 1->0: (1,0)-(1,50) = (0,-50). Reachable. Cost 100.
    #   So we are back at start with card 1. Total cost 100. 
    #   From (1,0) with cards 0 and 1. Moves GCD=25.
    #   To (0,0): (-1,0). -1%25 != 0.
    # Try path 0->1->2->... then nowhere.
    # Wait, maybe I missed a path. 
    # Let's re-evaluate Test 3 expected output -1.
    # The sample output says -1.
    # So my logic should produce -1 (0xFFFF).
    
    if int(dut.min_cost.value) != 0xFFFF:
        raise TestFailure(f"Expected -1 (0xFFFF), got {int(dut.min_cost.value)}")

    print("All tests passed!")
