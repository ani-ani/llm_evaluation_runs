import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

# Reference Python implementation
def sum_squares_reference(lst):
    """Reference implementation for testing."""
    result = 0
    for i, val in enumerate(lst):
        if i % 3 == 0:
            result += val * val
        elif i % 4 == 0:
            result += val * val * val
        else:
            result += val
    return result

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_sum_squares(dut):
    """Test sum_squares module with various test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr.value = 0
    for i in range(16):
        dut.arr[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ([1, 2, 3], 6),
        ([1, 4, 9], 14),
        ([], 0),  # Will be padded with zeros
        ([1, 1, 1, 1, 1, 1, 1, 1, 1], 9),
        ([-1, -1, -1, -1, -1, -1, -1, -1, -1], -3),
        ([0], 0),
        ([-1, -5, 2, -1, -5], -126),
        ([-56, -99, 1, 0, -2], 3030),
        ([-1, 0, 0, 0, 0, 0, 0, 0, -1], 0),
        ([-16, -9, -2, 36, 36, 26, -20, 25, -40, 20, -4, 12, -26, 35, 37], -14196),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_idx, (input_list, expected) in enumerate(test_cases):
        # Pad input to 16 elements with zeros
        padded_input = input_list + [0] * (16 - len(input_list))
        
        # Load array into DUT (use only first 16 elements if longer)
        for i in range(16):
            val = padded_input[i]
            dut.arr[i].value = from_signed(val, 8)
        
        # Wait one cycle for inputs to stabilize
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 25
        done_seen = False
        
        for cycle in range(max_cycles):
            if not is_value_defined(dut.done.value):
                await RisingEdge(dut.clk)
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
            
            await RisingEdge(dut.clk)
        
        if not done_seen:
            raise TestFailure(f"Test {test_idx}: Done signal not asserted after {max_cycles} cycles")
        
        # Verify output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx}: Result is undefined (X/Z)")
        
        # Read result
        result = to_signed(int(dut.result.value), 32)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {test_idx}: Input={input_list}, Expected={expected}, Got={result}")
        
        dut._log.info(f"Test {test_idx} passed: {input_list[:5]}... => {result}")
        passed += 1
        
        # Wait for next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases including zero, negative, and max values."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        dut.arr[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: all zeros
    for i in range(16):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    assert result == 0, f"All zeros test failed: got {result}"
    dut._log.info("Edge case: all zeros passed")
    
    # Test case: maximum positive values
    for i in range(16):
        dut.arr[i].value = 127  # Max positive for 8-bit signed
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    expected = sum_squares_reference([127] * 16)
    assert result == expected, f"Max values test failed: expected {expected}, got {result}"
    dut._log.info(f"Edge case: all max values passed (result={result})")
    
    # Test case: alternating pattern
    test_vals = [10 if i % 2 == 0 else -10 for i in range(16)]
    for i in range(16):
        dut.arr[i].value = from_signed(test_vals[i], 8)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    expected = sum_squares_reference(test_vals)
    assert result == expected, f"Alternating test failed: expected {expected}, got {result}"
    dut._log.info(f"Edge case: alternating pattern passed")
    
    dut._log.info("All edge cases passed!")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_specific_index_transformations(dut):
    """Verify specific index-based transformations."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        dut.arr[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: single element at index 0 (multiple of 3 and 4, should square)
    # Input: [5] -> index 0 -> square -> 25
    for i in range(16):
        dut.arr[i].value = 0
    dut.arr[0].value = from_signed(5, 8)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    assert result == 25, f"Index 0 (multiple of 3) test failed: got {result}"
    dut._log.info("Specific index test: index 0 (square) passed")
    
    # Test: index 3 (multiple of 3, should square)
    # Input: [0,0,0,2] -> index 3 -> square -> 4
    for i in range(16):
        dut.arr[i].value = 0
    dut.arr[3].value = from_signed(2, 8)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    assert result == 4, f"Index 3 (multiple of 3) test failed: got {result}"
    dut._log.info("Specific index test: index 3 (square) passed")
    
    # Test: index 4 (multiple of 4 but not 3, should cube)
    # Input: [0,0,0,0,2] -> index 4 -> cube -> 8
    for i in range(16):
        dut.arr[i].value = 0
    dut.arr[4].value = from_signed(2, 8)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    assert result == 8, f"Index 4 (multiple of 4) test failed: got {result}"
    dut._log.info("Specific index test: index 4 (cube) passed")
    
    # Test: index 8 (multiple of 4 but not 3, should cube)
    # Input: [0,0,0,0,0,0,0,0,3] -> index 8 -> cube -> 27
    for i in range(16):
        dut.arr[i].value = 0
    dut.arr[8].value = from_signed(3, 8)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    assert result == 27, f"Index 8 (multiple of 4) test failed: got {result}"
    dut._log.info("Specific index test: index 8 (cube) passed")
    
    # Test: index 5 (not multiple of 3 or 4, should be unchanged)
    # Input: [0,0,0,0,0,7] -> index 5 -> unchanged -> 7
    for i in range(16):
        dut.arr[i].value = 0
    dut.arr[5].value = from_signed(7, 8)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = to_signed(int(dut.result.value), 32)
    assert result == 7, f"Index 5 (no transform) test failed: got {result}"
    dut._log.info("Specific index test: index 5 (unchanged) passed")
    
    dut._log.info("All specific index transformation tests passed!")
