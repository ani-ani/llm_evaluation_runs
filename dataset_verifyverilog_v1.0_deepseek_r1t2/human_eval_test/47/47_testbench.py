import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert float to Q16.16 format
def to_q16_16(value):
    return int(value * 65536)

# Helper to convert Q16.16 to float
def from_q16_16(value):
    return value / 65536.0

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_median_basic(dut):
    """Test basic median functionality with small arrays"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    dut.count.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [3, 1, 2, 4, 5] -> median 3
    dut._log.info("Test 1: [3, 1, 2, 4, 5] -> 3")
    test_array = [3, 1, 2, 4, 5]
    expected = to_q16_16(3)
    
    # Start pulse
    dut.start.value = 1
    dut.count.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load array elements
    for i, val in enumerate(test_array):
        dut.valid_in.value = 1
        dut.index.value = i
        dut.data_in.value = to_q16_16(val)
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Wait for computation with timeout
    timeout_cycles = 100
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 1: Timeout after {timeout_cycles} cycles")
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Test 1: Result has X/Z values")
    
    result = int(dut.result.value)
    result_float = from_q16_16(result)
    expected_float = from_q16_16(expected)
    
    dut._log.info(f"Expected: {expected_float}, Got: {result_float}")
    if result != expected:
        raise TestFailure(f"Test 1: expected {expected} ({expected_float}), got {result} ({result_float})")
    
    await RisingEdge(dut.clk)
    
    # Test case 2: [-10, 4, 6, 1000, 10, 20] -> 8.0
    dut._log.info("Test 2: [-10, 4, 6, 1000, 10, 20] -> 8.0")
    test_array = [-10, 4, 6, 1000, 10, 20]
    expected = to_q16_16(8.0)
    
    dut.start.value = 1
    dut.count.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, val in enumerate(test_array):
        dut.valid_in.value = 1
        dut.index.value = i
        # Convert negative to 2's complement for 16-bit
        if val < 0:
            dut.data_in.value = (1 << 16) + val
        else:
            dut.data_in.value = to_q16_16(val)
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 2: Timeout after {timeout_cycles} cycles")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Test 2: Result has X/Z values")
    
    result = int(dut.result.value)
    result_float = from_q16_16(result)
    expected_float = from_q16_16(expected)
    
    dut._log.info(f"Expected: {expected_float}, Got: {result_float}")
    if abs(result_float - expected_float) > 0.01:
        raise TestFailure(f"Test 2: expected {expected_float}, got {result_float}")
    
    await RisingEdge(dut.clk)
    
    # Test case 3: [5] -> 5
    dut._log.info("Test 3: [5] -> 5")
    test_array = [5]
    expected = to_q16_16(5)
    
    dut.start.value = 1
    dut.count.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.valid_in.value = 1
    dut.index.value = 0
    dut.data_in.value = to_q16_16(5)
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 3: Timeout after {timeout_cycles} cycles")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Test 3: Result has X/Z values")
    
    result = int(dut.result.value)
    result_float = from_q16_16(result)
    expected_float = from_q16_16(expected)
    
    dut._log.info(f"Expected: {expected_float}, Got: {result_float}")
    if result != expected:
        raise TestFailure(f"Test 3: expected {expected}, got {result}")
    
    await RisingEdge(dut.clk)
    
    # Test case 4: [6, 5] -> 5.5
    dut._log.info("Test 4: [6, 5] -> 5.5")
    test_array = [6, 5]
    expected = to_q16_16(5.5)
    
    dut.start.value = 1
    dut.count.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, val in enumerate(test_array):
        dut.valid_in.value = 1
        dut.index.value = i
        dut.data_in.value = to_q16_16(val)
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 4: Timeout after {timeout_cycles} cycles")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Test 4: Result has X/Z values")
    
    result = int(dut.result.value)
    result_float = from_q16_16(result)
    expected_float = from_q16_16(expected)
    
    dut._log.info(f"Expected: {expected_float}, Got: {result_float}")
    if abs(result_float - expected_float) > 0.01:
        raise TestFailure(f"Test 4: expected {expected_float}, got {result_float}")
    
    await RisingEdge(dut.clk)
    
    # Test case 5: [8, 1, 3, 9, 9, 2, 7] -> 7
    dut._log.info("Test 5: [8, 1, 3, 9, 9, 2, 7] -> 7")
    test_array = [8, 1, 3, 9, 9, 2, 7]
    expected = to_q16_16(7)
    
    dut.start.value = 1
    dut.count.value = 7
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, val in enumerate(test_array):
        dut.valid_in.value = 1
        dut.index.value = i
        dut.data_in.value = to_q16_16(val)
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Test 5: Timeout after {timeout_cycles} cycles")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Test 5: Result has X/Z values")
    
    result = int(dut.result.value)
    result_float = from_q16_16(result)
    expected_float = from_q16_16(expected)
    
    dut._log.info(f"Expected: {expected_float}, Got: {result_float}")
    if result != expected:
        raise TestFailure(f"Test 5: expected {expected}, got {result}")
    
    dut._log.info("All tests passed [OK]")
