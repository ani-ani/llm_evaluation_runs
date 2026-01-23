import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_vertex_cover_simple(dut):
    """Test with 2 teams - friend in one team"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.team_valid.value = 0
    dut.team_done.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input teams: (1009, 2011) and (1017, 2011)
    # Expected output: 1 person (2011)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Team 1
    dut.team_stockholm.value = 1009
    dut.team_london.value = 2011
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    # Team 2
    dut.team_stockholm.value = 1017
    dut.team_london.value = 2011
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_valid.value = 0
    dut.team_done.value = 1
    await RisingEdge(dut.clk)
    dut.team_done.value = 0
    
    # Wait for computation
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    if dut.result_valid.value != 1:
        raise TestFailure("Result valid not asserted")
    
    count = int(dut.result_count.value)
    print(f"Result count: {count}")
    assert count == 1, f"Expected 1 invitee, got {count}"
    
    # Get result IDs
    ids = []
    for i in range(count):
        ids.append(int(dut.result_ids[i].value))
    print(f"Invitees: {ids}")
    assert 2011 in ids, f"Expected 2011 in results, got {ids}"
    print("Test 1 passed!")

@cocotb.test()
async def test_vertex_cover_with_friend(dut):
    """Test with 4 teams - verify friend inclusion when possible"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.team_valid.value = 0
    dut.team_done.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: (1009,2000), (1009,2001), (1002,2002), (1003,2002)
    # Expected: 2 invitees, ideally {2002, 1009}
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.team_stockholm.value = 1009
    dut.team_london.value = 2000
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1009
    dut.team_london.value = 2001
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1002
    dut.team_london.value = 2002
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1003
    dut.team_london.value = 2002
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_valid.value = 0
    dut.team_done.value = 1
    await RisingEdge(dut.clk)
    dut.team_done.value = 0
    
    # Wait for computation
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    if dut.result_valid.value != 1:
        raise TestFailure("Result valid not asserted")
    
    count = int(dut.result_count.value)
    print(f"Result count: {count}")
    assert count == 2, f"Expected 2 invitees, got {count}"
    
    ids = []
    for i in range(count):
        ids.append(int(dut.result_ids[i].value))
    ids.sort()
    print(f"Invitees: {ids}")
    
    # Must cover all edges
    # Edge 1: 1009-2000, Edge 2: 1009-2001, Edge 3: 1002-2002, Edge 4: 1003-2002
    # Cover: {2002, 1009} works
    assert 1009 in ids or 2000 in ids or 2001 in ids, "Missing coverage for first two edges"
    assert 1009 in ids or 2002 in ids, "Missing coverage for last two edges"
    assert len(ids) == 2, f"Should have 2 invitees, got {len(ids)}"
    assert 1009 in ids, "Friend (1009) should be included if possible"
    print("Test 2 passed!")

@cocotb.test()
async def test_vertex_cover_multiple_selections(dut):
    """Test with 3 teams forming chain"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.team_valid.value = 0
    dut.team_done.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Teams: (1000,2000), (1001,2000), (1009,2001)
    # Expected: 2 people needed
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.team_stockholm.value = 1000
    dut.team_london.value = 2000
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1001
    dut.team_london.value = 2000
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1009
    dut.team_london.value = 2001
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_valid.value = 0
    dut.team_done.value = 1
    await RisingEdge(dut.clk)
    dut.team_done.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done not asserted")
    
    count = int(dut.result_count.value)
    print(f"Result count: {count}")
    assert count <= 3, f"Reasonable count, got {count}"
    
    ids = []
    for i in range(count):
        ids.append(int(dut.result_ids[i].value))
    print(f"Invitees: {ids}")
    
    # Verify coverage
    edge1_cov = (1000 in ids) or (2000 in ids)
    edge2_cov = (1001 in ids) or (2000 in ids)
    edge3_cov = (1009 in ids) or (2001 in ids)
    assert edge1_cov and edge2_cov and edge3_cov, "Not all edges covered"
    print("Test 3 passed!")

@cocotb.test()
async def test_vertex_cover_single_team(dut):
    """Test with just one team"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.team_valid.value = 0
    dut.team_done.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.team_stockholm.value = 1009
    dut.team_london.value = 2050
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_valid.value = 0
    dut.team_done.value = 1
    await RisingEdge(dut.clk)
    dut.team_done.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    count = int(dut.result_count.value)
    assert count == 1, f"1 invitee expected, got {count}"
    
    ids = [int(dut.result_ids[0].value)]
    print(f"Invitees: {ids}")
    # Either 1009 or 2050 works, prefer 1009 if possible
    print("Test 4 passed!")

@cocotb.test()
async def test_vertex_cover_edge_case_high_ids(dut):
    """Test with high ID employees"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.team_valid.value = 0
    dut.team_done.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Teams: (1015,2015), (1015,2016), (1016,2016)
    dut.team_stockholm.value = 1015
    dut.team_london.value = 2015
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1015
    dut.team_london.value = 2016
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_stockholm.value = 1016
    dut.team_london.value = 2016
    dut.team_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.team_valid.value = 0
    dut.team_done.value = 1
    await RisingEdge(dut.clk)
    dut.team_done.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    count = int(dut.result_count.value)
    print(f"Result count: {count}")
    assert count == 2, f"Expected 2, got {count}"
    
    ids = []
    for i in range(count):
        ids.append(int(dut.result_ids[i].value))
    print(f"Invitees: {ids}")
    
    # Cover check: edges (1015,2015), (1015,2016), (1016,2016)
    # {2016} only covers 2 edges, need more
    # {1015, 2016} works (covers all)
    cov1 = (1015 in ids) or (2015 in ids)
    cov2 = (1015 in ids) or (2016 in ids)
    cov3 = (1016 in ids) or (2016 in ids)
    assert cov1 and cov2 and cov3, "Coverage incomplete"
    print("Test 5 passed!")