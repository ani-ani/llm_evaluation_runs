import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def is_prime(n):
    """Check if a number is prime."""
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    for i in range(3, int(n**0.5) + 1, 2):
        if n % i == 0:
            return False
    return True

def sum_digits(n):
    """Sum the digits of a number."""
    if n == 0:
        return 0
    s = 0
    while n > 0:
        s += n % 10
        n //= 10
    return s

def skjkasdkd_reference(lst):
    """Reference implementation."""
    primes = [x for x in lst if is_prime(x)]
    if not primes:
        return 0
    largest_prime = max(primes)
    return sum_digits(largest_prime)

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_skjkasdkd(dut):
    """Test skjkasdkd module."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ([0,3,2,1,3,5,7,4,5,5,5,2,181,32,4,32,3,2,32,324,4,3], 10, "Example 1"),
        ([1,0,1,8,2,4597,2,1,3,40,1,2,1,2,4,2,5,1], 25, "Example 2"),
        ([1,3,1,32,5107,34,83278,109,163,23,2323,32,30,1,9,3], 13, "Example 3"),
        ([0,724,32,71,99,32,6,0,5,91,83,0,5,6], 11, "Example 4"),
        ([0,81,12,3,1,21], 3, "Example 5"),
        ([0,8,1,2,1,7], 7, "Example 6"),
        ([8191], 19, "Single prime 8191"),
        ([8191, 123456, 127, 7], 19, "Multiple primes"),
        ([127, 97, 8192], 10, "8192 not prime"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for lst, expected, description in test_cases:
        # Pad or truncate to 8 elements
        input_data = lst[:8] + [0] * (8 - len(lst[:8]))
        input_len = min(len(lst), 8)
        
        # Load array
        for i in range(8):
            dut.arr[i].value = input_data[i]
        dut.len.value = input_len
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 200
        done_found = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test '{description}': Timeout - done not asserted after {max_cycles} cycles")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test '{description}': Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test '{description}': expected {expected}, got {result}")
        
        dut._log.info(f"Test '{description}' passed: result={result}")
        passed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
