import cocotb
from cocotb.triggers import Timer
import random

def calculate_expected(adj, n):
    """Calculate expected result from adjacency matrix"""
    result = 0
    for i in range(n):
        degree = sum(adj[i][j] for j in range(n))
        result += degree * (degree - 1)
    return result

@cocotb.test()
def test_optimal_paths_length2(dut):
    """Test optimal paths counting with various tree configurations"""
    
    test_cases = [
        # Case 1: N=3, star (1 connected to 2,3)
        {
            'n': 3,
            'edges': [(0,1), (0,2)],
            'expected': 2
        },
        # Case 2: N=5, more complex tree
        {
            'n': 5,
            'edges': [(1,0), (0,4), (2,0), (3,2)],
            'expected': 8
        },
        # Case 3: N=2, just one edge
        {
            'n': 2,
            'edges': [(0,1)],
            'expected': 0
        },
        # Case 4: N=4, path 0-1-2-3
        {
            'n': 4,
            'edges': [(0,1), (1,2), (2,3)],
            'expected': 2
        },
        # Case 5: N=1, single node
        {
            'n': 1,
            'edges': [],
            'expected': 0
        }
    ]
    
    for test_idx, tc in enumerate(test_cases):
        n = tc['n']
        edges = tc['edges']
        expected = tc['expected']
        
        # Build adjacency matrix
        adj = [[0]*16 for _ in range(16)]
        for u, v in edges:
            adj[u][v] = 1
            adj[v][u] = 1
        
        # Drive inputs
        dut.num_nodes.value = n
        for i in range(16):
            dut.adj_matrix[i].value = 0
            for j in range(16):
                if adj[i][j]:
                    dut.adj_matrix[i].value |= (1 << j)
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        result = int(dut.result.value)
        
        print(f"Test {test_idx + 1}: N={n}, edges={edges}")
        print(f"  Expected: {expected}, Got: {result}")
        assert result == expected, f"Test {test_idx + 1} failed: expected {expected}, got {result}"
    
    print(f"
{len(test_cases)}/{len(test_cases)} tests passed")