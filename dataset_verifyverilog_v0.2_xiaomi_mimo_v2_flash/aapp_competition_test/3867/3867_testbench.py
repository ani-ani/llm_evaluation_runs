import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_bfs_validator_basic(dut):
    """Test basic valid BFS sequence"""
    # Clock setup
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 0-1, 0-2, 1-3
    # Valid BFS: 0, 1, 2, 3
    adj_pairs = [(0,1), (0,2), (1,3)]
    sequence = [0, 1, 2, 3, 4, 5, 6, 7]
    
    # Load adjacency matrix
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            if (i,j) in adj_pairs or (j,i) in adj_pairs:
                dut.dut.adj_matrix[i][j].value = 1
            else:
                dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    # Load sequence
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    # Start verification
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 1, f"Expected valid=1 for basic test, got {dut.valid.value}"
    print("Basic valid test: PASSED")

@cocotb.test()
async def test_bfs_validator_invalid_order(dut):
    """Test invalid BFS sequence (wrong child order)"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 0-1, 0-2
    # Invalid BFS: 0, 1, 3, 2 (3 is not a child of 1)
    adj_pairs = [(0,1), (0,2)]
    sequence = [0, 1, 3, 2, 4, 5, 6, 7]
    
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            if (i,j) in adj_pairs or (j,i) in adj_pairs:
                dut.dut.adj_matrix[i][j].value = 1
            else:
                dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 0, f"Expected valid=0 for invalid test, got {dut.valid.value}"
    print("Invalid order test: PASSED")

@cocotb.test()
async def test_bfs_validator_tree_8nodes(dut):
    """Test 8-node tree with multiple branches"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 0-1, 0-5, 1-2, 1-3, 5-4, 5-6 (6 nodes, rest unused)
    # Valid BFS: 0, 1, 5, 2, 3, 4, 6, 7
    adj_pairs = [(0,1), (0,5), (1,2), (1,3), (5,4), (5,6)]
    sequence = [0, 1, 5, 2, 3, 4, 6, 7]
    
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            if (i,j) in adj_pairs or (j,i) in adj_pairs:
                dut.dut.adj_matrix[i][j].value = 1
            else:
                dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 1, f"Expected valid=1 for 8-node tree, got {dut.valid.value}"
    print("8-node tree test: PASSED")

@cocotb.test()
async def test_bfs_validator_non_root_start(dut):
    """Test sequence not starting with root"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 0-1, 0-2
    # Invalid BFS: 1, 0, 2 (doesn't start with root)
    adj_pairs = [(0,1), (0,2)]
    sequence = [1, 0, 2, 3, 4, 5, 6, 7]
    
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            if (i,j) in adj_pairs or (j,i) in adj_pairs:
                dut.dut.adj_matrix[i][j].value = 1
            else:
                dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 0, f"Expected valid=0 for non-root start, got {dut.valid.value}"
    print("Non-root start test: PASSED")

@cocotb.test()
async def test_bfs_validator_disconnected_tree(dut):
    """Test with disconnected component"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 0-1, 2-3 (disconnected from root)
    # Invalid BFS: 0, 1, 2, 3 (2 is not reachable from root)
    adj_pairs = [(0,1), (2,3)]
    sequence = [0, 1, 2, 3, 4, 5, 6, 7]
    
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            if (i,j) in adj_pairs or (j,i) in adj_pairs:
                dut.dut.adj_matrix[i][j].value = 1
            else:
                dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 0, f"Expected valid=0 for disconnected tree, got {dut.valid.value}"
    print("Disconnected tree test: PASSED")

@cocotb.test()
async def test_bfs_validator_single_node(dut):
    """Test single node tree"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single node: 0
    sequence = [0, 1, 2, 3, 4, 5, 6, 7]
    
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 1, f"Expected valid=1 for single node, got {dut.valid.value}"
    print("Single node test: PASSED")

@cocotb.test()
async def test_bfs_validator_wrong_child(dut):
    """Test sequence with wrong child node"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.adj_write.value = 0
    dut.seq_write.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Tree: 0-1, 0-2
    # Invalid: 0, 1, 4 (4 is not a neighbor)
    adj_pairs = [(0,1), (0,2)]
    sequence = [0, 1, 4, 2, 3, 5, 6, 7]
    
    for i in range(8):
        for j in range(8):
            dut.node_idx.value = i
            dut.neighbor_idx.value = j
            dut.adj_write.value = 1
            if (i,j) in adj_pairs or (j,i) in adj_pairs:
                dut.dut.adj_matrix[i][j].value = 1
            else:
                dut.dut.adj_matrix[i][j].value = 0
            await RisingEdge(dut.clk)
    dut.adj_write.value = 0
    
    for i in range(8):
        dut.seq_in.value = sequence[i]
        dut.seq_write.value = 1
        await RisingEdge(dut.clk)
    dut.seq_write.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 0, f"Expected valid=0 for wrong child, got {dut.valid.value}"
    print("Wrong child test: PASSED")

@cocotb.test()
async def test_bfs_validator_complete_test(dut):
    """Run all tests in sequence"""
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    tests_passed = 0
    total_tests = 8
    
    # Test configurations
    test_configs = [
        # (adj_pairs, sequence, expected_valid, description)
        ([(0,1), (0,2), (1,3)], [0,1,2,3,4,5,6,7], 1, "Basic valid"),
        ([(0,1), (0,2)], [0,1,3,2,4,5,6,7], 0, "Invalid order"),
        ([(0,1), (0,5), (1,2), (1,3), (5,4), (5,6)], [0,1,5,2,3,4,6,7], 1, "8-node tree"),
        ([(0,1), (0,2)], [1,0,2,3,4,5,6,7], 0, "Non-root start"),
        ([(0,1), (2,3)], [0,1,2,3,4,5,6,7], 0, "Disconnected"),
        ([], [0,1,2,3,4,5,6,7], 1, "Single node"),
        ([(0,1), (0,2)], [0,1,4,2,3,5,6,7], 0, "Wrong child"),
        ([(0,1), (0,5), (1,2), (1,3)], [0,5,1,2,3,4,6,7], 1, "Different order valid")
    ]
    
    for adj_pairs, sequence, expected, desc in test_configs:
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.adj_write.value = 0
        dut.seq_write.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load adjacency
        for i in range(8):
            for j in range(8):
                dut.node_idx.value = i
                dut.neighbor_idx.value = j
                dut.adj_write.value = 1
                if (i,j) in adj_pairs or (j,i) in adj_pairs:
                    dut.dut.adj_matrix[i][j].value = 1
                else:
                    dut.dut.adj_matrix[i][j].value = 0
                await RisingEdge(dut.clk)
        dut.adj_write.value = 0
        
        # Load sequence
        for i in range(8):
            dut.seq_in.value = sequence[i]
            dut.seq_write.value = 1
            await RisingEdge(dut.clk)
        dut.seq_write.value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        if dut.valid.value == expected:
            tests_passed += 1
            print(f"Test '{desc}': PASSED")
        else:
            print(f"Test '{desc}': FAILED (expected {expected}, got {dut.valid.value})")
    
    print(f"
=== SUMMARY: {tests_passed}/{total_tests} tests passed ===")
    assert tests_passed == total_tests, f"Only {tests_passed}/{total_tests} tests passed"
