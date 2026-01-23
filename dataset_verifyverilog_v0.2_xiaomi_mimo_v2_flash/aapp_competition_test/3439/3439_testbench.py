import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_baltic_drain_basic(dut):
    """Test basic flood drain functionality"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.device_row.value = 0
    dut.device_col.value = 0
    
    # Initialize altitude map - using the first sample
    # Grid: 3x3 shown, but we use 8x8 so pad with 0
    # Row 0: -5, 2, -5, 0, 0, 0, 0, 0
    # Row 1: -1, -2, -1, 0, 0, 0, 0, 0
    # Row 2: 5, 4, -5, 0, 0, 0, 0, 0
    # Rows 3-7: all 0
    
    # Note: Verilog 2D array indexing: altitude_map[row][col]
    for row in range(8):
        for col in range(8):
            # Set all to 0 first
            dut.altitude_map[row][col].value = 0
    
    # Sample 1: device at (2,2) 1-indexed = (1,1) 0-indexed
    # altitude_map[0][0] = -5
    # altitude_map[0][1] = 2
    # altitude_map[0][2] = -5
    # altitude_map[1][0] = -1
    # altitude_map[1][1] = -2
    # altitude_map[1][2] = -1
    # altitude_map[2][0] = 5
    # altitude_map[2][1] = 4
    # altitude_map[2][2] = -5
    
    # In Verilog, array indexing: [row][col] where row is first dimension
    dut.altitude_map[0][0].value = -5 & 0xF  # 2's complement: 1111 = -5
    dut.altitude_map[0][1].value = 2
    dut.altitude_map[0][2].value = -5 & 0xF
    dut.altitude_map[1][0].value = -1 & 0xF
    dut.altitude_map[1][1].value = -2 & 0xF  # Device location
    dut.altitude_map[1][2].value = -1 & 0xF
    dut.altitude_map[2][0].value = 5
    dut.altitude_map[2][1].value = 4
    dut.altitude_map[2][2].value = -5 & 0xF
    
    await Timer(20, units='ns')
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set device position (0-indexed)
    dut.device_row.value = 1  # row 2 in 1-indexed input
    dut.device_col.value = 1  # col 2 in 1-indexed input
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Did not complete within {timeout} cycles")
    
    # Check result
    result = int(dut.total_drained.value)
    expected = 10
    
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_baltic_drain_second_sample(dut):
    """Test second sample case"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Initialize all to 0
    for row in range(8):
        for col in range(8):
            dut.altitude_map[row][col].value = 0
    
    # Second sample: 2x3 grid
    # -2 -3 -4
    # -3 -2 -3
    # Device at (2,1) 1-indexed = (1,0) 0-indexed
    
    dut.altitude_map[0][0].value = -2 & 0xF
    dut.altitude_map[0][1].value = -3 & 0xF
    dut.altitude_map[0][2].value = -4 & 0xF
    dut.altitude_map[1][0].value = -3 & 0xF  # Device location
    dut.altitude_map[1][1].value = -2 & 0xF
    dut.altitude_map[1][2].value = -3 & 0xF
    
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.device_row.value = 1  # row 2 in 1-indexed
    dut.device_col.value = 0  # col 1 in 1-indexed
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Did not complete within {timeout} cycles")
    
    result = int(dut.total_drained.value)
    expected = 16
    
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_baltic_drain_edge_cases(dut):
    """Test edge cases: single cell drain"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Initialize all to 0
    for row in range(8):
        for col in range(8):
            dut.altitude_map[row][col].value = 0
    
    # Single negative cell at (0,0)
    dut.altitude_map[0][0].value = -5 & 0xF
    
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.device_row.value = 0
    dut.device_col.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = int(dut.total_drained.value)
    expected = 5
    
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_baltic_drain_no_drain(dut):
    """Test case where device is on dry land (should drain 0)"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Initialize all to positive values
    for row in range(8):
        for col in range(8):
            dut.altitude_map[row][col].value = 5
    
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.device_row.value = 3
    dut.device_col.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = int(dut.total_drained.value)
    expected = 0
    
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

@cocotb.test()
async def test_baltic_drain_complex(dut):
    """Test complex drain pattern"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Initialize all to 0
    for row in range(8):
        for col in range(8):
            dut.altitude_map[row][col].value = 0
    
    # 4x4 test: cross pattern of negative values
    # -1  0 -1  0
    #  0 -2  0 -1
    # -1  0 -3  0
    #  0 -1  0 -4
    dut.altitude_map[0][0].value = -1 & 0xF
    dut.altitude_map[0][2].value = -1 & 0xF
    dut.altitude_map[1][1].value = -2 & 0xF
    dut.altitude_map[1][3].value = -1 & 0xF
    dut.altitude_map[2][0].value = -1 & 0xF
    dut.altitude_map[2][2].value = -3 & 0xF
    dut.altitude_map[3][1].value = -1 & 0xF
    dut.altitude_map[3][3].value = -4 & 0xF
    
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Device at center (1,1) with altitude -2
    dut.device_row.value = 1
    dut.device_col.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Did not complete within {timeout} cycles")
    
    result = int(dut.total_drained.value)
    # Expected: 1+2+1+1+3+1+4 = 13 (all connected cells drain)
    # But depends on flood fill connectivity
    # From (1,1) can reach: (0,0)=1, (0,2)=1, (1,3)=1, (2,0)=1, (2,2)=3, (3,1)=1, (3,3)=4
    # Plus itself (1,1)=2 = total 14
    expected = 14
    
    print(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Expected {expected}, got {result}"

print("All tests completed!")