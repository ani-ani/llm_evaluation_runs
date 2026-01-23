import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_all_digits_odd(num):
    """Check if all digits of a number are odd."""
    if num == 0:
        return False
    while num > 0:
        digit = num % 10
        if digit % 2 == 0:
            return False
        num //= 10
    return True

def filter_numbers(numbers):
    """Filter numbers with only odd digits, return in input order."""
    result = []
    for n in numbers:
        if has_all_digits_odd(n):
            result.append(n)
    return result

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_unique_digits(dut):
    """Test unique_digits module with various test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.numbers.value = 0
    for i in range(8):
        dut.numbers[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ([15, 33, 1422, 1, 0, 0, 0, 0], [1, 15, 33]),
        ([152, 323, 1422, 10, 0, 0, 0, 0], []),
        ([12345, 2033, 111, 151, 0, 0, 0, 0], [111, 151]),
        ([135, 103, 31, 0, 0, 0, 0, 0], [31, 135]),
        ([1, 2, 3, 4, 5, 6, 7, 8], [1, 3, 5, 7]),
        ([11, 22, 33, 44, 55, 66, 77, 88], [11, 33, 55, 77]),
        ([13579, 24680, 11111, 33333, 0, 0, 0, 0], [11111, 33333]),
    ]
    
    for test_num, (input_nums, expected_output) in enumerate(test_cases):
        dut._log.info(f"Running test case {test_num + 1}: {input_nums}")
        
        # Load input array
        for i in range(8):
            dut.numbers[i].value = input_nums[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        max_cycles = 200
        completed = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                completed = True
                break
        
        if not completed:
            raise TestFailure(f"Test {test_num + 1}: Timeout after {max_cycles} cycles")
        
        # Read results
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Test {test_num + 1}: count is undefined")
        
        actual_count = int(dut.count.value)
        actual_result = []
        
        for i in range(8):
            if not is_value_defined(dut.result[i].value):
                raise TestFailure(f"Test {test_num + 1}: result[{i}] is undefined")
            if i < actual_count:
                actual_result.append(int(dut.result[i].value))
        
        # Verify
        if actual_count != len(expected_output):
            raise TestFailure(f"Test {test_num + 1}: Expected count {len(expected_output)}, got {actual_count}")
        
        for i, (actual, expected) in enumerate(zip(actual_result, expected_output)):
            if actual != expected:
                raise TestFailure(f"Test {test_num + 1}: result[{i}] expected {expected}, got {actual}")
        
        dut._log.info(f"Test {test_num + 1} passed: count={actual_count}, result={actual_result}")
    
    dut._log.info(f"All {len(test_cases)} tests passed [OK]")
