import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 2
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Grid conversion helper
def grid_to_data(grid):
    """Convert 8x8 grid to 128-bit data."""
    data = 0
    for i in range(8):
        for j in range(8):
            char = grid[i][j]
            if char == '#':
                val = 0
            elif char == '.':
                val = 1
            elif char == 'J':
                val = 2
            elif char == 'F':
                val = 3
            else:
                val = 0
            data |= (val << (i * 16 + j * 2))
    return data

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_maze_escape(dut):
    """Test maze escape module."""
    
    # Initialize
    dut.start.value = 0
    dut.grid_data.value = 0
    dut.rst_n.value = 1
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Example 1 - escape at time 3
    grid1 = [
        "########",
        "####JF##",
        "####..##",
        "####..##",
        "########",
        "########",
        "########",
        "########"
    ]
    grid1_data = grid_to_data(grid1)
    
    # Test case 2: Example 2 - impossible
    grid2 = [
        "########",
        "##J....#",
        "##.F...#",
        "########",
        "########",
        "########",
        "########",
        "########"
    ]
    grid2_data = grid_to_data(grid2)
    
    test_cases = [
        (grid1_data, 3, "Example 1: escape at time 3"),
        (grid2_data, 63, "Example 2: impossible")
    ]
    
    passed = 0
    failed = 0
    
    for grid_data, expected, description in test_cases:
        cocotb.log.info(f"Test: {description}")
        
        # Load grid
        dut.grid_data.value = grid_data
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not dut.done.value and cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= MAX_CYCLES:
            cocotb.log.error(f"  FAIL: Timeout")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Check result
        if result == expected:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
