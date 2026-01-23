import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_remove_kth_element(dut):
    """Test removing k-th element from array"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: remove k=3 from 8-element array
    # Input: [1,1,2,3,4,4,5,1] -> extend to 16 elements
    dut._log.info("Test Case 1: k=3")
    input_data = [1,1,2,3,4,4,5,1] + [0]*8
    expected = [1,1,3,4,4,5,1] + [0]*9
    
    # Input phase - fill array
    for i in range(16):
        dut.data_in_index.value = i
        dut.data_in.value = input_data[i]
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_in_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Set k and start
    dut.k.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check results
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    if dut.result_count.value != 15:
        raise TestFailure(f"Expected count=15, got {dut.result_count.value}")
    
    result_list = [int(dut.result[i].value) for i in range(15)]
    if result_list != expected:
        raise TestFailure(f"Expected {expected}, got {result_list}")
    
    dut._log.info(f"Test 1 Passed: {result_list}")
    
    # Test Case 2: remove k=4 from full array
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 2: k=4")
    input_data = [0,0,1,2,3,4,4,5,6,6,6,7,8,9,4,4]
    expected = [0,0,1,3,4,4,5,6,6,6,7,8,9,4,4]
    
    # Input phase
    for i in range(16):
        dut.data_in_index.value = i
        dut.data_in.value = input_data[i]
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_in_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Process
    dut.k.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    if dut.result_count.value != 15:
        raise TestFailure(f"Expected count=15, got {dut.result_count.value}")
    
    result_list = [int(dut.result[i].value) for i in range(15)]
    if result_list != expected:
        raise TestFailure(f"Expected {expected}, got {result_list}")
    
    dut._log.info(f"Test 2 Passed: {result_list}")
    
    # Test Case 3: remove k=5
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 3: k=5")
    input_data = [10,10,15,19,18,18,17,26,26,17,18,10] + [0]*4
    expected = [10,10,15,19,18,17,26,26,17,18,10] + [0]*4
    
    # Input phase
    for i in range(16):
        dut.data_in_index.value = i
        dut.data_in.value = input_data[i]
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_in_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Process
    dut.k.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    if dut.result_count.value != 15:
        raise TestFailure(f"Expected count=15, got {dut.result_count.value}")
    
    result_list = [int(dut.result[i].value) for i in range(15)]
    if result_list != expected:
        raise TestFailure(f"Expected {expected}, got {result_list}")
    
    dut._log.info(f"Test 3 Passed: {result_list}")
    
    # Test Case 4: Edge case k=1 (remove first)
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 4: k=1 (remove first)")
    input_data = [99,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
    expected = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
    
    # Input phase
    for i in range(16):
        dut.data_in_index.value = i
        dut.data_in.value = input_data[i]
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_in_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Process
    dut.k.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    if dut.result_count.value != 15:
        raise TestFailure(f"Expected count=15, got {dut.result_count.value}")
    
    result_list = [int(dut.result[i].value) for i in range(15)]
    if result_list != expected:
        raise TestFailure(f"Expected {expected}, got {result_list}")
    
    dut._log.info(f"Test 4 Passed: {result_list}")
    
    # Test Case 5: Edge case k=16 (remove last)
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 5: k=16 (remove last)")
    input_data = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,99]
    expected = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
    
    # Input phase
    for i in range(16):
        dut.data_in_index.value = i
        dut.data_in.value = input_data[i]
        dut.data_in_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_in_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Process
    dut.k.value = 16
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    if dut.result_count.value != 15:
        raise TestFailure(f"Expected count=15, got {dut.result_count.value}")
    
    result_list = [int(dut.result[i].value) for i in range(15)]
    if result_list != expected:
        raise TestFailure(f"Expected {expected}, got {result_list}")
    
    dut._log.info(f"Test 5 Passed: {result_list}")
    
    dut._log.info("All 5 tests passed!")