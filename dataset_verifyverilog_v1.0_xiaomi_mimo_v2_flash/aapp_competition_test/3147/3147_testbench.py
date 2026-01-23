import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4
MAX_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        val = val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        val = val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_square_killer(dut):
    """Test the SquareKiller module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    async def set_matrix(matrix, R, C):
        # matrix is list of strings, each string length <= 4
        # Pad to 4 bits with zeros
        rows = [row.ljust(4, '0') for row in matrix]
        row_vals = [int(row, 2) for row in rows]
        dut.row0.value = row_vals[0]
        dut.row1.value = row_vals[1]
        dut.row2.value = row_vals[2]
        dut.row3.value = row_vals[3]
        dut.R.value = R
        dut.C.value = C
        await Timer(10, units='ns')
    
    async def get_result():
        await wait_for_done(dut)
        raw = int(dut.result.value)
        if raw >= 8:  # 4-bit signed
            return raw - 16
        else:
            return raw
    
    # Test cases: (matrix, R, C, expected)
    test_cases = [
        # Case 1: No killer (all zeros)
        (["0000", "0000", "0000", "0000"], 4, 4, -1),
        # Case 2: Size-2 killer (2x2 block of ones)
        (["0000", "0011", "0011", "0000"], 4, 4, 2),
        # Case 3: Size-3 killer (from problem example, truncated)
        (["1010", "1110", "1010", "0000"], 4, 4, 3),
        # Case 4: Size-4 killer (symmetric pattern)
        (["0101", "1010", "0101", "1010"], 4, 4, 4),
        # Case 5: 2x2 matrix with killer
        (["11", "11"], 2, 2, 2),
        # Case 6: 3x3 matrix with no killer
        (["101", "111", "100"], 3, 3, -1),
    ]
    
    for idx, (matrix, R, C, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {idx+1}: R={R}, C={C}, expected={expected}")
        await set_matrix(matrix, R, C)
        await start_computation(dut)
        result = await get_result()
        if result != expected:
            raise TestFailure(f"Test {idx+1}: expected {expected}, got {result}")
        else:
            cocotb.log.info(f"  PASS: result = {result}")
    
    cocotb.log.info("All tests passed!")