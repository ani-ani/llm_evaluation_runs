import cocotb
from cocotb.triggers import Timer

def compute_expected_cost(router_mask, router_costs, K):
    """Compute cost for a given router configuration"""
    # Router costs
    router_sum = 0
    for i in range(6):
        if router_mask & (1 << i):
            router_sum += router_costs[i]
    
    # Corridor analysis for 2x3 grid
    # Horizontal edges
    edges = [
        (0, 1), (1, 2),  # row 0
        (3, 4), (4, 5),  # row 1
        (0, 3), (1, 4), (2, 5)  # vertical
    ]
    
    bad_corridors = 0
    for u, v in edges:
        u_router = (router_mask >> u) & 1
        v_router = (router_mask >> v) & 1
        if u_router + v_router != 1:
            bad_corridors += 1
    
    return router_sum + bad_corridors * K

def find_min_cost(router_costs, K):
    """Find minimum cost across all 64 configurations"""
    min_cost = float('inf')
    for mask in range(64):
        cost = compute_expected_cost(mask, router_costs, K)
        if cost < min_cost:
            min_cost = cost
    return min_cost

@cocotb.test()
async def test_wireless_coverage(dut):
    """Test wireless coverage module with various configurations"""
    
    # Test case 1: Sample Input 1 adapted to 2x3
    # Original: 2 3 4, costs: [10,1,3], [0,1,20]
    # We'll use costs as: [10,1,3,0,1,20], K=4
    dut.router_costs.value = (10 << 0) | (1 << 6) | (3 << 12) | (0 << 18) | (1 << 24) | (20 << 30)
    dut.K.value = 4
    
    # Test with mask = 0 (no routers)
    dut.router_mask.value = 0
    await Timer(10, units='ns')
    expected = find_min_cost([10,1,3,0,1,20], 4)
    actual = int(dut.min_cost.value)
    print(f"Test 1 - Mask 0: Expected={expected}, Actual={actual}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    # Test case 2: High K value
    dut.K.value = 100
    dut.router_costs.value = (10 << 0) | (1 << 6) | (10 << 12) | (10 << 18) | (1 << 24) | (10 << 30)
    dut.router_mask.value = 3  # bits 0 and 1
    await Timer(10, units='ns')
    expected = find_min_cost([10,1,10,10,1,10], 100)
    actual = int(dut.min_cost.value)
    print(f"Test 2 - High K: Expected={expected}, Actual={actual}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    # Test case 3: Small costs, low K
    dut.K.value = 1
    dut.router_costs.value = (10 << 0) | (10 << 6) | (10 << 12) | (10 << 18) | (10 << 24) | (10 << 30)
    dut.router_mask.value = 0
    await Timer(10, units='ns')
    expected = find_min_cost([10,10,10,10,10,10], 1)
    actual = int(dut.min_cost.value)
    print(f"Test 3 - Low K: Expected={expected}, Actual={actual}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    # Test case 4: Zero K (should prefer routers if they help)
    dut.K.value = 0
    dut.router_costs.value = (5 << 0) | (5 << 6) | (5 << 12) | (5 << 18) | (5 << 24) | (5 << 30)
    dut.router_mask.value = 0
    await Timer(10, units='ns')
    expected = find_min_cost([5,5,5,5,5,5], 0)
    actual = int(dut.min_cost.value)
    print(f"Test 4 - Zero K: Expected={expected}, Actual={actual}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    # Test case 5: All zeros cost
    dut.K.value = 10
    dut.router_costs.value = 0
    dut.router_mask.value = 0
    await Timer(10, units='ns')
    expected = find_min_cost([0,0,0,0,0,0], 10)
    actual = int(dut.min_cost.value)
    print(f"Test 5 - Zero costs: Expected={expected}, Actual={actual}")
    assert actual == expected, f"Expected {expected}, got {actual}"
    
    print("All tests passed!")