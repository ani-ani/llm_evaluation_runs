import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_bicycle_race_routes(dut):
    """Test bicycle race route counting with various graph configurations"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.node_enable.value = 0
    for i in range(8):
        dut.adj_matrix[i].value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    async def run_test_case(test_name, node_enable, edges, expected_count, expected_inf):
        """Run a single test case"""
        print(f"
Test: {test_name}")
        
        # Clear adjacency matrix
        for i in range(8):
            dut.adj_matrix[i].value = 0
        
        # Setup adjacency matrix
        adj = [[0]*8 for _ in range(8)]
        for (u, v) in edges:
            if u < 8 and v < 8:
                adj[u][v] = 1
        
        # Write to DUT
        for i in range(8):
            val = 0
            for j in range(8):
                if adj[i][j]:
                    val |= (1 << j)
            dut.adj_matrix[i].value = val
        
        dut.node_enable.value = node_enable
        await Timer(10, units="ns")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 200 cycles for safety)
        timeout = 200
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout in {test_name}")
        
        # Check results
        actual_count = int(dut.result.value)
        actual_inf = int(dut.inf_flag.value)
        
        print(f"Expected: count={expected_count}, inf={expected_inf}")
        print(f"Actual:   count={actual_count}, inf={actual_inf}")
        
        if actual_inf != expected_inf:
            raise TestFailure(f"inf_flag mismatch in {test_name}: expected {expected_inf}, got {actual_inf}")
        
        if not expected_inf and actual_count != expected_count:
            raise TestFailure(f"count mismatch in {test_name}: expected {expected_count}, got {actual_count}")
        
        if expected_inf and actual_count != 0:
            print(f"Warning: count={actual_count} when inf=1 (should be 0 or ignored)")
        
        return True
    
    # Test 1: Simple 3-node graph, 3 paths (from sample 1, scaled to 8 nodes)
    # Nodes: 0=source, 1=dest
    # Edges: 0->2, 0->3, 2->1, 3->1 (4 nodes total: 0,1,2,3)
    await run_test_case(
        "Simple 3-path case",
        node_enable=0b00001111,  # Nodes 0,1,2,3 enabled
        edges=[(0,2), (0,3), (2,1), (3,1)],
        expected_count=3,
        expected_inf=0
    )
    
    # Test 2: No paths
    await run_test_case(
        "No paths",
        node_enable=0b00000011,  # Nodes 0,1 enabled
        edges=[(0,0), (1,1)],  # Only self-loops
        expected_count=0,
        expected_inf=0
    )
    
    # Test 3: Single direct path
    await run_test_case(
        "Single path",
        node_enable=0b00000011,
        edges=[(0,1)],
        expected_count=1,
        expected_inf=0
    )
    
    # Test 4: Two parallel edges (multiple edges between same nodes)
    await run_test_case(
        "Parallel edges",
        node_enable=0b00000011,
        edges=[(0,1), (0,1)],  # Two edges from 0 to 1
        expected_count=2,
        expected_inf=0
    )
    
    # Test 5: Triangle cycle (but not affecting source to dest)
    # 0->1 (direct), also 2->3->2 cycle
    await run_test_case(
        "With disconnected cycle",
        node_enable=0b00001111,
        edges=[(0,1), (2,3), (3,2)],
        expected_count=1,
        expected_inf=0
    )
    
    # Test 6: Cycle reachable from source but not reaching dest (should not be inf)
    await run_test_case(
        "Cycle not reaching dest",
        node_enable=0b00001111,
        edges=[(0,1), (0,2), (2,3), (3,2)],  # Cycle on 2-3, but 0->1 still works
        expected_count=1,
        expected_inf=0
    )
    
    # Test 7: More complex multi-path
    await run_test_case(
        "Multi-path with intermediate",
        node_enable=0b00011111,  # 5 nodes
        edges=[(0,2), (0,3), (0,4), (2,1), (3,1), (4,1)],
        expected_count=3,
        expected_inf=0
    )
    
    # Test 8: Two ways with sharing
    await run_test_case(
        "Shared intermediate",
        node_enable=0b00001111,
        edges=[(0,2), (2,1), (2,3), (3,1)],
        expected_count=2,
        expected_inf=0
    )
    
    print("
" + "="*50)
    print("8/8 tests completed successfully")
    print("="*50)
