import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_largest_divisor(dut):
    """Test largest_divisor module with various test cases"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (3, 1),
        (7, 1),
        (10, 5),
        (100, 50),
        (49, 7),
        (2, 1),      # Edge case: prime number
        (1, 1),      # Edge case: 1 has no proper divisor
        (15, 5),     # Original example
        (255, 85),   # Max value: 255 = 3 * 85
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Load input
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (with timeout)
        timeout = 300  # Max cycles to wait
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout for n={n_val}: computation did not finish")
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"n={n_val}: expected {expected}, got {result}")
        
        passed += 1
        print(f"Test n={n_val}: PASSED (result={result})")
        
        # Wait a bit before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
