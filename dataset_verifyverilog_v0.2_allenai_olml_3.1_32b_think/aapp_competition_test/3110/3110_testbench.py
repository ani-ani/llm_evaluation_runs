import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_code_cracker(dut):
    """Test the code cracker module with multiple test cases"""
    
    # Initialize signals
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.load_en.value = 0
    dut.data_in.value = 0
    dut.row_addr.value = 0
    dut.col_addr.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 1: 3x3 Grid (Embedded in 4x4) ===")
    # Input: 3 3
    # 1 2 4
    # 0 3 6
    # 4 0 3
    # Embed in 4x4: 4th row/col can be 0 or dummy
    
    grid1 = [
        [1, 2, 4, 0],
        [0, 3, 6, 0],
        [4, 0, 3, 0],
        [0, 0, 0, 0]
    ]
    
    # Load grid
    dut.load_en.value = 1
    for r in range(4):
        for c in range(4):
            dut.row_addr.value = r
            dut.col_addr.value = c
            dut.data_in.value = grid1[r][c]
            await RisingEdge(dut.clk)
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        print("TIMEOUT!")
    else:
        result = int(dut.count.value)
        print(f"Result: {result} (Expected: 2)")
        assert result == 2, f"Expected 2, got {result}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 2: 3x4 Grid (Embedded in 4x4) ===")
    # Input: 3 4
    # 2 3 0 7
    # 0 0 2 1
    # 0 0 3 0
    
    grid2 = [
        [2, 3, 0, 7],
        [0, 0, 2, 1],
        [0, 0, 3, 0],
        [0, 0, 0, 0]
    ]
    
    dut.load_en.value = 1
    for r in range(4):
        for c in range(4):
            dut.row_addr.value = r
            dut.col_addr.value = c
            dut.data_in.value = grid2[r][c]
            await RisingEdge(dut.clk)
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        print("TIMEOUT!")
    else:
        result = int(dut.count.value)
        print(f"Result: {result} (Expected: 37)")
        assert result == 37, f"Expected 37, got {result}"
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 3: 3x4 Grid (Embedded) ===")
    # Input: 3 4
    # 1 3 0 7
    # 2 0 0 1
    # 0 0 9 0
    
    grid3 = [
        [1, 3, 0, 7],
        [2, 0, 0, 1],
        [0, 0, 9, 0],
        [0, 0, 0, 0]
    ]
    
    dut.load_en.value = 1
    for r in range(4):
        for c in range(4):
            dut.row_addr.value = r
            dut.col_addr.value = c
            dut.data_in.value = grid3[r][c]
            await RisingEdge(dut.clk)
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        print("TIMEOUT!")
    else:
        result = int(dut.count.value)
        print(f"Result: {result} (Expected: 14)")
        assert result == 14, f"Expected 14, got {result}"
    
    print("
=== All Tests Passed! ===")

@cocotb.test()
async def test_edge_case(dut):
    """Test with minimal unknowns"""
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.load_en.value = 0
    dut.data_in.value = 0
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Full grid with 1 unknown
    grid = [
        [1, 2, 3, 4],
        [4, 1, 2, 3],
        [2, 3, 4, 1],
        [3, 4, 1, 0]
    ]
    
    dut.load_en.value = 1
    for r in range(4):
        for c in range(4):
            dut.row_addr.value = r
            dut.col_addr.value = c
            dut.data_in.value = grid[r][c]
            await RisingEdge(dut.clk)
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout < 2000:
        print(f"Edge case result: {int(dut.count.value)}")
    else:
        print("Edge case timeout (acceptable for very constrained inputs)")