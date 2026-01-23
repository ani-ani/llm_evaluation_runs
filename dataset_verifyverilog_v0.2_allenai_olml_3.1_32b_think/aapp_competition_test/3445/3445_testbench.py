import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def manhattan_distance(x1, y1, x2, y2):
    return abs(x1 - x2) + abs(y1 - y2)

def compute_diameter(points):
    if len(points) <= 1:
        return 0
    max_dist = 0
    for i in range(len(points)):
        for j in range(i+1, len(points)):
            dist = manhattan_distance(points[i][0], points[i][1], points[j][0], points[j][1])
            max_dist = max(max_dist, dist)
    return max_dist

def find_optimal_partition(customers):
    n = len(customers)
    best_result = float('inf')
    
    # Try all partitions
    for mask in range(1 << n):
        group1 = []
        group2 = []
        
        for i in range(n):
            if mask & (1 << i):
                group1.append(customers[i])
            else:
                group2.append(customers[i])
        
        # Must have at least one customer per group
        if len(group1) == 0 or len(group2) == 0:
            continue
        
        diam1 = compute_diameter(group1)
        diam2 = compute_diameter(group2)
        max_diam = max(diam1, diam2)
        
        if max_diam < best_result:
            best_result = max_diam
    
    return best_result

@cocotb.test()
async def test_courier_partition_basic(dut):
    """Test basic case with 6 customers"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 6 customers from example
    customers = [(1,1), (4,1), (1,5), (10,10), (10,8), (7,10)]
    dut.num_customers.value = 6
    
    for i, (x, y) in enumerate(customers):
        dut.customer_x[i].value = x
        dut.customer_y[i].value = y
    
    # Fill unused entries
    for i in range(6, 8):
        dut.customer_x[i].value = 0
        dut.customer_y[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (allowing extra cycles)
    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    result = int(dut.min_max_diameter.value)
    expected = find_optimal_partition(customers)
    
    print(f"Test 1 - Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_courier_partition_case2(dut):
    """Test second example case with 7 customers"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    customers = [(0,0), (100,100), (0,100), (100,0), (50,50), (0,50), (100,50)]
    dut.num_customers.value = 7
    
    for i, (x, y) in enumerate(customers):
        dut.customer_x[i].value = x
        dut.customer_y[i].value = y
    
    # Fill unused
    for i in range(7, 8):
        dut.customer_x[i].value = 0
        dut.customer_y[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.min_max_diameter.value)
    expected = find_optimal_partition(customers)
    
    print(f"Test 2 - Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_courier_partition_small(dut):
    """Test with minimum 3 customers"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    customers = [(0,0), (5,5), (10,0)]
    dut.num_customers.value = 3
    
    for i, (x, y) in enumerate(customers):
        dut.customer_x[i].value = x
        dut.customer_y[i].value = y
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.min_max_diameter.value)
    expected = find_optimal_partition(customers)
    
    print(f"Test 3 - Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_courier_partition_edge(dut):
    """Test with all customers on a line"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    customers = [(0,0), (1,0), (2,0), (3,0), (4,0)]
    dut.num_customers.value = 5
    
    for i, (x, y) in enumerate(customers):
        dut.customer_x[i].value = x
        dut.customer_y[i].value = y
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.min_max_diameter.value)
    expected = find_optimal_partition(customers)
    
    print(f"Test 4 - Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_courier_partition_single(dut):
    """Test with customers that force one company to have single customer"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    customers = [(0,0), (100,100), (10,10)]
    dut.num_customers.value = 3
    
    for i, (x, y) in enumerate(customers):
        dut.customer_x[i].value = x
        dut.customer_y[i].value = y
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.min_max_diameter.value)
    expected = find_optimal_partition(customers)
    
    print(f"Test 5 - Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_courier_partition_all_tests(dut):
    """Run all test cases and print summary"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        [(1,1), (4,1), (1,5), (10,10), (10,8), (7,10)],
        [(0,0), (100,100), (0,100), (100,0), (50,50), (0,50), (100,50)],
        [(0,0), (5,5), (10,0)],
        [(0,0), (1,0), (2,0), (3,0), (4,0)],
        [(0,0), (100,100), (10,10)]
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, customers in enumerate(test_cases):
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        n = len(customers)
        dut.num_customers.value = n
        
        for i, (x, y) in enumerate(customers):
            dut.customer_x[i].value = x
            dut.customer_y[i].value = y
        
        for i in range(n, 8):
            dut.customer_x[i].value = 0
            dut.customer_y[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(20000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        result = int(dut.min_max_diameter.value)
        expected = find_optimal_partition(customers)
        
        if result == expected:
            passed += 1
            print(f"Case {idx+1}: PASS (result={result})")
        else:
            print(f"Case {idx+1}: FAIL (expected={expected}, got={result})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
