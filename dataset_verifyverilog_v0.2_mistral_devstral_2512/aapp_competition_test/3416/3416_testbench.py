import cocotb
from cocotb.triggers import Timer

def q16_16(value):
    return int(value * 65536)

def city_to_mask(cities):
    mask = 0
    for c in cities:
        mask |= 1 << (c-1)
    return mask

def edge_to_bits(src, dst):
    # src and dst are 1-4, convert to 0-3
    return (src-1) << 4 | (dst-1) << 2

@cocotb.test()
async def test_traveling_salesman(dut):
    # Test case 1: 4 cities, 4 edges (1->2, 1->3, 2->4, 3->4)
    dut.n.value = 4
    dut.m.value = 4
    dut.edges.value = 0  # Clear all edges
    dut.edges[0].value = edge_to_bits(1, 2)
    dut.edges[1].value = edge_to_bits(1, 3)
    dut.edges[2].value = edge_to_bits(2, 4)
    dut.edges[3].value = edge_to_bits(3, 4)
    dut.edges[4].value = 0
    dut.edges[5].value = 0
    
    await Timer(10, units='ns')
    
    # Expected: min_flights = 1, airports = all cities (1,2,3,4)
    assert dut.min_flights.value == 1, f"Test 1 failed: expected min_flights=1, got {dut.min_flights.value}"
    expected_airports = city_to_mask([1,2,3,4])
    assert dut.airports.value == expected_airports, f"Test 1 failed: expected airports={expected_airports:04b}, got {dut.airports.value:04b}"
    print(f"Test 1 passed: min_flights={dut.min_flights.value}, airports={dut.airports.value:04b}")
    
    # Test case 2: 4 cities, 3 edges (1->2, 2->3, 3->4)
    dut.n.value = 4
    dut.m.value = 3
    dut.edges.value = 0
    dut.edges[0].value = edge_to_bits(1, 2)
    dut.edges[1].value = edge_to_bits(2, 3)
    dut.edges[2].value = edge_to_bits(3, 4)
    dut.edges[3].value = 0
    dut.edges[4].value = 0
    dut.edges[5].value = 0
    
    await Timer(10, units='ns')
    
    # Expected: min_flights = 0, airports = 0
    assert dut.min_flights.value == 0, f"Test 2 failed: expected min_flights=0, got {dut.min_flights.value}"
    assert dut.airports.value == 0, f"Test 2 failed: expected airports=0, got {dut.airports.value}"
    print(f"Test 2 passed: min_flights={dut.min_flights.value}, airports={dut.airports.value:04b}")
    
    # Test case 3: 3 cities, 0 edges
    dut.n.value = 3
    dut.m.value = 0
    dut.edges.value = 0
    
    await Timer(10, units='ns')
    
    # Expected: min_flights = 2 (3 cities, 0 edges -> 3 paths, flights=2), airports = all 3
    assert dut.min_flights.value == 2, f"Test 3 failed: expected min_flights=2, got {dut.min_flights.value}"
    expected_airports = city_to_mask([1,2,3])
    assert dut.airports.value == expected_airports, f"Test 3 failed: expected airports={expected_airports:04b}, got {dut.airports.value:04b}"
    print(f"Test 3 passed: min_flights={dut.min_flights.value}, airports={dut.airports.value:04b}")
    
    # Test case 4: 2 cities, 1 edge (1->2)
    dut.n.value = 2
    dut.m.value = 1
    dut.edges.value = 0
    dut.edges[0].value = edge_to_bits(1, 2)
    
    await Timer(10, units='ns')
    
    # Expected: min_flights = 0, airports = 0
    assert dut.min_flights.value == 0, f"Test 4 failed: expected min_flights=0, got {dut.min_flights.value}"
    assert dut.airports.value == 0, f"Test 4 failed: expected airports=0, got {dut.airports.value}"
    print(f"Test 4 passed: min_flights={dut.min_flights.value}, airports={dut.airports.value:04b}")
    
    # Test case 5: 2 cities, 0 edges
    dut.n.value = 2
    dut.m.value = 0
    dut.edges.value = 0
    
    await Timer(10, units='ns')
    
    # Expected: min_flights = 1, airports = both cities
    assert dut.min_flights.value == 1, f"Test 5 failed: expected min_flights=1, got {dut.min_flights.value}"
    expected_airports = city_to_mask([1,2])
    assert dut.airports.value == expected_airports, f"Test 5 failed: expected airports={expected_airports:04b}, got {dut.airports.value:04b}"
    print(f"Test 5 passed: min_flights={dut.min_flights.value}, airports={dut.airports.value:04b}")
    
    print("
All tests passed!")
