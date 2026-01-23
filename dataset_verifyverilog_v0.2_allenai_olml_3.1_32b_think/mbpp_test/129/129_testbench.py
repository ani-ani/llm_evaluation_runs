import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_magic_square(dut):
    """Test magic_square_test module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    dut.matrix_cell_i.value = 0
    dut.write_addr.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to load matrix
    async def load_matrix(matrix):
        """Load 4x4 matrix into DUT"""
        flat = []
        for row in matrix:
            flat.extend(row)
        
        for i, val in enumerate(flat):
            dut.matrix_cell_i.value = val
            dut.write_addr.value = i
            dut.write_en.value = 1
            await RisingEdge(dut.clk)
        
        dut.write_en.value = 0
    
    # Helper function to run test
    async def run_test(matrix, expected):
        """Load matrix, start computation, wait for result"""
        await load_matrix(matrix)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 60 cycles)
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        actual = int(dut.result.value)
        return actual == expected
    
    # Test 1: 4x4 magic square (should pass)
    matrix1 = [[7, 12, 1, 14], [2, 13, 8, 11], [16, 3, 10, 5], [9, 6, 15, 4]]
    test1_pass = await run_test(matrix1, 1)
    
    # Test 2: 3x3 magic square (treated as 4x4 with zeros)
    matrix2 = [[2, 7, 6, 0], [9, 5, 1, 0], [4, 3, 8, 0], [0, 0, 0, 0]]
    # This is NOT a magic square (rows have different sums)
    # Actually test2 is 3x3, so let's use a proper 4x4 magic square
    matrix2 = [[2, 7, 6, 0], [9, 5, 1, 0], [4, 3, 8, 0], [0, 0, 0, 0]]
    # This will fail, so let's use actual 4x4 magic square
    matrix2 = [[16, 3, 2, 13], [5, 10, 11, 8], [9, 6, 7, 12], [4, 15, 14, 1]]
    test2_pass = await run_test(matrix2, 1)
    
    # Test 3: Non-magic square (modified matrix1 - change one element)
    matrix3 = [[7, 12, 1, 14], [2, 13, 8, 11], [16, 3, 10, 5], [9, 6, 15, 3]]  # Last element changed
    test3_pass = await run_test(matrix3, 0)
    
    # Test 4: All same numbers (should be magic square)
    matrix4 = [[5, 5, 5, 5], [5, 5, 5, 5], [5, 5, 5, 5], [5, 5, 5, 5]]
    test4_pass = await run_test(matrix4, 1)
    
    # Test 5: Sequential numbers (not magic)
    matrix5 = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
    test5_pass = await run_test(matrix5, 0)
    
    # Summary
    results = [test1_pass, test2_pass, test3_pass, test4_pass, test5_pass]
    passed = sum(results)
    total = len(results)
    
    print(f"
Test Results: {passed}/{total} tests passed")
    
    # Assertions
    assert test1_pass, "Test 1 failed: Valid 4x4 magic square"
    assert test2_pass, "Test 2 failed: Another valid 4x4 magic square"
    assert test3_pass, "Test 3 failed: Modified magic square should return false"
    assert test4_pass, "Test 4 failed: Uniform matrix should be magic"
    assert test5_pass, "Test 5 failed: Sequential matrix should not be magic"
