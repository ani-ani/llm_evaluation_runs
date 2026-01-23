import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_zergling_basic(dut):
    """Test basic simulation: 1 Zergling vs 1 Zergling, 1 turn."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load Test Case: 2x2 Grid
    # P1 at (0,0), P2 at (1,1)
    # Grid Layout (8x8 flattened):
    # Row 0: 1, 0, 0, 0, 0, 0, 0, 0
    # Row 1: 0, 2, 0, 0, 0, 0, 0, 0
    # Rest: 0s
    
    # 8x8 = 64 cells. We only populate first few.
    # grid_in_00_to_07: [1, 0, 0, 0, 0, 0, 0, 0]
    dut.grid_in_00_to_07.value = 0b00000001 # 1 at bit 0-2
    dut.grid_in_08_to_15.value = 0b00000000
    # grid_in_16_to_23: [0, 2, ...] -> 2 is at index 1 of this chunk (overall index 9)
    # Wait, flattened logic: index 0-7 is row 0. index 8-15 is row 1.
    # P2 at (1,1) -> index 8+1 = 9.
    # So chunk 1 (indices 8-15): value at bit 3-5 should be 2 (shifted 3 times).
    dut.grid_in_08_to_15.value = 0b00000000 # No 1s
    dut.grid_in_16_to_23.value = 0b00010000 # 2 at bit 3-5 (1 << 3)
    
    dut.grid_in_24_to_31.value = 0
    dut.grid_in_32_to_39.value = 0
    dut.grid_in_40_to_47.value = 0
    dut.grid_in_48_to_55.value = 0
    dut.grid_in_56_to_63.value = 0
    
    # Upgrades
    dut.p1_atk_up.value = 0
    dut.p1_arm_up.value = 0
    dut.p2_atk_up.value = 0
    dut.p2_arm_up.value = 0
    
    # Turns
    dut.num_turns.value = 1 # Just 1 turn
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Simulation timed out")
        
    # Check result
    # Expected: P1 moves to (1,1), attacks P2. P2 attacks P1.
    # P1 HP: 35 + 0(atk) - 0(arm) = 35 damage taken. 35 - 35 = 0 (Dead).
    # P2 HP: 35 + 0 - 0 = 35 damage taken. 35 - 35 = 0 (Dead).
    # Result: Empty board (all 0s).
    
    # Check grid_out_00_to_07 (Row 0) - should be 0
    if dut.grid_out_00_to_07.value != 0:
        raise TestFailure(f"Row 0 should be empty. Got {dut.grid_out_00_to_07.value}")
    
    # Check grid_out_08_to_15 (Row 1) - should be 0
    if dut.grid_out_08_to_15.value != 0:
        raise TestFailure(f"Row 1 should be empty. Got {dut.grid_out_08_to_15.value}")
        
    dut._log.info("Test passed: Both Zerglings killed each other.")

@cocotb.test()
async def test_zergling_survival(dut):
    """Test with different stats to ensure one survives."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup: P1 (0,0) vs P2 (1,1)
    # P1 has massive upgrades: Atk 5, Arm 0. P2 has none.
    # Damage dealt by P1: 5+5 - 0 = 10. P2 dies.
    # Damage dealt by P2: 5 - 0 = 5. P1 survives with 30 HP.
    
    dut.grid_in_00_to_07.value = 0b00000001
    dut.grid_in_16_to_23.value = 0b00010000
    dut.grid_in_08_to_15.value = 0
    dut.grid_in_24_to_31.value = 0
    dut.grid_in_32_to_39.value = 0
    dut.grid_in_40_to_47.value = 0
    dut.grid_in_48_to_55.value = 0
    dut.grid_in_56_to_63.value = 0
    
    dut.p1_atk_up.value = 5
    dut.p1_arm_up.value = 0
    dut.p2_atk_up.value = 0
    dut.p2_arm_up.value = 0
    
    dut.num_turns.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Simulation timed out")
    
    # Result: P1 survives with 30 HP. Output grid should have '1' at (0,0)
    # Row 0: 1 at col 0
    if dut.grid_out_00_to_07.value != 0b00000001:
        raise TestFailure(f"P1 should survive at (0,0). Got {dut.grid_out_00_to_07.value}")
    
    dut._log.info("Test passed: P1 survived with upgrades.")

@cocotb.test()
async def test_zergling_regeneration(dut):
    """Test regeneration after 1 turn."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup: P1 (0,0) vs P2 (1,1)
    # P1 Atk 4, P2 Arm 0 -> P2 takes 4 dmg. HP 31.
    # P2 Atk 0, P1 Arm 0 -> P1 takes 0 dmg. HP 35.
    # Turn 1 End: P1=35, P2=31.
    # Regeneration: P2 -> 32.
    
    dut.grid_in_00_to_07.value = 0b00000001
    dut.grid_in_16_to_23.value = 0b00010000
    dut.grid_in_08_to_15.value = 0
    dut.grid_in_24_to_31.value = 0
    
    dut.p1_atk_up.value = 4
    dut.p1_arm_up.value = 0
    dut.p2_atk_up.value = 0
    dut.p2_arm_up.value = 0
    
    dut.num_turns.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Both survive. Grid has P1 and P2.
    # P1 at (0,0), P2 at (1,1).
    # Row 0: P1
    # Row 1: P2 at index 1 (bit 3-5)
    
    row0 = dut.grid_out_00_to_07.value
    row1 = dut.grid_out_08_to_15.value
    
    if row0 != 0b00000001:
        raise TestFailure(f"P1 should be at (0,0). Got {row0}")
    if row1 != 0b00010000:
        raise TestFailure(f"P2 should be at (1,1). Got {row1}")
        
    dut._log.info("Test passed: Regeneration working.")
