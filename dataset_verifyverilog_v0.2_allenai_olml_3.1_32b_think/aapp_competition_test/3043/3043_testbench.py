import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

# Helper to pack grid for the DUT
def pack_grid(grid_str):
    # Grid is 8x8, flattened into 64 entries
    lines = grid_str.strip().split('
')
    # Pad to 8x8 if needed, though inputs will be scaled
    packed = []
    # Flatten and pad
    flat = []
    for line in lines:
        for char in line:
            flat.append(ord(char))
    # Pad with '.' (0x2E) to fill 64 bytes
    while len(flat) < 64:
        flat.append(0x2E) # plain
    return flat

@cocotb.test()
async def test_treasure_hunter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.K.value = 0
    # Initialize grid to plain
    for i in range(64):
        dut.grid[i].value = 0x2E
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample 1
    # 2 5 4
    # S#.F.
    # .MFMG
    # Scaled to 8x8 (we assume padding, but the path is in the top left)
    # S at (0,0), G at (1,4)
    # Path: (0,0) -> (0,1) is wall -> down to (1,0) -> (1,1) M -> (1,2) F -> (1,3) M -> (1,4) G
    # Costs: (1,0): . cost 1, cur_stam 3. (1,1): M cost 3, cur_stam 0. Rest required.
    # Next day: start (1,1). (1,2): F cost 2, cur_stam 2. (1,3): M cost 3 -> wait. (1,0): . cost 1.
    # Actually, optimal path: (0,0) -> (1,0) -> (1,1) [Cost 1+3=4, Reset]. Day 2 start at (1,1).
    # From (1,1): -> (1,2) [Cost 2, curr 2]. -> (1,3) [Cost 3, can't]. -> (0,1) wall.
    # So we are at (1,2) end of day 2. Day 3 start at (1,2).
    # From (1,2): -> (1,3) [Cost 3, curr 1]. -> (1,4) [Cost 1, curr 0]. Reached G. Day 3.
    
    grid1 = [
        "S#.F....",
        ".MFMG...",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........"
    ]
    grid_flat = pack_grid("
".join(grid1))
    for i, val in enumerate(grid_flat):
        dut.grid[i].value = val
    
    dut.K.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Test 1: Did not finish"
    assert dut.impossible.value == 0, "Test 1: Incorrectly marked impossible"
    assert dut.days.value == 3, f"Test 1: Expected 3 days, got {dut.days.value}"
    print(f"Test 1 Passed: {dut.days.value} days")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Sample 2
    # 1 2 1
    # GS
    # Scaled: G and S adjacent.
    # S at (0,1), G at (0,0). Path length 1.
    # Cost to move to G (plain): 1. K=1. Reachable in 1 day.
    grid2 = [
        "GS......",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........"
    ]
    grid_flat = pack_grid("
".join(grid2))
    for i, val in enumerate(grid_flat):
        dut.grid[i].value = val
    
    dut.K.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Test 2: Did not finish"
    assert dut.impossible.value == 0, "Test 2: Incorrectly marked impossible"
    assert dut.days.value == 1, f"Test 2: Expected 1 day, got {dut.days.value}"
    print(f"Test 2 Passed: {dut.days.value} days")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: Sample 3
    # 2 2 10
    # S#
    # #G
    # Scaled: S at (0,0), G at (1,1). Walls in between.
    grid3 = [
        "S#......",
        "#G......",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........"
    ]
    grid_flat = pack_grid("
".join(grid3))
    for i, val in enumerate(grid_flat):
        dut.grid[i].value = val
    
    dut.K.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Test 3: Did not finish"
    assert dut.impossible.value == 1, f"Test 3: Should be impossible, got {dut.impossible.value}"
    print(f"Test 3 Passed: Impossible")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 4: Sample 4
    # 1 7 4
    # SMMMMMG
    # Scaled: S at (0,0), G at (0,6).
    # Path: S -> M(1) -> M(2) -> M(3) -> M(4) -> M(5) -> G(6)
    # Costs: 1+3, 1+3, 1+3... Path length 6. Each M costs 3.
    # K=4. Can move 1 M per day (cost 3, 1 stamina left, can't move next M).
    # So 6 mountains = 6 days? Wait, let's re-calculate.
    # Day 1: S->M (cost 3). St=1. Rest needed.
    # Day 2: Start at M->M (cost 3). St=1. Rest.
    # ... 5 mountains = 5 days. Move to G costs 1. 
    # Day 6: Start at M->G (cost 1). St=3. Reach G. Total 6 days? 
    # Wait, check example output 5.
    # S M M M M M G. 
    # Day 1: S->M (cost 3). 
    # Day 2: M->M (cost 3).
    # Day 3: M->M (cost 3).
    # Day 4: M->M (cost 3).
    # Day 5: M->M (cost 3). Now at 5th M. G is next.
    # Day 5: From 5th M -> G (cost 1). Day 5.
    # Yes, 5 days.
    grid4 = [
        "SMMMMMG.",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........"
    ]
    grid_flat = pack_grid("
".join(grid4))
    for i, val in enumerate(grid_flat):
        dut.grid[i].value = val
    
    dut.K.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Test 4: Did not finish"
    assert dut.impossible.value == 0, "Test 4: Incorrectly marked impossible"
    assert dut.days.value == 5, f"Test 4: Expected 5 days, got {dut.days.value}"
    print(f"Test 4 Passed: {dut.days.value} days")
    
    print("All tests passed!")
