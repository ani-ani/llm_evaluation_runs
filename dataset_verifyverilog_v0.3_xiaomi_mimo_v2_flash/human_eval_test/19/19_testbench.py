import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Mapping from number words to values
word_to_value = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9
}

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal to be high, with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def parse_input(input_str):
    """Parse space-delimited string to list of integer values."""
    if input_str == '':
        return []
    words = input_str.split()
    return [word_to_value[word] for word in words]

def format_output(values):
    """Convert list of values back to space-delimited string."""
    if not values:
        return ''
    # Map values back to words
    value_to_word = {v: k for k, v in word_to_value.items()}
    words = [value_to_word[v] for v in values]
    return ' '.join(words)

async def reset_and_start(dut, numbers_list, valid_count):
    """Reset and start the sorting module."""
    # Apply reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_count.value = 0
    
    # Initialize all array elements
    for i in range(8):
        dut.numbers[i].value = 0
        dut.result[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    
    # Set input values
    dut.valid_count.value = valid_count
    for i in range(8):
        if i < len(numbers_list):
            dut.numbers[i].value = numbers_list[i]
        else:
            dut.numbers[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    return dut

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_sort_numbers(dut):
    """Test sort_numbers module with various inputs."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset dut
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.valid_count.value = 0
    for i in range(8):
        dut.numbers[i].value = 0
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ('', ''),
        ('three', 'three'),
        ('three five nine', 'three five nine'),
        ('five zero four seven nine eight', 'zero four five seven eight nine'),
        ('six five four three two one zero', 'zero one two three four five six')
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}/{total}: Input='{input_str}'")
        
        # Parse and setup
        numbers_list = parse_input(input_str)
        valid_count = len(numbers_list)
        expected_list = parse_input(expected_str)
        
        # Reset and start
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.valid_count.value = valid_count
        for j in range(8):
            if j < len(numbers_list):
                dut.numbers[j].value = numbers_list[j]
            else:
                dut.numbers[j].value = 0
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=100)
        
        # Read results
        result_values = []
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: Result[{j}] is undefined (X/Z)")
            val = int(dut.result[j].value)
            if j < valid_count:
                result_values.append(val)
        
        # Verify
        if valid_count == 0:
            dut._log.info(f"  Expected: empty, Got: {result_values}")
            passed += 1
            continue
            
        result_str = format_output(result_values)
        
        if result_values == expected_list:
            dut._log.info(f"  Result: {result_str} [PASS]")
            passed += 1
        else:
            expected_str_out = format_output(expected_list)
            dut._log.info(f"  Expected: {expected_str_out}")
            dut._log.info(f"  Got:      {result_str}")
            raise TestFailure(f"Test {i+1} failed")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed == total:
        dut._log.info("All tests passed!")
    else:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_sort_numbers_edge_cases(dut):
    """Test edge cases: single element, already sorted, reverse sorted."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Edge case tests
    edge_cases = [
        (['one'], ['one'], "Single element"),
        (['one', 'two', 'three'], ['one', 'two', 'three'], "Already sorted"),
        (['nine', 'eight', 'seven', 'six'], ['six', 'seven', 'eight', 'nine'], "Reverse sorted"),
        (['zero', 'zero', 'five'], ['zero', 'zero', 'five'], "Duplicates"),
        (['one', 'nine', 'two', 'eight', 'three', 'seven'], ['one', 'two', 'three', 'seven', 'eight', 'nine'], "Alternating")
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for i, (input_words, expected_words, desc) in enumerate(edge_cases):
        dut._log.info(f"Edge Test {i+1}/{total}: {desc}")
        
        # Convert to values
        numbers_list = [word_to_value[w] for w in input_words]
        expected_list = [word_to_value[w] for w in expected_words]
        valid_count = len(numbers_list)
        
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.valid_count.value = valid_count
        for j in range(8):
            if j < len(numbers_list):
                dut.numbers[j].value = numbers_list[j]
            else:
                dut.numbers[j].value = 0
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=100)
        
        # Read results
        result_values = []
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Edge Test {i+1}: Result[{j}] is undefined")
            if j < valid_count:
                result_values.append(int(dut.result[j].value))
        
        # Verify
        if result_values == expected_list:
            dut._log.info(f"  Passed: {input_words} -> {result_values}")
            passed += 1
        else:
            raise TestFailure(f"Edge Test {i+1}: Expected {expected_list}, got {result_values}")
    
    dut._log.info(f"\nEdge Summary: {passed}/{total} tests passed")
    assert passed == total, f"Edge tests failed: {passed}/{total}"
