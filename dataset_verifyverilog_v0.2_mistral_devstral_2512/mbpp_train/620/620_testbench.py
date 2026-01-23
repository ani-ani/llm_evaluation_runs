import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

async def load_data(dut, data_list):
    """Helper to load data into the module"""
    for i, val in enumerate(data_list):
        dut.addr.value = i
        dut.data_in.value = val
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    dut.write_en.value = 0

async def wait_for_done(dut, timeout_cycles=1000):
    """Wait for done signal with timeout"""
    cycles = 0
    while cycles < timeout_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.done.value == 1:
            return True
    return False

@cocotb.test()
async def test_largest_subset_basic(dut):
    """Test 1: [1, 3, 6, 13, 17, 18] -> expected 4"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load data
    data = [1, 3, 6, 13, 17, 18]
    await load_data(dut, data)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    done = await wait_for_done(dut)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    # Check result
    result = int(dut.result.value)
    expected = 4
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 1 Passed: Input {data}, Result {result}, Expected {expected}")

@cocotb.test()
async def test_largest_subset_numbers_2(dut):
    """Test 2: [10, 5, 3, 15, 20] -> expected 3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    data = [10, 5, 3, 15, 20]
    await load_data(dut, data)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = await wait_for_done(dut)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 3
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 2 Passed: Input {data}, Result {result}, Expected {expected}")

@cocotb.test()
async def test_largest_subset_numbers_3(dut):
    """Test 3: [18, 1, 3, 6, 13, 17] -> expected 4"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    data = [18, 1, 3, 6, 13, 17]
    await load_data(dut, data)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = await wait_for_done(dut)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 4
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 3 Passed: Input {data}, Result {result}, Expected {expected}")

@cocotb.test()
async def test_largest_subset_single_element(dut):
    """Test 4: Single element list"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    data = [7]
    await load_data(dut, data)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = await wait_for_done(dut)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 1
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 4 Passed: Input {data}, Result {result}, Expected {expected}")

@cocotb.test()
async def test_largest_subset_all_divisible(dut):
    """Test 5: All divisible (powers of 2)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    data = [2, 4, 8, 16]
    await load_data(dut, data)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = await wait_for_done(dut)
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 4
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test 5 Passed: Input {data}, Result {result}, Expected {expected}")
