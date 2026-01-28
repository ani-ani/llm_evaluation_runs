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

def q1616_to_float(q1616_value):
    """Convert Q16.16 fixed-point to float."""
    signed_val = int(q1616_value)
    # Handle two's complement for signed values if needed
    if signed_val >= 2**31:
        signed_val -= 2**32
    return signed_val / 65536.0

def float_to_q1616(f):
    """Convert float to Q16.16 fixed-point (unsigned)."""
    return int(f * 65536)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_fibonacci(dut):
    """Test Fibonacci module with multiple test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for initial propagation
    await Timer(10, units="ns")
    
    # Test cases: (n, expected_fib_value)
    test_cases = [
        (1, 1),      # fib(1) = 1
        (8, 21),     # fib(8) = 21
        (10, 55),    # fib(10) = 55
        (11, 89),    # fib(11) = 89
        (12, 144),   # fib(12) = 144
        (0, 0),      # Edge case: fib(0) = 0
        (2, 1),      # fib(2) = 1
        (5, 5),      # fib(5) = 5
        (15, 610),   # fib(15) = 610
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected_fib in test_cases:
        dut._log.info(f"Testing fib({n_val}) == {expected_fib}")
        
        # Set input
        dut.n.value = n_val
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with cycle-based timeout
        max_cycles = 256
        done_found = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if done is defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test fib({n_val}) timeout: done signal not asserted after {max_cycles} cycles")
        
        # Check output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test fib({n_val}) failed: result is undefined (X/Z)")
        
        # Read and convert result
        result_q1616 = int(dut.result.value)
        result_float = q1616_to_float(result_q1616)
        
        # Expected Q16.16 value
        expected_q1616 = float_to_q1616(expected_fib)
        
        # Compare
        if result_q1616 != expected_q1616:
            raise TestFailure(
                f"Test fib({n_val}) failed: expected {expected_fib} (Q16.16: 0x{expected_q1616:08X}), "
                f"got {result_float:.2f} (Q16.16: 0x{result_q1616:08X})"
            )
        
        dut._log.info(f"  Result: {result_float:.0f} (Q16.16: 0x{result_q1616:08X}) [PASS]")
        passed += 1
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nTest Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
