import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def to_binary(value, bits):
    return value & ((1 << bits) - 1)

@cocotb.test()
async def test_replace_list(dut):
    # Test case 1: replace_list([1, 3, 5, 7, 9, 10],[2, 4, 6, 8]) -> [1, 3, 5, 7, 9, 2, 4, 6, 8]
    dut._log.info("Starting Test 1")
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load list1 = [1, 3, 5, 7, 9, 10] (6 elements)
    list1 = [1, 3, 5, 7, 9, 10]
    dut.list1_len.value = len(list1)
    for i, val in enumerate(list1):
        dut.list1_addr.value = i
        dut.list1_data_in.value = val
        await RisingEdge(dut.clk)
    
    # Load list2 = [2, 4, 6, 8] (4 elements)
    list2 = [2, 4, 6, 8]
    dut.list2_len.value = len(list2)
    for i, val in enumerate(list2):
        dut.list2_addr.value = i
        dut.list2_data_in.value = val
        await RisingEdge(dut.clk)
    
    # Signal load complete
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for processing
    await Timer(50, units='ns')
    
    # Collect results
    results = []
    timeout = 20
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_data.value))
        if dut.done.value:
            break
        timeout -= 1
    
    expected = [1, 3, 5, 7, 9, 2, 4, 6, 8]
    if results != expected:
        raise TestFailure(f"Test 1 failed: got {results}, expected {expected}")
    
    dut._log.info(f"Test 1 passed: {results}")
    
    # Test case 2: replace_list([1,2,3,4,5],[5,6,7,8]) -> [1,2,3,4,5,6,7,8]
    dut._log.info("Starting Test 2")
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load list1 = [1, 2, 3, 4, 5]
    list1 = [1, 2, 3, 4, 5]
    dut.list1_len.value = len(list1)
    for i, val in enumerate(list1):
        dut.list1_addr.value = i
        dut.list1_data_in.value = val
        await RisingEdge(dut.clk)
    
    # Load list2 = [5, 6, 7, 8]
    list2 = [5, 6, 7, 8]
    dut.list2_len.value = len(list2)
    for i, val in enumerate(list2):
        dut.list2_addr.value = i
        dut.list2_data_in.value = val
        await RisingEdge(dut.clk)
    
    # Signal load complete
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = []
    timeout = 20
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_data.value))
        if dut.done.value:
            break
        timeout -= 1
    
    expected = [1, 2, 3, 4, 5, 6, 7, 8]
    if results != expected:
        raise TestFailure(f"Test 2 failed: got {results}, expected {expected}")
    
    dut._log.info(f"Test 2 passed: {results}")
    
    # Test case 3: Replace with single element
    dut._log.info("Starting Test 3")
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load list1 = [1, 2, 3] (simulating "red","blue","green" with 1,2,3)
    list1 = [1, 2, 3]
    dut.list1_len.value = len(list1)
    for i, val in enumerate(list1):
        dut.list1_addr.value = i
        dut.list1_data_in.value = val
        await RisingEdge(dut.clk)
    
    # Load list2 = [4] (simulating "yellow")
    list2 = [4]
    dut.list2_len.value = len(list2)
    for i, val in enumerate(list2):
        dut.list2_addr.value = i
        dut.list2_data_in.value = val
        await RisingEdge(dut.clk)
    
    # Signal load complete
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = []
    timeout = 20
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.result_valid.value and dut.done.value == 0:
            results.append(int(dut.result_data.value))
        if dut.done.value:
            break
        timeout -= 1
    
    expected = [1, 2, 4]
    if results != expected:
        raise TestFailure(f"Test 3 failed: got {results}, expected {expected}")
    
    dut._log.info(f"Test 3 passed: {results}")
    
    dut._log.info("All tests passed!")