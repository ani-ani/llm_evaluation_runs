import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_rows.value = 0
    for i in range(8):
        dut.row_lengths[i].value = 0
        for j in range(8):
            dut.lst[i][j].value = 0
    dut.x.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')

async def run_test(dut, lst, x, expected):
    await reset_dut(dut)
    
    num_rows = len(lst)
    dut.num_rows.value = num_rows
    
    # Prepare fixed-size inputs
    lst_padded = [[0]*8 for _ in range(8)]
    row_lengths = [0]*8
    
    for r in range(num_rows):
        row = lst[r]
        row_lengths[r] = len(row)
        for c in range(len(row)):
            lst_padded[r][c] = row[c]
    
    for i in range(8):
        dut.row_lengths[i].value = row_lengths[i]
        for j in range(8):
            dut.lst[i][j].value = lst_padded[i][j]
    
    dut.x.value = x
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check results
    count = dut.result_count.value
    actual = []
    for i in range(int(count)):
        actual.append((int(dut.result_rows[i]), int(dut.result_cols[i])))
    
    # Sort expected to match order (though logic should sort it correctly)
    # The python problem sorts by row asc, col desc
    # We verify the output matches the python specification
    
    print(f"Target: {x}, Found: {actual}, Expected: {expected}")
    assert actual == expected, f"Mismatch: {actual} != {expected}"

@cocotb.test()
async def test_basic(dut):
    """Test basic jagged search"""
    # Input from problem description
    lst = [
      [1,2,3,4,5,6],
      [1,2,3,4,1,6],
      [1,2,3,4,5,1]
    ]
    x = 1
    # Expected from problem: [(0, 0), (1, 4), (1, 0), (2, 5), (2, 0)]
    # Note: The python spec says 'Sort coordinates initially by rows in ascending order.'
    # 'Also, sort coordinates of the row by columns in descending order.'
    # This implies: Row 0: [(0,0)] -> Row 1: [(1,4), (1,0)] -> Row 2: [(2,5), (2,0)]
    expected = [(0, 0), (1, 4), (1, 0), (2, 5), (2, 0)]
    await run_test(dut, lst, x, expected)

@cocotb.test()
async def test_all_rows(dut):
    """Test finding value in every row"""
    lst = [
        [1,2,3,4,5,6],
        [1,2,3,4,5,6],
        [1,2,3,4,5,6],
        [1,2,3,4,5,6],
        [1,2,3,4,5,6],
        [1,2,3,4,5,6]
    ]
    x = 2
    # All have (r, 1)
    expected = [(0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1)]
    await run_test(dut, lst, x, expected)

@cocotb.test()
async def test_complex_sort(dut):
    """Test sorting: many values in different rows"""
    lst = [
        [1,2,3,4,5,6],
        [1,2,3,4,5,6],
        [1,1,3,4,5,6],
        [1,2,1,4,5,6],
        [1,2,3,1,5,6],
        [1,2,3,4,1,6],
        [1,2,3,4,5,1]
    ]
    x = 1
    # Python logic:
    # Row 0: [(0,0)] -> [(0,0)]
    # Row 1: [(1,0)] -> [(1,0)]
    # Row 2: [(2,1), (2,0)] -> Sorted Desc: (2,1), (2,0)
    # Row 3: [(3,2), (3,0)] -> Sorted Desc: (3,2), (3,0)
    # Row 4: [(4,3), (4,0)] -> Sorted Desc: (4,3), (4,0)
    # Row 5: [(5,4), (5,0)] -> Sorted Desc: (5,4), (5,0)
    # Row 6: [(6,5), (6,0)] -> Sorted Desc: (6,5), (6,0)
    expected = [(0, 0), (1, 0), (2, 1), (2, 0), (3, 2), (3, 0), (4, 3), (4, 0), (5, 4), (5, 0), (6, 5), (6, 0)]
    await run_test(dut, lst, x, expected)

@cocotb.test()
async def test_empty(dut):
    """Test empty list"""
    lst = []
    x = 1
    expected = []
    await run_test(dut, lst, x, expected)

@cocotb.test()
async def test_single_row(dut):
    """Test jagged row"""
    lst = [[], [1], [1, 2, 3]]
    x = 3
    expected = [(2, 2)]
    await run_test(dut, lst, x, expected)
