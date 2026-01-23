import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def count_ways_py(c50_total, c100_total, k):
    """Python reference for minimum rides and ways"""
    from collections import deque
    import math
    
    # Precompute combinations
    c = [[0] * 10 for _ in range(10)]
    for i in range(10):
        c[i][0] = 1
        c[i][i] = 1
    for i in range(2, 10):
        for j in range(1, i):
            c[i][j] = c[i-1][j-1] + c[i-1][j]
    
    INF = 10**9
    # d[c50][c100][side] = [ways, min_rides]
    d = [[[[0, INF] for _ in range(2)] for _ in range(c100_total + 1)] for _ in range(c50_total + 1)]
    d[0][0][0][0] = 1
    d[0][0][0][1] = 0
    
    q = deque()
    q.append([0, 0, 0])
    
    while q:
        i, j, shore = q.popleft()
        
        max50 = c50_total - i if shore == 0 else i
        max100 = c100_total - j if shore == 0 else j
        
        for fifty in range(max50 + 1):
            for hundreds in range(max100 + 1):
                if fifty * 50 + hundreds * 100 > k or (fifty + hundreds) == 0:
                    continue
                    
                if shore == 0:
                    i1 = i + fifty
                    j1 = j + hundreds
                else:
                    i1 = i - fifty
                    j1 = j - hundreds
                    
                next_shore = 1 ^ shore
                new_rides = d[i][j][shore][1] + 1
                
                # Update if better path found
                if d[i1][j1][next_shore][1] > new_rides:
                    d[i1][j1][next_shore][1] = new_rides
                    d[i1][j1][next_shore][0] = 0
                    q.append((i1, j1, next_shore))
                    
                if d[i1][j1][next_shore][1] == new_rides:
                    # Count ways
                    if shore == 0:
                        ways = c[c50_total - i][fifty] * c[c100_total - j][hundreds]
                    else:
                        ways = c[i][fifty] * c[j][hundreds]
                    d[i1][j1][next_shore][0] = (d[i1][j1][next_shore][0] + d[i][j][shore][0] * ways) % 1000000007
    
    min_rides = d[c50_total][c100_total][1][1]
    num_ways = d[c50_total][c100_total][1][0]
    
    if min_rides == INF:
        return -1, 0
    return min_rides, num_ways

@cocotb.test()
async def test_boat_crossing_basic(dut):
    """Test basic cases"""
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.weight_encoded.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=1, k=50, weight=50
    dut.n.value = 1
    dut.k.value = 50
    dut.weight_encoded.value = 0b0  # bit0=0 means 50kg
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Should be done"
    assert dut.min_rides.value == 1, f"Expected 1 rides, got {dut.min_rides.value}"
    assert dut.num_ways.value == 1, f"Expected 1 way, got {dut.num_ways.value}"
    print("Test 1 passed: 1 person, 50kg, k=50")
    
    await Timer(100, units='ns')

@cocotb.test()
async def test_boat_crossing_two_fifties(dut):
    """Test 2 people, 50kg each, k=100"""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2 people, both 50kg
    dut.n.value = 2
    dut.k.value = 100
    dut.weight_encoded.value = 0b00  # both 50kg
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    # Should be 1 ride: both go together
    assert dut.min_rides.value == 1, f"Expected 1 ride, got {dut.min_rides.value}"
    assert dut.num_ways.value == 1, f"Expected 1 way, got {dut.num_ways.value}"
    print("Test 2 passed: 2 people, 50kg each, k=100")

@cocotb.test()
async def test_boat_crossing_impossible(dut):
    """Test impossible case: 2 people, 50kg each, k=50"""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 2
    dut.k.value = 50
    dut.weight_encoded.value = 0b00
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    assert dut.min_rides.value == 255, f"Expected 255 (impossible), got {dut.min_rides.value}"
    assert dut.num_ways.value == 0, f"Expected 0 ways, got {dut.num_ways.value}"
    print("Test 3 passed: Impossible case correctly detected")

@cocotb.test()
async def test_boat_crossing_mixed(dut):
    """Test mixed weights: 2x50, 1x100, k=100 (should be impossible)"""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 people: bits 0,1 = 50kg, bit 2 = 100kg
    dut.n.value = 3
    dut.k.value = 100
    dut.weight_encoded.value = 0b100  # 100kg person at bit 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    # Actually should be possible with multiple trips
    print(f"Mixed test: rides={dut.min_rides.value}, ways={dut.num_ways.value}")
    assert dut.min_rides.value != 255 or dut.num_ways.value == 0, "Should be valid or return 0 ways"
    
    # Verify with reference
    c50 = 2
    c100 = 1
    ref_rides, ref_ways = count_ways_py(c50, c100, 100)
    
    if ref_rides != -1:
        assert dut.min_rides.value == ref_rides, f"Mismatch: dut={dut.min_rides.value}, ref={ref_rides}"
        assert dut.num_ways.value == ref_ways, f"Mismatch: dut={dut.num_ways.value}, ref={ref_ways}"
    else:
        assert dut.min_rides.value == 255
        assert dut.num_ways.value == 0
    
    print(f"Mixed test passed: expected {ref_rides} rides, {ref_ways} ways")

@cocotb.test()
async def test_boat_crossing_all_50s(dut):
    """Test 5 people all 50kg, k=150"""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    dut.k.value = 150
    dut.weight_encoded.value = 0b00000  # all 50kg
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    print(f"All 50s test: rides={dut.min_rides.value}, ways={dut.num_ways.value}")
    
    # Verify
    ref_rides, ref_ways = count_ways_py(5, 0, 150)
    if ref_rides != -1:
        assert dut.min_rides.value == ref_rides
        assert dut.num_ways.value == ref_ways
    else:
        assert dut.min_rides.value == 255
        assert dut.num_ways.value == 0

print("All boat crossing tests completed!")