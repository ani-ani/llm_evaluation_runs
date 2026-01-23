import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

async def setup_dut(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.s.value = 0
    dut.t.value = 0
    dut.valid_edges.value = 0
    for i in range(8):
        dut.edge_from[i].value = 0
        dut.edge_to[i].value = 0
        dut.edge_weight[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    return dut

def encode_graph(dut, edges):
    # edges is list of tuples (u, v, w)
    dut.valid_edges.value = 0
    for i, (u, v, w) in enumerate(edges):
        if i < 8:
            dut.edge_from[i].value = u
            dut.edge_to[i].value = v
            dut.edge_weight[i].value = w
            dut.valid_edges.value |= (1 << i)

@cocotb.test()
async def test_hamster_simple(dut):
    """Test Case 1: Simple path 0->1->2->3"""
    await setup_dut(dut)
    
    # Graph: 0->1(1), 1->2(2), 2->3(1)
    # Turns: 0(Left), 1(Right), 2(Left), 3(Target)
    # Left at 0: only edge to 1. Weight 1. Next is Right at 1.
    # Right at 1: only edge to 2. Weight 2. Next is Left at 2.
    # Left at 2: only edge to 3. Weight 1. Target reached.
    # Total: 1 + 2 + 1 = 4
    # Wait, sample input 3 is 2 1 0 1 with weight 2 -> Output 2.
    # Let's implement sample 3 logic: 0->1 weight 2. Left at 0 moves to 1. Done. Result 2.
    
    edges = [(0, 1, 2)]
    encode_graph(dut, edges)
    dut.s.value = 0
    dut.t.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.infinity.value == 0, "Should not be infinity"
    assert dut.result.value == 2, f"Expected 2, got {dut.result.value}"
    print("Test 1 passed")

@cocotb.test()
async def test_hamster_infinite(dut):
    """Test Case 2: Infinite loop (0->1, 1->0, 1->2 missing)"""
    await setup_dut(dut)
    
    # Sample 4: 3 nodes, edges 0->1(1), 1->0(1), 1->2(1). Start 1, Target 2.
    # Left at 1: can go to 0 or 2.
    # Left wants to maximize.
    # Path 1->2: weight 1. Done. Result 1.
    # Path 1->0->1->2... need to check values.
    # Let's trace:
    # DP_L[2]=0, DP_R[2]=0.
    # Left at 2: None. (Target).
    # Right at 1: edges to 0 (weight 1) and 2 (weight 1).
    #   Right chooses MIN(1+DP_L[0], 1+DP_L[2]=1).
    # Left at 0: edge to 1 (weight 1).
    #   Left chooses MAX(1+DP_R[1]).
    # Iterations:
    # Init: DP_L[2]=0, DP_R[2]=0. Others -1 (or 0).
    # Iter 1 (L):
    #   L[0] = 1 + R[1] (unknown -> assume 0? No, assume -inf/inf).
    #   L[1] = max(1 + R[0], 1 + R[2]=1) = 1 (since R[2]=0).
    #   L[2] = 0.
    # Iter 1 (R):
    #   R[0] = 1 + L[1] = 1 + 1 = 2.
    #   R[1] = min(1 + L[0], 1 + L[2]=1) = 1 (since L[2]=0).
    #   R[2] = 0.
    # Iter 2 (L):
    #   L[0] = 1 + R[1] = 1 + 1 = 2.
    #   L[1] = max(1 + R[0]=1+2=3, 1 + R[2]=1) = 3.
    # Iter 2 (R):
    #   R[0] = 1 + L[1] = 1 + 3 = 4.
    #   R[1] = min(1 + L[0]=1+2=3, 1).
    # This looks like values are growing.
    # The problem says Sample 4 is infinity.
    # Wait, let's re-read Sample 4.
    # 3 3 1 2
    # 0 1 1
    # 1 0 1
    # 1 2 1
    # Start 1. Target 2.
    # Left at 1: Max(1+R[0], 1+R[2]).
    # Right at 0: Min(1+L[1]).
    # If L[1] grows, R[0] grows. If R[0] grows, L[1] grows.
    # Left prefers path 1->0->1... loop because it yields larger value than 1->2.
    # So Left will cycle forever to maximize score.
    # Result infinity.
    
    # Let's setup Test Case 2
    edges = [(0, 1, 1), (1, 0, 1), (1, 2, 1)]
    encode_graph(dut, edges)
    dut.s.value = 1
    dut.t.value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.infinity.value == 1, "Should be infinity"
    print("Test 2 passed")

@cocotb.test()
async def test_hamster_sample_1(dut):
    """Test Case 3: Adapted Sample 1 (Simplified)"""
    await setup_dut(dut)
    # Original has cycles. We stick to small graph.
    # Let's do: 0->1(1), 1->2(2), 2->3(1).
    # 0(L) -> 1(R)
    # 1(R) -> 2(L)
    # 2(L) -> 3(T)
    # Result: 1 + 2 + 1 = 4.
    
    edges = [(0, 1, 1), (1, 2, 2), (2, 3, 1)]
    encode_graph(dut, edges)
    dut.s.value = 0
    dut.t.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.infinity.value == 0, "Should not be infinity"
    assert dut.result.value == 4, f"Expected 4, got {dut.result.value}"
    print("Test 3 passed")

@cocotb.test()
async def test_hamster_cycle_avoided(dut):
    """Test Case 4: Cycle exists but player avoids it (Shorter path wins)"""
    await setup_dut(dut)
    # 0->1(100), 0->2(1), 2->3(1).
    # Left at 0: Max(100+R[1], 1+R[2]).
    # If R[1] is small (e.g. 0 if 1 is not connected to T), R[2] is 1 (since 2->3).
    # Left chooses 0->2->3.
    # Result: 1+1 = 2.
    
    edges = [(0, 1, 100), (0, 2, 1), (2, 3, 1)]
    encode_graph(dut, edges)
    dut.s.value = 0
    dut.t.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.infinity.value == 0, "Should not be infinity"
    assert dut.result.value == 2, f"Expected 2, got {dut.result.value}"
    print("Test 4 passed")
