import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_gl_bot_tracker(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (grid_data, cmd_str, grid_size, start_row, start_col, expected)
    test_cases = [
        (
            # Sample Input 1 (adapted)
            64'h0FFFFFFFFFFFFFF0,  # 8x8 grid (only center passable)
            8'h3E3C3E,             # ASCII '>' '^' '<' '^'
            3'd6,                  # 6x6 grid
            2'd3, 2'd4,            # Start position (row,col)
            2                       # Expected X=2
        ),
        (
            # Sample Input 2
            64'h0FF0F0F0FFFFFFF0,  # 4x4 inner grid 
            8'h766776,             # 'v' '<' '^' '>'
            3'd4,
            2'd1, 2'd1,
            4
        ),
        (
            # Sample Input 3
            64'h0FF0F0F0FFFFFFF0,  # 4x4 grid
            8'h3C3C3C00,           # '<<<'
            3'd4,
            2'd1, 2'd1,
            1                        # Finite trail
        )
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (grid, cmd_str_in, gsize, srow, scol, expected) in enumerate(test_cases):
        # Reset module
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.grid_data.value = grid
        dut.cmd_str.value = cmd_str_in
        dut.grid_size.value = gsize
        dut.start_row.value = srow
        dut.start_col.value = scol
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while (dut.done.value == 0):
            await RisingEdge(dut.clk)
        
        # Check result
        result = dut.result_x.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test {idx+1} passed: {result} (expected {expected})")
        else:
            dut._log.error(f"Test {idx+1} FAILED: Got {result}, expected {expected}")
        
        # Short wait between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total
