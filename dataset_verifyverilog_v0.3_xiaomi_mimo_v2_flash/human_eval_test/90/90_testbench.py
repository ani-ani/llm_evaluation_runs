import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert negative values for 32-bit unsigned representation
def to_32bit_signed(val):
    """Convert Python int to 32-bit signed representation (unsigned for Verilog)."""
    if val < 0:
        return val + (1 << 32)
    return val & 0xFFFFFFFF

# Helper to convert from 32-bit unsigned to signed Python int
def from_32bit_signed(val):
    """Convert 32-bit unsigned Verilog value to signed Python int."""
    if val >= (1 << 31):
        return val - (1 << 32)
    return val

# Sentinel value for None
NONE_SENTINEL = 0x80000000

async def wait_for_done(dut, max_cycles=20):
    """Wait for done signal with cycle-based timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut):
    """Reset the DUT properly."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    # Initialize all array elements to 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def compute_next_smallest(dut, arr_values, arr_len):
    """Run the next_smallest computation and return result."""
    # Set up inputs
    for i in range(8):
        if i < arr_len:
            dut.arr[i].value = to_32bit_signed(arr_values[i])
        else:
            dut.arr[i].value = 0  # Don't care
    
    dut.len.value = arr_len
    
    # Pulse start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result has X/Z values")
    
    result = int(dut.result.value)
    return from_32bit_signed(result)

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_basic(dut):
    """Test basic functionality with sorted array."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: [1, 2, 3, 4, 5] -> 2
    result = await compute_next_smallest(dut, [1, 2, 3, 4, 5], 5)
    if result != 2:
        raise TestFailure(f"Test 1 failed: expected 2, got {result}")
    dut._log.info("Test 1 passed: [1,2,3,4,5] -> 2")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_unsorted(dut):
    """Test with unsorted array."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 2: [5, 1, 4, 3, 2] -> 2
    result = await compute_next_smallest(dut, [5, 1, 4, 3, 2], 5)
    if result != 2:
        raise TestFailure(f"Test 2 failed: expected 2, got {result}")
    dut._log.info("Test 2 passed: [5,1,4,3,2] -> 2")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_empty(dut):
    """Test empty list - should return None sentinel."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 3: [] -> 0x80000000 (None)
    result = await compute_next_smallest(dut, [0, 0, 0, 0, 0, 0, 0, 0], 0)
    expected = from_32bit_signed(NONE_SENTINEL)
    if result != expected:
        raise TestFailure(f"Test 3 failed: expected {expected} (None), got {result}")
    dut._log.info("Test 3 passed: [] -> None")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_duplicates(dut):
    """Test list with only duplicates."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 4: [1, 1] -> 0x80000000 (None)
    result = await compute_next_smallest(dut, [1, 1], 2)
    expected = from_32bit_signed(NONE_SENTINEL)
    if result != expected:
        raise TestFailure(f"Test 4 failed: expected {expected} (None), got {result}")
    dut._log.info("Test 4 passed: [1,1] -> None")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_with_zeros(dut):
    """Test with mixed values including zero."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 5: [1, 1, 1, 1, 0] -> 1
    result = await compute_next_smallest(dut, [1, 1, 1, 1, 0], 5)
    if result != 1:
        raise TestFailure(f"Test 5 failed: expected 1, got {result}")
    dut._log.info("Test 5 passed: [1,1,1,1,0] -> 1")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_power_zero(dut):
    """Test with 0**0 edge case (value 1)."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 6: [1, 0**0] = [1, 1] -> None
    result = await compute_next_smallest(dut, [1, 1], 2)
    expected = from_32bit_signed(NONE_SENTINEL)
    if result != expected:
        raise TestFailure(f"Test 6 failed: expected {expected} (None), got {result}")
    dut._log.info("Test 6 passed: [1,0**0] -> None")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_negative(dut):
    """Test with negative numbers."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 7: [-35, 34, 12, -45] -> -35
    result = await compute_next_smallest(dut, [-35, 34, 12, -45], 4)
    if result != -35:
        raise TestFailure(f"Test 7 failed: expected -35, got {result}")
    dut._log.info("Test 7 passed: [-35,34,12,-45] -> -35")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_single_element(dut):
    """Test with single element."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 8: [42] -> None
    result = await compute_next_smallest(dut, [42], 1)
    expected = from_32bit_signed(NONE_SENTINEL)
    if result != expected:
        raise TestFailure(f"Test 8 failed: expected {expected} (None), got {result}")
    dut._log.info("Test 8 passed: [42] -> None")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_large_array(dut):
    """Test with full 8-element array."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 9: [10, 9, 8, 7, 6, 5, 4, 3] -> 4
    result = await compute_next_smallest(dut, [10, 9, 8, 7, 6, 5, 4, 3], 8)
    if result != 4:
        raise TestFailure(f"Test 9 failed: expected 4, got {result}")
    dut._log.info("Test 9 passed: [10,9,8,7,6,5,4,3] -> 4")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_all_same(dut):
    """Test with all elements identical."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 10: [7, 7, 7, 7, 7, 7, 7, 7] -> None
    result = await compute_next_smallest(dut, [7, 7, 7, 7, 7, 7, 7, 7], 8)
    expected = from_32bit_signed(NONE_SENTINEL)
    if result != expected:
        raise TestFailure(f"Test 10 failed: expected {expected} (None), got {result}")
    dut._log.info("Test 10 passed: [7,7,7,7,7,7,7,7] -> None")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_min_int(dut):
    """Test boundary values."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 11: [-2147483648, 0, 2147483647] -> 0
    min_int = -2147483648
    max_int = 2147483647
    result = await compute_next_smallest(dut, [min_int, 0, max_int], 3)
    if result != 0:
        raise TestFailure(f"Test 11 failed: expected 0, got {result}")
    dut._log.info("Test 11 passed: min_int, 0, max_int -> 0")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_next_smallest_two_uniques(dut):
    """Test with exactly two unique values."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    await reset_dut(dut)
    
    # Test case 12: [5, 5, 2, 2, 5, 2] -> 5
    result = await compute_next_smallest(dut, [5, 5, 2, 2, 5, 2], 6)
    if result != 5:
        raise TestFailure(f"Test 12 failed: expected 5, got {result}")
    dut._log.info("Test 12 passed: [5,5,2,2,5,2] -> 5")

# Final summary
@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_summary(dut):
    """Print summary of all tests."""
    dut._log.info("="*60)
    dut._log.info("NEXT_SMALLEST TEST SUITE COMPLETE")
    dut._log.info("All 12 tests should pass with correct implementation")
    dut._log.info("Format: Test Name -> Expected Result")
    dut._log.info("="*60)
