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

def to_ascii_array(s):
    """Convert string to list of ASCII values, padded to 16 chars."""
    ascii_list = [ord(c) for c in s]
    while len(ascii_list) < 16:
        ascii_list.append(0)
    return ascii_list[:16]

def count_distinct_ref(s):
    """Reference implementation for verification."""
    seen = set()
    for char in s:
        if char.isalpha():
            seen.add(char.lower())
    return len(seen)

@cocotb.test(timeout_time=2, timeout_unit='ms')
async def test_count_distinct_characters(dut):
    """Test count_distinct_characters module with various test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(16):
        dut.char_array[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ('', 0),
        ('abcde', 5),
        ('abcdecadeCADE', 5),
        ('aaaaAAAAaaaa', 1),
        ('Jerry jERRY JeRRRY', 5),
        ('xyzXYZ', 3),
        ('Hello', 4),
        ('', 0),  # Empty string
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (test_str, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Testing string '{test_str}' (len={len(test_str)})")
        
        # Load inputs
        ascii_vals = to_ascii_array(test_str)
        dut.len.value = len(test_str)
        
        for j in range(16):
            dut.char_array[j].value = ascii_vals[j]
        
        # Wait for inputs to settle
        await Timer(20, units='ns')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 20
        done_found = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Done signal not asserted after {max_cycles} cycles")
        
        # Verify result is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has undefined value (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: For string '{test_str}', expected {expected}, got {result}")
        
        dut._log.info(f"Test {i+1}: PASSED (result={result})")
        passed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_edge_cases(dut):
    """Test edge cases: max length, all same, single char."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(16):
        dut.char_array[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: max length 16 with all distinct lowercase
    test_str = 'abcdefghijklmnop'
    dut._log.info(f"Edge case: max length 16 - '{test_str}'")
    
    ascii_vals = to_ascii_array(test_str)
    dut.len.value = 16
    for j in range(16):
        dut.char_array[j].value = ascii_vals[j]
    
    await Timer(20, units='ns')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for cycle in range(25):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Edge case: timeout")
    
    result = int(dut.result.value)
    expected = 16
    if result != expected:
        raise TestFailure(f"Edge case failed: expected {expected}, got {result}")
    
    dut._log.info(f"Edge case PASSED: result={result}")
    
    # Edge case: only uppercase
    await RisingEdge(dut.clk)
    test_str = 'ABCDEFG'
    dut._log.info(f"Edge case: uppercase only - '{test_str}'")
    
    ascii_vals = to_ascii_array(test_str)
    dut.len.value = 7
    for j in range(16):
        dut.char_array[j].value = ascii_vals[j]
    
    await Timer(20, units='ns')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for cycle in range(25):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    result = int(dut.result.value)
    expected = 7
    if result != expected:
        raise TestFailure(f"Uppercase edge case failed: expected {expected}, got {result}")
    
    dut._log.info(f"Uppercase edge case PASSED: result={result}")
    
    dut._log.info("\n=== All edge cases passed ===")
