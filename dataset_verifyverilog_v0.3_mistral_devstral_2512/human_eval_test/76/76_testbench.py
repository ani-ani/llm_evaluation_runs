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

async def wait_for_done(dut, max_cycles=20):
    """Wait for done signal to go high."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return cycle
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def python_check_power(x, n):
    """Python reference implementation for power check."""
    if x == 1:
        return True # 1 is n^0 for any n, or 1^anything
    if n == 1:
        return x == 1 # Only 1 is power of 1 (already handled above)
    if n == 0:
        return x == 0 or x == 1 # 0^1=0, 0^0=1
    if x == 0:
        return False # 0 is not a power of non-zero n (n^k is 0 only if n=0)
    
    # Iterative division check
    temp = x
    while temp > 1:
        if temp % n != 0:
            return False
        temp //= n
    return True

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_simple_power(dut):
    """Test the is_simple_power module."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.n.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for 8-bit inputs
    test_cases = [
        (16, 2, True),
        (143, 16, False),
        (4, 2, True),
        (9, 3, True),
        (16, 4, True),
        (24, 2, False),
        (128, 4, False),
        (12, 6, False),
        (1, 1, True),
        (1, 12, True),
        (0, 0, True),  # 0^0 = 1 convention or 0^1 = 0. Let's see hardware behavior. Usually 0^0=1 mathematically.
        (0, 5, False), # 0 is not a power of 5
        (5, 0, False), # n^0=1, n^1=0. x=5 != 1 or 0.
        (255, 255, True), # 255^1 = 255
        (64, 8, True), # 8^2 = 64
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} tests...")
    
    for x, n, expected in test_cases:
        # Input setup
        dut.x.value = x
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut, max_cycles=20)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test ({x}, {n}): Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        expected_val = 1 if expected else 0
        
        if result == expected_val:
            dut._log.info(f"Test ({x}, {n}): PASS (Result={result})")
            passed += 1
        else:
            raise TestFailure(f"Test ({x}, {n}): Expected {expected_val}, got {result}")
        
        # Small gap between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
