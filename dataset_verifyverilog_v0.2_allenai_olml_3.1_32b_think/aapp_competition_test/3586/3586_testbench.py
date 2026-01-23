import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_find_largest_d(dut):
    """Test find_largest_d module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: [2, 3, 5, 7, 12] -> 2+3+7=12
    dut._log.info("Test Case 1: [2, 3, 5, 7, 12]")
    test_data1 = [2, 3, 5, 7, 12, 0, 0, 0]
    for i, val in enumerate(test_data1):
        dut.data_in.value = val
        dut.index.value = i
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    dut.write_en.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (check done signal)
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module should complete computation"
    assert dut.valid.value == 1, "Should find valid solution"
    assert dut.result.value == 12, f"Expected 12, got {dut.result.value}"
    dut._log.info(f"Test 1 passed: result={dut.result.value}, valid={dut.valid.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 2: [2, 16, 64, 256, 1024] -> no solution
    dut._log.info("Test Case 2: [2, 16, 64, 256, 1024]")
    test_data2 = [2, 16, 64, 256, 1024, 0, 0, 0]
    for i, val in enumerate(test_data2):
        dut.data_in.value = val
        dut.index.value = i
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    dut.write_en.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module should complete computation"
    assert dut.valid.value == 0, "Should not find valid solution"
    dut._log.info(f"Test 2 passed: result={dut.result.value}, valid={dut.valid.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 3: [1, 2, 3, 6, 10, 15, 0, 0] -> 1+3+6=10 or 2+3+5=10 but 5 not present, so 10 is max
    # Actually 1+2+3=6, 1+2+6=9 not present, 1+3+6=10, 2+3+6=11 not present
    # So 10 is the answer
    dut._log.info("Test Case 3: [1, 2, 3, 6, 10, 15, 0, 0]")
    test_data3 = [1, 2, 3, 6, 10, 15, 0, 0]
    for i, val in enumerate(test_data3):
        dut.data_in.value = val
        dut.index.value = i
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    dut.write_en.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module should complete computation"
    assert dut.valid.value == 1, "Should find valid solution"
    # 1+2+3=6, 1+3+6=10 (largest)
    assert dut.result.value == 10, f"Expected 10, got {dut.result.value}"
    dut._log.info(f"Test 3 passed: result={dut.result.value}, valid={dut.valid.value}")
    
    # Test Case 4: [0, 0, 0, 0, 0, 0, 0, 0] -> 0+0+0=0 but need distinct indices, invalid
    # However with distinct elements constraint and all same values, this should be no solution
    dut._log.info("Test Case 4: [0, 0, 0, 0, 0, 0, 0, 0] with distinct values only")
    # Since problem requires distinct elements and input says distinct integers,
    # let's test with distinct values that sum to a larger one
    test_data4 = [-10, -5, 0, 5, 10, 15, 20, 25]
    for i, val in enumerate(test_data4):
        dut.data_in.value = val
        dut.index.value = i
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    dut.write_en.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module should complete computation"
    # -10 + -5 + 20 = 5, -10 + 0 + 25 = 15, -5 + 0 + 25 = 20, 0 + 5 + 20 = 25
    assert dut.valid.value == 1, "Should find valid solution"
    assert dut.result.value == 25, f"Expected 25, got {dut.result.value}"
    dut._log.info(f"Test 4 passed: result={dut.result.value}, valid={dut.valid.value}")
    
    # Summary
    dut._log.info("All tests passed!")
