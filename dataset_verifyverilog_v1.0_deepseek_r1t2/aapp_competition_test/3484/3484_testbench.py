import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 4
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# VALIDATION HELPER
# ============================================================================

def check_grid_validity(grid, k, input_rows):
    """Check if grid is a valid Latin square and matches given rows."""
    # Check each row contains 1-4
    for i in range(4):
        if set(grid[i]) != {1, 2, 3, 4}:
            return False
    # Check each column contains 1-4
    for j in range(4):
        col = [grid[i][j] for i in range(4)]
        if set(col) != {1, 2, 3, 4}:
            return False
    # Check first k rows match input
    for i in range(k):
        for j in range(4):
            if grid[i][j] != input_rows[i][j]:
                return False
    return True

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_latin_square_solver(dut):
    """Main test function for 4x4 Latin square solver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            "k": 2,
            "rows": [
                [1, 2, 3, 4],
                [2, 3, 4, 1],
            ],
            "expected_yes": 1,
            "description": "Valid input, should find a solution"
        },
        {
            "k": 2,
            "rows": [
                [1, 2, 3, 4],
                [2, 2, 2, 2],
            ],
            "expected_yes": 0,
            "description": "Invalid row, should output no"
        },
    ]
    
    for idx, tc in enumerate(test_cases):
        dut._log.info(f"Running test case {idx+1}: {tc['description']}")
        
        # Set k
        dut.k.value = tc['k']
        
        # Set input rows
        for row_idx in range(4):
            for col_idx in range(4):
                port_name = f'in_row{row_idx}_{col_idx}'
                if row_idx < tc['k']:
                    val = tc['rows'][row_idx][col_idx]
                else:
                    val = 0  # Unused
                setattr(dut, port_name, val)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Check yes
        if not is_value_defined(dut.yes.value):
            raise TestFailure(f"yes signal is undefined")
        
        yes_val = int(dut.yes.value)
        expected_yes = tc['expected_yes']
        
        if yes_val != expected_yes:
            raise TestFailure(f"Test {idx+1}: expected yes={expected_yes}, got {yes_val}")
        
        if yes_val == 1:
            # Read output grid
            grid = []
            for row in range(4):
                row_vals = []
                for col in range(4):
                    port_name = f'result_{row}_{col}'
                    val = getattr(dut, port_name).value
                    if not is_value_defined(val):
                        raise TestFailure(f"Output grid has undefined value at {row},{col}")
                    row_vals.append(int(val))
                grid.append(row_vals)
            
            # Validate grid
            if not check_grid_validity(grid, tc['k'], tc['rows']):
                raise TestFailure(f"Output grid is invalid: {grid}")
            
            dut._log.info(f"Test {idx+1}: PASS - valid solution found")
        else:
            dut._log.info(f"Test {idx+1}: PASS - correctly reported no solution")
    
    dut._log.info("All tests passed")
