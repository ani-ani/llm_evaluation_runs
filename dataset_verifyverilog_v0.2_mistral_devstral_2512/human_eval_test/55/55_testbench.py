import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_fibonacci(dut):
    """Test Fibonacci number computation for n from 0 to 16"""
    
    # Expected Fibonacci values
    fib_values = [
        0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987
    ]
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from the problem
    test_cases = [10, 1, 8, 11, 12]
    
    passed = 0
    total = len(test_cases)
    
    for n in test_cases:
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        timeout = 20 * n + 50 if n > 0 else 50
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        actual = int(dut.result.value)
        expected = fib_values[n]
        
        print(f"n={n}: expected {expected}, got {actual}")
        assert actual == expected, f"Failed for n={n}: expected {expected}, got {actual}"
        passed += 1
        
        # Wait one more cycle to return to IDLE
        await RisingEdge(dut.clk)
    
    # Additional edge case tests
    print("
Additional edge case tests:")
    
    # Test n=0
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    if dut.done.value == 1:
        actual = int(dut.result.value)
        expected = 0
        print(f"n=0: expected {expected}, got {actual}")
        assert actual == expected
        passed += 1
    total += 1
    
    # Test n=16
    dut.n.value = 16
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    timeout = 400
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    actual = int(dut.result.value)
    expected = 987
    print(f"n=16: expected {expected}, got {actual}")
    assert actual == expected
    passed += 1
    total += 1
    
    print(f"
{passed}/{total} tests passed")
