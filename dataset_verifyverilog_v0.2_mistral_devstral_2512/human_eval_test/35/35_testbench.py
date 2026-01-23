import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_element(dut):
    """Test max_element module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_size.value = 0
    for i in range(16):
        dut.array_data[i].value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 2, 3] -> 3
    dut.array_size.value = 3
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (17 cycles: init + 15 compares + done)
    for _ in range(18):
        await RisingEdge(dut.clk)
    
    if dut.max_result.value.integer != 3:
        raise TestFailure(f"Test 1 failed: expected 3, got {dut.max_result.value.integer}")
    if not dut.done.value:
        raise TestFailure("Test 1 failed: done not asserted")
    print("Test 1 passed: [1,2,3] -> 3")
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test case 2: [5, 3, -5, 2, -3, 3, 9, 0, 124, 1, -10] -> 124
    test_array = [5, 3, -5, 2, -3, 3, 9, 0, 124, 1, -10]
    dut.array_size.value = len(test_array)
    for i, val in enumerate(test_array):
        # Handle signed values for 16-bit
        if val < 0:
            dut.array_data[i].value = (1 << 16) + val
        else:
            dut.array_data[i].value = val
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(18):
        await RisingEdge(dut.clk)
    
    result = dut.max_result.value.integer
    if result > 32767:
        result = result - 65536
    if result != 124:
        raise TestFailure(f"Test 2 failed: expected 124, got {result}")
    print("Test 2 passed: array with 124 as max")
    
    # Test case 3: all negative [-5, -3, -10, -1] -> -1
    dut.array_size.value = 4
    dut.array_data[0].value = 65531  # -5
    dut.array_data[1].value = 65533  # -3
    dut.array_data[2].value = 65526  # -10
    dut.array_data[3].value = 65535  # -1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(18):
        await RisingEdge(dut.clk)
    
    result = dut.max_result.value.integer
    if result > 32767:
        result = result - 65536
    if result != -1:
        raise TestFailure(f"Test 3 failed: expected -1, got {result}")
    print("Test 3 passed: all negatives -> -1")
    
    # Test case 4: single element [42] -> 42
    dut.array_size.value = 1
    dut.array_data[0].value = 42
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(18):
        await RisingEdge(dut.clk)
    
    if dut.max_result.value.integer != 42:
        raise TestFailure(f"Test 4 failed: expected 42, got {dut.max_result.value.integer}")
    print("Test 4 passed: single element -> 42")
    
    # Test case 5: max at beginning [123, 5, 3, 1] -> 123
    dut.array_size.value = 4
    dut.array_data[0].value = 123
    dut.array_data[1].value = 5
    dut.array_data[2].value = 3
    dut.array_data[3].value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(18):
        await RisingEdge(dut.clk)
    
    if dut.max_result.value.integer != 123:
        raise TestFailure(f"Test 5 failed: expected 123, got {dut.max_result.value.integer}")
    print("Test 5 passed: max at beginning -> 123")
    
    print("
All tests passed!")