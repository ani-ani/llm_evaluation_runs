import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_producer_routing(dut):
    """Test the producer routing optimizer"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.edges_valid.value = 0
    dut.edges_done.value = 0
    dut.K.value = 0
    dut.N.value = 0
    dut.M.value = 0
    dut.edge_a.value = 0
    dut.edge_b.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: N=4, K=2, M=3, edges: (1,3), (2,3), (3,4) -> Output: 2
    # Paths: P1: 1->3->4 (len=2), P2: 2->3->4 (len=2)
    # Shared edge (3,4): P1 dist to edge=1, P2 dist to edge=1. Diff=0 (even) -> collision? 
    # Wait, product from P1 at t=1 arrives at (3,4) at t=2. P2 at t=2 arrives at (3,4) at t=3.
    # P1 uses (3,4) at even minutes. P2 uses at odd minutes. Compatible.
    # Dist to shared edge: P1 dist=1, P2 dist=1. 
    # Time offset = (dist2 - dist1) = 0. Even. But production times differ.
    # P1 item 0 produced t=1. Arrives edge t=2 (even).
    # P2 item 0 produced t=2. Arrives edge t=3 (odd).
    # Collision check: 
    # P1 at edge at t = 1 + dist1 + x*K + j = 1 + 1 + 2x + 1 = 2x + 4 (Wait, formula is x*K + j)
    # P1 (j=1): t_gen = 2x + 1. Arrive edge = 2x + 1 + 1 = 2x + 2 (Even)
    # P2 (j=2): t_gen = 2x + 2. Arrive edge = 2x + 2 + 1 = 2x + 3 (Odd)
    # Compatible.
    
    dut.K.value = 2
    dut.N.value = 4
    dut.M.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed edges
    edges = [(1,3), (2,3), (3,4)]
    for a, b in edges:
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edges_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edges_valid.value = 0
    dut.edges_done.value = 1
    await RisingEdge(dut.clk)
    dut.edges_done.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    result = int(dut.max_producers.value)
    print(f"Test 1 Result: {result}")
    if result != 2:
        raise TestFailure(f"Test 1 Failed: Expected 2, got {result}")
    
    await RisingEdge(dut.clk)
    await Timer(100, units='ns')
    
    # Test case 2: N=5, K=2, M=4, edges: (1,3),(3,4),(2,4),(4,5) -> Output: 1
    # Paths: P1: 1->3->4->5 (len=3), P2: 2->4->5 (len=2)
    # Shared edge (4,5): P1 dist=2, P2 dist=1. Diff=1 (Odd).
    # P1 (j=1): t_gen = 2x+1. Arrive edge = 2x+1 + 2 = 2x+3 (Odd)
    # P2 (j=2): t_gen = 2x+2. Arrive edge = 2x+2 + 1 = 2x+3 (Odd)
    # Collision! (Both arrive at t=3, 7, 11...). Compatible = False.
    # So max producers = 1.
    
    dut.start.value = 1
    dut.K.value = 2
    dut.N.value = 5
    dut.M.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    edges = [(1,3), (3,4), (2,4), (4,5)]
    for a, b in edges:
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edges_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edges_valid.value = 0
    dut.edges_done.value = 1
    await RisingEdge(dut.clk)
    dut.edges_done.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    result = int(dut.max_producers.value)
    print(f"Test 2 Result: {result}")
    if result != 1:
        raise TestFailure(f"Test 2 Failed: Expected 1, got {result}")
    
    await RisingEdge(dut.clk)
    await Timer(100, units='ns')
    
    # Test case 3: N=5, K=2, M=6, edges: (1,4),(2,3),(3,4),(4,5),(2,4),(3,3) -> Output: 2
    # K=2, N=5. 
    # P1 (j=1) at junction 1. P2 (j=2) at junction 2.
    # Find paths to 5.
    # P1: 1->4->5 (len 2). P2: 2->4->5 (len 2). 
    # Shared edge (4,5). P1 dist=1, P2 dist=1. Diff 0 (Even).
    # P1: t_gen 2x+1, arrive edge 2x+1+1=2x+2 (Even).
    # P2: t_gen 2x+2, arrive edge 2x+2+1=2x+3 (Odd).
    # Wait, diff 0 means same offset from source? 
    # P1 dist to edge = 1. P2 dist to edge = 1. 
    # Arrival times: T1 = 1 + 1 + 2x = 2x+2. T2 = 2 + 1 + 2x = 2x+3.
    # Even vs Odd. Compatible.
    # So answer should be 2.
    
    dut.start.value = 1
    dut.K.value = 2
    dut.N.value = 5
    dut.M.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    edges = [(1,4), (2,3), (3,4), (4,5), (2,4), (3,3)]
    for a, b in edges:
        dut.edge_a.value = a
        dut.edge_b.value = b
        dut.edges_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.edges_valid.value = 0
    dut.edges_done.value = 1
    await RisingEdge(dut.clk)
    dut.edges_done.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    result = int(dut.max_producers.value)
    print(f"Test 3 Result: {result}")
    if result != 2:
        raise TestFailure(f"Test 3 Failed: Expected 2, got {result}")
    
    print("All tests passed!")
