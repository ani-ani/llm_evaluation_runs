import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_badge_connectivity_basic(dut):
    """Test basic badge connectivity with simple path"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lock_load.value = 0
    dut.lock_next.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 4 rooms, 2 locks
    # Lock 1: Room 1 -> Room 2, badges 100-200
    # Lock 2: Room 2 -> Room 3, badges 150-250
    # Start: Room 1, Dest: Room 3
    # Expected: 51 badges (150-200)
    
    # Load Lock 1
    dut.lock_from.value = 0  # Room 1
    dut.lock_to.value = 1    # Room 2
    dut.lock_range_min.value = 100 * 65536  # Q16.16
    dut.lock_range_max.value = 200 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    # Load Lock 2
    dut.lock_from.value = 1  # Room 2
    dut.lock_to.value = 2    # Room 3
    dut.lock_range_min.value = 150 * 65536
    dut.lock_range_max.value = 250 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    # Set parameters and start
    dut.start_room.value = 0  # Room 1
    dut.dest_room.value = 2   # Room 3
    dut.num_locks.value = 2
    dut.badge_min.value = 0
    dut.badge_max.value = 1000 * 65536
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout waiting for completion")
    
    # Check result: expect 51 badges (150-200 inclusive)
    result = int(dut.valid_badge_count.value)
    expected = 51
    if result != expected:
        raise TestFailure(f"Expected {expected} badges, got {result}")
    print(f"Test 1 passed: {result} valid badges")

@cocotb.test()
async def test_badge_connectivity_no_path(dut):
    """Test case with no valid path"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lock_load.value = 0
    dut.lock_next.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load disjoint locks
    # Lock 1: Room 1 -> Room 2, badges 100-200
    # Lock 2: Room 3 -> Room 4, badges 100-200
    # Start: Room 1, Dest: Room 4 (no path)
    
    dut.lock_from.value = 0
    dut.lock_to.value = 1
    dut.lock_range_min.value = 100 * 65536
    dut.lock_range_max.value = 200 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    dut.lock_from.value = 2
    dut.lock_to.value = 3
    dut.lock_range_min.value = 100 * 65536
    dut.lock_range_max.value = 200 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    dut.start_room.value = 0
    dut.dest_room.value = 3
    dut.num_locks.value = 2
    dut.badge_min.value = 0
    dut.badge_max.value = 1000 * 65536
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout")
    
    result = int(dut.valid_badge_count.value)
    if result != 0:
        raise TestFailure(f"Expected 0 badges for no path, got {result}")
    if not dut.error.value:
        raise TestFailure("Error flag should be set for no path")
    print(f"Test 2 passed: {result} badges, error={dut.error.value}")

@cocotb.test()
async def test_badge_connectivity_disjoint_ranges(dut):
    """Test overlapping badge ranges"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lock_load.value = 0
    dut.lock_next.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Lock 1: Room 1 -> Room 2, badges 100-200
    # Lock 2: Room 2 -> Room 3, badges 300-400
    # Start: Room 1, Dest: Room 3
    # Expected: 0 (disjoint ranges)
    
    dut.lock_from.value = 0
    dut.lock_to.value = 1
    dut.lock_range_min.value = 100 * 65536
    dut.lock_range_max.value = 200 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    dut.lock_from.value = 1
    dut.lock_to.value = 2
    dut.lock_range_min.value = 300 * 65536
    dut.lock_range_max.value = 400 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    dut.start_room.value = 0
    dut.dest_room.value = 2
    dut.num_locks.value = 2
    dut.badge_min.value = 0
    dut.badge_max.value = 1000 * 65536
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout")
    
    result = int(dut.valid_badge_count.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Expected {expected} badges, got {result}")
    print(f"Test 3 passed: {result} valid badges")

@cocotb.test()
async def test_badge_connectivity_same_room(dut):
    """Test same start and dest"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lock_load.value = 0
    dut.lock_next.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # No locks needed, start == dest
    dut.start_room.value = 3
    dut.dest_room.value = 3
    dut.num_locks.value = 0
    dut.badge_min.value = 0
    dut.badge_max.value = 1000 * 65536
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout")
    
    result = int(dut.valid_badge_count.value)
    # All badges valid when staying in same room
    expected = 1001  # 0-1000 range
    if result != expected:
        raise TestFailure(f"Expected {expected} badges, got {result}")
    print(f"Test 4 passed: {result} valid badges")

@cocotb.test()
async def test_badge_connectivity_edge_case(dut):
    """Test with badge range constraints"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lock_load.value = 0
    dut.lock_next.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Lock 1: Room 1 -> Room 2, badges 10-100
    # Lock 2: Room 2 -> Room 3, badges 50-150
    # User range: 30-80
    # Expected: 51 badges (50-80)
    
    dut.lock_from.value = 0
    dut.lock_to.value = 1
    dut.lock_range_min.value = 10 * 65536
    dut.lock_range_max.value = 100 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    dut.lock_from.value = 1
    dut.lock_to.value = 2
    dut.lock_range_min.value = 50 * 65536
    dut.lock_range_max.value = 150 * 65536
    await RisingEdge(dut.clk)
    dut.lock_load.value = 1
    await RisingEdge(dut.clk)
    dut.lock_load.value = 0
    dut.lock_next.value = 1
    await RisingEdge(dut.clk)
    dut.lock_next.value = 0
    
    dut.start_room.value = 0
    dut.dest_room.value = 2
    dut.num_locks.value = 2
    dut.badge_min.value = 30 * 65536
    dut.badge_max.value = 80 * 65536
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Timeout")
    
    result = int(dut.valid_badge_count.value)
    expected = 31  # 50-80 inclusive
    if result != expected:
        raise TestFailure(f"Expected {expected} badges, got {result}")
    print(f"Test 5 passed: {result} valid badges")
