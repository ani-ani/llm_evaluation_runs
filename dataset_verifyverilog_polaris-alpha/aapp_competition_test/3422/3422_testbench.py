import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.handle import Force
import random

@cocotb.test()
async def test_treasure_map(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1 (Original sample scaled - already fits)
    test_data = {
        'num_pieces': 3,
        'piece_w': [4,2,2],
        'piece_h': [1,2,2],
        'piece_data': [
            [[3, 2, 1, 0]],  # Piece 0: 4x1 '2123' rotated 180
            [[1, 0],         # Piece 1: 2x2 '21
             [3, 2]],           #       '10' rotated 270
            [[2, 1],         # Piece 2: 2x2 '23
             [3, 0]]            #       '12' rotated 90
        ]
    }
    
    # Apply inputs
    dut.num_pieces.value = test_data['num_pieces']
    for i in range(8):
        dut.piece_w[i].value = test_data['piece_w'][i] if i < 3 else 0
        dut.piece_h[i].value = test_data['piece_h'][i] if i < 3 else 0
        for r in range(4):
            for c in range(4):
                val = test_data['piece_data'][i][r][c] if (i < 3 and r < test_data['piece_h'][i] and c < test_data['piece_w'][i]) else 0
                dut.piece_data[i][r][c].value = val
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (timeout after 10k cycles)
    cycles = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 10000:
            assert False, "Timeout waiting for done"
    
    # Check outputs (expected 4x3 map)
    assert dut.map_w.value == 4, f"Expected map width 4, got {dut.map_w.value}"
    assert dut.map_h.value == 3, f"Expected map height 3, got {dut.map_h.value}"
    
    # Expected map data
    expected_map = [
        [2,1,2,3],
        [1,0,1,2],
        [2,1,2,3]
    ]
    for r in range(3):
        for c in range(4):
            actual = dut.solution_grid[r][c].value.integer
            expected = expected_map[r][c]
            assert actual == expected, f"At ({r},{c}): expected {expected}, got {actual}"
    
    # Expected piece grid (matching sample)
    expected_pieces = [
        [2,2,3,3],
        [2,2,3,3], 
        [1,1,1,1]
    ]
    for r in range(3):
        for c in range(4):
            actual = dut.piece_grid[r][c].value.integer
            expected = expected_pieces[r][c] + 1 # Convert to 1-based index
            assert actual == expected, f"Piece at ({r},{c}): expected {expected}, got {actual}"
    
    dut._log.info("1/1 tests passed")
