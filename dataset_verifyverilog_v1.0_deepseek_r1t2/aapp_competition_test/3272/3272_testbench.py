import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

# ============================================================================
# GRID ENCODING
# ============================================================================

EMPTY = 0
OBSTACLE = 1
MIRROR_SLASH = 2
MIRROR_BACKSLASH = 3
GARGOYLE_V = 4
GARGOYLE_H = 5

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tomb_raider(dut):
    """Test tomb raider puzzle solver"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Sample 1: 5x5 grid
        {
            'name': 'Sample 1 (5x5, 3 rotations)',
            'grid': [
                [MIRROR_SLASH, EMPTY, GARGOYLE_V, EMPTY, MIRROR_BACKSLASH],
                [EMPTY, MIRROR_SLASH, EMPTY, GARGOYLE_V, EMPTY],
                [EMPTY, EMPTY, OBSTACLE, EMPTY, EMPTY],
                [EMPTY, GARGOYLE_V, EMPTY, OBSTACLE, EMPTY],
                [MIRROR_BACKSLASH, EMPTY, GARGOYLE_V, EMPTY, MIRROR_SLASH]
            ],
            'expected': 3,
            'valid': 1
        },
        # Sample 2: 2x5 grid (no solution)
        {
            'name': 'Sample 2 (2x5, no solution)',
            'grid': [
                [GARGOYLE_V, EMPTY, EMPTY, EMPTY, MIRROR_BACKSLASH],
                [GARGOYLE_H, EMPTY, EMPTY, EMPTY, GARGOYLE_V]
            ],
            'expected': 15,  # 4'hF indicates no solution
            'valid': 0
        },
        # Sample 3: 2x2 all V gargoyles (0 rotations)
        {
            'name': 'Sample 3 (2x2, 0 rotations)',
            'grid': [
                [GARGOYLE_V, GARGOYLE_V],
                [GARGOYLE_V, GARGOYLE_V]
            ],
            'expected': 0,
            'valid': 1
        }
    ]
    
    for test in test_cases:
        dut._log.info(f"Testing: {test['name']}")
        
        # Prepare grid input - pad to 8x8
        grid_padded = [[EMPTY]*8 for _ in range(8)]
        for i in range(len(test['grid'])):
            for j in range(len(test['grid'][i])):
                grid_padded[i][j] = test['grid'][i][j]
        
        # Assign grid to DUT
        for row in range(8):
            for col in range(8):
                # Assuming grid is flattened: grid[row][col]
                if hasattr(dut, 'grid'):
                    dut.grid[row][col].value = grid_padded[row][col]
        
        # Find gargoyle positions and create mask
        gargoyle_mask = 0
        gargoyle_count = 0
        for row in range(8):
            for col in range(8):
                if grid_padded[row][col] in [GARGOYLE_V, GARGOYLE_H]:
                    if gargoyle_count < 4:
                        gargoyle_mask |= (1 << gargoyle_count)
                        gargoyle_count += 1
        
        if hasattr(dut, 'gargoyle_mask'):
            dut.gargoyle_mask.value = gargoyle_mask
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done in {test['name']}")
        
        # Read results
        if is_value_defined(dut.min_rotations.value) and is_value_defined(dut.valid.value):
            result = int(dut.min_rotations.value)
            valid = int(dut.valid.value)
            
            if valid == test['valid']:
                if test['valid'] == 1:
                    if result == test['expected']:
                        dut._log.info(f"  PASS: rotations={result}")
                    else:
                        raise TestFailure(f"Expected {test['expected']}, got {result}")
                else:
                    dut._log.info(f"  PASS: correctly detected no solution")
            else:
                raise TestFailure(f"Valid mismatch: expected {test['valid']}, got {valid}")
        else:
            raise TestFailure("Result signals undefined")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info("All tests completed successfully")
