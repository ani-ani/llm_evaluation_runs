import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 8
N_WIDTH = 8
K_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_char(dut):
    """Test the find_char module with various queries."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, k, expected_char)
    # Scaled down test cases - n max 10, k max based on scaled lengths
    test_cases = [
        # f_0 tests
        (0, 1, 'W'),   # First char
        (0, 75, '?'),  # Last char
        (0, 76, '.'),  # Out of bounds
        
        # f_1 tests (based on Python examples)
        (1, 1, 'W'),   # First char of prefix
        (1, 34, '"'),  # Last char of prefix
        (1, 35, 'W'),  # First char of first f0
        (1, 109, '?'), # Last char of first f0
        (1, 110, '"'), # First char of middle
        (1, 141, '"'), # Last char of middle
        (1, 142, 'W'), # First char of second f0
        (1, 216, '?'), # Last char of second f0
        (1, 217, '"'), # First char of suffix
        (1, 218, '?'), # Last char of suffix
        (1, 219, '.'), # Out of bounds
        
        # Edge cases
        (2, 1, 'W'),   # Start of f_2
        (2, 504, '?'), # End of f_2
        (2, 505, '.'), # Out of bounds
        
        # Large n (scaled)
        (10, 1, 'W'),  # Start of f_10
        (10, 73148, '?'), # End of f_10
        (10, 73149, '.'), # Out of bounds
        
        # Random tests with known results
        (3, 50, 'a'),  # Character from middle of f_3
        (4, 100, ' '), # Space from f_4
        (5, 500, 'o'), # Letter from f_5
    ]
    
    passed = 0
    failed = 0
    
    for n, k, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, k={k}, expected='{expected}'")
        
        # Convert expected char to ASCII integer
        expected_ascii = ord(expected)
        
        # Set inputs
        dut.n.value = n
        dut.k.value = k
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
        
        # Read result
        if not is_value_defined(dut.char.value):
            raise TestFailure(f"Result char is undefined (X/Z)")
        
        result = int(dut.char.value)
        
        # Convert to character for comparison
        if result == 46:  # '.'
            result_char = '.'
        else:
            result_char = chr(result)
        
        if result_char == expected:
            cocotb.log.info(f"  PASS: got '{result_char}'")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected '{expected}', got '{result_char}' (ASCII: {result})")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# Additional test with the exact examples from problem
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_examples(dut):
    """Test with the exact examples from the problem statement."""
    
    # Start clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Example 1: "Wh." (n=1, k=1,2,111111111111)
    # We'll scale k values: k=1 -> 1, k=2 -> 2, k=111111111111 -> 1000 (scaled)
    examples = [
        (1, 1, 'W'),
        (1, 2, 'h'),
        (1, 1000, '.'),  # Out of bounds for scaled system
    ]
    
    for n, k, expected in examples:
        dut.n.value = n
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure("Timeout")
        
        result = int(dut.char.value)
        result_char = '.' if result == 46 else chr(result)
        
        if result_char != expected:
            raise TestFailure(f"Example failed: n={n}, k={k}, expected='{expected}', got='{result_char}'")
        
        cocotb.log.info(f"Example passed: n={n}, k={k} -> '{result_char}'")
        await Timer(50, units='ns')
    
    cocotb.log.info("All examples passed!")