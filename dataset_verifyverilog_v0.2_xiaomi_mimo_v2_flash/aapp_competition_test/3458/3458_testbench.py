import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_xor_subset(dut):
    """Test maximum XOR subset calculation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    dut.num_count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 3, 5] -> expected 7
    dut._log.info("Test 1: [1, 3, 5] -> 7")
    dut.num_count.value = 3
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for COLLECT state
    await RisingEdge(dut.clk)
    
    # Provide numbers
    numbers = [1, 3, 5]
    for num in numbers:
        dut.data_in.value = num
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    # Wait for completion
    timeout = 500
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    result = int(dut.result.value)
    expected = 7
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 1 failed: got {result}, expected {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 2: [2, 6, 4, 8] -> expected 14
    dut._log.info("Test 2: [2, 6, 4, 8] -> 14")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_count.value = 4
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    
    numbers = [2, 6, 4, 8]
    for num in numbers:
        dut.data_in.value = num
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    timeout = 500
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    result = int(dut.result.value)
    expected = 14
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 2 failed: got {result}, expected {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 3: Single number [42] -> expected 42
    dut._log.info("Test 3: [42] -> 42")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_count.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    
    dut.data_in.value = 42
    dut.data_valid.value = 1
    await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    timeout = 500
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    result = int(dut.result.value)
    expected = 42
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 3 failed: got {result}, expected {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 4: All same numbers [5, 5, 5] -> expected 5
    dut._log.info("Test 4: [5, 5, 5] -> 5")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_count.value = 3
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    
    numbers = [5, 5, 5]
    for num in numbers:
        dut.data_in.value = num
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    timeout = 500
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    result = int(dut.result.value)
    expected = 5
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 4 failed: got {result}, expected {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 5: [15, 7, 3] -> expected 15 (0xF=15, 0x7=7, 0x3=3, 15 xor anything < 15)
    dut._log.info("Test 5: [15, 7, 3] -> 15")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_count.value = 3
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    
    numbers = [15, 7, 3]
    for num in numbers:
        dut.data_in.value = num
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    timeout = 500
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    result = int(dut.result.value)
    expected = 15
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert result == expected, f"Test 5 failed: got {result}, expected {expected}"
    
    print(f"
=== Test Summary ===")
    print(f"All 5 tests passed!")
