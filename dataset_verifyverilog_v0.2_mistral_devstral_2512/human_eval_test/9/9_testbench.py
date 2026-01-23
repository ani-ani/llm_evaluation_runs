import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_rolling_max_basic(dut):
    """Test basic rolling_max functionality"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.input_array[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 2, 3, 4] -> [1, 2, 3, 4]
    dut.array_len.value = 4
    dut.input_array[0].value = 1
    dut.input_array[1].value = 2
    dut.input_array[2].value = 3
    dut.input_array[3].value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected: [1, 2, 3, 4]
    expected = [1, 2, 3, 4]
    
    for i, exp in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.valid.value != 1:
            raise TestFailure(f"Cycle {i+1}: valid should be 1")
        if dut.result.value != exp:
            raise TestFailure(f"Cycle {i+1}: expected {exp}, got {int(dut.result.value)}")
        if dut.index.value != i:
            raise TestFailure(f"Cycle {i+1}: expected index {i}, got {int(dut.index.value)}")
    
    # Should be done
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Should be done after processing")
    
    print("Test 1 passed: [1,2,3,4] -> [1,2,3,4]")

@cocotb.test()
async def test_rolling_max_decreasing(dut):
    """Test decreasing sequence [4,3,2,1] -> [4,4,4,4]"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.input_array[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [4, 3, 2, 1] -> [4, 4, 4, 4]
    dut.array_len.value = 4
    dut.input_array[0].value = 4
    dut.input_array[1].value = 3
    dut.input_array[2].value = 2
    dut.input_array[3].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [4, 4, 4, 4]
    
    for i, exp in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result.value != exp:
            raise TestFailure(f"Cycle {i+1}: expected {exp}, got {int(dut.result.value)}")
    
    print("Test 2 passed: [4,3,2,1] -> [4,4,4,4]")

@cocotb.test()
async def test_rolling_max_mixed(dut):
    """Test mixed sequence [3,2,3,100,3] -> [3,3,3,100,100]"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.input_array[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [3, 2, 3, 100, 3] -> [3, 3, 3, 100, 100]
    dut.array_len.value = 5
    dut.input_array[0].value = 3
    dut.input_array[1].value = 2
    dut.input_array[2].value = 3
    dut.input_array[3].value = 100
    dut.input_array[4].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [3, 3, 3, 100, 100]
    
    for i, exp in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result.value != exp:
            raise TestFailure(f"Cycle {i+1}: expected {exp}, got {int(dut.result.value)}")
    
    print("Test 3 passed: [3,2,3,100,3] -> [3,3,3,100,100]")

@cocotb.test()
async def test_rolling_max_empty(dut):
    """Test empty array"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.input_array[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: [] -> []
    dut.array_len.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Should immediately be done
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Empty array should immediately complete")
    
    print("Test 4 passed: empty array")

@cocotb.test()
async def test_rolling_max_single(dut):
    """Test single element [1] -> [1]"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.input_array[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.array_len.value = 1
    dut.input_array[0].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure(f"Expected 1, got {int(dut.result.value)}")
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Should be done after single element")
    
    print("Test 5 passed: [1] -> [1]")