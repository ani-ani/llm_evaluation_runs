import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def generate_small_test_case(n, k, specific_adj=None, specific_s=None):
    # Generates inputs for n<=8
    # adj matrix as list of lists
    # s as list of indices
    if specific_adj:
        adj = specific_adj
    else:
        # Generate random DAG to ensure at least one solution exists, then maybe add cycles
        adj = [[0]*n for _ in range(n)]
        # Create a random topological order
        order = list(range(n))
        random.shuffle(order)
        # Add edges from earlier in order to later
        for i in range(n):
            for j in range(i+1, n):
                # Direction: order[i] beats order[j] with some probability
                if random.random() > 0.3:
                    adj[order[i]][order[j]] = 1
    
    if specific_s:
        s = specific_s
    else:
        # Pick random S
        s = random.sample(range(n), k)
        
    # Create bitmask for S
    s_mask = 0
    for p in s:
        s_mask |= (1 << p)
        
    # Format inputs for Verilog
    # adj_matrix needs to be flattened or indexed. Verilog expects [7:0] adj_matrix [0:7][0:7]
    # We will pass it as a flattened list or handle in testbench logic
    
    return adj, s, s_mask

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(5, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_fair_ranking_basic(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test Case 1: Small graph, 1 solution
    # 4 players. S = {0, 2}. 
    # Adj matrix from sample input 1:
    # 0 beats 2, 3
    # 1 beats 0, 3
    # 2 beats 1
    # 3 beats 2
    # Cycle: 0->2->1->0 (and others). 
    # If we remove player 0, remaining: 1, 2, 3. 
    # 1 beats 3, 2 beats 1, 3 beats 2. Cycle 1->3->2->1. Fail.
    # If we remove player 2, remaining: 0, 1, 3.
    # 0 beats 3, 1 beats 0, 1 beats 3. DAG. Valid.
    # So S' = {2}. But wait, 2 is in S! We cannot pick players in S.
    # S = {0, 2}. S' must be disjoint from S.
    # Candidates: {1}, {3}, {1,3}.
    # Remove 1: remaining {0, 2, 3}. 0->2, 0->3, 2->1(removed), 3->2. Cycle 0->2->... wait 2->1 is gone. 0->2, 0->3, 3->2. 
    # 0 beats 2. 3 beats 2. 0 beats 3. No 2->? 2 doesn't beat 0 or 3. So DAG? Yes. 
    # Wait, original sample output is 1. 
    # Sample 1 input: S = {0, 2}. Output 1.
    # Let's re-verify Sample 1.
    # Adj: 0->2,3; 1->0,3; 2->1; 3->2.
    # S = {0,2}. Remaining = {1,3}. 
    # Edges: 1->3. No cycle. Size 0? But S is {0,2} (size 2). We need S' size < 2. 
    # If we remove nothing (S' size 0), remaining {1,3} is acyclic. But wait, the condition is: S' is the set we remove. 
    # We start with ALL players. We remove S'. Resulting set must be acyclic.
    # If S' = {}, remaining {0,1,2,3}. Has cycle 0->2->1->0.
    # If S' = {1}, remaining {0,2,3}. Edges: 0->2, 0->3, 3->2. Acyclic. Size 1.
    # If S' = {3}, remaining {0,1,2}. Edges: 0->2, 1->0, 2->1. Cycle 0->2->1->0.
    # So answer is 1.
    
    dut.n.value = 4
    dut.k.value = 2
    
    # Adj matrix
    adj = [
        [0, 0, 1, 1],
        [1, 0, 0, 1],
        [0, 1, 0, 0],
        [0, 0, 1, 0]
    ]
    
    # Load adj matrix
    for i in range(8):
        for j in range(8):
            if i < 4 and j < 4:
                dut.adj_matrix[i][j].value = adj[i][j]
            else:
                dut.adj_matrix[i][j].value = 0
                
    # S = {0, 2} -> bitmask 0b0101 = 5
    dut.s_mask.value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done or impossible
    found = False
    impossible = False
    timeout = 0
    
    while timeout < 2000: # Safety timeout
        await RisingEdge(dut.clk)
        if dut.found.value == 1:
            found = True
            size = dut.min_disqualify_size.value
            dut._log.info(f"Found solution with size {size}")
            assert size == 1, f"Expected size 1, got {size}"
            break
        if dut.impossible.value == 1:
            impossible = True
            dut._log.info("Resulted in impossible")
            break
        timeout += 1
        
    assert found, "Did not find a solution"

@cocotb.test()
async def test_fair_ranking_impossible(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Sample 2: S = {1, 2}
    # Adj same as above.
    # S = {1, 2} -> mask 0b0110 = 6.
    # Candidates for S' size < 2: {}, {0}, {3}.
    # {}: {0,1,2,3} -> Cycle (0->2->1->0). No.
    # {0}: {1,2,3}. Edges: 1->3, 2->1, 3->2. Cycle 1->3->2->1. No.
    # {3}: {0,1,2}. Edges: 0->2, 1->0, 2->1. Cycle 0->2->1->0. No.
    # So no solution. Output impossible.
    
    dut.n.value = 4
    dut.k.value = 2
    
    adj = [
        [0, 0, 1, 1],
        [1, 0, 0, 1],
        [0, 1, 0, 0],
        [0, 0, 1, 0]
    ]
    
    for i in range(8):
        for j in range(8):
            if i < 4 and j < 4:
                dut.adj_matrix[i][j].value = adj[i][j]
            else:
                dut.adj_matrix[i][j].value = 0
                
    # S = {1, 2}
    dut.s_mask.value = 0b0110
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while timeout < 2000:
        await RisingEdge(dut.clk)
        if dut.impossible.value == 1:
            dut._log.info("Confirmed impossible as expected")
            return
        if dut.found.value == 1:
            raise TestFailure(f"Found unexpected solution size {dut.min_disqualify_size.value}")
        timeout += 1
    
    raise TestFailure("Did not finish in time")
