import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFF

def float_to_q32_32(value):
    """Convert float to Q32.32 fixed-point representation"""
    return int(value * 4294967296) & 0xFFFFFFFF

def q32_32_to_float(value):
    """Convert Q32.32 to float"""
    return value / 4294967296.0

def compute_expected(roost_x, roost_y, spots):
    """Compute expected minimum distance using Python"""
    n = len(spots)
    if n == 0:
        return 0.0
    
    # Generate all possible pairings
    from itertools import permutations
    
    min_dist = float('inf')
    
    if n % 2 == 0:
        # Even: need n/2 trips, each with 2 spots
        # Generate all permutations, then group into pairs
        spots_indices = list(range(n))
        for perm in permutations(spots_indices):
            valid = True
            total = 0.0
            used = [False] * n
            for i in range(0, n, 2):
                s1_idx = perm[i]
                s2_idx = perm[i+1]
                if used[s1_idx] or used[s2_idx]:
                    valid = False
                    break
                used[s1_idx] = True
                used[s2_idx] = True
                s1 = spots[s1_idx]
                s2 = spots[s2_idx]
                dist = math.sqrt((roost_x - s1[0])**2 + (roost_y - s1[1])**2) + \
                       math.sqrt((s1[0] - s2[0])**2 + (s1[1] - s2[1])**2) + \
                       math.sqrt((s2[0] - roost_x)**2 + (s2[1] - roost_y)**2)
                total += dist
            if valid:
                min_dist = min(min_dist, total)
    else:
        # Odd: need (n+1)/2 trips, one trip with 1 spot
        spots_indices = list(range(n))
        # Try each spot as the single one
        for single_idx in spots_indices:
            remaining = [i for i in spots_indices if i != single_idx]
            for perm in permutations(remaining):
                valid = True
                total = 0.0
                # Add the single trip
                s = spots[single_idx]
                total += 2 * math.sqrt((roost_x - s[0])**2 + (roost_y - s[1])**2)
                used = [False] * n
                used[single_idx] = True
                # Add pair trips
                for i in range(0, len(remaining), 2):
                    s1_idx = perm[i]
                    s2_idx = perm[i+1]
                    if used[s1_idx] or used[s2_idx]:
                        valid = False
                        break
                    used[s1_idx] = True
                    used[s2_idx] = True
                    s1 = spots[s1_idx]
                    s2 = spots[s2_idx]
                    dist = math.sqrt((roost_x - s1[0])**2 + (roost_y - s1[1])**2) + \
                           math.sqrt((s1[0] - s2[0])**2 + (s1[1] - s2[1])**2) + \
                           math.sqrt((s2[0] - roost_x)**2 + (s2[1] - roost_y)**2)
                    total += dist
                if valid:
                    min_dist = min(min_dist, total)
    return min_dist

@cocotb.test()
async def test_fox_hiding_basic(dut):
    """Test basic case with 1 spot"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 10.0, 20.123456 roost, 1 spot at 13.141593, 20.123456
    roost_x = float_to_q16_16(10.0)
    roost_y = float_to_q16_16(20.123456)
    dut.roost_x.value = roost_x
    dut.roost_y.value = roost_y
    dut.num_spots.value = 1
    
    # Set spots
    for i in range(6):
        dut.spots_x[i].value = 0
        dut.spots_y[i].value = 0
    dut.spots_x[0].value = float_to_q16_16(13.141593)
    dut.spots_y[0].value = float_to_q16_16(20.123456)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout waiting for done signal")
    
    # Expected: 3.141593
    result = q32_32_to_float(int(dut.min_distance.value))
    expected = 3.141593
    
    print(f"Test 1 - Result: {result:.6f}, Expected: {expected:.6f}")
    assert abs(result - expected) < 1e-6, f"Result {result} != expected {expected}"

@cocotb.test()
async def test_fox_hiding_four_spots(dut):
    """Test with 4 spots"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 5.0, 5.0 roost, 4 spots
    roost_x = float_to_q16_16(5.0)
    roost_y = float_to_q16_16(5.0)
    dut.roost_x.value = roost_x
    dut.roost_y.value = roost_y
    dut.num_spots.value = 4
    
    spots = [(2.0, 9.0), (14.0, 17.0), (6.5, 3.0), (14.0, 18.5)]
    for i in range(6):
        dut.spots_x[i].value = 0
        dut.spots_y[i].value = 0
    for i, (x, y) in enumerate(spots):
        dut.spots_x[i].value = float_to_q16_16(x)
        dut.spots_y[i].value = float_to_q16_16(y)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout waiting for done signal")
    
    result = q32_32_to_float(int(dut.min_distance.value))
    expected = compute_expected(5.0, 5.0, spots)
    
    print(f"Test 2 - Result: {result:.6f}, Expected: {expected:.6f}")
    assert abs(result - expected) < 1e-5, f"Result {result} != expected {expected}"

@cocotb.test()
async def test_fox_hiding_edge_cases(dut):
    """Test edge cases: identical spots, zero distance"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: 2 spots at same location
    roost_x = float_to_q16_16(0.0)
    roost_y = float_to_q16_16(0.0)
    dut.roost_x.value = roost_x
    dut.roost_y.value = roost_y
    dut.num_spots.value = 2
    
    for i in range(6):
        dut.spots_x[i].value = 0
        dut.spots_y[i].value = 0
    dut.spots_x[0].value = float_to_q16_16(10.0)
    dut.spots_y[0].value = float_to_q16_16(0.0)
    dut.spots_x[1].value = float_to_q16_16(10.0)
    dut.spots_y[1].value = float_to_q16_16(0.0)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout waiting for done signal")
    
    result = q32_32_to_float(int(dut.min_distance.value))
    # Trip: roost->s1->s2->roost: 10 + 0 + 10 = 20
    expected = 20.0
    
    print(f"Test 3 - Result: {result:.6f}, Expected: {expected:.6f}")
    assert abs(result - expected) < 1e-5, f"Result {result} != expected {expected}"

@cocotb.test()
async def test_fox_hiding_three_spots(dut):
    """Test with 3 spots (odd number)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 spots
    roost_x = float_to_q16_16(0.0)
    roost_y = float_to_q16_16(0.0)
    dut.roost_x.value = roost_x
    dut.roost_y.value = roost_y
    dut.num_spots.value = 3
    
    for i in range(6):
        dut.spots_x[i].value = 0
        dut.spots_y[i].value = 0
    dut.spots_x[0].value = float_to_q16_16(3.0)
    dut.spots_y[0].value = float_to_q16_16(4.0)
    dut.spots_x[1].value = float_to_q16_16(6.0)
    dut.spots_y[1].value = float_to_q16_16(8.0)
    dut.spots_x[2].value = float_to_q16_16(5.0)
    dut.spots_y[2].value = float_to_q16_16(0.0)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout waiting for done signal")
    
    result = q32_32_to_float(int(dut.min_distance.value))
    spots = [(3.0, 4.0), (6.0, 8.0), (5.0, 0.0)]
    expected = compute_expected(0.0, 0.0, spots)
    
    print(f"Test 4 - Result: {result:.6f}, Expected: {expected:.6f}")
    assert abs(result - expected) < 1e-5, f"Result {result} != expected {expected}"

@cocotb.test()
async def test_fox_hiding_zero_spots(dut):
    """Test with 0 spots"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 0 spots
    roost_x = float_to_q16_16(10.0)
    roost_y = float_to_q16_16(20.0)
    dut.roost_x.value = roost_x
    dut.roost_y.value = roost_y
    dut.num_spots.value = 0
    
    for i in range(6):
        dut.spots_x[i].value = 0
        dut.spots_y[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout waiting for done signal")
    
    result = q32_32_to_float(int(dut.min_distance.value))
    expected = 0.0
    
    print(f"Test 5 - Result: {result:.6f}, Expected: {expected:.6f}")
    assert abs(result - expected) < 1e-6, f"Result {result} != expected {expected}"

print("
=== Fox Hiding Optimizer Test Summary ===")
print("Tests completed. Check individual test results above.")