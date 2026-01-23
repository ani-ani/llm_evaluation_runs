import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_prime_digit_sum(dut):
    """Test the prime digit sum module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.list_size.value = 0
    for i in range(8):
        dut.list_data[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [0,3,2,1,3,5,7,4] -> max prime 7 -> sum 7
    dut.list_size.value = 8
    dut.list_data[0].value = 0
    dut.list_data[1].value = 3
    dut.list_data[2].value = 2
    dut.list_data[3].value = 1
    dut.list_data[4].value = 3
    dut.list_data[5].value = 5
    dut.list_data[6].value = 7
    dut.list_data[7].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (up to 100 cycles)
    for _ in range(150):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Test 1: Done signal not raised"
    assert dut.result.value == 7, f"Test 1: Expected 7, got {dut.result.value}"
    print("Test 1 passed: [0,3,2,1,3,5,7,4] -> 7")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [1,0,1,8,2,4,5,9] -> max prime 5 -> sum 5
    dut.list_size.value = 8
    dut.list_data[0].value = 1
    dut.list_data[1].value = 0
    dut.list_data[2].value = 1
    dut.list_data[3].value = 8
    dut.list_data[4].value = 2
    dut.list_data[5].value = 4
    dut.list_data[6].value = 5
    dut.list_data[7].value = 9
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Test 2: Done signal not raised"
    assert dut.result.value == 5, f"Test 2: Expected 5, got {dut.result.value}"
    print("Test 2 passed: [1,0,1,8,2,4,5,9] -> 5")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [1,3,1,32,5,34,7,8] -> max prime 7 -> sum 7
    dut.list_size.value = 8
    dut.list_data[0].value = 1
    dut.list_data[1].value = 3
    dut.list_data[2].value = 1
    dut.list_data[3].value = 32
    dut.list_data[4].value = 5
    dut.list_data[5].value = 34
    dut.list_data[6].value = 7
    dut.list_data[7].value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Test 3: Done signal not raised"
    assert dut.result.value == 7, f"Test 3: Expected 7, got {dut.result.value}"
    print("Test 3 passed: [1,3,1,32,5,34,7,8] -> 7")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: [8191] -> max prime 8191 -> sum 8+1+9+1 = 19
    dut.list_size.value = 1
    dut.list_data[0].value = 8191
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Test 4: Done signal not raised"
    assert dut.result.value == 19, f"Test 4: Expected 19, got {dut.result.value}"
    print("Test 4 passed: [8191] -> 19")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 5: [8191, 7] -> max prime 8191 -> sum 19
    dut.list_size.value = 2
    dut.list_data[0].value = 8191
    dut.list_data[1].value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Test 5: Done signal not raised"
    assert dut.result.value == 19, f"Test 5: Expected 19, got {dut.result.value}"
    print("Test 5 passed: [8191, 7] -> 19")
    
    # Summary
    print("
All tests passed!")