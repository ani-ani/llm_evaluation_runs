import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_pancake_sort_basic(dut):
    """Test basic pancake sort functionality"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.idx.value = 0
    dut.data_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Load test array: [15, 79, 25, 38, 69] -> [15, 25, 38, 69, 79]
    # For 8-element array, remaining positions are zero
    test_values = [15, 79, 25, 38, 69, 0, 0, 0]
    for i, val in enumerate(test_values):
        dut.idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Start sorting
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max ~120 cycles)
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    # Check result
    assert dut.done.value == 1, "Sort did not complete"
    expected = [15, 25, 38, 69, 79, 0, 0, 0]
    for i in range(8):
        actual = int(dut.sorted_out[i].value)
        assert actual == expected[i], f"Index {i}: expected {expected[i]}, got {actual}"
    print(f"Test 1 passed: {test_values[:5]} -> {expected[:5]}")

@cocotb.test()
async def test_pancake_sort_test2(dut):
    """Test with different values: [98, 12, 54, 36, 85]"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Load array [98, 12, 54, 36, 85]
    test_values = [98, 12, 54, 36, 85, 0, 0, 0]
    for i, val in enumerate(test_values):
        dut.idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    expected = [12, 36, 54, 85, 98, 0, 0, 0]
    for i in range(8):
        actual = int(dut.sorted_out[i].value)
        assert actual == expected[i], f"Index {i}: expected {expected[i]}, got {actual}"
    print(f"Test 2 passed: {test_values[:5]} -> {expected[:5]}")

@cocotb.test()
async def test_pancake_sort_test3(dut):
    """Test with values: [41, 42, 32, 12, 23]"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Load array [41, 42, 32, 12, 23]
    test_values = [41, 42, 32, 12, 23, 0, 0, 0]
    for i, val in enumerate(test_values):
        dut.idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    expected = [12, 23, 32, 41, 42, 0, 0, 0]
    for i in range(8):
        actual = int(dut.sorted_out[i].value)
        assert actual == expected[i], f"Index {i}: expected {expected[i]}, got {actual}"
    print(f"Test 3 passed: {test_values[:5]} -> {expected[:5]}")

@cocotb.test()
async def test_pancake_sort_already_sorted(dut):
    """Test with already sorted array"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Load sorted array [10, 20, 30, 0, 0, 0, 0, 0]
    test_values = [10, 20, 30, 0, 0, 0, 0, 0]
    for i, val in enumerate(test_values):
        dut.idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    for i in range(8):
        actual = int(dut.sorted_out[i].value)
        assert actual == test_values[i], f"Index {i}: expected {test_values[i]}, got {actual}"
    print(f"Already sorted test passed")

@cocotb.test()
async def test_pancake_sort_reverse(dut):
    """Test with reverse sorted array"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Load reverse sorted [50, 40, 30, 20, 10, 0, 0, 0]
    test_values = [50, 40, 30, 20, 10, 0, 0, 0]
    for i, val in enumerate(test_values):
        dut.idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    expected = [10, 20, 30, 40, 50, 0, 0, 0]
    for i in range(8):
        actual = int(dut.sorted_out[i].value)
        assert actual == expected[i], f"Index {i}: expected {expected[i]}, got {actual}"
    print(f"Reverse sorted test passed")

@cocotb.test()
async def test_pancake_sort_max_elements(dut):
    """Test with all 8 elements filled"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Load 8 elements: [64, 128, 32, 255, 16, 96, 48, 80]
    test_values = [64, 128, 32, 255, 16, 96, 48, 80]
    for i, val in enumerate(test_values):
        dut.idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 250
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    expected = [16, 32, 48, 64, 80, 96, 128, 255]
    for i in range(8):
        actual = int(dut.sorted_out[i].value)
        assert actual == expected[i], f"Index {i}: expected {expected[i]}, got {actual}"
    print(f"All 8 elements test passed: {test_values} -> {expected}")