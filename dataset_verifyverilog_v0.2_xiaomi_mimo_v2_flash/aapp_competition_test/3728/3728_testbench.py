import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper to convert Python table to input stream
# The module expects row-by-row input on specific ports

async def load_table(dut, table):
    # Reset inputs
    dut.row_idx.value = 0
    dut.col_val_0.value = 0
    dut.col_val_1.value = 0
    dut.col_val_2.value = 0
    dut.col_val_3.value = 0
    dut.col_val_4.value = 0
    dut.col_val_5.value = 0
    dut.col_val_6.value = 0
    dut.col_val_7.value = 0
    await RisingEdge(dut.clk)
    
    # Stream table rows
    # Assuming row_idx is used to select internal storage or simply passing data
    # Based on prompt, it seems like we need to present data for specific row indices
    for i, row in enumerate(table):
        dut.row_idx.value = i
        dut.col_val_0.value = row[0]
        dut.col_val_1.value = row[1]
        dut.col_val_2.value = row[2]
        dut.col_val_3.value = row[3]
        dut.col_val_4.value = row[4]
        dut.col_val_5.value = row[5]
        dut.col_val_6.value = row[6]
        dut.col_val_7.value = row[7]
        await RisingEdge(dut.clk)

@cocotb.test()
async def test_table_sorter(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.row_idx.value = 0
    dut.col_val_0.value = 0
    dut.col_val_1.value = 0
    dut.col_val_2.value = 0
    dut.col_val_3.value = 0
    dut.col_val_4.value = 0
    dut.col_val_5.value = 0
    dut.col_val_6.value = 0
    dut.col_val_7.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: YES (Sample 1 adapted)
    # Original: [[1,3,2,4], [1,3,4,2]] -> Swap cols 1 and 2 (0-indexed) sorts it.
    # Adapted 4x8:
    # [1, 3, 2, 4, 5, 6, 7, 8]
    # [1, 3, 4, 2, 5, 6, 7, 8]
    # [1, 2, 3, 4, 5, 6, 7, 8] (identity)
    # [1, 2, 3, 4, 5, 6, 7, 8] (identity)
    table1 = [
        [1, 3, 2, 4, 5, 6, 7, 8],
        [1, 3, 4, 2, 5, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8]
    ]
    
    # Load table
    await load_table(dut, table1)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.done.value:
        raise TestFailure("Test Case 1: Timeout waiting for done")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 1 Failed: Expected 1 (YES), got {int(dut.result.value)}")
    
    dut._log.info("Test Case 1 Passed")
    
    # Test Case 2: NO (Sample 2 adapted)
    # Original: [[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]]
    # Adapted to 4x8 (add 5..8 identity)
    table2 = [
        [1, 2, 3, 4, 5, 6, 7, 8],
        [2, 3, 4, 1, 5, 6, 7, 8],
        [3, 4, 1, 2, 5, 6, 7, 8],
        [4, 1, 2, 3, 5, 6, 7, 8]
    ]
    
    # Reset required for next run (simplified logic, just reset module or reload)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await load_table(dut, table2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.done.value:
        raise TestFailure("Test Case 2: Timeout waiting for done")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test Case 2 Failed: Expected 0 (NO), got {int(dut.result.value)}")
        
    dut._log.info("Test Case 2 Passed")

    # Test Case 3: YES (Single row needs swap)
    # Row 0: [1, 2, 3, 5, 4, 6, 7, 8] -> Needs swap of indices 3 and 4
    table3 = [
        [1, 2, 3, 5, 4, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8]
    ]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await load_table(dut, table3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.done.value:
        raise TestFailure("Test Case 3: Timeout waiting for done")
        
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 3 Failed: Expected 1 (YES), got {int(dut.result.value)}")
    
    dut._log.info("Test Case 3 Passed")

    # Test Case 4: NO (Needs more than one swap per row, even with column swap)
    # Row 0: [1, 2, 4, 3, 6, 5, 7, 8] (needs two swaps: 3/4 and 5/6)
    table4 = [
        [1, 2, 4, 3, 6, 5, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [1, 2, 3, 4, 5, 6, 7, 8]
    ]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await load_table(dut, table4)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.done.value:
        raise TestFailure("Test Case 4: Timeout waiting for done")
        
    if dut.result.value != 0:
        raise TestFailure(f"Test Case 4 Failed: Expected 0 (NO), got {int(dut.result.value)}")
        
    dut._log.info("Test Case 4 Passed")
    
    # Summary
    dut._log.info("4/4 tests passed")
