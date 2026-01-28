import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for 8x8 matrix
DATA_WIDTH = 8
MAX_ROWS = 8
MAX_COLS = 8
CLK_NS = 10
MAX_CYCLES = 10000

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    if v < min_val: return min_val
    if v > max_val: return max_val
    return v

def pack_matrix(matrix_vals, rows, cols):
    # matrix_vals is list of lists
    packed = 0
    for r in range(rows):
        for c in range(cols):
            val = matrix_vals[r][c]
            # 8-bit signed
            idx = r * 8 + c
            val = clamp_to_width(val, 8)
            packed |= (val & 0xFF) << (idx * 8)
    return packed

def compute_expected(matrix_vals, rows, cols):
    # Python logic to find max valid submatrix area
    max_area = 0
    # Check all submatrices
    for r1 in range(rows):
        for c1 in range(cols):
            for r2 in range(r1 + 1, rows):
                for c2 in range(c1 + 1, cols):
                    # Check Monge property for this submatrix
                    valid = True
                    for i in range(r1, r2):
                        for j in range(c1, c2):
                            # A[i][j] + A[i+1][j+1] <= A[i][j+1] + A[i+1][j]
                            v1 = matrix_vals[i][j]
                            v2 = matrix_vals[i+1][j+1]
                            v3 = matrix_vals[i][j+1]
                            v4 = matrix_vals[i+1][j]
                            if (v1 + v2) > (v3 + v4):
                                valid = False
                                break
                        if not valid:
                            break
                    if valid:
                        area = (r2 - r1 + 1) * (c2 - c1 + 1)
                        if area > max_area:
                            max_area = area
    # Also check 1xN or Nx1 or 1x1 (always valid)
    if max_area == 0 and rows > 0 and cols > 0:
        max_area = 1 # At least 1 element
    return max_area

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_monge_matrix(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (matrix, rows, cols)
    # Case 1: 3x3 from sample 1
    mat1 = [
        [1, 4, 10],
        [5, 2, 6],
        [11, 1, 3]
    ]
    # Case 2: 3x3 from sample 2
    mat2 = [
        [1, 3, 1],
        [2, 1, 2],
        [1, 1, 1]
    ]
    # Case 3: 5x6 from sample 3 (truncated to 8x8)
    mat3 = [
        [1, 1, 4, 0, 3, 3],
        [4, 4, 9, 7, 11, 13],
        [-3, -1, 4, 2, 8, 11],
        [1, 5, 9, 5, 9, 10],
        [4, 8, 10, 5, 8, 8]
    ]
    
    test_cases = [
        (mat1, 3, 3, 9),
        (mat2, 3, 3, 4),
        (mat3, 5, 6, 15)
    ]

    for idx, (mat, r, c, exp) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: {r}x{c} expecting {exp}")
        
        # Pack matrix into flat vector
        packed = pack_matrix(mat, r, c)
        
        # Assign to DUT
        # Assuming input is 'matrix_flat' as 512-bit vector
        dut.matrix_flat.value = packed
        dut.rows.value = r
        dut.cols.value = c
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {idx+1}: Result undefined")
            
        result = int(dut.result.value)
        
        # Allow for 1x1 edge case if no larger found
        if result != exp:
            # Note: Logic allows 1x1 if nothing else valid. 
            # The problem asks for largest extremely cool submatrix.
            # In the logic provided, 1x1 is always valid.
            # However, sample 2 output is 4, which implies 2x2 or 1x4/4x1.
            # Sample 1 output is 9 (3x3).
            # My python logic handles this correctly.
            # If HDL matches python logic, it should pass.
            raise TestFailure(f"Test {idx+1}: Expected {exp}, got {result}")

    cocotb.log.info("All tests passed!")