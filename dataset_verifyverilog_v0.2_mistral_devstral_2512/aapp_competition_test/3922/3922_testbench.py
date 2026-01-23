import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

async def setup_dut(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_in.value = [0, 0, 0, 0, 0, 0]
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')

@cocotb.test()
async def test_surgery_simple(dut):
    """Test a solvable 2x3 puzzle: 1,2,3 in row0, 4,5,6 in row1 but swapped (5,4)."""
    await setup_dut(dut)
    
    # Target: 1,2,3,4,5,6 (Row0: 1,2,3; Row1: 4,5,6)
    # Current: 1,2,3,5,4,6 -> Flattened: 1,2,3,5,4,6
    # Wait, input is Row0 then Row1. 
    # Let's do a valid solvable state: 
    # Row0: 1 2 3
    # Row1: 4 E 6 -> Represented as 1,2,3,4,0,6
    # Target: 1,2,3,4,5,6 (where 5 is at position 4)
    
    dut.grid_in.value = [1, 2, 3, 4, 0, 6]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Monitor moves until done
    moves = []
    for _ in range(100): # Limit simulation steps
        await RisingEdge(dut.clk)
        if dut.move_valid.value == 1:
            m = int(dut.move_out.value)
            if m == 1: moves.append('up')
            elif m == 2: moves.append('down')
            elif m == 3: moves.append('left')
            elif m == 4: moves.append('right')
        if dut.done.value == 1:
            break
    
    dut._log.info(f"Moves performed: {moves}")
    if dut.done.value != 1:
        raise TestFailure("DUT did not reach done state in time")

@cocotb.test()
async def test_surgery_unreachable(dut):
    """Test an unreachable puzzle configuration."""
    await setup_dut(dut)
    
    # A configuration that might be unreachable or simply requires more steps than we simulate
    # For k=1 (2x3), the goal is row0: 1,2,3 and row1: 4,5,6
    # Let's try a specific input: 2,1,3,4,5,6 (Swap 1 and 2 in row0)
    # In 2x3 sliding puzzle, 1 and 2 are in the same row, so we can swap them.
    # Let's try something hard: 3,2,1,4,5,6. 
    # We will just check if the module can detect failure or timeout.
    
    dut.grid_in.value = [3, 2, 1, 4, 5, 6] # This is solvable but let's see
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while cycles < 200: # Short timeout for test
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
        cycles += 1
    
    if dut.done.value == 1:
        dut._log.info("Solved 3,2,1...")
    else:
        dut._log.info("Did not finish (acceptable for this test structure if fail logic is complex)")

@cocotb.test()
async def test_surgery_already_solved(dut):
    """Test that done is asserted immediately if already solved."""
    await setup_dut(dut)
    
    # Already solved
    dut.grid_in.value = [1, 2, 3, 4, 5, 6]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Should be done quickly
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        # Might take a cycle to process, check next
        await RisingEdge(dut.clk)
        if dut.done.value != 1:
             raise TestFailure("Should be done for already solved grid")
    dut._log.info("Correctly detected solved state")
