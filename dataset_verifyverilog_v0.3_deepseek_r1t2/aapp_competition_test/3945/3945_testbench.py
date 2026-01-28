import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def write_matrix(dut, matrix):
    """Write 4x4 matrix to individual ports."""
    for i in range(4):
        for j in range(4):
            port_name = f'matrix{i}{j}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(matrix[i][j], 8)
            else:
                raise TestFailure(f"Port {port_name} not found")

async def read_answer(dut):
    """Read 4x4 answer matrix from individual ports."""
    ans = [[0]*4 for _ in range(4)]
    for i in range(4):
        for j in range(4):
            port_name = f'answer{i}{j}'
            if has_signal(dut, port_name):
                val = getattr(dut, port_name).value
                if is_value_defined(val):
                    ans[i][j] = int(val)
                else:
                    ans[i][j] = None
            else:
                raise TestFailure(f"Port {port_name} not found")
    return ans

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_cell_answer(dut):
    """Test the cell_answer module with two test cases."""
    
    # Test case 1: all ones
    matrix1 = [
        [1, 1, 1, 1],
        [1, 1, 1, 1],
        [1, 1, 1, 1],
        [1, 1, 1, 1]
    ]
    expected1 = [
        [1, 1, 1, 1],
        [1, 1, 1, 1],
        [1, 1, 1, 1],
        [1, 1, 1, 1]
    ]
    
    # Test case 2: identity matrix (distinct values)
    matrix2 = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 16]
    ]
    expected2 = [
        [4, 5, 6, 7],
        [5, 4, 5, 6],
        [6, 5, 4, 5],
        [7, 6, 5, 4]
    ]
    
    # Since the module is combinational, just set inputs and wait
    dut._log.info("Testing case 1: all ones")
    await write_matrix(dut, matrix1)
    await Timer(10, units='ns')
    result1 = await read_answer(dut)
    
    for i in range(4):
        for j in range(4):
            if result1[i][j] != expected1[i][j]:
                raise TestFailure(f"Case 1 cell ({i},{j}): expected {expected1[i][j]}, got {result1[i][j]}")
    
    dut._log.info("Testing case 2: identity matrix")
    await write_matrix(dut, matrix2)
    await Timer(10, units='ns')
    result2 = await read_answer(dut)
    
    for i in range(4):
        for j in range(4):
            if result2[i][j] != expected2[i][j]:
                raise TestFailure(f"Case 2 cell ({i},{j}): expected {expected2[i][j]}, got {result2[i][j]}")
    
    dut._log.info("All tests passed")
