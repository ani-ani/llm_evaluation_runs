import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_divisor_counter(dut):
    """Test divisor counter module with multiple test cases"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_n, expected_divisors)
    test_cases = [
        (15, 4),   # divisors: 1, 3, 5, 15
        (12, 6),   # divisors: 1, 2, 3, 4, 6, 12
        (9, 3),    # divisors: 1, 3, 9
        (7, 2),    # divisors: 1, 7
        (1, 1),    # divisors: 1
        (255, 8),  # divisors: 1, 3, 5, 15, 17, 51, 85, 255
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Set input
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 300  # max cycles
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout for n={n_val}, done never went high")
        
        # Read result
        result = int(dut.divisor_count.value)
        
        if result == expected:
            passed += 1
            print(f"Test passed: n={n_val}, result={result}, expected={expected}")
        else:
            raise TestFailure(f"Test failed: n={n_val}, result={result}, expected={expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
