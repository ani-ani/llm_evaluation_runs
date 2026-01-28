import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Testbench configuration
CLK_NS = 10
MAX_CYCLES = 100

def pack_matrix(matrix):
    """Pack 4x4 signed 8-bit integers into a 128-bit integer.
       Matrix is list of 4 rows, each row list of 4 ints.
       Packing order: row0_col0, row0_col1, row0_col2, row0_col3, row1_col0..."""
    packed = 0
    for r in range(4):
        for c in range(4):
            val = matrix[r][c]
            # Convert to unsigned representation for storage if negative
            if val < 0:
                val = (1 << 8) + val
            # Shift by (r*4 + c) * 8 bits
            packed |= (val & 0xFF) << ((r * 4 + c) * 8)
    return packed

def compute_expected(matrix):
    """Compute expected Q8.8 averages (scaled by 256)."""
    results = []
    for c in range(4):
        col_sum = 0
        for r in range(4):
            col_sum += matrix[r][c]
        # Divide by 4, multiply by 256
        # Note: integer division truncates towards negative infinity in Python, 
        # but for averaging scaled integers, we typically use truncation towards zero or floor.
        # For average = sum/4, we compute (sum * 256) / 4.
        # If sum is negative, Python's // behaves as floor division.
        # To match hardware shift, we should use integer division (floor) for positive sums.
        # For negative sums, arithmetic shift right is implementation defined but usually floor.
        # Let's use (sum * 256) >> 2 for clarity.
        avg = (col_sum * 256) >> 2
        results.append(avg)
    return results

def to_q8_8(val):
    """Format float to Q8.8 integer."""
    return int(val * 256)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_average_tuple(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases (4x4 matrices)
    test_cases = [
        (
            [
                [10, 10, 10, 12],
                [30, 45, 56, 45],
                [81, 80, 39, 32],
                [1, 2, 3, 4]
            ],
            [30.5, 34.25, 27.0, 23.25],
            "Test 1: Positive Integers"
        ),
        (
            [
                [1, 1, -5, 0],
                [30, -15, 56, 0],
                [81, -60, -39, 0],
                [-10, 2, 3, 0]
            ],
            [25.5, -18.0, 3.75, 0.0],
            "Test 2: Mixed Signs (4th column 0)"
        ),
        (
            [
                [100, 100, 100, 120],
                [300, 450, 560, 450],
                [810, 800, 390, 320],
                [10, 20, 30, 40]
            ],
            [305.0, 342.5, 270.0, 232.5],
            "Test 3: Larger Values"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (matrix_in, expected_float, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Prepare inputs
            packed_input = pack_matrix(matrix_in)
            expected_ints = [to_q8_8(f) for f in expected_float]
            
            # Drive inputs
            dut.matrix_in.value = packed_input
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read outputs
            col0 = int(dut.result_col0.value)
            col1 = int(dut.result_col1.value)
            col2 = int(dut.result_col2.value)
            col3 = int(dut.result_col3.value)
            
            # Check results (allow small rounding difference)
            actual = [col0, col1, col2, col3]
            expected = expected_ints
            
            # Log comparison
            cocotb.log.info(f"  Expected: {expected}")
            cocotb.log.info(f"  Got:      {actual}")
            
            for idx, (act, exp) in enumerate(zip(actual, expected)):
                if act != exp:
                    raise TestFailure(f"Col {idx}: Expected {exp}, got {act}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
