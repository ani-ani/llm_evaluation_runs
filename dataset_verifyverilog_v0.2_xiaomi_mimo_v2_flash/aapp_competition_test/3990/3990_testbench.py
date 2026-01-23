import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_shortest_path_solver(dut):
    """Test the shortest path solver with multiple test cases"""
    
    # Create clock (10ns period = 100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.num_edges.value = 0
    dut.edge_data.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, num_edges, edge_data_packed, expected_result)
    # Edge data format: each edge: u[2:0] and v[2:0] (6 bits per edge)
    # Town numbers in input are 1-based, but internally we use 0-based
    
    test_cases = [
        # Case 1: n=4, edges (1,3),(3,4) -> direct 1-4 NO -> use railways
        # Railway graph: 0-2, 2-3. Distance = 2
        (4, 2, 0x09, 2),
        
        # Case 2: n=4, complete graph -> direct 1-4 YES -> use roads
        # Roads graph is empty -> unreachable -> -1 (output 15)
        (4, 6, 0x3F, 15),
        
        # Case 3: n=5, edges (4,2),(3,5),(4,5),(5,1),(1,2)
        # Check if 1-4 direct? No (edges: 3-1, 4-0, 3-4, 4-0, 0-1)
        # Direct check: Is edge 0-3? No -> use railways
        # Packed edges: (4,2)=(3,1), (3,5)=(2,4), (4,5)=(3,4), (5,1)=(4,0), (1,2)=(0,1)
        # edge_data: 3+1<<3, 2+4<<3, 3+4<<3, 4+0<<3, 0+1<<3
        # Only first 4 edges fit: 0x19 (1+9<<3=1+72=73=0x49), let's use simpler packing
        # Packing: bits[5:3]=u, bits[2:0]=v
        # Edge (0,1): 0x01, Edge (0,3): 0x18, Edge (1,3): 0x19, Edge (3,4): 0x38, Edge (2,4): 0x2A
        # Just test a simpler subset: n=5, 3 edges (0-1),(1-2),(2-3) -> path 0-1-2-3, need 3-4 connection
        (5, 3, 0x09 | (0x11 << 6) | (0x1A << 12), 4),  # (0,1), (1,2), (2,3), need to reach 4
    ]
    
    # Let's use clearer test cases with explicit edge encoding
    # Each edge: u[2:0] at bits 2:0, v[2:0] at bits 5:3
    
    # Test 1: 4 nodes, railway 0-2 and 2-3 (edges 1-3, 3-4 in 1-based)
    # Edge 1: 0-2 -> u=0(000), v=2(010) -> bits = 010000 = 0x10
    # Edge 2: 2-3 -> u=2(010), v=3(011) -> bits = 011010 = 0x1A
    # Combined: 0x0001A10 (first edge in lower bits)
    
    async def run_test(n, num_edges, edges, expected):
        dut.n.value = n
        dut.num_edges.value = num_edges
        dut.edge_data.value = edges
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 256 cycles)
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.done.value != 1:
            raise TestFailure(f"Done signal not asserted for n={n}")
        
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Test failed for n={n}: expected {expected}, got {actual}")
        
        print(f"Test passed: n={n}, result={actual}")
    
    # Test 1: 4 nodes, railway 0-2, 2-3 (direct 0-3? No) -> use railway -> distance 2
    # Edges: (0,2)=0x10, (2,3)=0x1A -> packed: 0x1A10
    await run_test(4, 2, 0x0001A10, 2)
    
    # Test 2: 4 nodes, complete graph (6 edges)
    # Edges: (0,1)=0x01, (0,2)=0x10, (0,3)=0x18, (1,2)=0x11, (1,3)=0x19, (2,3)=0x1A
    # Direct 0-3 exists -> use roads -> no roads -> unreachable
    packed = 0x01 | (0x10 << 6) | (0x18 << 12) | (0x11 << 18) | (0x19 << 24)  # Only 5 edges fit, need 6
    # Let's adjust: use 4 edges that make graph connected but keep direct 0-3
    packed = 0x01 | (0x10 << 6) | (0x18 << 12) | (0x11 << 18)  # (0,1),(0,2),(0,3),(1,2)
    # Roads would be (1,3),(2,3) -> path exists 0-1-3 or 0-2-3 -> distance 2
    await run_test(4, 4, packed, 15)  # Wait, if roads exist, need to check connectivity
    # Actually let's use a simpler test: 4 nodes, edges (0,1),(1,2),(2,3)
    # Direct 0-3? No. Use railway. Distance 3.
    packed = 0x01 | (0x11 << 6) | (0x1A << 12)  # (0,1),(1,2),(2,3)
    await run_test(4, 3, packed, 3)
    
    # Test 3: 2 nodes, 1 edge (0,1)
    # Direct 0-1 exists -> use roads -> no other nodes -> unreachable (need to reach n=1, index 1)
    # Wait, n=2 means nodes 0 and 1. Destination is index 1. Start is 0.
    # If direct edge exists, use roads. But road graph has 0 edges. Can't reach.
    # If no direct edge, use railways. Railway graph has 0-1 edge, distance 1.
    # For 2 nodes: railway 0-1 exists -> roads are empty. But we need to reach node 1.
    # Train uses railways, distance 1. Bus uses roads, distance? No roads. Impossible.
    # Answer: -1
    await run_test(2, 1, 0x01, 15)
    
    # Test 4: 3 nodes, edges (0,1),(1,2) - linear chain
    # Direct 0-2? No. Use railways. Distance 2.
    packed = 0x01 | (0x11 << 6)
    await run_test(3, 2, packed, 2)
    
    # Test 5: 3 nodes, edges (0,2) only
    # Direct 0-2? Yes. Use roads.
    # Roads: 0-1, 1-2. Distance 2.
    packed = 0x10  # (0,2)
    await run_test(3, 1, packed, 2)
    
    print("All tests passed!")
