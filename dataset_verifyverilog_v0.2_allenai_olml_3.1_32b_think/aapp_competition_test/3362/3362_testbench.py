import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_lava_game(dut):
    """Test the Lava Game module with various scenarios"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.A.value = 0
    dut.F.value = 0
    dut.map_data.value = 0
    dut.map_index.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: GO FOR IT - Elsa wins
    # Map 4x4 (padded to 8x8):
    # WWWW
    # WSBB
    # WWWW
    # WBWG
    # A=2 (0x00020000 in Q16.16), F=3 (0x00030000)
    # Elsa can reach G in 2 steps, father in 3 steps
    
    dut.A.value = 0x00020000  # 2.0 in Q16.16
    dut.F.value = 0x00030000  # 3.0 in Q16.16
    
    # Load map (8x8 = 64 tiles)
    # Row 0: W W W W W W W W
    # Row 1: W S B B W W W W
    # Row 2: W W W W W W W W
    # Row 3: W B W G W W W W
    # Rows 4-7: All W
    map_tiles = [
        0, 0, 0, 0, 0, 0, 0, 0,  # Row 0: W W W W...
        0, 2, 1, 1, 0, 0, 0, 0,  # Row 1: W S B B...
        0, 0, 0, 0, 0, 0, 0, 0,  # Row 2: W W W W...
        0, 1, 0, 3, 0, 0, 0, 0,  # Row 3: W B W G...
        0, 0, 0, 0, 0, 0, 0, 0,  # Row 4-7: All W
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    
    for i in range(64):
        dut.map_index.value = i
        dut.map_data.value = map_tiles[i]
        await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (up to 500 cycles)
    max_cycles = 500
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Computation did not complete within timeout")
    
    # Expected: GO FOR IT = 2
    if dut.result.value != 2:
        raise TestFailure(f"Test 1 failed: Expected GO FOR IT (2), got {dut.result.value}")
    print("Test 1 passed: GO FOR IT")
    
    # Test Case 2: SUCCESS - Both reach at same time
    # Map 1x2: GS
    # A=1 (0x00010000), F=1 (0x00010000)
    # Both can reach G in 1 step
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.A.value = 0x00010000
    dut.F.value = 0x00010000
    
    # Load 1x2 map padded to 8x8
    map_tiles = [
        3, 2, 0, 0, 0, 0, 0, 0,  # Row 0: G S W W...
        0, 0, 0, 0, 0, 0, 0, 0,  # Rest are W
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    
    for i in range(64):
        dut.map_index.value = i
        dut.map_data.value = map_tiles[i]
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 500
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Computation did not complete within timeout")
    
    # Expected: SUCCESS = 3
    if dut.result.value != 3:
        raise TestFailure(f"Test 2 failed: Expected SUCCESS (3), got {dut.result.value}")
    print("Test 2 passed: SUCCESS")
    
    # Test Case 3: NO WAY - Both cannot reach
    # Map 2x2: SB, BB
    # A=1, F=1
    # Goal blocked by lava
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.A.value = 0x00010000
    dut.F.value = 0x00010000
    
    map_tiles = [
        2, 1, 0, 0, 0, 0, 0, 0,  # Row 0: S B W W...
        1, 1, 0, 0, 0, 0, 0, 0,  # Row 1: B B W W...
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    
    for i in range(64):
        dut.map_index.value = i
        dut.map_data.value = map_tiles[i]
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 500
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Computation did not complete within timeout")
    
    # Expected: NO WAY = 0
    if dut.result.value != 0:
        raise TestFailure(f"Test 3 failed: Expected NO WAY (0), got {dut.result.value}")
    print("Test 3 passed: NO WAY")
    
    # Test Case 4: NO CHANCE - Father wins
    # Map 3x3:
    # S W W
    # B B W
    # B B G
    # A=1.4 (0x00016666), F=3 (0x00030000)
    # Father can move through longer path, Elsa limited
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.A.value = 0x00016666  # ~1.4 in Q16.16
    dut.F.value = 0x00030000  # 3.0
    
    map_tiles = [
        2, 0, 0, 0, 0, 0, 0, 0,  # Row 0: S W W...
        1, 1, 0, 0, 0, 0, 0, 0,  # Row 1: B B W...
        1, 1, 3, 0, 0, 0, 0, 0,  # Row 2: B B G W...
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    
    for i in range(64):
        dut.map_index.value = i
        dut.map_data.value = map_tiles[i]
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 500
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Computation did not complete within timeout")
    
    # Expected: NO CHANCE = 1
    if dut.result.value != 1:
        raise TestFailure(f"Test 4 failed: Expected NO CHANCE (1), got {dut.result.value}")
    print("Test 4 passed: NO CHANCE")
    
    print("
=== Test Summary ===")
    print("All 4 tests passed!")
    print("Results: 0=NO WAY, 1=NO CHANCE, 2=GO FOR IT, 3=SUCCESS")
