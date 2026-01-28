import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to pack 8x8 matrix of 4-bit values into 256-bit integer
def pack_lut(matrix):
    packed = 0
    for row in range(8):
        for col in range(8):
            val = matrix[row][col] & 0xF
            # Index: row*32 + col*4
            shift = row * 32 + col * 4
            packed |= (val << shift)
    return packed

# Helper to pack row lengths into 32-bit integer
def pack_row_lengths(lengths):
    packed = 0
    for i in range(8):
        packed |= (lengths[i] & 0xF) << (i * 4)
    return packed

@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_find_coordinates(dut):
    """Test the find_coordinates module with various jagged arrays"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset Sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target.value = 0
    dut.row_valid_mask.value = 0
    dut.row_lengths.value = 0
    dut.data_lut.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # --- Test Case 1: Basic functionality from prompt ---
    # Matrix:
    # [1,2,3,4,5,6]
    # [1,2,3,4,1,6]
    # [1,2,3,4,5,1]
    # Target: 1
    # Expected: [(0,0), (1,4), (1,0), (2,5), (2,0)]
    
    dut._log.info("Test 1: Basic jagged search")
    matrix1 = [
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,1,6,0,0],
        [1,2,3,4,5,1,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    
    dut.target.value = 1
    dut.row_valid_mask.value = 0b00000111 # Rows 0, 1, 2 active
    dut.row_lengths.value = pack_row_lengths([6, 6, 6, 0, 0, 0, 0, 0])
    dut.data_lut.value = pack_lut(matrix1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal
    done = False
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    # Verify results
    if not is_value_defined(dut.match_count.value):
        raise TestFailure("Test 1: match_count undefined")
        
    count = int(dut.match_count.value)
    if count != 5:
        raise TestFailure(f"Test 1: Expected 5 matches, got {count}")
    
    # Expected: [(0,0), (1,4), (1,0), (2,5), (2,0)]
    # Note: Algorithm scans columns 7->0, so within row 1, finds col 4 then col 0.
    expected1 = [(0,0), (1,4), (1,0), (2,5), (2,0)]
    
    for i in range(5):
        if not is_value_defined(dut.matches[i].value):
             raise TestFailure(f"Test 1: Match {i} undefined")
        val = int(dut.matches[i].value)
        row = (val >> 4) & 0xF
        col = val & 0xF
        if (row, col) != expected1[i]:
            raise TestFailure(f"Test 1: Match {i}: exp {expected1[i]}, got ({row},{col})")
            
    dut._log.info("Test 1 passed")

    # --- Test Case 2: Multiple rows, single value ---
    # 6 rows, all [1,2,3,4,5,6]
    # Target 2
    # Expected: [(0,1), (1,1), (2,1), (3,1), (4,1), (5,1)]
    
    dut._log.info("Test 2: Multiple rows")
    matrix2 = [
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,5,6,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    
    dut.target.value = 2
    dut.row_valid_mask.value = 0b00111111 # Rows 0-5
    dut.row_lengths.value = pack_row_lengths([6]*8)
    dut.data_lut.value = pack_lut(matrix2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done: raise TestFailure("Test 2: Timeout")
    
    count = int(dut.match_count.value)
    if count != 6: raise TestFailure(f"Test 2: Expected 6, got {count}")
    
    for i in range(6):
        val = int(dut.matches[i].value)
        row = (val >> 4) & 0xF
        col = val & 0xF
        if row != i or col != 1:
             raise TestFailure(f"Test 2: Match {i}: expected ({i}, 1), got ({row}, {col})")
    
    dut._log.info("Test 2 passed")

    # --- Test Case 3: Complex matches (from prompt example) ---
    # Matrix with scattered 1s
    # Target 1
    # Expected based on scan order (R0->R7, C7->C0):
    # R0: C0 -> (0,0)
    # R1: C0 -> (1,0)
    # R2: C1, C0 -> (2,1), (2,0)
    # R3: C2, C0 -> (3,2), (3,0)
    # R4: C3, C0 -> (4,3), (4,0)
    # R5: C4, C0 -> (5,4), (5,0)
    # R6: C5, C0 -> (6,5), (6,0)
    
    dut._log.info("Test 3: Complex pattern")
    matrix3 = [
        [1,2,3,4,5,6,0,0],
        [1,2,3,4,5,6,0,0],
        [1,1,3,4,5,6,0,0],
        [1,2,1,4,5,6,0,0],
        [1,2,3,1,5,6,0,0],
        [1,2,3,4,1,6,0,0],
        [1,2,3,4,5,1,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    
    dut.target.value = 1
    dut.row_valid_mask.value = 0b01111111 # 7 rows
    dut.row_lengths.value = pack_row_lengths([6,6,6,6,6,6,6,0])
    dut.data_lut.value = pack_lut(matrix3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(200):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done: raise TestFailure("Test 3: Timeout")
    
    count = int(dut.match_count.value)
    expected_count = 12
    if count != expected_count:
         raise TestFailure(f"Test 3: Expected {expected_count}, got {count}")
    
    expected3 = [(0,0), (1,0), (2,1), (2,0), (3,2), (3,0), (4,3), (4,0), (5,4), (5,0), (6,5), (6,0)]
    
    for i in range(expected_count):
        val = int(dut.matches[i].value)
        row = (val >> 4) & 0xF
        col = val & 0xF
        if (row, col) != expected3[i]:
            raise TestFailure(f"Test 3: Match {i}: exp {expected3[i]}, got ({row},{col})")
    
    dut._log.info("Test 3 passed")

    # --- Test Case 4: Empty search ---
    dut._log.info("Test 4: Empty input")
    dut.row_valid_mask.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(50):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done: raise TestFailure("Test 4: Timeout")
    if int(dut.match_count.value) != 0: raise TestFailure("Test 4: Should be empty")
    dut._log.info("Test 4 passed")

    # --- Test Case 5: No matches ---
    dut._log.info("Test 5: No matches")
    matrix5 = [
        [2,3,4,5,6,7,0,0],
        [2,3,4,5,6,7,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    dut.target.value = 1
    dut.row_valid_mask.value = 0b00000011
    dut.row_lengths.value = pack_row_lengths([6,6,0,0,0,0,0,0])
    dut.data_lut.value = pack_lut(matrix5)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(50):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done: raise TestFailure("Test 5: Timeout")
    if int(dut.match_count.value) != 0: raise TestFailure("Test 5: Should be empty")
    dut._log.info("Test 5 passed")

    # --- Test Case 6: Capacity Limit (16 matches) ---
    dut._log.info("Test 6: Capacity limit")
    # Create a row of 1s, length 16 (but max is 8, so we need 2 rows of 8)
    matrix6 = [
        [1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    dut.target.value = 1
    dut.row_valid_mask.value = 0b00000011
    dut.row_lengths.value = pack_row_lengths([8, 8, 0, 0, 0, 0, 0, 0])
    dut.data_lut.value = pack_lut(matrix6)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done: raise TestFailure("Test 6: Timeout")
    
    count = int(dut.match_count.value)
    if count != 16: raise TestFailure(f"Test 6: Expected 16 (cap), got {count}")
    
    # Check that we found valid coordinates (Row 0 Cols 7-0, Row 1 Cols 7-0)
    # Scanning R0 Cols 7->0, then R1 Cols 7->0
    # Expected sequence: (0,7), (0,6)...(0,0), (1,7)...(1,0)
    
    for i in range(16):
        if not is_value_defined(dut.matches[i].value):
             raise TestFailure(f"Test 6: Match {i} undefined")
        val = int(dut.matches[i].value)
        row = (val >> 4) & 0xF
        col = val & 0xF
        
        if i < 8:
            exp_row = 0
            exp_col = 7 - i
        else:
            exp_row = 1
            exp_col = 7 - (i - 8)
            
        if row != exp_row or col != exp_col:
             raise TestFailure(f"Test 6: Match {i}: exp ({exp_row},{exp_col}), got ({row},{col})")
    
    dut._log.info("Test 6 passed")
    dut._log.info("All tests passed [OK]")
