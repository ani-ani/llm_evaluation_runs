import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_hopscotch_paths(dut):
    """Test hopscotch paths calculation"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.X.value = 0
    dut.Y.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down from original)
    # Format: (N, X, Y, expected_result)
    test_cases = [
        (2, 1, 1, 2),  # Original case
        (3, 1, 1, 4),  # Extended case
        (3, 2, 1, 1),  # Different constraints
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, x, y, expected in test_cases:
        # Set inputs
        dut.N.value = n
        dut.X.value = x
        dut.Y.value = y
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 2000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 2000:
            raise TestFailure(f"Timeout for test case N={n}, X={x}, Y={y}")
        
        # Check result
        result = int(dut.result.value)
        if result == expected:
            print(f"Test passed: N={n}, X={x}, Y={y}, Result={result} (expected {expected})")
            passed += 1
        else:
            print(f"Test FAILED: N={n}, X={x}, Y={y}, Result={result} (expected {expected})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
