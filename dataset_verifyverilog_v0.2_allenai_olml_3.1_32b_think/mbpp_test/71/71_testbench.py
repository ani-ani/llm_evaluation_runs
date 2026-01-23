import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure, TestSuccess

@cocotb.test()
async def test_comb_sort_seq(dut):
    """Test sequential Comb Sort implementation with 8 elements"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in_0.value = 0
    dut.data_in_1.value = 0
    dut.data_in_2.value = 0
    dut.data_in_3.value = 0
    dut.data_in_4.value = 0
    dut.data_in_5.value = 0
    dut.data_in_6.value = 0
    dut.data_in_7.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [5, 15, 37, 25, 79] + extra values
    dut._log.info("Test 1: [5, 15, 37, 25, 79, 12, 8, 42]")
    dut.data_in_0.value = 5
    dut.data_in_1.value = 15
    dut.data_in_2.value = 37
    dut.data_in_3.value = 25
    dut.data_in_4.value = 79
    dut.data_in_5.value = 12
    dut.data_in_6.value = 8
    dut.data_in_7.value = 42
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 50 cycles)
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout - computation did not finish")
    
    # Verify result: [5, 8, 12, 15, 25, 37, 42, 79]
    expected = [5, 8, 12, 15, 25, 37, 42, 79]
    actual = [int(dut.sorted_out_0.value), int(dut.sorted_out_1.value), int(dut.sorted_out_2.value), 
              int(dut.sorted_out_3.value), int(dut.sorted_out_4.value), int(dut.sorted_out_5.value), 
              int(dut.sorted_out_6.value), int(dut.sorted_out_7.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 1 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test 2: [41, 32, 15, 19, 22] + extra values
    dut._log.info("Test 2: [41, 32, 15, 19, 22, 67, 3, 56]")
    dut.data_in_0.value = 41
    dut.data_in_1.value = 32
    dut.data_in_2.value = 15
    dut.data_in_3.value = 19
    dut.data_in_4.value = 22
    dut.data_in_5.value = 67
    dut.data_in_6.value = 3
    dut.data_in_7.value = 56
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout - computation did not finish")
    
    expected = [3, 15, 19, 22, 32, 41, 56, 67]
    actual = [int(dut.sorted_out_0.value), int(dut.sorted_out_1.value), int(dut.sorted_out_2.value), 
              int(dut.sorted_out_3.value), int(dut.sorted_out_4.value), int(dut.sorted_out_5.value), 
              int(dut.sorted_out_6.value), int(dut.sorted_out_7.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 2 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test 3: [99, 15, 13, 47] + extra values
    dut._log.info("Test 3: [99, 15, 13, 47, 88, 24, 5, 71]")
    dut.data_in_0.value = 99
    dut.data_in_1.value = 15
    dut.data_in_2.value = 13
    dut.data_in_3.value = 47
    dut.data_in_4.value = 88
    dut.data_in_5.value = 24
    dut.data_in_6.value = 5
    dut.data_in_7.value = 71
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout - computation did not finish")
    
    expected = [5, 13, 15, 24, 47, 71, 88, 99]
    actual = [int(dut.sorted_out_0.value), int(dut.sorted_out_1.value), int(dut.sorted_out_2.value), 
              int(dut.sorted_out_3.value), int(dut.sorted_out_4.value), int(dut.sorted_out_5.value), 
              int(dut.sorted_out_6.value), int(dut.sorted_out_7.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 3 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test 4: Edge case - already sorted
    dut._log.info("Test 4: [1, 2, 3, 4, 5, 6, 7, 8]")
    dut.data_in_0.value = 1
    dut.data_in_1.value = 2
    dut.data_in_2.value = 3
    dut.data_in_3.value = 4
    dut.data_in_4.value = 5
    dut.data_in_5.value = 6
    dut.data_in_6.value = 7
    dut.data_in_7.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout - computation did not finish")
    
    expected = [1, 2, 3, 4, 5, 6, 7, 8]
    actual = [int(dut.sorted_out_0.value), int(dut.sorted_out_1.value), int(dut.sorted_out_2.value), 
              int(dut.sorted_out_3.value), int(dut.sorted_out_4.value), int(dut.sorted_out_5.value), 
              int(dut.sorted_out_6.value), int(dut.sorted_out_7.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 4 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test 5: Edge case - reverse sorted
    dut._log.info("Test 5: [8, 7, 6, 5, 4, 3, 2, 1]")
    dut.data_in_0.value = 8
    dut.data_in_1.value = 7
    dut.data_in_2.value = 6
    dut.data_in_3.value = 5
    dut.data_in_4.value = 4
    dut.data_in_5.value = 3
    dut.data_in_6.value = 2
    dut.data_in_7.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout - computation did not finish")
    
    expected = [1, 2, 3, 4, 5, 6, 7, 8]
    actual = [int(dut.sorted_out_0.value), int(dut.sorted_out_1.value), int(dut.sorted_out_2.value), 
              int(dut.sorted_out_3.value), int(dut.sorted_out_4.value), int(dut.sorted_out_5.value), 
              int(dut.sorted_out_6.value), int(dut.sorted_out_7.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 5 failed: expected {expected}, got {actual}"
    
    dut._log.info("All 5 tests passed!")

@cocotb.test()
async def test_comb_sort_comb(dut):
    """Test combinational Comb Sort implementation with 4 elements"""
    
    # Test 1: [5, 15, 37, 25]
    dut._log.info("Test 1: [5, 15, 37, 25]")
    dut.in_0.value = 5
    dut.in_1.value = 15
    dut.in_2.value = 37
    dut.in_3.value = 25
    await Timer(1, units='ns')
    
    expected = [5, 15, 25, 37]
    actual = [int(dut.out_0.value), int(dut.out_1.value), int(dut.out_2.value), int(dut.out_3.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 1 failed: expected {expected}, got {actual}"
    
    # Test 2: [41, 32, 15, 19]
    dut._log.info("Test 2: [41, 32, 15, 19]")
    dut.in_0.value = 41
    dut.in_1.value = 32
    dut.in_2.value = 15
    dut.in_3.value = 19
    await Timer(1, units='ns')
    
    expected = [15, 19, 32, 41]
    actual = [int(dut.out_0.value), int(dut.out_1.value), int(dut.out_2.value), int(dut.out_3.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 2 failed: expected {expected}, got {actual}"
    
    # Test 3: [99, 15, 13, 47]
    dut._log.info("Test 3: [99, 15, 13, 47]")
    dut.in_0.value = 99
    dut.in_1.value = 15
    dut.in_2.value = 13
    dut.in_3.value = 47
    await Timer(1, units='ns')
    
    expected = [13, 15, 47, 99]
    actual = [int(dut.out_0.value), int(dut.out_1.value), int(dut.out_2.value), int(dut.out_3.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 3 failed: expected {expected}, got {actual}"
    
    # Test 4: Already sorted [1, 2, 3, 4]
    dut._log.info("Test 4: [1, 2, 3, 4]")
    dut.in_0.value = 1
    dut.in_1.value = 2
    dut.in_2.value = 3
    dut.in_3.value = 4
    await Timer(1, units='ns')
    
    expected = [1, 2, 3, 4]
    actual = [int(dut.out_0.value), int(dut.out_1.value), int(dut.out_2.value), int(dut.out_3.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 4 failed: expected {expected}, got {actual}"
    
    # Test 5: Reverse sorted [4, 3, 2, 1]
    dut._log.info("Test 5: [4, 3, 2, 1]")
    dut.in_0.value = 4
    dut.in_1.value = 3
    dut.in_2.value = 2
    dut.in_3.value = 1
    await Timer(1, units='ns')
    
    expected = [1, 2, 3, 4]
    actual = [int(dut.out_0.value), int(dut.out_1.value), int(dut.out_2.value), int(dut.out_3.value)]
    
    dut._log.info(f"Expected: {expected}")
    dut._log.info(f"Actual: {actual}")
    assert actual == expected, f"Test 5 failed: expected {expected}, got {actual}"
    
    dut._log.info("All 5 tests passed!")

if __name__ == "__main__":
    print("Cocotb testbench for Comb Sort")
    print("This file should be run with cocotb: cocotb -s module_name -p testbench.py")
