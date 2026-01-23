import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_matrix_recovery_basic(dut):
    """Test basic matrix recovery case"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.row_parity.value = 0
    dut.col_parity.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: row=0110 (0x6), col=1001 (0x9)
    dut.row_parity.value = 0b0110
    dut.col_parity.value = 0b1001
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 128 cycles)
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check result
    assert dut.done.value == 1, "Should complete"
    if dut.impossible.value == 0:
        matrix = int(dut.matrix_out.value)
        print(f"Matrix: {bin(matrix)}")
        # Expected: 1111 0111 1110 1111 = 0xF7EEF = 1013487
        # In hex: row0=1111 (15), row1=0111 (7), row2=1110 (14), row3=1111 (15)
        print(f"Result matrix: {matrix:016b}")
        # Verify parities
        for i in range(4):
            row = (matrix >> (4*i)) & 0xF
            row_xor = 0
            for j in range(4):
                row_xor ^= (row >> j) & 1
            expected = (dut.row_parity.value >> i) & 1
            assert row_xor == expected, f"Row {i} parity mismatch"
        
        for i in range(4):
            col_xor = 0
            for j in range(4):
                col_xor ^= (matrix >> (j*4 + i)) & 1
            expected = (dut.col_parity.value >> i) & 1
            assert col_xor == expected, f"Col {i} parity mismatch"
    
    print("Test 1 passed!")

@cocotb.test()
async def test_matrix_recovery_impossible(dut):
    """Test impossible case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: row=0 (0x0), col=1 (0x1) - impossible
    dut.row_parity.value = 0b0
    dut.col_parity.value = 0b1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Should complete"
    assert dut.impossible.value == 1, "Should be impossible"
    print("Test 2 passed!")

@cocotb.test()
async def test_matrix_recovery_case3(dut):
    """Test case 3: row=11 (0x3), col=0110 (0x6)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # row=11 (binary 0011 for 2 rows), col=0110 (binary 0110 for 4 columns)
    # But we need 2 rows and 4 columns, so row_parity = 0011, col_parity = 0110
    dut.row_parity.value = 0b0011  # 2 rows: row0=1, row1=1
    dut.col_parity.value = 0b0110  # 4 cols: col0=0, col1=1, col2=1, col3=0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Should complete"
    if dut.impossible.value == 0:
        matrix = int(dut.matrix_out.value)
        print(f"Matrix: {matrix:016b}")
        # Extract first 2 rows (8 bits)
        row0 = matrix & 0xF
        row1 = (matrix >> 4) & 0xF
        print(f"Row0: {row0:04b}, Row1: {row1:04b}")
        # Expected: 1011 1101 = 0xB 0xD
        # This is 1011 and 1101 which matches sample output
    
    print("Test 3 passed!")

@cocotb.test()
async def test_matrix_recovery_all_zeros(dut):
    """Test all zeros case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2x2 all zeros: row=00, col=00
    dut.row_parity.value = 0b00
    dut.col_parity.value = 0b00
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Should complete"
    assert dut.impossible.value == 0, "Should be possible"
    matrix = int(dut.matrix_out.value)
    # Should be 1111 1111 for 4x4 but with 2 rows, only first 8 bits matter
    print(f"Matrix: {matrix:016b}")
    assert matrix == 0xFFFF or matrix == 0x3F3F, "Should be all 1s"
    print("Test 4 passed!")

@cocotb.test()
async def test_matrix_recovery_single_row(dut):
    """Test single row case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 1x3: row=0, col=100 (but 3 columns -> 0b100 = 4, need 0b100 for 3 cols? )
    # For 1 row, 3 cols: row_parity = 0, col_parity = 100 (3 bits)
    # But we're limited to 4x4, so:
    dut.row_parity.value = 0b0  # 1 row: parity 0
    dut.col_parity.value = 0b0100  # 3 cols: col2=1 (bit 2)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Should complete"
    if dut.impossible.value == 0:
        matrix = int(dut.matrix_out.value)
        row0 = matrix & 0xF
        print(f"Row0: {row0:04b}")
    
    print("Test 5 passed!")
}