import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_newman_prime(dut):
    """Test Newman-Shanks-Williams prime calculation for n=0 to 8"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.n.value = 0
    
    # Reset sequence
    await Timer(15, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Expected values for n=0 to 8
    expected = [1, 1, 3, 7, 17, 41, 99, 239, 577]
    
    passed = 0
    total = 0
    
    for test_n in range(9):
        dut._log.info(f"Testing n={test_n}")
        dut.n.value = test_n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done for n={test_n}")
        
        result = int(dut.result.value)
        total += 1
        
        if result == expected[test_n]:
            dut._log.info(f"n={test_n}: PASSED (result={result})")
            passed += 1
        else:
            dut._log.error(f"n={test_n}: FAILED - Expected {expected[test_n]}, got {result}")
        
        # Wait for completion before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_newman_prime_specific(dut):
    """Test the specific examples from the problem statement"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.n.value = 0
    await Timer(15, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem statement
    test_cases = [(3, 7), (4, 17), (5, 41)]
    
    for n, expected_val in test_cases:
        dut._log.info(f"Testing newman_prime({n}) == {expected_val}")
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        result = int(dut.result.value)
        assert result == expected_val, f"FAILED: newman_prime({n}) = {result}, expected {expected_val}"
        dut._log.info(f"PASSED: newman_prime({n}) = {result}")
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info("All specific tests passed!")

@cocotb.test()
async def test_newman_prime_edge_cases(dut):
    """Test edge cases: n=0, n=1, and boundary n=8"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.n.value = 0
    await Timer(15, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=0 (should return 1)
    dut._log.info("Testing edge case n=0")
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    result = int(dut.result.value)
    assert result == 1, f"Edge case n=0 failed: got {result}, expected 1"
    dut._log.info("n=0: PASSED")
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test n=1 (should return 1)
    dut._log.info("Testing edge case n=1")
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    result = int(dut.result.value)
    assert result == 1, f"Edge case n=1 failed: got {result}, expected 1"
    dut._log.info("n=1: PASSED")
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test n=8 (boundary)
    dut._log.info("Testing boundary case n=8")
    dut.n.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    result = int(dut.result.value)
    assert result == 577, f"Boundary n=8 failed: got {result}, expected 577"
    dut._log.info("n=8: PASSED (result=577)")
    
    dut._log.info("All edge cases passed!")
