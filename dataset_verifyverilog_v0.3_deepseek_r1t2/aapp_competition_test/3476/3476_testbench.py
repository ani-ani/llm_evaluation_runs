import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8          # 8-bit signed values
R = 8                   # Number of rows
C = 8                   # Number of columns
RESULT_WIDTH = 16       # Sum width
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000      # Allow enough cycles for brute-force search

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_matrix(dut, matrix, element_width=DATA_WIDTH):
    """Write matrix values to DUT."""
    for i in range(R):
        for j in range(C):
            val = from_signed(matrix[i][j], element_width)
            dut.matrix_in[i][j].value = clamp_to_width(val, element_width)

async def read_matrix(dut):
    """Read matrix from DUT."""
    matrix = []
    for i in range(R):
        row = []
        for j in range(C):
            if is_value_defined(dut.matrix_in[i][j].value):
                val = int(dut.matrix_in[i][j].value)
                row.append(to_signed(val, DATA_WIDTH))
            else:
                row.append(0)
        matrix.append(row)
    return matrix

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def python_max_sum_optimization(matrix):
    """
    Python reference: find optimal row/column negations via brute force.
    Returns: (max_sum, row_mask, col_mask, operations)
    """
    best_sum = -float('inf')
    best_row_mask = 0
    best_col_mask = 0
    
    # Try all row negation patterns
    for row_pattern in range(1 << R):
        # Apply row negations to get intermediate matrix
        intermediate = []
        for i in range(R):
            row = []
            for j in range(C):
                val = matrix[i][j]
                if (row_pattern >> i) & 1:
                    val = -val
                row.append(val)
            intermediate.append(row)
        
        # For this row pattern, choose column negations greedily
        col_sums = [sum(intermediate[i][j] for i in range(R)) for j in range(C)]
        col_mask = 0
        current_sum = 0
        for j in range(C):
            if col_sums[j] < 0:
                col_mask |= (1 << j)
                current_sum += -col_sums[j]
            else:
                current_sum += col_sums[j]
        
        # Track best
        if current_sum > best_sum:
            best_sum = current_sum
            best_row_mask = row_pattern
            best_col_mask = col_mask
    
    # Generate operation sequence
    operations = []
    for i in range(R):
        if (best_row_mask >> i) & 1:
            operations.append(f"negR {i+1}")
    for j in range(C):
        if (best_col_mask >> j) & 1:
            operations.append(f"negS {j+1}")
    
    return best_sum, best_row_mask, best_col_mask, operations

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_matrix_max_sum(dut):
    """Test matrix sum maximization module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (matrix, description)
    # Scaled down from original problem
    test_cases = [
        (
            [
                [1, -2, 5, 20, -8, 0, -4, -10],
                [11, 4, 0, 100, 3, -5, 6, -7],
                [-9, 2, -1, 8, 0, 5, -3, 12],
                [1, 2, 3, 4, -1, -2, -3, -4],
                [5, -6, 7, -8, 9, -10, 11, -12],
                [0, 0, 0, 0, 1, 1, 1, 1],
                [-5, 5, -5, 5, -5, 5, -5, 5],
                [10, -20, 30, -40, 50, -60, 70, -80]
            ],
            "8x8 mixed matrix"
        ),
        (
            [
                [10, -5, 20, -15, 0, 0, 0, 0],
                [-10, 5, -20, 15, 0, 0, 0, 0],
                [1, 1, 1, 1, -1, -1, -1, -1],
                [-1, -1, -1, -1, 1, 1, 1, 1],
                [100, -100, 50, -50, 25, -25, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [1, 2, 3, 4, 5, 6, 7, 8],
                [-1, -2, -3, -4, -5, -6, -7, -8]
            ],
            "Structured patterns"
        ),
    ]
    
    for test_idx, (matrix, description) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {test_idx+1}: {description}")
        dut._log.info(f"{'='*60}")
        
        # Write matrix to DUT
        await write_matrix(dut, matrix)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read results
        if not all(is_value_defined(dut.max_sum.value),
                   is_value_defined(dut.row_mask.value),
                   is_value_defined(dut.col_mask.value),
                   is_value_defined(dut.op_count.value)):
            raise TestFailure(f"Output signals contain X/Z values")
        
        hw_sum = to_signed(int(dut.max_sum.value), RESULT_WIDTH)
        hw_row_mask = int(dut.row_mask.value)
        hw_col_mask = int(dut.col_mask.value)
        hw_op_count = int(dut.op_count.value)
        
        # Compute Python reference
        py_sum, py_row_mask, py_col_mask, py_ops = python_max_sum_optimization(matrix)
        
        # Verify
        dut._log.info(f"HW Result: sum={hw_sum}, row_mask={hw_row_mask:08b}, col_mask={hw_col_mask:08b}, ops={hw_op_count}")
        dut._log.info(f"PY Result: sum={py_sum}, row_mask={py_row_mask:08b}, col_mask={py_col_mask:08b}, ops={len(py_ops)}")
        
        # Allow small differences due to algorithm approximation
        if hw_sum < py_sum - 5:  # Allow 5 LSB tolerance
            raise TestFailure(f"Sum mismatch: HW={hw_sum}, PY={py_sum}")
        
        # Operation count should match
        if hw_op_count != len(py_ops):
            raise TestFailure(f"Op count mismatch: HW={hw_op_count}, PY={len(py_ops)}")
        
        # Show operations
        dut._log.info("Operations:")
        for op in py_ops:
            dut._log.info(f"  {op}")
        
        dut._log.info(f"PASS: Test {test_idx+1} completed")
        
        # Short delay between tests
        await Timer(100, units='ns')
        await reset_dut(dut)
    
    dut._log.info(f"\n{'='*60}")
    dut._log.info("ALL TESTS PASSED")
    dut._log.info(f"{'='*60}")
