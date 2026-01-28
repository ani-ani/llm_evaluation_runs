import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def count_even_odd_digits(number):
    """Python reference implementation for verification."""
    if number == 0:
        return (1, 0)  # 0 is even
    
    num = abs(number)
    even = 0
    odd = 0
    
    while num > 0:
        digit = num % 10
        if digit % 2 == 0:
            even += 1
        else:
            odd += 1
        num //= 10
    
    return (even, odd)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_even_odd_count(dut):
    """Test even_odd_count module with multiple test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        (7, (0, 1)),
        (-78, (1, 1)),
        (3452, (2, 2)),
        (346211, (3, 3)),
        (-345821, (3, 3)),
        (-2, (1, 0)),
        (-45347, (2, 3)),
        (0, (1, 0)),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_num, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input={input_num}, Expected={expected}")
        
        # Load input
        dut.num.value = input_num & 0xFFFFFFFF  # Convert to 32-bit unsigned for assignment
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation
        max_cycles = 20
        done_seen = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if signals are defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Timeout - done signal never asserted")
        
        # Read outputs
        if not is_value_defined(dut.even_count.value):
            raise TestFailure(f"Test {i+1}: even_count is undefined (X/Z)")
        if not is_value_defined(dut.odd_count.value):
            raise TestFailure(f"Test {i+1}: odd_count is undefined (X/Z)")
        
        even_result = int(dut.even_count.value)
        odd_result = int(dut.odd_count.value)
        
        if (even_result, odd_result) != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got ({even_result}, {odd_result})")
        
        dut._log.info(f"Test {i+1}: PASSED - Result ({even_result}, {odd_result})")
        passed += 1
        
        # Small gap between tests
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
    
    # Additional edge cases
    edge_cases = [
        (1234567890, (5, 5)),  # Maximum 10 digits
        (-13579, (0, 5)),      # All odd
        (24680, (5, 0)),       # All even
        (1, (0, 1)),           # Single digit odd
        (2, (1, 0)),           # Single digit even
    ]
    
    for i, (input_num, expected) in enumerate(edge_cases, start=len(test_cases)+1):
        dut._log.info(f"Edge Test {i}: Input={input_num}, Expected={expected}")
        
        dut.num.value = input_num & 0xFFFFFFFF
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_cycles = 20
        done_seen = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Edge Test {i}: Timeout")
        
        if not is_value_defined(dut.even_count.value) or not is_value_defined(dut.odd_count.value):
            raise TestFailure(f"Edge Test {i}: Output undefined")
        
        even_result = int(dut.even_count.value)
        odd_result = int(dut.odd_count.value)
        
        if (even_result, odd_result) != expected:
            raise TestFailure(f"Edge Test {i}: Expected {expected}, got ({even_result}, {odd_result})")
        
        dut._log.info(f"Edge Test {i}: PASSED")
        passed += 1
        total += 1
        
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Some tests failed. Passed: {passed}/{total}")
