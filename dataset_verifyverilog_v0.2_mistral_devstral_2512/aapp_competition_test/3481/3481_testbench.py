import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_dj_polygon_gigs(dut):
    """Test DJ Polygon gig selection optimization"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input 1
    # 3 gigs, 2 venues, 1 road
    # Gigs: (venue, start, end, money)
    # Gig 0: v=0, s=4, e=6, m=6
    # Gig 1: v=0, s=6, e=10, m=5  
    # Gig 2: v=1, s=10, e=30, m=33
    # Dist: dist[0][1] = 10, dist[1][0] = 10, others = 0
    
    dut.total_gigs.value = 3
    dut.total_venues.value = 2
    
    # Distance matrix (8x8 = 64 entries)
    for i in range(64):
        dut.dist_matrix[i].value = 0
    # Self distances are 0, road distance is 10
    dut.dist_matrix[0*8 + 0].value = 0
    dut.dist_matrix[0*8 + 1].value = 10
    dut.dist_matrix[1*8 + 0].value = 10
    dut.dist_matrix[1*8 + 1].value = 0
    # Set others to large value (infinity equivalent)
    for i in range(2):
        for j in range(2, 8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    for i in range(2, 8):
        for j in range(8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    
    # Gig 0
    dut.gig_venue[0].value = 0
    dut.gig_start[0].value = 4
    dut.gig_end[0].value = 6
    dut.gig_money[0].value = 6
    
    # Gig 1
    dut.gig_venue[1].value = 0
    dut.gig_start[1].value = 6
    dut.gig_end[1].value = 10
    dut.gig_money[1].value = 5
    
    # Gig 2
    dut.gig_venue[2].value = 1
    dut.gig_start[2].value = 10
    dut.gig_end[2].value = 30
    dut.gig_money[2].value = 33
    
    # Fill remaining gigs with zeros
    for i in range(3, 16):
        dut.gig_venue[i].value = 0
        dut.gig_start[i].value = 0
        dut.gig_end[i].value = 0
        dut.gig_money[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (allow up to 200,000 cycles)
    timeout = 0
    while not dut.done.value and timeout < 200000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200000:
        raise TestFailure("Test 1: Timeout - computation did not finish in 200000 cycles")
    
    # Check result
    result = int(dut.max_earnings.value)
    expected = 33
    
    print(f"Test 1: Got {result}, Expected {expected}")
    if result != expected:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected}")
    
    await RisingEdge(dut.clk)
    
    # Test Case 2: Sample Input 2
    # 3 gigs, 2 venues, 1 road
    # Gig 0: v=0, s=4, e=6, m=30
    # Gig 1: v=0, s=6, e=10, m=40
    # Gig 2: v=1, s=10, e=30, m=50
    # Expected: 70 (take gigs 0 and 1 at venue 0)
    
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.total_gigs.value = 3
    dut.total_venues.value = 2
    
    # Same distance matrix
    for i in range(64):
        dut.dist_matrix[i].value = 0
    dut.dist_matrix[0*8 + 1].value = 10
    dut.dist_matrix[1*8 + 0].value = 10
    for i in range(2):
        for j in range(2, 8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    for i in range(2, 8):
        for j in range(8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    
    # Gig 0
    dut.gig_venue[0].value = 0
    dut.gig_start[0].value = 4
    dut.gig_end[0].value = 6
    dut.gig_money[0].value = 30
    
    # Gig 1
    dut.gig_venue[1].value = 0
    dut.gig_start[1].value = 6
    dut.gig_end[1].value = 10
    dut.gig_money[1].value = 40
    
    # Gig 2
    dut.gig_venue[2].value = 1
    dut.gig_start[2].value = 10
    dut.gig_end[2].value = 30
    dut.gig_money[2].value = 50
    
    # Fill remaining
    for i in range(3, 16):
        dut.gig_venue[i].value = 0
        dut.gig_start[i].value = 0
        dut.gig_end[i].value = 0
        dut.gig_money[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 200000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200000:
        raise TestFailure("Test 2: Timeout - computation did not finish in 200000 cycles")
    
    result = int(dut.max_earnings.value)
    expected = 70
    
    print(f"Test 2: Got {result}, Expected {expected}")
    if result != expected:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected}")
    
    # Test Case 3: Single gig
    # 1 gig at venue 1, time 0-100, money 500
    # Expected: 500
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.total_gigs.value = 1
    dut.total_venues.value = 1
    
    # Distance matrix (1 venue)
    dut.dist_matrix[0].value = 0
    for i in range(1, 64):
        dut.dist_matrix[i].value = 0xFFFFFFFF
    
    # Gig 0
    dut.gig_venue[0].value = 0
    dut.gig_start[0].value = 0
    dut.gig_end[0].value = 100
    dut.gig_money[0].value = 500
    
    # Fill remaining
    for i in range(1, 16):
        dut.gig_venue[i].value = 0
        dut.gig_start[i].value = 0
        dut.gig_end[i].value = 0
        dut.gig_money[i].value = 0
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 200000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200000:
        raise TestFailure("Test 3: Timeout - computation did not finish in 200000 cycles")
    
    result = int(dut.max_earnings.value)
    expected = 500
    
    print(f"Test 3: Got {result}, Expected {expected}")
    if result != expected:
        raise TestFailure(f"Test 3 failed: got {result}, expected {expected}")
    
    # Test Case 4: Two gigs with travel constraint
    # Gig 0: venue 0, time 0-10, money 100
    # Gig 1: venue 1, time 15-20, money 200
    # Distance 0->1 = 5, so can travel 10+5=15 <= 15: OK
    # Expected: 300
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.total_gigs.value = 2
    dut.total_venues.value = 2
    
    # Distance matrix
    for i in range(64):
        dut.dist_matrix[i].value = 0
    dut.dist_matrix[0*8 + 1].value = 5
    dut.dist_matrix[1*8 + 0].value = 5
    for i in range(2):
        for j in range(2, 8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    for i in range(2, 8):
        for j in range(8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    
    # Gig 0
    dut.gig_venue[0].value = 0
    dut.gig_start[0].value = 0
    dut.gig_end[0].value = 10
    dut.gig_money[0].value = 100
    
    # Gig 1
    dut.gig_venue[1].value = 1
    dut.gig_start[1].value = 15
    dut.gig_end[1].value = 20
    dut.gig_money[1].value = 200
    
    # Fill remaining
    for i in range(2, 16):
        dut.gig_venue[i].value = 0
        dut.gig_start[i].value = 0
        dut.gig_end[i].value = 0
        dut.gig_money[i].value = 0
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 200000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200000:
        raise TestFailure("Test 4: Timeout - computation did not finish in 200000 cycles")
    
    result = int(dut.max_earnings.value)
    expected = 300
    
    print(f"Test 4: Got {result}, Expected {expected}")
    if result != expected:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected}")
    
    # Test Case 5: Insufficient travel time
    # Gig 0: venue 0, time 0-10, money 100
    # Gig 1: venue 1, time 12-20, money 200
    # Distance 0->1 = 5, so can travel 10+5=15 > 12: cannot make it
    # Expected: 200 (just gig 1)
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.total_gigs.value = 2
    dut.total_venues.value = 2
    
    # Distance matrix
    for i in range(64):
        dut.dist_matrix[i].value = 0
    dut.dist_matrix[0*8 + 1].value = 5
    dut.dist_matrix[1*8 + 0].value = 5
    for i in range(2):
        for j in range(2, 8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    for i in range(2, 8):
        for j in range(8):
            dut.dist_matrix[i*8 + j].value = 0xFFFFFFFF
    
    # Gig 0
    dut.gig_venue[0].value = 0
    dut.gig_start[0].value = 0
    dut.gig_end[0].value = 10
    dut.gig_money[0].value = 100
    
    # Gig 1
    dut.gig_venue[1].value = 1
    dut.gig_start[1].value = 12
    dut.gig_end[1].value = 20
    dut.gig_money[1].value = 200
    
    # Fill remaining
    for i in range(2, 16):
        dut.gig_venue[i].value = 0
        dut.gig_start[i].value = 0
        dut.gig_end[i].value = 0
        dut.gig_money[i].value = 0
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 200000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200000:
        raise TestFailure("Test 5: Timeout - computation did not finish in 200000 cycles")
    
    result = int(dut.max_earnings.value)
    expected = 200
    
    print(f"Test 5: Got {result}, Expected {expected}")
    if result != expected:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected}")
    
    print("All 5 tests passed!")
