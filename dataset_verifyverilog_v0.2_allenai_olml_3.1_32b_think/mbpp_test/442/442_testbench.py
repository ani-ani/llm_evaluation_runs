import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_positive_ratio(dut):
    """Test the positive_ratio module with various test cases"""
    
    # Initialize inputs
    dut.data_in.value = 0
    dut.index.value = 0
    dut.valid.value = 0
    
    # Wait for a few cycles
    await Timer(10, units='ns')
    
    # Test case 1: [0, 1, 2, -1, -5, 6, 0, -3] expected 0.54 = 0x00008A3D
    array1 = [0, 1, 2, -1, -5, 6, 0, -3]
    dut._log.info("Test 1: Array %s", array1)
    
    for i, val in enumerate(array1):
        dut.data_in.value = val & 0xFF  # 8-bit signed
        dut.index.value = i
        dut.valid.value = 1
        await Timer(10, units='ns')
        await RisingEdge(dut.clk) if hasattr(dut, 'clk') else Timer(10, units='ns')
    
    await Timer(10, units='ns')
    result1 = dut.result.value.integer
    expected1 = int(0.54 * 65536)  # 35389 = 0x8A3D
    
    dut._log.info("Result 1: 0x%08X, Expected: 0x%08X", result1, expected1)
    assert abs(result1 - expected1) <= 1, f"Test 1 failed: got {result1}, expected {expected1}"
    
    # Test case 2: [2, 1, 2, -1, -5, 6, 4, -3] expected 0.69 = 0x0000B333
    array2 = [2, 1, 2, -1, -5, 6, 4, -3]
    dut._log.info("Test 2: Array %s", array2)
    
    # Reset for next test
    dut.valid.value = 0
    await Timer(10, units='ns')
    
    for i, val in enumerate(array2):
        dut.data_in.value = val & 0xFF
        dut.index.value = i
        dut.valid.value = 1
        await Timer(10, units='ns')
        await RisingEdge(dut.clk) if hasattr(dut, 'clk') else Timer(10, units='ns')
    
    await Timer(10, units='ns')
    result2 = dut.result.value.integer
    expected2 = int(0.69 * 65536)  # 45875 = 0xB333
    
    dut._log.info("Result 2: 0x%08X, Expected: 0x%08X", result2, expected2)
    assert abs(result2 - expected2) <= 1, f"Test 2 failed: got {result2}, expected {expected2}"
    
    # Test case 3: [2, 4, -6, -9, 11, -12, 14, -5] expected 0.56 = 0x00008F5C
    array3 = [2, 4, -6, -9, 11, -12, 14, -5]
    dut._log.info("Test 3: Array %s", array3)
    
    dut.valid.value = 0
    await Timer(10, units='ns')
    
    for i, val in enumerate(array3):
        dut.data_in.value = val & 0xFF
        dut.index.value = i
        dut.valid.value = 1
        await Timer(10, units='ns')
        await RisingEdge(dut.clk) if hasattr(dut, 'clk') else Timer(10, units='ns')
    
    await Timer(10, units='ns')
    result3 = dut.result.value.integer
    expected3 = int(0.56 * 65536)  # 36700 = 0x8F5C
    
    dut._log.info("Result 3: 0x%08X, Expected: 0x%08X", result3, expected3)
    assert abs(result3 - expected3) <= 1, f"Test 3 failed: got {result3}, expected {expected3}"
    
    # Edge case: all negative
    array4 = [-1, -2, -3, -4, -5, -6, -7, -8]
    dut._log.info("Test 4: All negative %s", array4)
    
    dut.valid.value = 0
    await Timer(10, units='ns')
    
    for i, val in enumerate(array4):
        dut.data_in.value = val & 0xFF
        dut.index.value = i
        dut.valid.value = 1
        await Timer(10, units='ns')
        await RisingEdge(dut.clk) if hasattr(dut, 'clk') else Timer(10, units='ns')
    
    await Timer(10, units='ns')
    result4 = dut.result.value.integer
    expected4 = 0  # 0/8 = 0
    
    dut._log.info("Result 4: 0x%08X, Expected: 0x%08X", result4, expected4)
    assert result4 == expected4, f"Test 4 failed: got {result4}, expected {expected4}"
    
    # Edge case: all positive
    array5 = [1, 2, 3, 4, 5, 6, 7, 8]
    dut._log.info("Test 5: All positive %s", array5)
    
    dut.valid.value = 0
    await Timer(10, units='ns')
    
    for i, val in enumerate(array5):
        dut.data_in.value = val & 0xFF
        dut.index.value = i
        dut.valid.value = 1
        await Timer(10, units='ns')
        await RisingEdge(dut.clk) if hasattr(dut, 'clk') else Timer(10, units='ns')
    
    await Timer(10, units='ns')
    result5 = dut.result.value.integer
    expected5 = int(1.0 * 65536)  # 65536 = 0x10000
    
    dut._log.info("Result 5: 0x%08X, Expected: 0x%08X", result5, expected5)
    assert result5 == expected5, f"Test 5 failed: got {result5}, expected {expected5}"
    
    dut._log.info("All 5/5 tests passed!")
