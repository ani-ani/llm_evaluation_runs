import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def grid_to_int_array(grid_str):
    """Converts grid string to list of integers for Verilog input"""
    rows = grid_str.strip().split('
')
    r, c = len(rows), len(rows[0])
    # We will use a fixed 16x16 grid. If input is smaller, we pad with 0s.
    int_rows = []
    for i in range(16):
        if i < r:
            row_str = rows[i]
            val = 0
            for j in range(min(c, 16)):
                if row_str[j] == 'x':
                    val |= (1 << j)
            int_rows.append(val)
        else:
            int_rows.append(0)
    return int_rows

@cocotb.test()
async def test_building_detector(dut):
    """Test the building detector module"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    # Initialize grid inputs
    for i in range(16):
        getattr(dut, f'grid_row_{i}').value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 3x3 Grid from Sample 1
    # Input: 
    # xx.
    # xxx
    # ...
    grid1 = "xx.
xxx
...
"
    grid_vals = grid_to_int_array(grid1)
    print(f"Test Case 1 Grid: {grid1.strip()}")
    
    for i in range(16):
        getattr(dut, f'grid_row_{i}').value = grid_vals[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (with timeout)
    cycles = 0
    while dut.done.value == 0 and cycles < 20000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 20000:
        raise TestFailure("Timeout reached - done not asserted")
    
    # Check results
    # Expected outputs based on python example:
    # 1 1 2 (row 0, col 0, size 2 in 0-indexed logic -> row 1, col 1 in 1-based)
    # 2 3 1 (row 1, col 2, size 1 -> row 2, col 3)
    # In Verilog 0-indexed: b1=(0,0,2), b2=(1,2,1)
    
    b1_row = int(dut.building1_row.value)
    b1_col = int(dut.building1_col.value)
    b1_size = int(dut.building1_size.value)
    b2_row = int(dut.building2_row.value)
    b2_col = int(dut.building2_col.value)
    b2_size = int(dut.building2_size.value)
    
    print(f"Found Building 1: Row={b1_row}, Col={b1_col}, Size={b1_size}")
    print(f"Found Building 2: Row={b2_row}, Col={b2_col}, Size={b2_size}")
    
    # Verify validity of squares in the input grid
    # Just check if they make sense (covered by 'x')
    # Building 1
    valid1 = True
    for r in range(b1_row, b1_row + b1_size):
        for c in range(b1_col, b1_col + b1_size):
            if r < 3 and c < 3:
                # Map back to grid string coordinates
                char = grid1.split('
')[r][c]
                if char != 'x':
                    valid1 = False
            else:
                valid1 = False
    
    # Building 2
    valid2 = True
    for r in range(b2_row, b2_row + b2_size):
        for c in range(b2_col, b2_col + b2_size):
            if r < 3 and c < 3:
                char = grid1.split('
')[r][c]
                if char != 'x':
                    valid2 = False
            else:
                valid2 = False
                
    if not valid1 or not valid2:
        raise TestFailure(f"Found invalid squares: B1 valid={valid1}, B2 valid={valid2}")
        
    if b1_size == 0 or b2_size == 0:
        raise TestFailure("One of the buildings has size 0")

    # Test Case 2: 4x6 Grid
    # xx....
    # xx.xxx
    # ...xxx
    # ...xxx
    grid2 = "xx....
xx.xxx
...xxx
...xxx
"
    grid_vals2 = grid_to_int_array(grid2)
    print(f"
Test Case 2 Grid: {grid2.strip()}")
    
    for i in range(16):
        getattr(dut, f'grid_row_{i}').value = grid_vals2[i]
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 20000:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if cycles >= 20000:
        raise TestFailure("Timeout reached for Test Case 2")
        
    b1_row = int(dut.building1_row.value)
    b1_col = int(dut.building1_col.value)
    b1_size = int(dut.building1_size.value)
    b2_row = int(dut.building2_row.value)
    b2_col = int(dut.building2_col.value)
    b2_size = int(dut.building2_size.value)
    
    print(f"Found Building 1: Row={b1_row}, Col={b1_col}, Size={b1_size}")
    print(f"Found Building 2: Row={b2_row}, Col={b2_col}, Size={b2_size}")
    
    # Basic validation for test case 2
    # Expect B1: (0,0,2), B2: (1,3,3)
    # Or any other valid detection
    if b1_size == 0 or b2_size == 0:
        raise TestFailure("One of the buildings has size 0 in Test Case 2")
        
    print("Tests passed!")
