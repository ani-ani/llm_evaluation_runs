import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
SUM_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_matrix_packed(dut, matrix):
    """Write 4x4 matrix as packed 8-bit values to consecutive array elements"""
    flat = []
    for row in matrix:
        flat.extend(row)
    
    for i, val in enumerate(flat):
        attr_name = f'matrix_{i}'
        if hasattr(dut, attr_name):
            getattr(dut, attr_name).value = clamp_to_width(val, DATA_WIDTH)
        elif hasattr(dut, 'matrix'):
            if i < len(dut.matrix):
                dut.matrix[i].value = clamp_to_width(val, DATA_WIDTH)

def is_magic_square(matrix):
    """Reference implementation for Python test"""
    size = len(matrix)
    sums = []
    # Rows
    for row in matrix:
        sums.append(sum(row))
    # Columns
    for col in range(size):
        sums.append(sum(row[col] for row in matrix))
    # Main diagonal
    sums.append(sum(matrix[i][i] for i in range(size)))
    # Anti-diagonal
    sums.append(sum(matrix[i][size-1-i] for i in range(size)))
    return len(set(sums)) == 1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_magic_square(dut):
    """Test 4x4 magic square detection"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("True 4x4 magic square",
         [[7, 12, 1, 14], [2, 13, 8, 11], [16, 3, 10, 5], [9, 6, 15, 4]],
         True),
        ("False 4x4 non-magic",
         [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]],
         False),
        ("Edge case - all same",
         [[8, 8, 8, 8], [8, 8, 8, 8], [8, 8, 8, 8], [8, 8, 8, 8]],
         False)  # Not 1-16 range
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (desc, matrix, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        
        try:
            # Write matrix
            await write_matrix_packed(dut, matrix)
            await RisingEdge(dut.clk)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value) == 1
            
            # Verify against Python reference
            py_result = is_magic_square(matrix)
            if expected != py_result:
                raise TestFailure(f"Python reference mismatch: expected {py_result}, got {expected}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")