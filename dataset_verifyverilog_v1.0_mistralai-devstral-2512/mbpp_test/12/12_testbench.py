import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 4
ARRAY_ROWS = 3
ARRAY_COLS = 3
CLK_NS = 10
MAX_CYCLES = 100

def pack_matrix(vals):
    """Pack 9x4-bit signed matrix into 36-bit value (row-major)"""
    result = 0
    for i in range(9):
        # Convert signed to unsigned for packing
        packed_val = vals[i] & 0xF
        result |= packed_val << (i * 4)
    return result

def get_signed_matrix_value(matrix_00, matrix_01, matrix_02, matrix_10, matrix_11, matrix_12, matrix_20, matrix_21, matrix_22):
    """Convert all 4-bit signed signals to Python signed integers"""
    vals = []
    for name, val in [(matrix_00, 'matrix_00'), (matrix_01, 'matrix_01'), (matrix_02, 'matrix_02'),
                      (matrix_10, 'matrix_10'), (matrix_11, 'matrix_11'), (matrix_12, 'matrix_12'),
                      (matrix_20, 'matrix_20'), (matrix_21, 'matrix_21'), (matrix_22, 'matrix_22')]:
        if is_value_defined(getattr(dut, val).value):
            v = int(getattr(dut, val).value)
            vals.append(to_signed(v, DATA_WIDTH))
        else:
            vals.append(0)
    return vals

def compute_expected_sort(matrix):
    """Compute expected sorted matrix in Python"""
    rows_with_sum = []
    for row in matrix:
        row_sum = sum(row)
        rows_with_sum.append((row_sum, row))
    # Stable sort by sum
    rows_with_sum.sort(key=lambda x: x[0])
    return [row for _, row in rows_with_sum]

def read_matrix_from_dut(dut):
    """Read 3x3 matrix from DUT signals"""
    matrix = []
    for row in range(3):
        row_data = []
        for col in range(3):
            signal_name = f'matrix_{row}{col}'
            if has_signal(dut, signal_name):
                val = int(getattr(dut, signal_name).value)
                row_data.append(to_signed(val, DATA_WIDTH))
            else:
                row_data.append(0)
        matrix.append(row_data)
    return matrix

def read_result_from_dut(dut):
    """Read packed result from DUT and unpack to 3x3 matrix"""
    if has_signal(dut, 'result') and is_value_defined(dut.result.value):
        packed = int(dut.result.value)
        matrix = []
        for row in range(3):
            row_data = []
            for col in range(3):
                idx = row * 3 + col
                val = (packed >> (idx * 4)) & 0xF
                row_data.append(to_signed(val, DATA_WIDTH))
            matrix.append(row_data)
        return matrix
    return None

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_matrix_input(dut, matrix):
    """Write 3x3 matrix to DUT input signals"""
    flat_vals = []
    for row in matrix:
        for val in row:
            flat_vals.append(val)
    
    signal_names = [
        'matrix_00', 'matrix_01', 'matrix_02',
        'matrix_10', 'matrix_11', 'matrix_12',
        'matrix_20', 'matrix_21', 'matrix_22'
    ]
    
    for i, sig_name in enumerate(signal_names):
        if has_signal(dut, sig_name):
            # Convert signed to unsigned for HDL
            val_unsigned = flat_vals[i] & 0xF
            getattr(dut, sig_name).value = val_unsigned

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sort_matrix(dut):
    """Test matrix sorting by row sum"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_matrix, expected_output_matrix, description)
    test_cases = [
        ([
            [1, 2, 3],  # sum = 6
            [2, 4, 5],  # sum = 11
            [1, 1, 1]   # sum = 3
        ], [
            [1, 1, 1],  # sum = 3 (smallest)
            [1, 2, 3],  # sum = 6
            [2, 4, 5]   # sum = 11 (largest)
        ], "Test 1: Positive values"),
        ([
            [1, 2, 3],   # sum = 6
            [-2, 4, -5], # sum = -3
            [1, -1, 1]   # sum = 1
        ], [
            [-2, 4, -5], # sum = -3 (smallest)
            [1, -1, 1],  # sum = 1
            [1, 2, 3]    # sum = 6 (largest)
        ], "Test 2: Mixed signs"),
        ([
            [5, 8, 9],   # sum = 22
            [6, 4, 3],   # sum = 13
            [2, 1, 4]    # sum = 7
        ], [
            [2, 1, 4],   # sum = 7 (smallest)
            [6, 4, 3],   # sum = 13
            [5, 8, 9]    # sum = 22 (largest)
        ], "Test 3: Larger values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_matrix, expected_matrix, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"Input matrix: {input_matrix}")
        cocotb.log.info(f"Expected output: {expected_matrix}")
        
        try:
            # Write input matrix to DUT
            await write_matrix_input(dut, input_matrix)
            
            if is_seq:
                # Start the computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
                
                # Read result when done
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result_matrix = read_result_from_dut(dut)
                if result_matrix is None:
                    raise TestFailure("Could not read result from DUT")
                
                cocotb.log.info(f"DUT result: {result_matrix}")
                
                # Compare with expected
                if result_matrix != expected_matrix:
                    raise TestFailure(f"Expected {expected_matrix}, got {result_matrix}")
            else:
                # Combinational case
                await Timer(100, units='ns')
                result_matrix = read_result_from_dut(dut)
                if result_matrix != expected_matrix:
                    raise TestFailure(f"Expected {expected_matrix}, got {result_matrix}")
            
            cocotb.log.info(f"Test {i+1} PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
        
        # Prepare for next test
        if is_seq:
            await reset_dut(dut, cycles=1)
    
    cocotb.log.info(f"\nTotal tests: {len(test_cases)}, Passed: {passed}, Failed: {failed}")
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {len(test_cases)}")
