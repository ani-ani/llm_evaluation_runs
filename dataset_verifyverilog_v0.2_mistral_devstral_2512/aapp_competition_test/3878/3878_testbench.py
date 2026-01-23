import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_graph_optimizer(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(16):
        setattr(dut, f'adj_matrix_{i}', 0)
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Example 1 - n=5, expected 2 steps
    # Graph: 1-2, 1-3, 2-3, 2-5, 3-4, 4-5 (0-indexed: 0-1, 0-2, 1-2, 1-4, 2-3, 3-4)
    dut.n.value = 5
    # Adjacency matrix (complement edges need covering)
    adj = [[0]*16 for _ in range(16)]
    edges = [(0,1),(0,2),(1,2),(1,4),(2,3),(3,4)]
    for u,v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    for i in range(5):
        mask = 0
        for j in range(5):
            if adj[i][j]:
                mask |= (1 << j)
        setattr(dut, f'adj_matrix_{i}', mask)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 2000 cycles for n=5)
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not complete within timeout")
    
    if dut.result_steps.value != 2:
        raise TestFailure(f"Test 1: Expected steps=2, got {dut.result_steps.value}")
    print(f"Test 1 passed: steps={dut.result_steps.value}, mask={dut.result_mask.value:05b}")
    
    # Test Case 2: Example 2 - n=4, expected 1 step
    await Timer(100, units='ns')
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 4
    # Graph: 1-2, 1-3, 1-4, 3-4 (0-indexed: 0-1, 0-2, 0-3, 2-3)
    adj = [[0]*16 for _ in range(16)]
    edges = [(0,1),(0,2),(0,3),(2,3)]
    for u,v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    for i in range(4):
        mask = 0
        for j in range(4):
            if adj[i][j]:
                mask |= (1 << j)
        setattr(dut, f'adj_matrix_{i}', mask)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Did not complete")
    if dut.result_steps.value != 1:
        raise TestFailure(f"Test 2: Expected steps=1, got {dut.result_steps.value}")
    print(f"Test 2 passed: steps={dut.result_steps.value}")
    
    # Test Case 3: n=3, chain 1-3, 2-3 (0-2, 1-2), expected 1 step
    await Timer(100, units='ns')
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 3
    adj = [[0]*16 for _ in range(16)]
    edges = [(0,2),(1,2)]
    for u,v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    for i in range(3):
        mask = 0
        for j in range(3):
            if adj[i][j]:
                mask |= (1 << j)
        setattr(dut, f'adj_matrix_{i}', mask)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Did not complete")
    if dut.result_steps.value != 1:
        raise TestFailure(f"Test 3: Expected steps=1, got {dut.result_steps.value}")
    print(f"Test 3 passed: steps={dut.result_steps.value}")
    
    # Test Case 4: n=2, single edge, expected 0 steps
    await Timer(100, units='ns')
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 2
    adj = [[0]*16 for _ in range(16)]
    edges = [(0,1)]
    for u,v in edges:
        adj[u][v] = 1
        adj[v][u] = 1
    for i in range(2):
        mask = 0
        for j in range(2):
            if adj[i][j]:
                mask |= (1 << j)
        setattr(dut, f'adj_matrix_{i}', mask)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Did not complete")
    if dut.result_steps.value != 0:
        raise TestFailure(f"Test 4: Expected steps=0, got {dut.result_steps.value}")
    print(f"Test 4 passed: steps={dut.result_steps.value}")
    
    # Test Case 5: n=5, complete graph minus one edge, expected 1 step
    await Timer(100, units='ns')
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    adj = [[1]*16 for _ in range(16)]
    for i in range(5):
        adj[i][i] = 0
    # Remove edge 0-4
    adj[0][4] = 0
    adj[4][0] = 0
    for i in range(5):
        mask = 0
        for j in range(5):
            if adj[i][j]:
                mask |= (1 << j)
        setattr(dut, f'adj_matrix_{i}', mask)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: Did not complete")
    if dut.result_steps.value != 1:
        raise TestFailure(f"Test 5: Expected steps=1, got {dut.result_steps.value}")
    print(f"Test 5 passed: steps={dut.result_steps.value}")
    
    print("All tests passed!")