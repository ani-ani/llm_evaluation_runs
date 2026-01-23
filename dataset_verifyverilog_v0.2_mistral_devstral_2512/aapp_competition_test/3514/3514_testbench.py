import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_bomb_disarm(dut):
    """Test maximum disarmed buildings calculation"""
    
    # Helper to set grid from string
    def set_grid(grid_str):
        rows = grid_str.strip().split('
')
        for r in range(8):
            for c in range(8):
                if r < len(rows) and c < len(rows[0]):
                    val = 1 if rows[r][c] == 'x' else 0
                else:
                    val = 0
                # Set individual bits of grid array
                # Verilog: reg [7:0] grid [0:7][0:7]
                # In cocotb, we access as dut.grid[r][c]
                dut.grid[r][c].value = val
    
    # Test 1: Original example 3x3 - x.. .x. x.x
    # Expected: 2 (can disarm 2 buildings)
    dut._log.info("Test 1: Original 3x3 example")
    set_grid("""
x..
.x.
x.x
""".strip())
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 2")
    assert result == 2, f"Test 1 failed: got {result}, expected 2"
    
    # Test 2: Second example 3x4 - .xx. x... x..x
    # Expected: 3
    dut._log.info("Test 2: Second example 3x4")
    set_grid("""
.xx.
x...
x..x
""".strip())
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 3")
    assert result == 3, f"Test 2 failed: got {result}, expected 3"
    
    # Test 3: All isolated - 2x2 with single bombs
    # x. .x - cannot disarm any
    dut._log.info("Test 3: All isolated bombs")
    set_grid("""
x.
.x
"".strip())
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 0")
    assert result == 0, f"Test 3 failed: got {result}, expected 0"
    
    # Test 4: Single row with 3 bombs - xxx
    # All can be disarmed: 3
    dut._log.info("Test 4: Single row with 3 bombs")
    set_grid("xxx")
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 3")
    assert result == 3, f"Test 4 failed: got {result}, expected 3"
    
    # Test 5: Single bomb
    dut._log.info("Test 5: Single bomb")
    set_grid("x")
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 0")
    assert result == 0, f"Test 5 failed: got {result}, expected 0"
    
    # Test 6: Complete 2x2 grid
    # All bombs, each has row and col count 2
    # Can disarm 3 (one remains as cover for the last)
    dut._log.info("Test 6: Complete 2x2 grid")
    set_grid("xx
xx")
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 3")
    assert result == 3, f"Test 6 failed: got {result}, expected 3"
    
    # Test 7: Empty grid
    dut._log.info("Test 7: Empty grid")
    set_grid("")
    await Timer(10, units='ns')
    result = int(dut.max_disarmed.value)
    dut._log.info(f"Result: {result}, Expected: 0")
    assert result == 0, f"Test 7 failed: got {result}, expected 0"
    
    print(f"
All tests passed!")