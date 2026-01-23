import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=200, timeout_unit="ms")
async def test_count_nums(dut):
    """Test count_nums module with various cases."""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    # Format: (array_values, expected_count, description)
    test_cases = [
        ([], 0, "empty array"),
        ([-1, -2, 0], 0, "all non-positive sums"),
        ([1, 1, 2, -2, 3, 4, 5], 6, "mixed with one negative"),
        ([1, 6, 9, -6, 0, 1, 5], 5, "mixed with negative"),
        ([1, 100, 98, -7, 1, -1], 4, "larger numbers"),
        ([12, 23, 34, -45, -56, 0], 5, "two digit numbers"),
        ([0, 1], 1, "zero and one"),
        ([1], 1, "single positive"),
        ([-123], 1, "single negative with positive sum"),
        ([-10], 0, "negative with zero sum"),
        ([-100], 0, "negative with zero sum"),
        ([11, -22, 33], 2, "alternating signs"),
        ([5, -5, 5], 2, "zero sum middle"),
        ([-123, 123, 0, -1, 1, -100, 100, 5], 5, "full 8 elements"),
        ([1000, 2000, -3000], 2, "large magnitude"),
        ([-9999], 0, "large negative"),
    ]
    
    total_tests = 0
    passed_tests = 0
    
    for arr_values, expected, description in test_cases:
        total_tests += 1
        
        # Pad array to length 8 with zeros
        padded_arr = arr_values + [0] * (8 - len(arr_values))
        
        # Set inputs
        dut.len.value = len(arr_values)
        for i in range(8):
            dut.arr[i].value = from_signed(padded_arr[i], 16)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        MAX_CYCLES = 100
        done_found = False
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test '{description}': Timeout after {MAX_CYCLES} cycles")
        
        # Verify output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test '{description}': Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result == expected:
            dut._log.info(f"Test '{description}': PASSED (result={result})")
            passed_tests += 1
        else:
            raise TestFailure(f"Test '{description}': FAILED - Expected {expected}, got {result}")
    
    dut._log.info(f"\nTest Summary: {passed_tests}/{total_tests} tests passed")
    if passed_tests != total_tests:
        raise TestFailure(f"Not all tests passed: {passed_tests}/{total_tests}")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test specific edge cases for digit calculation."""
    
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: 0 (sum=0, should not count)
    dut.len.value = 1
    dut.arr[0].value = from_signed(0, 16)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    if int(dut.result.value) != 0:
        raise TestFailure(f"Edge case '0' failed: expected 0, got {int(dut.result.value)}")
    
    # Edge case: -1 (sum=-1, should not count)
    dut.len.value = 1
    dut.arr[0].value = from_signed(-1, 16)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    if int(dut.result.value) != 0:
        raise TestFailure(f"Edge case '-1' failed: expected 0, got {int(dut.result.value)}")
    
    # Edge case: 10 (sum=1+0=1, should count)
    dut.len.value = 1
    dut.arr[0].value = from_signed(10, 16)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    if int(dut.result.value) != 1:
        raise TestFailure(f"Edge case '10' failed: expected 1, got {int(dut.result.value)}")
    
    # Edge case: -10 (sum=-1+0=-1, should not count)
    dut.len.value = 1
    dut.arr[0].value = from_signed(-10, 16)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    if int(dut.result.value) != 0:
        raise TestFailure(f"Edge case '-10' failed: expected 0, got {int(dut.result.value)}")
    
    dut._log.info("Edge cases passed")
