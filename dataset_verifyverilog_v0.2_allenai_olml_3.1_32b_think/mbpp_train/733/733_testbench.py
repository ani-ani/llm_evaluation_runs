import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_find_first_occurrence(dut):
    """Test find_first_occurrence module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target.value = 0
    dut.array_element_0.value = 0
    dut.array_element_1.value = 0
    dut.array_element_2.value = 0
    dut.array_element_3.value = 0
    dut.array_element_4.value = 0
    dut.array_element_5.value = 0
    dut.array_element_6.value = 0
    dut.array_element_7.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [2, 5, 5, 5, 6, 6, 8, 9] find 5 -> expected 1
    dut._log.info("Test 1: Array=[2,5,5,5,6,6,8,9], Target=5")
    dut.array_element_0.value = 2
    dut.array_element_1.value = 5
    dut.array_element_2.value = 5
    dut.array_element_3.value = 5
    dut.array_element_4.value = 6
    dut.array_element_5.value = 6
    dut.array_element_6.value = 8
    dut.array_element_7.value = 9
    dut.target.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 6 cycles)
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: done signal not asserted after 10 cycles")
    if dut.found.value != 1:
        raise TestFailure(f"Test 1: found should be 1, got {dut.found.value}")
    if dut.result.value != 1:
        raise TestFailure(f"Test 1: Expected result=1, got {dut.result.value}")
    
    # Test case 2: [2, 3, 5, 5, 6, 6, 8, 9] find 5 -> expected 2
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 2: Array=[2,3,5,5,6,6,8,9], Target=5")
    dut.array_element_0.value = 2
    dut.array_element_1.value = 3
    dut.array_element_2.value = 5
    dut.array_element_3.value = 5
    dut.array_element_4.value = 6
    dut.array_element_5.value = 6
    dut.array_element_6.value = 8
    dut.array_element_7.value = 9
    dut.target.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: done signal not asserted")
    if dut.found.value != 1:
        raise TestFailure(f"Test 2: found should be 1, got {dut.found.value}")
    if dut.result.value != 2:
        raise TestFailure(f"Test 2: Expected result=2, got {dut.result.value}")
    
    # Test case 3: [2, 4, 1, 5, 6, 6, 8, 9] find 6 -> expected 4 (note: array not sorted, but test expects 4)
    # Actually this test case has 1 at index 2 which breaks sorting assumption
    # Let's use corrected test case: [1, 2, 4, 5, 6, 6, 8, 9] find 6 -> expected 4
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 3: Array=[1,2,4,5,6,6,8,9], Target=6")
    dut.array_element_0.value = 1
    dut.array_element_1.value = 2
    dut.array_element_2.value = 4
    dut.array_element_3.value = 5
    dut.array_element_4.value = 6
    dut.array_element_5.value = 6
    dut.array_element_6.value = 8
    dut.array_element_7.value = 9
    dut.target.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: done signal not asserted")
    if dut.found.value != 1:
        raise TestFailure(f"Test 3: found should be 1, got {dut.found.value}")
    if dut.result.value != 4:
        raise TestFailure(f"Test 3: Expected result=4, got {dut.result.value}")
    
    # Test case 4: Target not found
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 4: Array=[1,2,4,5,6,6,8,9], Target=7")
    dut.array_element_0.value = 1
    dut.array_element_1.value = 2
    dut.array_element_2.value = 4
    dut.array_element_3.value = 5
    dut.array_element_4.value = 6
    dut.array_element_5.value = 6
    dut.array_element_6.value = 8
    dut.array_element_7.value = 9
    dut.target.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: done signal not asserted")
    if dut.found.value != 0:
        raise TestFailure(f"Test 4: found should be 0, got {dut.found.value}")
    if dut.result.value != 15:
        raise TestFailure(f"Test 4: Expected result=15 (not found), got {dut.result.value}")
    
    # Test case 5: Target at index 0
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 5: Array=[1,2,4,5,6,6,8,9], Target=1")
    dut.array_element_0.value = 1
    dut.array_element_1.value = 2
    dut.array_element_2.value = 4
    dut.array_element_3.value = 5
    dut.array_element_4.value = 6
    dut.array_element_5.value = 6
    dut.array_element_6.value = 8
    dut.array_element_7.value = 9
    dut.target.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: done signal not asserted")
    if dut.found.value != 1:
        raise TestFailure(f"Test 5: found should be 1, got {dut.found.value}")
    if dut.result.value != 0:
        raise TestFailure(f"Test 5: Expected result=0, got {dut.result.value}")
    
    # Test case 6: Target at index 7
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 6: Array=[1,2,4,5,6,6,8,9], Target=9")
    dut.array_element_0.value = 1
    dut.array_element_1.value = 2
    dut.array_element_2.value = 4
    dut.array_element_3.value = 5
    dut.array_element_4.value = 6
    dut.array_element_5.value = 6
    dut.array_element_6.value = 8
    dut.array_element_7.value = 9
    dut.target.value = 9
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 6: done signal not asserted")
    if dut.found.value != 1:
        raise TestFailure(f"Test 6: found should be 1, got {dut.found.value}")
    if dut.result.value != 7:
        raise TestFailure(f"Test 6: Expected result=7, got {dut.result.value}")
    
    dut._log.info("All tests passed!")