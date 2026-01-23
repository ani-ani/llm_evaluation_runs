import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_digit_distance(dut):
    """Test digit distance calculation for various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n1.value = 0
    dut.n2.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to compute expected result
    def expected_result(a, b):
        diff = abs(a - b)
        return sum(int(d) for d in str(diff))
    
    # Test cases from problem
    test_cases = [
        (1, 2),
        (23, 56),
        (123, 256),
        # Additional edge cases
        (0, 0),           # Zero difference
        (999, 999),       # Same large number
        (0, 999999999),   # Large difference
        (1234567890, 987654321),  # Large numbers
        (2147483647, 0),  # Max 32-bit signed
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n1_val, n2_val in test_cases:
        # Start computation
        dut.n1.value = n1_val
        dut.n2.value = n2_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout after 30 cycles)
        timeout = 30
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for n1={n1_val}, n2={n2_val}")
        
        # Check result
        actual = int(dut.result.value)
        expected = expected_result(n1_val, n2_val)
        
        if actual == expected:
            dut._log.info(f"PASS: n1={n1_val}, n2={n2_val}, expected={expected}, got={actual}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n1={n1_val}, n2={n2_val}, expected={expected}, got={actual}")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
