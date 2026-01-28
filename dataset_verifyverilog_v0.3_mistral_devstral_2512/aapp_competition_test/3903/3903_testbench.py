import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 3
ARRAY_SIZE = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Grid packing function
def pack_grid(grid_list):
    """Pack 64 3-bit values into 192-bit integer."""
    result = 0
    for i, val in enumerate(grid_list):
        result |= (val & 0x7) << (3*i)
    return result

# State encoding
STATE1 = 1
STATE2 = 2
STATE3 = 3
ROAD = 4
BLOCKED = 5

# Convert string grid to list of integers
def convert_grid(grid_str):
    grid = []
    for row in grid_str:
        for char in row:
            if char == '1':
                grid.append(STATE1)
            elif char == '2':
                grid.append(STATE2)
            elif char == '3':
                grid.append(STATE3)
            elif char == '.':
                grid.append(ROAD)
            elif char == '#':
                grid.append(BLOCKED)
            else:
                grid.append(0)
    # Pad to 64 if needed
    while len(grid) < 64:
        grid.append(BLOCKED)
    return grid[:64]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_three_states(dut):
    """Test three states connection problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (grid_8x8, expected_min_roads, expected_valid, description)
        (
            [
                '11..2...',
                '#..22...',
                '#.323...',
                '.#333...',
                '........',
                '........',
                '........',
                '........'
            ],
            2, True, "Small example from problem"
        ),
        (
            [
                '1#2#3###',
                '########',
                '########',
                '########',
                '########',
                '########',
                '########',
                '########'
            ],
            63, False, "Impossible case"
        ),
        (
            [
                '1.2.3...',
                '........',
                '........',
                '........',
                '........',
                '........',
                '........',
                '........'
            ],
            1, True, "Three states in row with roads"
        ),
        (
            [
                '123.....',
                '........',
                '........',
                '........',
                '........',
                '........',
                '........',
                '........'
            ],
            0, True, "States adjacent - no roads needed"
        ),
        (
            [
                '1###2...',
                '###3###.',
                '########',
                '########',
                '########',
                '########',
                '########',
                '########'
            ],
            4, True, "Complex path required"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid_rows, expected_roads, expected_valid, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Convert grid to packed format
        grid_list = convert_grid(grid_rows)
        grid_packed = pack_grid(grid_list)
        
        # Apply inputs
        dut.grid_flat.value = grid_packed
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done")
        
        # Read results
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Valid signal undefined")
        
        valid = int(dut.valid.value)
        min_roads = int(dut.min_roads.value)
        
        # Convert 63 to -1 for impossible
        if min_roads == 63:
            min_roads = -1
        
        # Check results
        if expected_valid:
            if valid != 1:
                cocotb.log.error(f"  FAIL: Expected valid=1, got {valid}")
                failed += 1
            elif min_roads != expected_roads:
                cocotb.log.error(f"  FAIL: Expected {expected_roads} roads, got {min_roads}")
                failed += 1
            else:
                cocotb.log.info(f"  PASS: Got {min_roads} roads")
                passed += 1
        else:
            if valid != 0:
                cocotb.log.error(f"  FAIL: Expected valid=0 (impossible), got valid={valid}")
                failed += 1
            else:
                cocotb.log.info(f"  PASS: Correctly detected impossible")
                passed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")