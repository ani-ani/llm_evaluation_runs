import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
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

def string_to_array(s, max_len=16):
    """Convert Python string to 16-element byte array."""
    arr = [32] * max_len  # Fill with spaces
    for i, c in enumerate(s[:max_len]):
        arr[i] = ord(c)
    return arr

def check_expected(txt):
    """Original Python function logic."""
    if not txt:
        return False
    
    # Find last non-space character
    last_char_idx = -1
    for i in range(len(txt) - 1, -1, -1):
        if txt[i] != ' ':
            last_char_idx = i
            break
    
    if last_char_idx == -1:
        return False  # All spaces
    
    last_char = txt[last_char_idx]
    
    # Check if it's a letter
    if not (last_char.isalpha()):
        return False
    
    # Check if it's a standalone word (preceded by space or at start)
    if last_char_idx == 0:
        return True
    
    if txt[last_char_idx - 1] == ' ':
        return True
    
    return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_check_last_char_letter(dut):
    """Test the check_last_char_letter module."""
    
    # Helper function to wait for done with timeout
    async def wait_for_done(max_cycles=50):
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                return True
        return False
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    await clock.start()
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_array.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("apple", False),
        ("apple pi e", True),
        ("eeeee", False),
        ("A", True),
        ("Pumpkin pie ", False),
        ("Pumpkin pie 1", False),
        ("", False),
        ("eeeee e ", False),
        ("apple pie", False),
        ("apple pi e ", False),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (test_str, expected) in enumerate(test_cases):
        # Prepare input array
        arr = string_to_array(test_str)
        
        # Assign to DUT
        for j in range(16):
            dut.char_array[j].value = arr[j]
        
        # Wait for clock edge and start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(30)
        
        if not done_ok:
            raise TestFailure(f"Test {i}: Timeout waiting for done signal")
        
        # Check output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        expected_val = 1 if expected else 0
        
        if result != expected_val:
            dut._log.error(f"Test {i} FAILED: Input='{test_str}' Expected={expected_val}, Got={result}")
        else:
            dut._log.info(f"Test {i} PASSED: Input='{test_str}' Result={result}")
            passed += 1
        
        # Small delay between tests
        await Timer(50, units="ns")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases for robustness."""
    
    async def wait_for_done(max_cycles=30):
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                return True
        return False
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case 1: All spaces
    arr = [32] * 16
    for j in range(16):
        dut.char_array[j].value = arr[j]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    if not await wait_for_done():
        raise TestFailure("Edge case 1: Timeout")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Edge case 1: Result undefined")
    
    if int(dut.result.value) != 0:
        raise TestFailure(f"Edge case 1: All spaces should return 0, got {int(dut.result.value)}")
    
    dut._log.info("Edge case 1 (all spaces): PASSED")
    
    # Edge case 2: Single letter at position 0
    arr = [65] + [32] * 15  # 'A' followed by spaces
    for j in range(16):
        dut.char_array[j].value = arr[j]
    
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    if not await wait_for_done():
        raise TestFailure("Edge case 2: Timeout")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Edge case 2: Result undefined")
    
    if int(dut.result.value) != 1:
        raise TestFailure(f"Edge case 2: Single 'A' should return 1, got {int(dut.result.value)}")
    
    dut._log.info("Edge case 2 (single 'A'): PASSED")
    
    # Edge case 3: Letter-space-letter pattern
    arr = [65, 32, 66] + [32] * 13  # "A B"
    for j in range(16):
        dut.char_array[j].value = arr[j]
    
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    if not await wait_for_done():
        raise TestFailure("Edge case 3: Timeout")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Edge case 3: Result undefined")
    
    if int(dut.result.value) != 1:
        raise TestFailure(f"Edge case 3: 'A B' should return 1, got {int(dut.result.value)}")
    
    dut._log.info("Edge case 3 ('A B'): PASSED")
    
    dut._log.info("All edge cases passed!")
