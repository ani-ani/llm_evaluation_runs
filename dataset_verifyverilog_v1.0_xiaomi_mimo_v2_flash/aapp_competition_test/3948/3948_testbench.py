import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def count_bits(x):
    return bin(x).count('1')

def build_adjacency(n, edges):
    """Build 16x16 adjacency matrix for given edges"""
    adj = [0] * 16
    for (u, v) in edges:
        # Convert to 0-indexed
        u_idx = u - 1
        v_idx = v - 1
        # Set bits in both directions
        adj[u_idx] |= (1 << v_idx)
        adj[v_idx] |= (1 << u_idx)
    return adj

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_k_multihedgehog(dut):
    """Test the k-multihedgehog checker with various cases"""
    
    # Test cases: (n, k, edges, expected_valid)
    test_cases = [
        # Example 1: Valid 2-multihedgehog
        (14, 2, [(1,4),(2,4),(3,4),(4,13),(10,5),(11,5),(12,5),(14,5),(5,13),(6,7),(8,6),(13,6),(9,6)], True),
        # Example 2: Invalid hedgehog (center degree 2)
        (3, 1, [(1,3),(2,3)], False),
        # Additional cases
        (16, 2, [(1,12),(2,12),(3,12),(4,13),(5,13),(6,13),(7,16),(8,16),(9,15),(10,15),(11,15),(12,14),(13,14),(16,14),(15,14)], False),
        (13, 2, [(7,5),(10,11),(5,12),(1,2),(10,7),(2,6),(10,4),(9,5),(13,10),(2,8),(3,10),(2,7)], False),
        (2, 1, [(1,2)], False),
        (13, 1000000000, [(1,i) for i in range(2,14)], False),  # k>3
        (4, 1, [(2,3),(4,2),(1,2)], True),
        (7, 1, [(1,2),(1,3),(1,4),(5,1),(1,6),(1,7)], True),
        (14, 1, [(1,4),(2,4),(3,4),(4,13),(10,5),(11,5),(12,5),(14,5),(5,13),(6,7),(8,6),(13,6),(9,6)], False),
        (14, 3, [(1,4),(2,4),(3,4),(4,13),(10,5),(11,5),(12,5),(14,5),(5,13),(6,7),(8,6),(13,6),(9,6)], False),
        (13, 2, [(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8),(1,9),(1,10),(1,11),(1,12),(1,13)], False),
        (8, 1, [(8,2),(2,5),(5,1),(7,2),(2,4),(3,5),(5,6)], False),
        (8, 2, [(8,2),(2,5),(5,1),(7,2),(2,4),(3,5),(5,6)], False),
        (2, 1, [(2,1)], False),
        (5, 1, [(4,1),(3,1),(5,1),(1,2)], True),
        (33, 2, [(3,13),(17,3),(2,6),(5,33),(4,18),(1,2),(31,5),(4,19),(3,16),(1,3),(9,2),(10,3),(5,1),(5,28),(21,4),(7,2),(1,4),(5,24),(30,5),(14,3),(3,11),(27,5),(8,2),(22,4),(12,3),(20,4),(26,5),(4,23),(32,5),(25,5),(15,3),(29,5)], False),
        (10, 980000000, [(5,4),(7,1),(3,2),(10,6),(2,8),(6,4),(7,9),(1,8),(3,10)], False),
        (1, 1, [], False),
        (18, 2, [(1,4),(2,4),(3,4),(4,13),(10,5),(11,5),(12,5),(14,5),(5,13),(6,7),(8,6),(13,6),(9,6),(13,15),(15,16),(15,17),(15,18)], False),
        (21, 2, [(3,1),(4,1),(5,1),(6,2),(7,2),(8,2),(1,2),(9,1),(9,10),(9,11),(9,12),(10,13),(10,14),(10,15),(11,16),(11,17),(11,18),(12,19),(12,20),(12,21)], False),
        (22, 2, [(1,4),(2,4),(3,4),(5,8),(6,8),(7,8),(9,12),(10,12),(11,12),(13,16),(14,16),(15,16),(17,20),(18,20),(19,20),(4,21),(8,21),(12,21),(4,22),(16,22),(20,22)], False),
        (25, 2, [(1,2),(1,3),(1,4),(2,5),(2,6),(2,7),(3,8),(3,9),(3,10),(4,11),(4,12),(4,13),(4,14),(14,15),(14,16),(14,17),(4,18),(18,19),(18,20),(18,21),(1,22),(22,23),(22,24),(22,25)], False),
    ]
    
    for idx, (n, k, edges, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: n={n}, k={k}, edges={len(edges)}")
        
        # Build adjacency matrix
        adj = build_adjacency(n, edges)
        
        # Drive inputs
        dut.n.value = n
        dut.k.value = k
        for i in range(16):
            dut.adj[i].value = adj[i]
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Check result
        result = bool(dut.valid.value)
        if result != expected:
            raise TestFailure(f"Case {idx+1} failed: expected {expected}, got {result}")
        else:
            dut._log.info(f"Case {idx+1} passed")
    
    dut._log.info("All test cases passed!")