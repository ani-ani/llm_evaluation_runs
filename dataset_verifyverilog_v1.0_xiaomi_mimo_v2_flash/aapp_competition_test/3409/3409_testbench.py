import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1  # Each cell is 1 bit (1=up, 0=down)
GRID_SIZE = 4   # 4x4 grid
TOTAL_BITS = GRID_SIZE * GRID_SIZE  # 16 bits
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def grid_to_bits(grid_str):
    """Convert 4x4 string grid to 16-bit integer."""
    # grid_str is a string of 16 chars, 'O' for up, 'X' for down
    result = 0
    for i, char in enumerate(grid_str):
        if char == 'O':
            result |= (1 << i)
    return result

def bits_to_grid(bits, size=GRID_SIZE):
    """Convert 16-bit integer to grid string for logging."""
    grid = []
    for i in range(size * size):
        if bits & (1 << i):
            grid.append('O')
        else:
            grid.append('X')
    return ''.join(grid)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut, start_bits, target_bits):
    """Start computation with given start and target grids."""
    # Write inputs
    dut.start_grid.value = start_bits
    dut.target_grid.value = target_bits
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES
# ============================================================================

test_cases = [
    {
        "name": "No change needed",
        "start": "XXXXXXXXXXXXXXXX",
        "target": "XXXXXXXXXXXXXXXX",
        "expected": 1
    },
    {
        "name": "Single peg up (possible)",
        "start": "OXXXXXXXXXXXXXXX",
        "target": "XXXXXXXXXXXXXXXX",
        "expected": 1
    },
    {
        "name": "All down to all up (impossible from all down)",
        "start": "XXXXXXXXXXXXXXXX",
        "target": "OOOOOOOOOOOOOOOO",
        "expected": 0
    },
    {
        "name": "Row operation",
        "start": "OXXXXXXXXXXXXXXX",
        "target": "OOOOXXXXXXXXXXXX",
        "expected": 1
    },
    {
        "name": "Example 1 from problem",
        "start": "XOXOXOXO",  # 4x2 flattened
        "target": "OXOXXOXO",  # 4x2 flattened
        "expected": 1
    },
    {
        "name": "Example 2 from problem",
        "start": "XXXXXXXX",  # 2x4 flattened, all down
        "target": "XOOOXXXX",  # 2x4 flattened
        "expected": 0
    }
]

# Adjust test cases for 4x4 if needed
# For 2x4, we can pack into 4x4 by adding zeros

def pack_2x4_to_16bits(grid_2x4):
    """Pack 2x4 grid into 16-bit 4x4 format."""
    bits = 0
    for i in range(2):
        for j in range(4):
            if grid_2x4[i*4+j] == 'O':
                # Map to 4x4 positions: (i,j) -> (i*2+j*2) or similar
                # Let's map linearly: row 0: positions 0-3, row 1: positions 4-7
                # In 4x4: use first 2 rows, first 4 columns
                pos = i*4 + j
                bits |= (1 << pos)
    return bits

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_peg_board_checker(dut):
    """Main test for peg board checker."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    has_result = has_signal(dut, 'result')
    has_start_grid = has_signal(dut, 'start_grid')
    has_target_grid = has_signal(dut, 'target_grid')
    
    if not all([has_clk, has_rst, has_start, has_done, has_result, has_start_grid, has_target_grid]):
        dut._log.error("Missing required signals")
        raise TestFailure("DUT missing required signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {i+1}: {test['name']}")
        dut._log.info(f"Start:  {test['start']}")
        dut._log.info(f"Target: {test['target']}")
        
        # Convert grids to bits
        if len(test['start']) == 8:  # 2x4
            start_bits = pack_2x4_to_16bits(test['start'])
            target_bits = pack_2x4_to_16bits(test['target'])
        else:
            start_bits = grid_to_bits(test['start'])
            target_bits = grid_to_bits(test['target'])
        
        dut._log.info(f"Start bits: 0x{start_bits:04X}, Target bits: 0x{target_bits:04X}")
        
        try:
            # Start computation
            await start_computation(dut, start_bits, target_bits)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected = test['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"Result: FAIL - {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# Additional test with random inputs
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random valid operations."""
    
    # Setup
    has_clk = has_signal(dut, 'clk')
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential test requires clk")
    
    # Generate random test cases
    for i in range(10):
        # Random start grid with at least one 'O' to allow operations
        start_bits = random.randint(0, (1 << TOTAL_BITS) - 1)
        # Ensure at least one bit is set
        if start_bits == 0:
            start_bits = 1
        
        # Apply a few random operations to generate a target
        temp_state = start_bits
        operations = random.randint(1, 3)
        
        for op in range(operations):
            # Find a cell that is 'O'
            possible = [j for j in range(TOTAL_BITS) if (temp_state >> j) & 1]
            if not possible:
                break
            
            # Random operation
            pos = random.choice(possible)
            row = pos // GRID_SIZE
            col = pos % GRID_SIZE
            
            # Apply operation
            # Set (row,col) to 0
            temp_state &= ~(1 << pos)
            # Set other cells in row to 1
            for c in range(GRID_SIZE):
                if c != col:
                    temp_state |= (1 << (row * GRID_SIZE + c))
            # Set other cells in column to 1
            for r in range(GRID_SIZE):
                if r != row:
                    temp_state |= (1 << (r * GRID_SIZE + col))
        
        target_bits = temp_state
        
        dut._log.info(f"Random test {i+1}: start=0x{start_bits:04X}, target=0x{target_bits:04X}")
        
        # Test
        await start_computation(dut, start_bits, target_bits)
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        
        # Since we generated target from start, it must be reachable (result=1)
        if result != 1:
            raise TestFailure(f"Random test failed: expected 1, got {result}")
        
        dut._log.info(f"  Result: {result} [PASS]")
    
    dut._log.info("\nAll random tests passed!")
