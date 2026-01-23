import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure, TestSuccess

def popcount(n):
    """Count set bits in 8-bit number"""
    return bin(n).count('1')

def check_independent_set(n, k, adj):
    """Check if k drones can be placed on graph with n nodes"""
    # adj is list of 8-bit masks
    for placement in range(1 << n):
        valid = True
        for i in range(n):
            if (placement >> i) & 1:  # node i has drone
                # Check if any neighbor also has drone
                if placement & adj[i]:
                    valid = False
                    break
        if valid and popcount(placement) == k:
            return True
    return False

def build_adj_list_from_sample(n, sample_input):
    """Parse sample input and build adjacency list for n nodes (scaled to 8 max)"""
    lines = sample_input.strip().split('
')
    k = int(lines[0])
    actual_n = int(lines[1])
    adj = [0] * 8  # Max 8 nodes
    
    for i in range(min(n, actual_n)):
        parts = list(map(int, lines[2 + i].split()))
        d = parts[0]
        for neighbor in parts[1:d+1]:
            # Convert from 1-based to 0-based
            neighbor_idx = neighbor - 1
            if neighbor_idx < 8:
                adj[i] |= (1 << neighbor_idx)
    
    return adj

@cocotb.test()
async def test_basin_city_drones(dut):
    """Test the basin_city_drones module with multiple test cases"""
    
    test_cases = [
        # (k, n, adj_list, expected_possible)
        # Test case 1: Original sample 1 (7 nodes, k=4)
        # Scale to 7 nodes for this test
        (4, 7, [0, 0, 0, 0, 0, 0, 0, 0], False),  # Will fill below
        
        # Test case 2: Simple bipartite graph
        (2, 4, [0, 0, 0, 0, 0, 0, 0, 0], True),  # Line: 1-2-3-4, k=2 possible
        
        # Test case 3: Triangle (3 nodes fully connected)
        (1, 3, [0, 0, 0, 0, 0, 0, 0, 0], True),  # k=1 possible, k=2 not
        
        # Test case 4: Empty graph
        (8, 8, [0]*8, True),  # All disconnected, 8 drones possible
        
        # Test case 5: Complete graph K4
        (2, 4, [0, 0, 0, 0, 0, 0, 0, 0], False),  # K4, max independent set = 1
    ]
    
    # Build adjacency for actual samples
    sample1 = "4
7
2 2 4
3 1 3 5
1 2
2 1 5
4 2 6 4 7
2 5 7
2 6 5
"
    sample2 = "4
8
2 2 4
3 1 3 5
1 2
2 1 5
4 2 6 4 7
2 5 8
2 8 5
2 7 6
"
    
    # Override test case 1 with actual sample 1
    adj1 = build_adj_list_from_sample(7, sample1)
    test_cases[0] = (4, 7, adj1, False)
    
    # Override test case 2 with sample 2
    adj2 = build_adj_list_from_sample(8, sample2)
    test_cases[1] = (4, 8, adj2, True)
    
    # Fix test case 2 to use correct values
    test_cases[1] = (4, 8, adj2, True)  # This should be 'possible'
    
    # Rebuild test cases properly
    test_cases = [
        # Sample 1: 7 nodes, k=4 -> impossible
        (4, 7, build_adj_list_from_sample(7, sample1), False),
        # Sample 2: 8 nodes, k=4 -> possible  
        (4, 8, build_adj_list_from_sample(8, sample2), True),
        # Test 3: 3-node line, k=1
        (1, 3, [0b00000010, 0b00000101, 0b00000010, 0,0,0,0,0], True),
        # Test 4: 4-node complete graph, k=2 -> impossible
        (2, 4, [0b00001110, 0b00001101, 0b00001011, 0b00000111, 0,0,0,0], False),
        # Test 5: 8 empty nodes, k=8 -> possible
        (8, 8, [0]*8, True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (k, n, adj, expected) in enumerate(test_cases):
        # Set inputs
        dut.k.value = k
        dut.n.value = n
        dut.adj_0.value = adj[0]
        dut.adj_1.value = adj[1]
        dut.adj_2.value = adj[2]
        dut.adj_3.value = adj[3]
        dut.adj_4.value = adj[4]
        dut.adj_5.value = adj[5]
        dut.adj_6.value = adj[6]
        dut.adj_7.value = adj[7]
        
        # Combinational, wait small amount
        await Timer(10, units='ns')
        
        # Read output
        actual = bool(dut.possible.value)
        
        if actual == expected:
            passed += 1
            print(f"Test {idx + 1}: PASS (k={k}, n={n}, expected={expected}, got={actual})")
        else:
            raise TestFailure(f"Test {idx + 1} FAILED: k={k}, n={n}, expected={expected}, got={actual}")
    
    print(f"
--- Summary: {passed}/{total} tests passed ---")
    
    if passed == total:
        raise TestSuccess(f"All {total} tests passed!")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    
    # Edge case 1: k=0 (always possible)
    dut.k.value = 0
    dut.n.value = 5
    dut.adj_0.value = 0b00111111
    dut.adj_1.value = 0b00111111
    dut.adj_2.value = 0b00111111
    dut.adj_3.value = 0b00111111
    dut.adj_4.value = 0b00111111
    dut.adj_5.value = 0
    dut.adj_6.value = 0
    dut.adj_7.value = 0
    await Timer(10, units='ns')
    assert dut.possible.value == 1, "k=0 should always be possible"
    print("Edge case k=0: PASS")
    
    # Edge case 2: n=1
    dut.k.value = 1
    dut.n.value = 1
    dut.adj_0.value = 0
    dut.adj_1.value = 0
    dut.adj_2.value = 0
    dut.adj_3.value = 0
    dut.adj_4.value = 0
    dut.adj_5.value = 0
    dut.adj_6.value = 0
    dut.adj_7.value = 0
    await Timer(10, units='ns')
    assert dut.possible.value == 1, "n=1, k=1 should be possible"
    print("Edge case n=1: PASS")
    
    # Edge case 3: k > n (impossible)
    dut.k.value = 10
    dut.n.value = 5
    dut.adj_0.value = 0
    dut.adj_1.value = 0
    dut.adj_2.value = 0
    dut.adj_3.value = 0
    dut.adj_4.value = 0
    dut.adj_5.value = 0
    dut.adj_6.value = 0
    dut.adj_7.value = 0
    await Timer(10, units='ns')
    assert dut.possible.value == 0, "k > n should be impossible"
    print("Edge case k>n: PASS")
    
    print("
--- All edge cases passed ---")
