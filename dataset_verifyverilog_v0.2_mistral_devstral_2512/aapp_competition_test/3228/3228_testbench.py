import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def calculate_expected(arrival_times, valid_mask, T, G):
    """Calculate expected total waiting time for Python verification"""
    if G == 0:
        return 0
    departure_interval = (2 * T + G - 1) // G
    total_wait = 0
    
    for i, arrival in enumerate(arrival_times):
        if valid_mask & (1 << i):  # Check if this skier is valid
            if departure_interval == 0:
                next_dep = arrival
            else:
                # Find next departure time
                if arrival % departure_interval == 0:
                    next_dep = arrival
                else:
                    next_dep = ((arrival // departure_interval) + 1) * departure_interval
            wait = next_dep - arrival
            total_wait += wait
    
    return total_wait

@cocotb.test()
async def test_gondola_scheduler_basic(dut):
    """Test basic functionality with sample input 1"""
    # Sample input 1: 4 skiers, T=10, G=2
    # Arrival times: 0, 15, 30, 45
    # Expected output: 10
    
    arrival_times = [0, 15, 30, 45]
    valid_mask = 0b1111  # All 4 valid
    T = 10
    G = 2
    
    # Set inputs
    dut.arrival_times_0.value = arrival_times[0]
    dut.arrival_times_1.value = arrival_times[1]
    dut.arrival_times_2.value = arrival_times[2]
    dut.arrival_times_3.value = arrival_times[3]
    dut.arrival_times_4.value = 0
    dut.arrival_times_5.value = 0
    dut.arrival_times_6.value = 0
    dut.arrival_times_7.value = 0
    dut.valid_skiers.value = valid_mask
    dut.T.value = T
    dut.G.value = G
    
    await Timer(1, units='ns')
    
    result = int(dut.total_waiting_time.value)
    expected = calculate_expected(arrival_times, valid_mask, T, G)
    
    print(f"Test 1: Input=[{', '.join(map(str, arrival_times))}], T={T}, G={G}")
    print(f"  Result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

@cocotb.test()
async def test_gondola_scheduler_sample2(dut):
    """Test with sample input 2"""
    # Sample input 2: 4 skiers, T=10, G=3
    # Arrival times: 0, 15, 30, 45
    # Expected output: 5
    
    arrival_times = [0, 15, 30, 45]
    valid_mask = 0b1111
    T = 10
    G = 3
    
    dut.arrival_times_0.value = arrival_times[0]
    dut.arrival_times_1.value = arrival_times[1]
    dut.arrival_times_2.value = arrival_times[2]
    dut.arrival_times_3.value = arrival_times[3]
    dut.arrival_times_4.value = 0
    dut.arrival_times_5.value = 0
    dut.arrival_times_6.value = 0
    dut.arrival_times_7.value = 0
    dut.valid_skiers.value = valid_mask
    dut.T.value = T
    dut.G.value = G
    
    await Timer(1, units='ns')
    
    result = int(dut.total_waiting_time.value)
    expected = calculate_expected(arrival_times, valid_mask, T, G)
    
    print(f"Test 2: Input=[{', '.join(map(str, arrival_times))}], T={T}, G={G}")
    print(f"  Result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

@cocotb.test()
async def test_gondola_scheduler_sample3(dut):
    """Test with sample input 3"""
    # Sample input 3: 5 skiers, T=16, G=3
    # Arrival times: 16, 7, 5, 8, 1
    # Expected output: 4
    
    arrival_times = [16, 7, 5, 8, 1]
    valid_mask = 0b11111  # 5 valid skiers
    T = 16
    G = 3
    
    dut.arrival_times_0.value = arrival_times[0]
    dut.arrival_times_1.value = arrival_times[1]
    dut.arrival_times_2.value = arrival_times[2]
    dut.arrival_times_3.value = arrival_times[3]
    dut.arrival_times_4.value = arrival_times[4]
    dut.arrival_times_5.value = 0
    dut.arrival_times_6.value = 0
    dut.arrival_times_7.value = 0
    dut.valid_skiers.value = valid_mask
    dut.T.value = T
    dut.G.value = G
    
    await Timer(1, units='ns')
    
    result = int(dut.total_waiting_time.value)
    expected = calculate_expected(arrival_times, valid_mask, T, G)
    
    print(f"Test 3: Input=[{', '.join(map(str, arrival_times))}], T={T}, G={G}")
    print(f"  Result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

@cocotb.test()
async def test_gondola_scheduler_edge_case(dut):
    """Test edge case: single skier, single gondola"""
    arrival_times = [50]
    valid_mask = 0b00000001
    T = 10
    G = 1
    
    dut.arrival_times_0.value = arrival_times[0]
    dut.arrival_times_1.value = 0
    dut.arrival_times_2.value = 0
    dut.arrival_times_3.value = 0
    dut.arrival_times_4.value = 0
    dut.arrival_times_5.value = 0
    dut.arrival_times_6.value = 0
    dut.arrival_times_7.value = 0
    dut.valid_skiers.value = valid_mask
    dut.T.value = T
    dut.G.value = G
    
    await Timer(1, units='ns')
    
    result = int(dut.total_waiting_time.value)
    expected = calculate_expected(arrival_times, valid_mask, T, G)
    
    print(f"Test 4: Single skier, T={T}, G={G}")
    print(f"  Result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

@cocotb.test()
async def test_gondola_scheduler_all_on_time(dut):
    """Test case where all skiers arrive exactly at departure times"""
    # With T=10, G=2: interval = ceil(20/2) = 10
    # Departures at 0, 10, 20, 30...
    arrival_times = [0, 10, 20, 30]
    valid_mask = 0b1111
    T = 10
    G = 2
    
    dut.arrival_times_0.value = arrival_times[0]
    dut.arrival_times_1.value = arrival_times[1]
    dut.arrival_times_2.value = arrival_times[2]
    dut.arrival_times_3.value = arrival_times[3]
    dut.arrival_times_4.value = 0
    dut.arrival_times_5.value = 0
    dut.arrival_times_6.value = 0
    dut.arrival_times_7.value = 0
    dut.valid_skiers.value = valid_mask
    dut.T.value = T
    dut.G.value = G
    
    await Timer(1, units='ns')
    
    result = int(dut.total_waiting_time.value)
    expected = 0  # No waiting time
    
    print(f"Test 5: All on-time arrivals")
    print(f"  Result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

print("Gondola Scheduler Tests Complete")