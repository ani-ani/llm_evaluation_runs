import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to check if a number is a palindrome
def is_palindrome(num):
    """Check if a number is a palindrome."""
    if num < 1:
        return False
    s = str(num)
    return s == s[::-1]

# Helper function to count even and odd palindromes
def count_palindromes(n):
    """Count even and odd palindromes in range [1, n]."""
    even_count = 0
    odd_count = 0
    for i in range(1, n + 1):
        if is_palindrome(i):
            if i % 2 == 0:
                even_count += 1
            else:
                odd_count += 1
    return even_count, odd_count

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_even_odd_palindrome(dut):
    """Test even_odd_palindrome module with various test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_even, expected_odd)
    test_cases = [
        (1, 0, 1),      # Edge case: n=1
        (3, 1, 2),      # Example 1
        (9, 4, 5),      # 1-9 all palindromes, 4 even (2,4,6,8), 5 odd (1,3,5,7,9)
        (12, 4, 6),     # Example 2
        (19, 4, 6),     # Additional test
        (25, 5, 6),     # Additional test
        (63, 6, 8),     # Additional test
        (123, 8, 13),   # Additional test
    ]
    
    for n, expected_even, expected_odd in test_cases:
        # Wait for IDLE state
        await RisingEdge(dut.clk)
        
        # Assert start signal
        dut.start.value = 1
        dut.n.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with cycle timeout
        max_cycles = 5000  # Should be enough for n=123
        done_found = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Timeout for n={n}: done signal not asserted after {max_cycles} cycles")
        
        # Read outputs
        if not is_value_defined(dut.even.value):
            raise TestFailure(f"even output is undefined (X/Z) for n={n}")
        if not is_value_defined(dut.odd.value):
            raise TestFailure(f"odd output is undefined (X/Z) for n={n}")
        
        actual_even = int(dut.even.value)
        actual_odd = int(dut.odd.value)
        
        # Verify results
        if actual_even != expected_even or actual_odd != expected_odd:
            raise TestFailure(
                f"Test failed for n={n}:\n"
                f"  Expected: (even={expected_even}, odd={expected_odd})\n"
                f"  Got: (even={actual_even}, odd={actual_odd})"
            )
        
        dut._log.info(f"Test passed for n={n}: even={actual_even}, odd={actual_odd}")
    
    # Final summary
    dut._log.info(f"All {len(test_cases)} tests passed [OK]")

@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_edge_case_minimal(dut):
    """Test minimal edge case with n=1."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=1
    dut.start.value = 1
    dut.n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for cycle in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    # Check result
    if int(dut.even.value) != 0 or int(dut.odd.value) != 1:
        raise TestFailure(f"Edge case failed: expected (0,1), got ({int(dut.even.value)}, {int(dut.odd.value)})")
    
    dut._log.info("Edge case n=1 passed [OK]")

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_no_palindrome(dut):
    """Test case where there might be few or no palindromes."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=2 (palindromes: 1, 2)
    dut.start.value = 1
    dut.n.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for cycle in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    # Check result: 1 is odd, 2 is even
    if int(dut.even.value) != 1 or int(dut.odd.value) != 1:
        raise TestFailure(f"Test failed: expected (1,1), got ({int(dut.even.value)}, {int(dut.odd.value)})")
    
    dut._log.info("Test n=2 passed [OK]")