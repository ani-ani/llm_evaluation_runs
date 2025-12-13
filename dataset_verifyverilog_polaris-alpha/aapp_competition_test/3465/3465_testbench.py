import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_road_assignment(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1 - Original 4-city example (scaled)
    test1_input = [
        (1, 2), (2, 3), (3, 1), (4, 1), 
        0, 0, 0, 0, 0, 0  # Padding for unused roads
    ][:8]
    test1_encoded = [(a<<3)|b for a,b in test1_input]
    
    dut.num_cities.value = 4
    for i in range(8):
        try:
            dut.roads[i].value = test1_encoded[i]
        except IndexError:
            dut.roads[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')  # Wait for computation
    assert dut.done.value == 1, "Test1: Didn't complete in time"
    
    # Verify assignment correctness
    cities_used = set()
    roads_assigned = set()
    for i in range(8):
        if i < 4:
            road_val = dut.assignments[i].value.integer
            a = (road_val >> 3) & 0x7
            b = road_val & 0x7
            cities_used.add(a)
            roads_assigned.add((a,b) if a < b else (b,a))
    
    assert len(cities_used) == 4, "Test1: Incorrect city count"
    assert roads_assigned == set([(1,2), (2,3), (1,3), (1,4)]), "Test1: Wrong road selection"
    
    # Test case 2 - 2 cities with duplicate roads
    await RisingEdge(dut.clk)
    dut.num_cities.value = 2
    dut.roads[0].value = (1 << 3) | 2
    dut.roads[1].value = (1 << 3) | 2
    for i in range(2,8):
        dut.roads[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')
    assert dut.done.value == 1, "Test2: Didn't complete in time"
    
    cities_used = set()
    roads_assigned = set()
    for i in range(2):
        road_val = dut.assignments[i].value.integer
        a = (road_val >> 3) & 0x7
        b = road_val & 0x7
        cities_used.add(a)
        roads_assigned.add((a,b) if a < b else (b,a))
    
    assert len(cities_used) == 2, "Test2: Incorrect city count"
    assert roads_assigned == set([(1,2)]), "Test2: Wrong road selection"
    
    # Additional edge case: All roads from city 1
    await RisingEdge(dut.clk)
    dut.num_cities.value = 3
    dut.roads[0].value = (1 << 3) | 2
    dut.roads[1].value = (1 << 3) | 3
    dut.roads[2].value = (1 << 3) | 4
    for i in range(3,8):
        dut.roads[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')
    assert dut.done.value == 1, "Test3: Didn't complete in time"
    
    # Random test with 5 cities
    await RisingEdge(dut.clk)
    cities = [1,2,3,4,5]
    test_roads = [(i,j) for i in cities for j in cities if i < j]
    random.shuffle(test_roads)
    test_roads = test_roads[:5]  # Select 5 unique roads
    
    dut.num_cities.value = 5
    for i in range(8):
        if i < 5:
            a,b = test_roads[i]
            dut.roads[i].value = (a << 3) | b
        else:
            dut.roads[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')
    assert dut.done.value == 1, "Test4: Didn't complete in time"
    
    cities_used = set()
    roads_assigned = set()
    for i in range(5):
        road_val = dut.assignments[i].value.integer
        a = (road_val >> 3) & 0x7
        b = road_val & 0x7
        cities_used.add(a)
        roads_assigned.add((a,b) if a < b else (b,a))
    
    assert len(cities_used) == 5, "Test4: Only %d cities used" % len(cities_used)
    assert roads_assigned == set(test_roads), "Test4: Road mismatch"
    dut._log.info("4/4 tests passed")