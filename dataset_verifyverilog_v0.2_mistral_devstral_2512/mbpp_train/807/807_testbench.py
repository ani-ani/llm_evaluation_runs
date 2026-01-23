import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_first_odd_finder(dut):
    """Test the first_odd_finder module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.data_in.value = 0
    dut.list_size.value = 0
    dut.valid_in.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def search_list(numbers):
        """Helper to test searching a list of numbers"""
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        list_len = len(numbers)
        dut.list_size.value = list_len
        
        # Feed numbers one by one
        for i, num in enumerate(numbers):
            dut.valid_in.value = 1
            dut.data_in.value = num
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            # Wait a cycle for processing
            await RisingEdge(dut.clk)
        
        # Wait for completion
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        return int(dut.first_odd.value), int(dut.found.value)
    
    # Test 1: [1, 3, 5] -> first odd is 1
    print("Test 1: [1, 3, 5]")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    result, found = await search_list([1, 3, 5])
    print(f"  Result: {result}, Found: {found}")
    assert result == 1, f"Expected 1, got {result}"
    assert found == 1, f"Expected found=1, got {found}"
    print("  PASSED")
    
    # Test 2: [2, 4, 1, 3] -> first odd is 1
    print("Test 2: [2, 4, 1, 3]")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    result, found = await search_list([2, 4, 1, 3])
    print(f"  Result: {result}, Found: {found}")
    assert result == 1, f"Expected 1, got {result}"
    assert found == 1, f"Expected found=1, got {found}"
    print("  PASSED")
    
    # Test 3: [8, 9, 1] -> first odd is 9
    print("Test 3: [8, 9, 1]")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    result, found = await search_list([8, 9, 1])
    print(f"  Result: {result}, Found: {found}")
    assert result == 9, f"Expected 9, got {result}"
    assert found == 1, f"Expected found=1, got {found}"
    print("  PASSED")
    
    # Test 4: [2, 4, 6, 8] -> no odd numbers
    print("Test 4: [2, 4, 6, 8] (all even)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    result, found = await search_list([2, 4, 6, 8])
    print(f"  Result: {result}, Found: {found}")
    assert found == 0, f"Expected found=0, got {found}"
    assert result == 255, f"Expected 255 (error value), got {result}"
    print("  PASSED")
    
    # Test 5: [1] -> single element odd
    print("Test 5: [1] (single odd)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    result, found = await search_list([1])
    print(f"  Result: {result}, Found: {found}")
    assert result == 1, f"Expected 1, got {result}"
    assert found == 1, f"Expected found=1, got {found}"
    print("  PASSED")
    
    print("
Summary: All 5 tests passed!")
