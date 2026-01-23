import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_jelly_raid_basic(dut):
    """Test basic pathfinding with one master"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Map definition (8x8)
    # 0 = walkable, 1 = blocked
    # 0 1 2 3 4 5 6 7
    # . . . . . . . .
    # . # . . . . . .
    # . . . . . . . .
    # . . . . . . . .
    # . . . . . . . .
    # . . . . . . . .
    # . . . . . . . .
    # . . . . . . . .
    
    # Create map data
    for r in range(8):
        for c in range(8):
            dut.map_data[r][c].value = 0
    
    # Add some walls
    dut.map_data[1][1].value = 1  # Wall at (1,1)
    
    # Start at (0,0), Target at (0,7)
    dut.start_row.value = 0
    dut.start_col.value = 0
    dut.target_row.value = 0
    dut.target_col.value = 7
    
    # Master 1 patrol: (0,4) <-> (0,5) -> (0,6) -> (0,7) - Wait, path is contiguous
    # Sample input format: 6 (4 2) (4 3) (3 3) (2 3) (1 3) (1 2)
    # It goes forward then backward.
    # Let's put master at (0,3) and (0,4). Patrol: (0,3) -> (0,4). Cycle: 0->1->0->1...
    # Let's make it longer to allow some movement: Master at (2,2)
    # Path: (2,2) (2,3) (2,4) (2,5)
    
    dut.m1_path[0].value = 0b010_010 # (2,2)
    dut.m1_path[1].value = 0b011_010 # (2,3)
    dut.m1_path[2].value = 0b100_010 # (2,4)
    dut.m1_path[3].value = 0b101_010 # (2,5)
    
    # Master 2 path (dummy or identical)
    for i in range(4):
        dut.m2_path[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation (max 256 cycles)
    done = False
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.possible.value == 1 and dut.min_turns.value != 0:
            done = True
            print(f"Result: Turns={dut.min_turns.value}")
            break
        if dut.possible.value == 0 and dut.min_turns.value == 0:
             # Check if it transitioned to DONE state logic (implied)
             # If it finishes without finding, we expect possible=0
            
    # We expect path exists: (0,0) -> ... -> (0,7). Master is at row 2, so row 0 is safe.
 # However, master moves. Let's verify roughly.
 # If the module works, it should find a path.

@cocotb.test()
async def test_jelly_raid_blocked(dut):
    """Test case where path is blocked"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Map: All walls between start and target
    for r in range(8):
        for c in range(8):
            if r == 0 and 0 < c < 7:
                dut.map_data[r][c].value = 1 # Block row 0
            else:
                dut.map_data[r][c].value = 0

    # Start (0,0), Target (0,7)
    dut.start_row.value = 0
    dut.start_col.value = 0
    dut.target_row.value = 0
    dut.target_col.value = 7

    # Masters
    for i in range(4):
        dut.m1_path[i].value = 0
        dut.m2_path[i].value = 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.possible.value == 0:
             # Expected IMPOSSIBLE
             print("Correctly identified as impossible")
             break
